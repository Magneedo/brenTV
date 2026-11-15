import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:brentv/generated/generated_proto.pb.dart' as pb;
import 'package:fixnum/fixnum.dart';
import 'models.dart';

class ConversionPaused extends DownloadFailure {
  const ConversionPaused()
    : super(
        'MP4 preparation paused. Keep brenTV open and tap Resume; your download is kept.',
      );
}

class DownloadFailure implements Exception {
  final String message;
  const DownloadFailure(this.message);
}

Future<int> availableDiskBytes(String folder) async {
  // Linux df reads the actual target filesystem, including mounted Videos.
  final result = await Process.run('df', [
    '--output=avail',
    '-B1',
    folder,
  ]).timeout(const Duration(seconds: 5));
  if (result.exitCode != 0) {
    throw const DownloadFailure(
      'Could not check free disk space. Check the destination folder.',
    );
  }
  final bytes = int.tryParse(
    (result.stdout as String).trim().split('\n').last.trim(),
  );
  if (bytes == null) {
    throw const DownloadFailure('Could not check free disk space.');
  }
  return bytes;
}

/// The core's transfer engine. Tests leave it out and use the dart:io
/// transfer below, which is correct but several times slower.
class NativeTransfer {
  final Future<pb.DownloadStatus> Function(pb.DownloadRequest) start;
  final Future<pb.DownloadStatus> Function(String id) progress;
  final Future<void> Function(String id) stop;
  const NativeTransfer({
    required this.start,
    required this.progress,
    required this.stop,
  });
}

class DownloadQueue extends ChangeNotifier {
  final NativeTransfer? native;
  final Future<void> Function(DownloadJob, VoidCallback)? makePlayable;
  final Future<void> Function(String)? cancelConversion;
  final Future<void> Function(String)? conversionFinished;
  final Future<pb.TransferInfo> Function(int) resolve;
  final Future<void> Function(String) save;
  final MediaPreferences Function() preferences;
  final bool Function(int sourceId, int extra) canStart;
  final Future<int> Function(String) freeSpace;
  final List<DownloadJob> jobs = [];
  final Map<String, Future<void>> _running = {};
  final Map<String, HttpClient> _clients = {};
  Future<void>? _write;
  Timer? _timer;
  bool _pumping = false, _closed = false;
  String? storageError;
  DownloadQueue({
    required this.resolve,
    required this.save,
    required this.preferences,
    required this.canStart,
    Future<int> Function(String)? freeSpace,
    this.native,
    this.makePlayable,
    this.cancelConversion,
    this.conversionFinished,
  }) : freeSpace = freeSpace ?? availableDiskBytes;
  int connections(int source) => jobs
      .where(
        (j) =>
            j.sourceId == source &&
            _running.containsKey(j.id) &&
            j.state == DownloadState.downloading,
      )
      .length;
  Future<void> initialize(
    String value, {
    String Function(String)? restorePath,
  }) async {
    try {
      final list = value.isEmpty ? [] : jsonDecode(value) as List;
      jobs.addAll(
        list.map((m) {
          final data = Map<String, dynamic>.from(m);
          if (restorePath != null) {
            data['file'] = restorePath(data['file'] as String);
            if (data['conversionTarget'] is String) {
              data['conversionTarget'] = restorePath(
                data['conversionTarget'] as String,
              );
            }
            if (data['conversionSource'] is String) {
              data['conversionSource'] = restorePath(
                data['conversionSource'] as String,
              );
            }
          }
          return DownloadJob.fromJson(data);
        }),
      );
      for (final job in jobs) {
        // Repair in-flight jobs from the first converter beta without losing
        // their catalog link to the original completed file.
        if (job.state != DownloadState.completed &&
            job.conversionSource != null &&
            !job.conversionSourceIsPartial) {
          if (job.conversionTarget == null &&
              job.file != job.conversionSource) {
            job.conversionTarget = job.file;
          }
          job.file = job.conversionSource!;
        }
        if (makePlayable != null &&
            job.readyToConvert &&
            job.state != DownloadState.completed) {
          _mp4Target(job);
        }
        if (job.state == DownloadState.downloading ||
            job.state == DownloadState.converting) {
          job.state = DownloadState.queued;
        }
        // Earlier versions kept the original beside its finished MP4.
        final leftover = job.conversionSource;
        if (makePlayable != null &&
            job.state == DownloadState.completed &&
            leftover != null &&
            !job.conversionSourceIsPartial &&
            leftover != job.file &&
            job.file.toLowerCase().endsWith('.mp4') &&
            await File(job.file).exists()) {
          try {
            if (await File(leftover).exists()) await File(leftover).delete();
            job.conversionSource = null;
          } on FileSystemException {
            /* Try again on the next launch. */
          }
        }
        if (!job.readyToConvert &&
            job.state != DownloadState.completed &&
            await File(job.file).exists() &&
            job.total > 0 &&
            await File(job.file).length() == job.total &&
            !await File(job.part).exists()) {
          job.state = DownloadState.completed;
          job.bytes = job.total;
        }
      }
      await persist();
    } catch (_) {
      storageError =
          'Could not load saved downloads. Restart before making changes.';
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => pump());
    unawaited(pump());
  }

