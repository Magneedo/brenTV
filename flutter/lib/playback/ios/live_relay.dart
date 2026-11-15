import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:brentv/generated/generated_proto.pb.dart' as pb;
import 'package:brentv/native_bridge.dart';

/// What Apple's player needs done to a live MPEG-TS stream, from the codec
/// names in its program map (`pb.RelayInfo`).
///
/// Apple plays H.264 with AAC, AC-3 or E-AC-3 from a provider's own HLS.
/// HEVC plays only from fragmented MP4, so it is repackaged without
/// re-encoding. Other video is encoded as H.264, other audio as AAC.
class LivePlan {
  final String video, audio;
  const LivePlan(this.video, this.audio);

  /// Whether the program map was read at all.
  bool get known => video.isNotEmpty || audio.isNotEmpty;
  bool get copyVideo => video == 'h264' || video == 'hevc';
  bool get copyAudio => const {'', 'aac', 'ac3', 'eac3'}.contains(audio);

  /// Whether the provider's stream cannot play as it is.
  bool get required =>
      known && video.isNotEmpty && (video != 'h264' || !copyAudio);

  /// FFmpeg arguments turning [input] into an HLS playlist `live.m3u8` of
  /// fragmented MP4 segments in [directory].
  List<String> arguments(
    String input,
    String directory, {
    String videoEncoder = 'h264_videotoolbox',
  }) => [
    '-hide_banner',
    '-loglevel',
    'error',
    '-nostdin',
    '-fflags',
    '+genpts+discardcorrupt',
    '-protocol_whitelist',
    'file,http,tcp',
    '-i',
    input,
    '-map',
    '0:v:0',
    // One audio track: alternates would have to be separate renditions.
    '-map',
    '0:a:0?',
    '-sn',
    '-dn',
    if (copyVideo) ...[
      '-c:v',
      'copy',
      if (video == 'hevc') ...['-tag:v', 'hvc1'],
    ] else ...[
      '-c:v',
      videoEncoder,
      '-b:v',
      '5M',
      '-pix_fmt',
      'yuv420p',
      // Broadcast MPEG-2 is usually interlaced; only flagged frames change.
      '-vf',
      'yadif=0:-1:1,scale=trunc(iw/2)*2:trunc(ih/2)*2',
      '-force_key_frames',
      'expr:gte(t,n_forced*2)',
      if (videoEncoder == 'h264_videotoolbox') ...[
        '-realtime',
        '1',
        '-allow_sw',
        '1',
      ],
    ],
    if (copyAudio) ...[
      '-c:a',
      'copy',
      if (audio == 'aac') ...['-bsf:a', 'aac_adtstoasc'],
    ] else ...[
      '-c:a',
      'aac',
      '-b:a',
      '160k',
      '-ac',
      '2',
    ],
    '-f',
    'hls',
    '-hls_time',
    '2',
    '-hls_list_size',
    '20',
    '-hls_delete_threshold',
    '10',
    '-hls_flags',
    'delete_segments+independent_segments+temp_file',
    '-hls_segment_type',
    'fmp4',
    '-hls_fmp4_init_filename',
    'init.mp4',
    '-hls_segment_filename',
    '$directory/seg%05d.m4s',
    '$directory/live.m3u8',
  ];
}

/// How to turn a movie or episode Apple's player cannot open (MKV, AVI…)
/// into HLS it can, from `ffprobe` output. Unlike a live stream this runs as
/// fast as the provider sends, so playback can seek within what is done.
class MoviePlan {
  final Map<String, dynamic> info;
  const MoviePlan(this.info);

  List<Map> get _streams =>
      (info['streams'] as List? ?? []).whereType<Map>().toList();
  Map? _first(String type) =>
      _streams.where((s) => s['codec_type'] == type).firstOrNull;
  Map? get video => _first('video');
  Map? get audio => _first('audio');

  /// The first text subtitle, preferring English.
  Map? get subtitle {
    final text = _streams
        .where(
          (s) =>
              s['codec_type'] == 'subtitle' &&
              const {
                'subrip',
                'ass',
                'ssa',
                'webvtt',
                'mov_text',
              }.contains(s['codec_name']),
        )
        .toList();
    return text
            .where((s) => '${(s['tags'] as Map?)?['language']}' == 'eng')
            .firstOrNull ??
        text.firstOrNull;
  }

  bool get copyVideo =>
      (video?['codec_name'] == 'hevc' &&
          const ['yuv420p', 'yuv420p10le'].contains(video?['pix_fmt'])) ||
      (video?['codec_name'] == 'h264' &&
          const ['yuv420p', 'yuvj420p'].contains(video?['pix_fmt']));
  bool get copyAudio =>
      const {'aac', 'ac3', 'eac3'}.contains(audio?['codec_name']);

