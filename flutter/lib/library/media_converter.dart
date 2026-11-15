import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:brentv/native_bridge.dart';
import 'download_queue.dart';
import 'models.dart';

/// Local conversion only. Apple remains the sole iOS playback engine.
class MediaConverter {
  static final instance = MediaConverter();
  static const channel = MethodChannel('brentv/media_converter');
  final Future<dynamic> Function(String, Map<String, dynamic>) invoke;
  final Future<int> Function(String) freeSpace;
  final String videoEncoder;
  Future<void> _tail = Future.value();
  final _canceled = <String>{};
  final _sessions = <String, String>{};
  int _sequence = 0;

  MediaConverter({
    Future<dynamic> Function(String, Map<String, dynamic>)? invoke,
    Future<int> Function(String)? freeSpace,
    this.videoEncoder = 'h264_videotoolbox',
  }) : invoke =
           invoke ?? ((method, args) => channel.invokeMethod(method, args)),
       freeSpace =
           freeSpace ?? ((path) => NativeBridge.instance.getDiskSpace(path));

  Future<void> finished(String id) async {
    await invoke('discardReceipt', {'id': id});
  }

  Future<void> cancel(String id) async {
    _canceled.add(id);
    final session = _sessions[id];
    if (session != null) await invoke('cancel', {'id': session});
  }

  Future<void> prepare(DownloadJob job, VoidCallback changed) {
    _canceled.remove(job.id);
    final next = _tail.then((_) => _prepare(job, changed));
    _tail = next.catchError((_) {});
    return next;
  }

  void _check(DownloadJob job) {
    if (_canceled.contains(job.id) || job.state != DownloadState.converting) {
      throw const DownloadFailure(
        'MP4 preparation paused. Your download is kept.',
      );
    }
  }

  Future<dynamic> _call(
    DownloadJob job,
    String method,
    Map<String, dynamic> args,
  ) async {
    _check(job);
    final id = '${job.id}:${_sequence++}';
    _sessions[job.id] = id;
    try {
      return await invoke(method, {'id': id, ...args}).timeout(
        method == 'probe'
            ? const Duration(seconds: 30)
            : const Duration(hours: 6),
        onTimeout: () async {
          await invoke('cancel', {'id': id});
          throw const DownloadFailure(
            'MP4 preparation took too long. Your download is kept.',
          );
        },
      );
    } finally {
      _sessions.remove(job.id);
    }
  }

  Future<Map<String, dynamic>> _probe(DownloadJob job, String file) async {
    final raw = await _call(job, 'probe', {
      'arguments': [
        '-v',
        'quiet',
        '-protocol_whitelist',
        'file,pipe',
        '-probesize',
        '5000000',
        '-analyzeduration',
        '5000000',
        '-show_entries',
        'stream=index,codec_type,codec_name,codec_tag_string,pix_fmt,duration:format=format_name,duration',
        '-of',
        'json',
        '-i',
        file,
      ],
    });
    return _mediaInfo(raw as String);
  }

  Map<String, dynamic> _mediaInfo(String raw) {
    // FFmpegKit merges stdout and stderr. Accept a complete media JSON object
    // even if the wrapper adds diagnostics before or after it.
    if (raw.length > 4 * 1024 * 1024) {
      throw const FormatException('Probe response too large');
    }
    for (
      var start = raw.indexOf('{');
      start >= 0;
      start = raw.indexOf('{', start + 1)
    ) {
      var depth = 0, quoted = false, escaped = false;
      for (var i = start; i < raw.length; i++) {
        final c = raw[i];
        if (quoted) {
          if (escaped) {
            escaped = false;
          } else if (c == r'\') {
            escaped = true;
          } else if (c == '"') {
            quoted = false;
          }
        } else if (c == '"') {
          quoted = true;
        } else if (c == '{') {
          depth++;
        } else if (c == '}' && --depth == 0) {
          try {
            final value = jsonDecode(raw.substring(start, i + 1));
            if (value is Map && value['streams'] is List) {
              return Map<String, dynamic>.from(value);
            }
          } on FormatException {
            /* Try the next object, never expose log text. */
          }
          break;
        }
      }
    }
    throw const FormatException('No complete media information');
  }