  Future<void> persist() {
    final snapshot = jsonEncode(jobs.map((j) => j.toJson()).toList());
    final next = (_write ?? Future<void>.value())
        .catchError((_) {})
        .then((_) => save(snapshot));
    _write = next;
    return next;
  }

  Future<void> add(DownloadJob job) async {
    if (storageError != null || _closed) {
      throw DownloadFailure(storageError ?? 'The app is closing.');
    }
    // Check disk first, then reserve synchronously. Concurrent Add actions
    // must see each other's jobs before either transfer can start.
    if (await File(job.file).exists() || await File(job.part).exists()) {
      throw const DownloadFailure(
        'A file already uses this name. Rename or move it before downloading.',
      );
    }
    if (jobs.any(
      (j) =>
          j.id == job.id ||
          (job.channelId > 0 &&
              j.channelId == job.channelId &&
              j.sourceId == job.sourceId &&
              j.state != DownloadState.canceled),
    )) {
      throw const DownloadFailure('This video is already in Downloads.');
    }
    if (jobs.any((j) => j.conversionDestination == job.conversionDestination)) {
      throw const DownloadFailure(
        'A file already uses this name. Rename or move it before downloading.',
      );
    }
    jobs.add(job);
    try {
      await persist();
    } catch (_) {
      jobs.remove(job);
      rethrow;
    }
    notifyListeners();
    unawaited(pump());
  }

  Future<void> pump() async {
    if (_pumping || _closed || storageError != null) return;
    _pumping = true;
    try {
      for (final job in [...jobs]) {
        if (_running.length >= preferences().concurrentDownloads) break;
        if (job.state != DownloadState.queued ||
            job.retryAt > unixNow ||
            (!job.readyToConvert && !canStart(job.sourceId, 1))) {
          continue;
        }
        job.state = job.readyToConvert
            ? DownloadState.converting
            : DownloadState.downloading;
        // Reserve synchronously before the first await, so other transfers see it.
        final done = Completer<void>();
        _running[job.id] = done.future;
        unawaited(
          _run(job).whenComplete(() {
            _running.remove(job.id);
            _clients.remove(job.id);
            done.complete();
            notifyListeners();
          }),
        );
      }
    } finally {
      _pumping = false;
    }
  }

  void _mp4Target(DownloadJob job) {
    if (job.conversionTarget != null ||
        job.file.toLowerCase().endsWith('.mp4')) {
      return;
    }
    // The old partial keeps its exact name and resume offset. Only the final
    // destination changes after the transfer has been verified.
    job.conversionSource ??= job.part;
    job.conversionSourceIsPartial = true;
    job.file = '${job.file.replaceFirst(RegExp(r'\.[^./]+$'), '')}.mp4';
  }