  /// Bytes of the source, or 0 when the server did not say.
  int get size => int.tryParse('${(info['format'] as Map?)?['size']}') ?? 0;

  /// A completed film starts over instead of reopening its last few seconds.
  double resumePosition(double saved) {
    final duration = double.tryParse(
      '${(info['format'] as Map?)?['duration']}',
    );
    if (!saved.isFinite || saved < 0) return 0;
    if (duration != null &&
        duration.isFinite &&
        duration > 0 &&
        saved >= duration - 30) {
      return 0;
    }
    return saved;
  }

  /// Writes `live.m3u8` (video and audio), and with a subtitle `live_vtt.m3u8`
  /// plus a `master.m3u8` naming both, starting [start] seconds in.
  List<String> arguments(
    String input,
    String directory, {
    double start = 0,
    String videoEncoder = 'h264_videotoolbox',
  }) => [
    '-hide_banner',
    '-loglevel',
    'error',
    '-nostdin',
    '-protocol_whitelist',
    'file,http,tcp',
    if (start > 0) ...['-ss', start.toStringAsFixed(3)],
    '-i',
    input,
    '-map',
    '0:${video!['index']}',
    if (audio != null) ...['-map', '0:${audio!['index']}'],
    if (subtitle != null) ...['-map', '0:${subtitle!['index']}'],
    '-dn',
    if (copyVideo) ...[
      '-c:v',
      'copy',
      if (video?['codec_name'] == 'hevc') ...['-tag:v', 'hvc1'],
    ] else ...[
      '-c:v',
      videoEncoder,
      '-b:v',
      '8M',
      '-pix_fmt',
      'yuv420p',
      '-vf',
      'scale=trunc(iw/2)*2:trunc(ih/2)*2',
      '-force_key_frames',
      'expr:gte(t,n_forced*6)',
      if (videoEncoder == 'h264_videotoolbox') ...['-allow_sw', '1'],
    ],
    if (audio != null && copyAudio) ...[
      '-c:a',
      'copy',
    ] else if (audio != null) ...[
      '-c:a',
      'aac',
      '-b:a',
      '192k',
      '-ac',
      '2',
    ],
    if (subtitle != null) ...['-c:s', 'webvtt'],
    '-f',
    'hls',
    '-hls_time',
    '6',
    // Everything stays listed, so the player can seek back to the start.
    '-hls_playlist_type',
    'event',
    '-hls_flags',
    'independent_segments+temp_file',
    '-hls_segment_type',
    'fmp4',
    '-hls_fmp4_init_filename',
    'init.mp4',
    '-hls_segment_filename',
    '$directory/seg%05d.m4s',
    if (subtitle != null) ...[
      '-master_pl_name',
      'master.m3u8',
      '-var_stream_map',
      'v:0,${audio != null ? 'a:0,' : ''}s:0,sgroup:subs',
    ],
    '$directory/live.m3u8',
  ];
}

/// One stream held open through the core's loopback relay.
class LiveRelay {
  static const _channel = MethodChannel('brentv/media_converter');
  static int _sequence = 0;

  /// Runs FFmpeg until it exits: `stream` starts it, `cancel` stops it.
  final Future<dynamic> Function(String method, Map<String, dynamic> args)
  invoke;
  final Future<void> Function(String token) closeRelay;
  final pb.RelayInfo info;
  final Directory directory;
  final String videoEncoder;
  final _id = 'live-${_sequence++}';
  Future<void>? _running;
  bool _closed = false;

  LiveRelay._(
    this.info,
    this.directory,
    this.invoke,
    this.closeRelay,
    this.videoEncoder,
  );

  LivePlan get plan => LivePlan(info.video, info.audio);
  String get _base => 'http://127.0.0.1:${info.port}/${info.token}';
  String _playlist = 'live.m3u8';
  String get playlistUrl => '$_base/$_playlist';

  /// Where FFmpeg reads the provider's bytes; [extension] only names it.
  String input([String extension = 'ts']) => '$_base/input.$extension';

  /// Connects to [url] and reads its codecs. Throws when the stream cannot
  /// be reached at all.
  static Future<LiveRelay> open(
    String url, {
    Map<String, String> headers = const {},
    bool ignoreSsl = false,
    bool seekable = false,
    Future<pb.RelayInfo> Function(pb.RelayRequest)? openRelay,
    Future<void> Function(String)? closeRelay,
    Future<dynamic> Function(String, Map<String, dynamic>)? invoke,
    String videoEncoder = 'h264_videotoolbox',
  }) async {
    final directory = await Directory.systemTemp.createTemp('brentv-live-');
    try {
      final info = await (openRelay ?? NativeBridge.instance.relayOpen)(
        pb.RelayRequest(
          url: url,
          userAgent: headers['User-Agent'],
          referrer: headers['Referer'],
          httpOrigin: headers['Origin'],
          ignoreSsl: ignoreSsl,
          directory: directory.path,
          seekable: seekable,
        ),
      );
      return LiveRelay._(
        info,
        directory,
        invoke ?? ((method, args) => _channel.invokeMethod(method, args)),
        closeRelay ?? NativeBridge.instance.relayClose,
        videoEncoder,
      );
    } catch (_) {
      await _remove(directory);
      rethrow;
    }
  }