  Future<void> _prepare(DownloadJob job, VoidCallback changed) async {
    Directory? work;
    Timer? poll;
    try {
      _check(job);
      final destination = job.conversionDestination;
      if (await invoke('published', {
            'id': job.id,
            'destination': destination,
          }) ==
          true) {
        job.conversionProgress = 1;
        return;
      }
      final input = File(job.conversionSource ?? job.part);
      if (!await input.exists()) {
        throw const DownloadFailure(
          'The downloaded file is missing. Download it again.',
        );
      }
      final info = await _probe(job, input.path);
      final plan = Mp4Plan(info);
      if (plan.video == null) {
        throw const DownloadFailure(
          'This download has no readable video track.',
        );
      }
      _check(job);
      var output = input.path;
      final isMp4 = '${(info['format'] as Map?)?['format_name']}'
          .split(',')
          .contains('mp4');
      if (!isMp4 ||
          !plan.copyVideo ||
          !plan.copyAudio ||
          (plan.video?['codec_name'] == 'hevc' &&
              plan.video?['codec_tag_string'] != 'hvc1')) {
        final bytes = await input.length();
        final reserve =
            math.max(
              bytes,
              (plan.duration * (8000000 + plan.audioCount * 192000) / 8).ceil(),
            ) +
            64 * 1024 * 1024;
        if (await freeSpace(input.parent.path) < reserve) {
          throw const DownloadFailure(
            'Not enough free space to prepare MP4. Your download is kept; free space and retry.',
          );
        }
        work = await Directory.systemTemp.createTemp('brentv-convert-');
        output = '${work.path}/video.mp4';
        var lowSpace = false, polling = false;
        poll = Timer.periodic(const Duration(seconds: 1), (_) async {
          if (polling) return;
          polling = true;
          try {
            final id = _sessions[job.id];
            if (id == null) return;
            final progress = await invoke('progress', {'id': id}) as Map;
            final seconds = (progress['seconds'] as num?)?.toDouble() ?? 0;
            job.conversionProgress = plan.duration > 0
                ? (seconds / plan.duration).clamp(0, 0.99)
                : null;
            changed();
            if (await freeSpace(input.parent.path) < 32 * 1024 * 1024) {
              lowSpace = true;
              await invoke('cancel', {'id': id});
            }
          } catch (_) {
            /* Completion reports any real conversion failure. */
          } finally {
            polling = false;
          }
        });
        var ok = false;
        var outputBudget = 0;
        for (final fullTranscode in [false, true]) {
          _check(job);
          if (lowSpace) break;
          final budget = await freeSpace(input.parent.path) - 32 * 1024 * 1024;
          if (budget <= 0) break;
          outputBudget = budget;
          final result = await _call(job, 'run', {
            'arguments': plan.arguments(
              input.path,
              output,
              videoEncoder: videoEncoder,
              forceTranscode: fullTranscode,
              maxBytes: budget,
            ),
          });
          if (result is Map && result['status'] == 'canceled') {
            if (lowSpace) {
              throw const DownloadFailure(
                'Not enough free space to prepare MP4. Your source is kept.',
              );
            }
            throw const ConversionPaused();
          }
          ok =
              result == true ||
              (result is Map && result['status'] == 'success');
          if (ok) break;
        }
        _check(job);
        if (!ok || lowSpace) {
          throw DownloadFailure(
            lowSpace
                ? 'MP4 preparation ran out of free space. Your download is kept; free space and retry.'
                : 'Could not prepare this video as MP4. Your download is kept; retry with brenTV open.',
          );
        }
        if (plan.duration == 0 &&
            await File(output).length() >= outputBudget * 0.98) {
          throw const DownloadFailure(
            'The MP4 reached its size limit before completion could be verified. Your original is kept.',
          );
        }
        final verified = Mp4Plan(await _probe(job, output));
        if (verified.video == null ||
            !verified.copyVideo ||
            !verified.copyAudio ||
            (plan.duration > 0 &&
                (verified.duration - plan.duration).abs() >
                    math.max(0.25, math.min(1, plan.duration * 0.01)))) {
          throw const DownloadFailure(
            'The MP4 could not be verified. Your original download is kept.',
          );
        }
      }
      _check(job);
      if (await File(destination).exists()) {
        throw const DownloadFailure(
          'An MP4 already uses this name. Move it before retrying.',
        );
      }
      await invoke('publish', {
        'id': job.id,
        'source': output,
        'destination': destination,
      });
      job.conversionProgress = 1;
    } on DownloadFailure {
      rethrow;
    } catch (_) {
      throw const DownloadFailure(
        'Could not prepare MP4. Your original download is kept; retry with brenTV open.',
      );
    } finally {
      poll?.cancel();
      if (work != null && await work.exists()) {
        await work.delete(recursive: true);
      }
      _canceled.remove(job.id);
    }
  }