  Future<void> _run(DownloadJob job) async {
    try {
      await persist();
      if (!job.readyToConvert) {
        final data = await resolve(job.channelId);
        if (job.state != DownloadState.downloading) return;
        if (data.identity != job.identity ||
            data.channel.sourceId.toInt() != job.sourceId) {
          throw const DownloadFailure(
            'The source or video changed. Cancel this job and download it again.',
          );
        }
        if (!canStart(job.sourceId, 0)) {
          job.state = DownloadState.queued;
          await persist();
          return;
        }
        await _transfer(job, data.channel);
        if (job.state != DownloadState.downloading) return;
        final file = File(job.part);
        if (job.total <= 0 || await file.length() != job.total) {
          throw const DownloadFailure(
            'The downloaded size does not match the server. Retry to resume.',
          );
        }
        if (makePlayable != null) {
          job.readyToConvert = true;
          _mp4Target(job);
          await persist();
        }
      }
      if (job.state != DownloadState.downloading &&
          job.state != DownloadState.converting) {
        return;
      }
      if (makePlayable != null) {
        _mp4Target(job);
        job.state = DownloadState.converting;
        job.speed = 0;
        await persist();
        if (job.state != DownloadState.converting) return;
        notifyListeners();
        await makePlayable!(job, notifyListeners);
        if (job.state != DownloadState.converting) return;
      } else {
        if (await File(job.file).exists()) {
          throw const DownloadFailure(
            'The destination already exists. Move it before retrying.',
          );
        }
        await File(job.part).rename(job.file);
      }
      final input = job.conversionSource ?? job.part;
      job.file = job.conversionDestination;
      job.conversionTarget = null;
      // The verified MP4 replaces what it was made from, including an
      // existing MKV the user asked to convert.
      final removeInput = input != job.file;
      if (makePlayable != null) {
        job.conversionSource = null;
        job.conversionSourceIsPartial = false;
      }
      job.bytes = job.total;
      job.state = DownloadState.completed;
      job.speed = 0;
      job.error = null;
      job.attempts = 0;
      try {
        await persist();
      } catch (_) {
        job.state = DownloadState.failed;
        job.error =
            'The finished file is kept, but download state could not be saved. Restart the app before downloading.';
        storageError = job.error;
        rethrow;
      }
      // Commit the MP4 job first; a failed/canceled conversion keeps its input.
      if (makePlayable != null) {
        if (removeInput && await File(input).exists()) {
          await File(input).delete();
        }
        try {
          await conversionFinished?.call(job.id);
        } catch (_) {
          /* A stale receipt is safe. */
        }
      }
    } catch (e) {
      if (job.state == DownloadState.downloading ||
          job.state == DownloadState.converting) {
        job.speed = 0;
        job.attempts++;
        job.error = e is DownloadFailure
            ? e.message
            : 'Download interrupted. Check the connection and folder, then retry.';
        job.state = e is ConversionPaused
            ? DownloadState.paused
            : (e is DownloadFailure || job.attempts >= 4
                  ? DownloadState.failed
                  : DownloadState.queued);
        job.retryAt = unixNow + (1 << job.attempts.clamp(1, 5));
        try {
          await persist();
        } catch (_) {
          storageError =
              'Could not save download state. Check free disk space.';
        }
      }
    } finally {
      _clients[job.id]?.close(force: true);
      notifyListeners();
    }
  }

  int _reserved(DownloadJob job) => jobs
      .where(
        (other) =>
            other.id != job.id &&
            other.state == DownloadState.downloading &&
            other.total > other.bytes,
      )
      .fold<int>(0, (sum, other) => sum + other.total - other.bytes);

  void _apply(DownloadJob job, pb.DownloadStatus status) {
    job.bytes = status.bytes.toInt();
    job.total = status.total.toInt();
    job.etag = status.hasEtag() ? status.etag : null;
    job.lastModified = status.hasLastModified() ? status.lastModified : null;
  }