  /// What `ffprobe` says about the source, through the relay. Null when it
  /// cannot be read.
  Future<Map<String, dynamic>?> probe(String extension) async {
    try {
      final raw = await invoke('probe', {
        'id': '$_id-probe',
        'arguments': [
          '-v',
          'quiet',
          '-protocol_whitelist',
          'file,http,tcp',
          '-show_entries',
          'stream=index,codec_type,codec_name,pix_fmt:stream_tags=language:format=duration,size',
          '-of',
          'json',
          '-i',
          input(extension),
        ],
      }).timeout(const Duration(seconds: 40));
      final text = '$raw';
      // FFmpegKit can wrap the JSON in log text.
      final value = jsonDecode(
        text.substring(text.indexOf('{'), text.lastIndexOf('}') + 1),
      );
      return value is Map && value['streams'] is List
          ? Map<String, dynamic>.from(value)
          : null;
    } catch (_) {
      return null;
    }
  }

  /// Starts repackaging a live stream as [plan] says.
  Future<bool> start({Duration timeout = const Duration(seconds: 20)}) => run(
    plan.arguments(input(), directory.path, videoEncoder: videoEncoder),
    timeout: timeout,
  );

  /// Starts converting a movie from [start] seconds in.
  Future<bool> startMovie(
    MoviePlan movie,
    String extension, {
    double start = 0,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final ready = await run(
      movie.arguments(
        input(extension),
        directory.path,
        start: start,
        videoEncoder: videoEncoder,
      ),
      timeout: timeout,
    );
    if (!ready || movie.subtitle == null) return ready;
    // FFmpeg marks the subtitle as on by default; leave that to the viewer.
    try {
      final master = await File('${directory.path}/master.m3u8').readAsString();
      await File('${directory.path}/play.m3u8').writeAsString(
        master.replaceAll('DEFAULT=YES', 'DEFAULT=NO,AUTOSELECT=YES'),
      );
      _playlist = 'play.m3u8';
    } on FileSystemException {
      /* Without it the film still plays, minus its subtitle. */
    }
    return ready;
  }

  /// Runs FFmpeg and waits until the player has something to load. False
  /// when FFmpeg stopped or nothing appeared in time.
  Future<bool> run(
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    var ended = false;
    _running = invoke('stream', {
      'id': _id,
      'arguments': arguments,
    }).then<void>((_) {}, onError: (_) {}).whenComplete(() => ended = true);
    final playlist = File('${directory.path}/live.m3u8');
    final deadline = DateTime.now().add(timeout);
    Future<bool> ready() async {
      try {
        final text = await playlist.readAsString();
        final segments = '#EXTINF'.allMatches(text).length;
        // A short completed film may contain only one segment.
        return segments >= 2 ||
            (ended && segments == 1 && text.contains('#EXT-X-ENDLIST'));
      } on FileSystemException {
        return false;
      }
    }

    while (!_closed && !ended && DateTime.now().isBefore(deadline)) {
      if (await ready()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    // A short film can be finished before the first look.
    return !_closed && await ready();
  }

  /// Completes when FFmpeg has exited, for whatever reason.
  Future<void> get ended => _running ?? Future.value();

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await closeRelay(info.token);
    } catch (_) {
      /* The session may already be gone. */
    }
    if (_running != null) {
      try {
        await invoke('cancel', {'id': _id});
      } catch (_) {
        /* FFmpeg may already have exited. */
      }
      await _running!.timeout(const Duration(seconds: 5), onTimeout: () {});
    }
    await _remove(directory);
  }

  static Future<void> _remove(Directory directory) async {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } on FileSystemException {
      /* iOS reclaims temporary files. */
    }
  }

  /// Output of sessions that ended with the app, not through [close].
  static Future<void> clearStale() async {
    try {
      await for (final entry in Directory.systemTemp.list(followLinks: false)) {
        if (entry is Directory &&
            entry.path.split('/').last.startsWith('brentv-live-')) {
          await _remove(entry);
        }
      }
    } on FileSystemException {
      /* Cleanup must not prevent startup. */
    }
  }
}