  /// Interrupted work is private cache data, never the downloaded original.
  Future<void> clearInterruptedFiles() async {
    try {
      await for (final entry in Directory.systemTemp.list(followLinks: false)) {
        if (entry is Directory &&
            entry.path.split('/').last.startsWith('brentv-convert-')) {
          try {
            await entry.delete(recursive: true);
          } on FileSystemException {
            /* iOS can reclaim inaccessible cache files. */
          }
        }
      }
    } on FileSystemException {
      /* Cache cleanup must not prevent startup. */
    }
  }
}

class Mp4Plan {
  final Map<String, dynamic> info;
  Mp4Plan(this.info);
  List<Map> get streams =>
      (info['streams'] as List? ?? []).whereType<Map>().toList();
  Map? get video =>
      streams.where((s) => s['codec_type'] == 'video').firstOrNull;
  int get audioCount => streams.where((s) => s['codec_type'] == 'audio').length;
  bool get copyVideo =>
      (video?['codec_name'] == 'hevc' &&
          ['yuv420p', 'yuv420p10le'].contains(video?['pix_fmt'])) ||
      (video?['codec_name'] == 'h264' &&
          ['yuv420p', 'yuvj420p'].contains(video?['pix_fmt']));
  bool get copyAudio => streams
      .where((s) => s['codec_type'] == 'audio')
      .every((s) => s['codec_name'] == 'aac');
  double get duration {
    final value =
        double.tryParse('${(info['format'] as Map?)?['duration']}') ??
        double.tryParse('${video?['duration']}') ??
        0;
    return value.isFinite && value > 0 ? value : 0;
  }

  List<String> arguments(
    String input,
    String output, {
    String videoEncoder = 'h264_videotoolbox',
    bool forceTranscode = false,
    required int maxBytes,
  }) {
    final encodeVideo = forceTranscode || !copyVideo;
    return [
      '-hide_banner',
      '-loglevel',
      'error',
      '-nostdin',
      '-y',
      '-protocol_whitelist',
      'file,pipe',
      '-i',
      input,
      '-map',
      '0:v:0',
      '-map',
      '0:a?',
      for (final s in streams.where(
        (s) =>
            s['codec_type'] == 'subtitle' &&
            [
              'subrip',
              'ass',
              'ssa',
              'webvtt',
              'mov_text',
            ].contains(s['codec_name']),
      )) ...['-map', '0:${s['index']}'],
      '-map_metadata',
      '0',
      '-c:v',
      encodeVideo ? videoEncoder : 'copy',
      if (encodeVideo) ...[
        '-b:v',
        '8M',
        '-pix_fmt',
        'yuv420p',
        '-vf',
        'scale=trunc(iw/2)*2:trunc(ih/2)*2',
        if (videoEncoder == 'h264_videotoolbox') ...['-allow_sw', '1'],
      ] else if (video?['codec_name'] == 'hevc') ...[
        '-tag:v',
        'hvc1',
      ],
      '-c:a',
      !forceTranscode && copyAudio ? 'copy' : 'aac',
      if (!forceTranscode && copyAudio) ...['-bsf:a', 'aac_adtstoasc'],
      if (forceTranscode || !copyAudio) ...['-b:a', '192k', '-ac', '2'],
      '-c:s',
      'mov_text',
      '-movflags',
      '+faststart',
      '-fs',
      '$maxBytes',
      '-f',
      'mp4',
      output,
    ];
  }
}