  Future<void> _nativeTransfer(
    DownloadJob job,
    pb.Channel channel,
    NativeTransfer native,
  ) async {
    final h = channel.playbackHeaders;
    var checkpoint = job.bytes, stamp = DateTime.now().millisecondsSinceEpoch;
    var polling = false;
    final poll = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (polling) return;
      polling = true;
      try {
        // A stop requested before the core registered the transfer is lost.
        if (job.state != DownloadState.downloading) await native.stop(job.id);
        final status = await native.progress(job.id);
        if (!status.active || job.state != DownloadState.downloading) return;
        _apply(job, status);
        if (job.total > 0) job.error = null;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (job.bytes < checkpoint) checkpoint = job.bytes;
        job.speed = (job.bytes - checkpoint) * 1000 / (now - stamp);
        stamp = now;
        checkpoint = job.bytes;
        await persist();
        notifyListeners();
      } catch (_) {
        /* The transfer's own result reports real failures. */
      } finally {
        polling = false;
      }
    });
    try {
      final status = await native.start(
        pb.DownloadRequest(
          id: job.id,
          url: channel.url,
          partPath: job.part,
          userAgent: h.hasUserAgent() ? h.userAgent : null,
          referrer: h.hasReferrer() ? h.referrer : null,
          httpOrigin: h.hasHttpOrigin() ? h.httpOrigin : null,
          ignoreSsl: h.ignoreSsl,
          etag: job.etag,
          lastModified: job.lastModified,
          total: Int64(job.total),
          reservedBytes: Int64(_reserved(job)),
        ),
      );
      _apply(job, status);
      if (status.hasFailure()) throw DownloadFailure(status.failure);
    } finally {
      poll.cancel();
    }
  }

  Future<void> _transfer(DownloadJob job, pb.Channel channel) async {
    if (native case final NativeTransfer native) {
      return _nativeTransfer(job, channel, native);
    }
    final uri = Uri.parse(channel.url);
    if (!{'http', 'https'}.contains(uri.scheme)) {
      throw const DownloadFailure('Only HTTP videos can be downloaded.');
    }
    await File(job.file).parent.create(recursive: true);
    final part = File(job.part);
    var offset = await part.exists() ? await part.length() : 0;
    // Many providers send neither ETag nor Last-Modified. Their partial files
    // are then validated by the total size the server reports on resume.
    if (offset > 0 &&
        job.etag == null &&
        job.lastModified == null &&
        job.total <= 0) {
      await part.writeAsBytes([]);
      offset = 0;
    }
    for (var restart = 0; restart < 2; restart++) {
      if (job.state != DownloadState.downloading) return;
      final client = HttpClient()
        ..autoUncompress = false
        ..connectionTimeout = const Duration(seconds: 15);
      _clients[job.id] = client;
      final h = channel.playbackHeaders;
      if (h.ignoreSsl) {
        client.badCertificateCallback = (_, _, _) => true;
      }
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 20));
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      if (h.hasUserAgent()) {
        request.headers.set(HttpHeaders.userAgentHeader, h.userAgent);
      }
      if (h.hasReferrer()) {
        request.headers.set(HttpHeaders.refererHeader, h.referrer);
      }
      if (h.hasHttpOrigin()) request.headers.set('Origin', h.httpOrigin);
      if (offset > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
        final validator = job.etag ?? job.lastModified;
        if (validator != null) {
          request.headers.set(HttpHeaders.ifRangeHeader, validator);
        }
      }
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final etag = response.headers.value(HttpHeaders.etagHeader);
      final strongEtag = etag != null && !etag.startsWith('W/') ? etag : null;
      final modified = response.headers.value(HttpHeaders.lastModifiedHeader);
      final range =
          response.headers.value(HttpHeaders.contentRangeHeader) ?? '';
      if (response.statusCode == 416) {
        final size = int.tryParse(range.replaceFirst('bytes */', ''));
        final valid = job.etag != null
            ? strongEtag == job.etag
            : modified != null && modified == job.lastModified;
        client.close(force: true);
        if (offset > 0 && size == offset && size == job.total && valid) {
          job.bytes = offset;
          return;
        }
        await part.writeAsBytes([]);
        offset = 0;
        job.total = 0;
        job.etag = null;
        job.lastModified = null;
        continue;
      }
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException('HTTP status ${response.statusCode}');
      }
      if (response.headers.value(HttpHeaders.contentEncodingHeader)
          case final String encoding when encoding != 'identity') {
        throw const DownloadFailure(
          'The server compressed this file; a safe resumable download is unavailable.',
        );
      }
      final type = response.headers.contentType?.mimeType ?? '';
      if (type.contains('mpegurl') ||
          type.contains('text/html') ||
          type.contains('application/json')) {
        throw const DownloadFailure(
          'This URL is a playlist or webpage. Downloads require a direct video file.',
        );
      }
      if (response.statusCode == 206) {
        final match = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$').firstMatch(range);
        if (match == null || int.parse(match[1]!) != offset) {
          throw const DownloadFailure(
            'The server returned an invalid resume range.',
          );
        }
        final end = int.parse(match[2]!), total = int.parse(match[3]!);
        if (end < offset ||
            end >= total ||
            (response.contentLength >= 0 &&
                response.contentLength != end - offset + 1)) {
          throw const DownloadFailure(
            'The server returned an invalid file size.',
          );
        }
        final changed =
            offset > 0 &&
            ((job.etag != null
                    ? job.etag != strongEtag
                    : job.lastModified != modified) ||
                (job.total > 0 && job.total != total));
        if (changed) {
          client.close(force: true);
          await part.writeAsBytes([]);
          offset = 0;
          job.etag = null;
          job.lastModified = null;
          job.total = 0;
          continue;
        }
        job.total = total;
      } else {
        offset = 0;
        job.total = response.contentLength;
      }
      if (job.total <= 0) {
        throw const DownloadFailure(
          'The server did not provide a file size. A complete download cannot be verified.',
        );
      }
      job.etag = strongEtag;
      job.lastModified = modified;
      job.bytes = offset;
      job.error = null;
      final available = await freeSpace(part.parent.path);
      final reserved = _reserved(job);
      if (available < job.total - offset + reserved + 64 * 1024 * 1024) {
        throw const DownloadFailure(
          'Not enough free disk space for this video. Free space or choose another folder in Settings > Downloads.',
        );
      }
      if (job.state != DownloadState.downloading) return;
      final output = await part.open(
        mode: offset == 0 ? FileMode.write : FileMode.append,
      );
      final pending = BytesBuilder(copy: false);
      var stamp = DateTime.now().millisecondsSinceEpoch, checkpoint = offset;
      try {
        await for (final chunk in response.timeout(
          const Duration(seconds: 30),
        )) {
          if (job.state != DownloadState.downloading) break;
          if (job.bytes + chunk.length > job.total) {
            throw const DownloadFailure(
              'The server sent more data than the declared file size.',
            );
          }
          // Sockets deliver a few kilobytes at a time; writing each piece
          // separately makes the disk the bottleneck.
          pending.add(chunk);
          job.bytes += chunk.length;
          if (pending.length >= 1 << 20) {
            await output.writeFrom(pending.takeBytes());
          }
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - stamp >= 1000) {
            job.speed = (job.bytes - checkpoint) * 1000 / (now - stamp);
            stamp = now;
            checkpoint = job.bytes;
            if (pending.isNotEmpty) {
              await output.writeFrom(pending.takeBytes());
            }
            await output.flush();
            await persist();
            notifyListeners();
          }
        }
      } finally {
        try {
          if (pending.isNotEmpty) {
            await output.writeFrom(pending.takeBytes());
          }
          await output.flush();
        } finally {
          await output.close();
          client.close(force: true);
        }
      }
      if (job.state == DownloadState.downloading && job.bytes != job.total) {
        throw const HttpException('Incomplete file');
      }
      return;
    }
    throw const DownloadFailure(
      'The server changed the file while resuming. Retry to start again.',
    );
  }

  Future<void> pause(DownloadJob job, {bool requeue = false}) async {
    final wasConverting = job.state == DownloadState.converting;
    job.state = DownloadState.paused;
    if (wasConverting) await cancelConversion?.call(job.id);
    _clients[job.id]?.close(force: true);
    if (!wasConverting && _running.containsKey(job.id)) {
      await native?.stop(job.id);
    }
    final running = _running[job.id];
    if (running != null) await running;
    job.speed = 0;
    if (requeue) {
      job.state = DownloadState.queued;
      job.retryAt = unixNow + 2;
    }
    await persist();
    notifyListeners();
  }

  Future<void> resume(DownloadJob job) async {
    if (job.state == DownloadState.completed || _running.containsKey(job.id)) {
      return;
    }
    job.state = DownloadState.queued;
    job.error = null;
    job.attempts = 0;
    job.retryAt = 0;
    await persist();
    notifyListeners();
    unawaited(pump());
  }

  Future<void> cancel(DownloadJob job, {bool deleteCompleted = false}) async {
    await pause(job);
    if (!deleteCompleted &&
        job.conversionSource != null &&
        !job.conversionSourceIsPartial) {
      // Cancel only the conversion; the original catalog download remains.
      job.file = job.conversionSource!;
      job.conversionSource = null;
      job.conversionTarget = null;
      job.readyToConvert = false;
      job.conversionProgress = null;
      job.state = DownloadState.completed;
      job.error = null;
      await persist();
      notifyListeners();
      return;
    }
    final partial = job.conversionSourceIsPartial
        ? job.conversionSource!
        : job.part;
    if (await File(partial).exists()) await File(partial).delete();
    if (deleteCompleted && await File(job.file).exists()) {
      await File(job.file).delete();
    }
    jobs.remove(job);
    await persist();
    notifyListeners();
  }

  Future<void> convertFile(String path, {String? title}) async {
    if (makePlayable == null) {
      throw const DownloadFailure('MP4 conversion is available on iPhone.');
    }
    if (jobs.any(
      (j) => j.conversionSource == path && j.state != DownloadState.completed,
    )) {
      throw const DownloadFailure(
        'This video is already being prepared. Open the progress indicator.',
      );
    }
    final input = File(path);
    final target = '${path.replaceFirst(RegExp(r'\.[^./]+$'), '')}.mp4';
    if (await File(target).exists() ||
        await File('$target.part').exists() ||
        jobs.any(
          (j) => j.conversionDestination == target || j.file == target,
        )) {
      throw const DownloadFailure('An MP4 or download already uses this name.');
    }
    final size = await input.length();
    final existing = jobs
        .where((j) => j.file == path && j.state == DownloadState.completed)
        .firstOrNull;
    if (existing != null) {
      final previousSource = existing.conversionSource;
      final previousReady = existing.readyToConvert;
      existing.conversionSource = path;
      existing.conversionTarget = target;
      existing.readyToConvert = true;
      existing.state = DownloadState.queued;
      try {
        await persist();
      } catch (_) {
        existing.conversionTarget = null;
        existing.conversionSource = previousSource;
        existing.readyToConvert = previousReady;
        existing.state = DownloadState.completed;
        rethrow;
      }
      notifyListeners();
      unawaited(pump());
      return;
    }
    final job = DownloadJob(
      id: 'convert-${DateTime.now().microsecondsSinceEpoch}',
      title: title ?? path.split('/').last,
      identity: 'local',
      file: target,
      channelId: 0,
      sourceId: 0,
      readyToConvert: true,
      conversionSource: path,
      bytes: size,
      total: size,
    );
    await add(job);
  }

  Future<void> move(DownloadJob job, int step) async {
    final queued = jobs.where((j) => j.state == DownloadState.queued).toList();
    final index = queued.indexOf(job), target = queued.indexOf(job) + step;
    if (index < 0 || target < 0 || target >= queued.length) return;
    final a = jobs.indexOf(job), b = jobs.indexOf(queued[target]);
    jobs[a] = queued[target];
    jobs[b] = job;
    await persist();
    notifyListeners();
  }

  Future<void> yieldConnections(int source, int count) async {
    for (final job
        in jobs
            .where(
              (j) =>
                  j.sourceId == source &&
                  j.state == DownloadState.downloading &&
                  _running.containsKey(j.id),
            )
            .take(count)
            .toList()) {
      await pause(job, requeue: true);
    }
  }

  Future<void> shutdown() async {
    _closed = true;
    _timer?.cancel();
    for (final job in jobs.where((j) => _running.containsKey(j.id)).toList()) {
      await pause(job, requeue: true);
    }
    if (_write != null) await _write;
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _clients.values) {
      c.close(force: true);
    }
    super.dispose();
  }
}
