import '../library/models.dart';
import '../library/download_ui.dart';
import '../library/media_library.dart';
import '../library/recording_ui.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:brentv/models/channel.dart';
import 'package:brentv/models/filters.dart';
import 'package:brentv/models/media_type.dart';
import 'package:brentv/models/settings.dart';
import 'package:brentv/models/view_type.dart';
import 'package:brentv/native_bridge.dart';
import 'package:brentv/playback/feeds.dart';
import 'package:brentv/playback/mpv/ipc.dart';
import 'package:brentv/playback/mpv/options.dart';
import 'package:brentv/playback/playback.dart';
import 'package:brentv/programme_guide.dart';

class ExternalMpv {
  static final ExternalMpv instance = ExternalMpv._();
  ExternalMpv._();

  BuildContext? _context;
  int _confirmRecordUntil = 0;
  int? _confirmRecordChannel;
  bool _recordingListening = false;
  String _recordOverlay = '';
  ({Channel channel, List<Channel>? siblings, RecordingJob stop, int until})?
  _pendingRecordingSwitch;

  void _recordingChanged() {
    final ipc = _ipc;
    if (ipc == null) return;
    final active = MediaLibrary.instance.activeRecordings;
    final j = active.firstOrNull;
    final elapsed = j == null ? 0 : unixNow - (j.actualStart ?? unixNow);
    final label = j == null
        ? ''
        : '● REC ${two(elapsed ~/ 60)}:${two(elapsed % 60)}${active.length > 1 ? ' (${active.length})' : ''}';
    if (_recordOverlay == label) return;
    _recordOverlay = label;
    unawaited(
      ipc
          .command([
            'osd-overlay',
            73,
            'ass-events',
            label.isEmpty ? '' : r'{\an9\fs20\c&H0000FF&}' + label,
            0,
            0,
          ])
          .catchError((_) => null),
    );
  }

  bool _armingRecord = false, _recordProbe = false;

  /// Saves the stream mpv is showing to [file], or stops when given null.
  Future<bool> _record(String? file) async {
    try {
      final ipc = _ipc!;
      if (file == null) {
        await ipc.command(['set_property', 'stream-record', '']);
        if (_recordProbe) {
          // Back to the low-latency profile's fast open for the next channel.
          _recordProbe = false;
          await ipc.command([
            'set_property',
            'demuxer-lavf-probe-info',
            'nostreams',
          ]);
          await ipc.command([
            'set_property',
            'demuxer-lavf-analyzeduration',
            0.1,
          ]);
        }
        return true;
      }
      final feed = _feed;
      if (feed == null) return false;
      if (!(_settings?.lowLatency ?? false) ||
          feed.channel.mediaType != MediaType.livestream) {
        await ipc.command(['set_property', 'stream-record', file]);
        return true;
      }
      // The low-latency profile opens a stream without reading its codec
      // details, which mpv's recorder needs: open it again with them.
      await ipc.command(['set_property', 'demuxer-lavf-probe-info', 'auto']);
      await ipc.command(['set_property', 'demuxer-lavf-analyzeduration', 0.5]);
      _recordProbe = true;
      await ipc.command(['set_property', 'stream-record', file]);
      await _serial(() async {
        if (_ipc != ipc || _feed != feed) throw StateError('Channel changed');
        _armingRecord = true;
        try {
          await _load(feed);
        } finally {
          _armingRecord = false;
        }
      });
      return _ipc == ipc && _feed == feed;
    } catch (_) {
      return false;
    }
  }

  void _stopRecordIndicator() {
    MediaLibrary.instance.removeListener(_recordingChanged);
    _recordingListening = false;
    _recordOverlay = '';
  }

  Process? _process;
  MpvIpc? _ipc;
  Directory? _runtime;
  Channel? _channel;
  Channel? _navigationChannel;
  ({Channel channel, List<Channel> siblings})? _previousChannel;
  Settings? _settings;
  List<Channel> _siblings = [];
  List<Feed> _feeds = [];
  Feed? _feed;
  final _properties = <String, dynamic>{};
  Future<void> _queue = Future.value();
  int _generation = 0;
  int? _entryId;
  int _retries = 0;
  bool _progressReady = false;
  double? _highWater;
  double _forwardProgress = 0;
  final _failedAlternates = <int?>{};
  late final _guide = ProgrammeGuide(
    (id) => NativeBridge.instance.getNowNext(id),
  )..addListener(_programmeChanged);
  StreamSubscription<void>? _guideInvalidation;
  String? _displayedTitle;
  String _numberInput = '';
  Channel? _discoveredChannel;

  Future<void> _reloadGuide() async {
    final generation = _generation;
    _guide.setActive(false);
    _guide.invalidate();
    try {
      final settings = await NativeBridge.instance.getSettings();
      if (_process == null || generation != _generation) return;
      _settings!.showProgrammes = settings.showProgrammes;
      _settings!.guidePlayerTitles = settings.guidePlayerTitles;
      _settings!.enableXmltv = settings.enableXmltv;
      _settings!.autoQualityDiscovery = settings.autoQualityDiscovery;
      if (_feed != null) {
        _guide.setVisible([_feed!.channel]);
        _guide.setActive(
          guideEnabled(_feed!.channel, _settings!, player: true),
        );
      }
      _programmeChanged();
    } catch (_) {
      /* Keep guide requests stopped when settings cannot be read. */
    }
  }

  void _programmeChanged() {
    final ipc = _ipc;
    final feed = _feed;
    if (ipc == null || feed == null) return;
    unawaited(
      _serial(() async {
        if (!identical(_ipc, ipc) || !identical(_feed, feed)) return;
        final title =
            _settings?.showProgrammes == true &&
                _settings?.guidePlayerTitles == true
            ? _guide.playbackTitle(feed.channel)
            : feed.channel.name;
        if (title == _displayedTitle) return;
        await ipc.command(['set_property', 'force-media-title', title]);
        _displayedTitle = title;
      }).catchError((_) {}),
    );
  }

  Future<void> _serial(Future<void> Function() action) {
    final next = _queue.then((_) => action());
    _queue = next.catchError((_) {});
    return next;
  }

  Future<void> play(
    BuildContext context,
    Channel channel,
    Settings settings, {
    List<Channel> siblings = const [],
  }) async {
    _context = Navigator.of(context).context;
    _generation++;
    try {
      await _serial(() async {
        _generation++;
        await _savePosition();
        if (_process != null &&
            (!settings.mpvReuseWindow || _settings != settings)) {
          // Settings are fetched afresh by the dispatcher. Compare launch options.
          final old = _settings;
          if (!settings.mpvReuseWindow ||
              old == null ||
              old.mpvPath != settings.mpvPath ||
              old.numberKeySwitching != settings.numberKeySwitching ||
              mpvArguments(
                    old,
                    '',
                    live: _channel?.mediaType == MediaType.livestream,
                  ).join('\n') !=
                  mpvArguments(
                    settings,
                    '',
                    live: channel.mediaType == MediaType.livestream,
                  ).join('\n')) {
            await _stop();
          }
        }
        _settings = settings;
        await _selectChannel(channel, siblings: siblings);
      });
    } catch (_) {
      await _stop();
      if (!context.mounted) return;
      final builtIn = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('mpv could not play this stream'),
          content: const Text(
            'Check the mpv executable and settings, or use the built-in player.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Use built-in'),
            ),
          ],
        ),
      );
      if (builtIn == true && context.mounted) {
        final resolved = await preferredChannel(await offlineChannel(channel));
        if (!context.mounted) return;
        await Playback.openBuiltIn(
          context,
          resolved,
          settings,
          siblings: siblings,
          navigationId: channel.id,
        );
      }
    }
  }

  Future<void> _start() async {
    if (_ipc != null) return;
    final base = Platform.environment['XDG_RUNTIME_DIR'];
    Directory? runtime;
    if (base != null) {
      final root = Directory('$base/brentv');
      try {
        await root.create();
        if ((await Process.run('chmod', ['700', root.path])).exitCode != 0) {
          throw StateError('Cannot secure IPC directory');
        }
        runtime = await root.createTemp('mpv-');
      } on FileSystemException {
        /* Use a private temporary directory. */
      }
    }
    runtime ??= await Directory.systemTemp.createTemp('brentv-');
    _runtime = runtime;
    await Process.run('chmod', ['700', runtime.path]);
    final socket = '${runtime.path}/ipc';
    final process = await Process.start(_settings!.mpvPath, [
      ...mpvArguments(
        _settings!,
        socket,
        live: _channel!.mediaType == MediaType.livestream,
      ),
      // Live EOF must leave IPC available for bounded reconnects.
      if (_channel!.mediaType == MediaType.livestream) '--idle=yes',
    ]);
    _process = process;
    // Drain output without retaining it: mpv diagnostics may contain provider URLs.
    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());
    unawaited(
      process.exitCode.then((code) async {
        if (_process != process) return;
        final saved = _savePosition().catchError((_) {});
        _generation++;
        _progressReady = false;
        _ipc?.close();
        _ipc = null;
        _process = null;
        _stopRecordIndicator();
        MediaLibrary.instance.playing = null;
        MediaLibrary.instance.closePlayer = null;
        MediaLibrary.instance.playerRecord = null;
        unawaited(MediaLibrary.instance.playerStreamEnded());
        _guide.setActive(false);
        _guideInvalidation?.cancel();
        _guideInvalidation = null;
        _properties.clear();
        await saved;
        if (await runtime!.exists()) await runtime.delete(recursive: true);
      }),
    );
    for (var i = 0; i < 500; i++) {
      if (_process != process) throw StateError('mpv exited');
      try {
        _ipc = await MpvIpc.connect(socket);
        break;
      } on SocketException {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
    final ipc = _ipc;
    if (ipc == null) throw StateError('mpv IPC unavailable');
    ipc.events.listen((event) {
      if (identical(_ipc, ipc)) _event(event);
    });
    for (final binding in <String, String>{
      ...mpvKeyBindings,
      if (_settings!.numberKeySwitching) ...{
        for (var n = 0; n < 10; n++) '$n': 'brentv-number-$n',
        'ENTER': 'brentv-number-go',
        'ESC': 'brentv-number-cancel',
      },
    }.entries) {
      await ipc.command([
        'keybind',
        binding.key,
        'script-message ${binding.value}',
      ]);
    }
    if (!_recordingListening) {
      MediaLibrary.instance.addListener(_recordingChanged);
      _recordingListening = true;
    }
    _recordingChanged();
    await ipc.observe([
      'time-pos',
      'duration',
      'video-params',
      'estimated-vf-fps',
      'container-fps',
      'video-bitrate',
      'idle-active',
    ]);
  }

  Future<void> _stop() async {
    _stopRecordIndicator();
    if (_ipc != null) await _record(null);
    MediaLibrary.instance.playing = null;
    MediaLibrary.instance.closePlayer = null;
    MediaLibrary.instance.playerRecord = null;
    unawaited(MediaLibrary.instance.playerStreamEnded());
    _numberInput = '';
    _guide.setActive(false);
    _guideInvalidation?.cancel();
    _guideInvalidation = null;
    final process = _process;
    _process = null;
    _ipc?.close();
    _ipc = null;
    if (process != null) {
      process.kill();
      await process.exitCode.timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
    }
    final runtime = _runtime;
    _runtime = null;
    if (runtime != null && await runtime.exists()) {
      await runtime.delete(recursive: true);
    }
  }

  Future<void> _savePosition() async {
    final channel = _channel;
    final position = _properties['time-pos'];
    if (channel?.mediaType == MediaType.movie &&
        !channel!.transient &&
        position is num) {
      await NativeBridge.instance.setMoviePosition(
        channel.id!,
        position.round(),
      );
    }
  }

  Future<void> _selectChannel(
    Channel channel, {
    List<Channel>? siblings,
  }) async {
    final navigationChannel = channel;
    channel = await offlineChannel(channel);
    final library = MediaLibrary.instance;
    if (_ipc != null && library.initialized && !channel.isLocal) {
      final limit =
          library.limits[channel.sourceId] ??
          (channel.id == null
              ? 1
              : (await library.info(channel.id!)).maxConnections);
      await library.downloads.yieldConnections(
        channel.sourceId,
        (library.connections(channel.sourceId, includePlayer: false) +
                1 -
                limit)
            .clamp(0, 64),
      );
      if (library.connections(channel.sourceId, includePlayer: false) >=
          limit) {
        final recording = library.activeRecordings
            .where((j) => j.sourceId == channel.sourceId)
            .firstOrNull;
        if (recording != null) {
          _pendingRecordingSwitch = (
            channel: channel,
            siblings: siblings,
            stop: recording,
            until: unixNow + 8,
          );
          await _osd(
            'Provider connection limit. Press R within 8 seconds to stop a recording and switch; otherwise playback stays here.',
            milliseconds: 8000,
          );
        }
        return;
      }
    }
    _pendingRecordingSwitch = null;
    _confirmRecordUntil = 0;
    final context = _context;
    if (context != null &&
        context.mounted &&
        !await prepareLibraryPlayback(context, channel)) {
      return;
    }
    MediaLibrary.instance.closePlayer = _stop;
    _numberInput = '';
    final current = _navigationChannel;
    if (current != null && !current.sameAs(navigationChannel)) {
      _previousChannel = (channel: current, siblings: _siblings);
    }
    _navigationChannel = navigationChannel;
    if (siblings != null) _siblings = siblings;
    channel = await preferredChannel(channel);
    if (context != null &&
        context.mounted &&
        !await prepareLibraryPlayback(context, channel)) {
      return;
    }
    final feeds = <Feed>[Feed(channel, channel.url!)];
    await _savePosition();
    if (_process != null &&
        (!_settings!.mpvReuseWindow ||
            (_settings!.lowLatency &&
                _channel?.mediaType != channel.mediaType))) {
      await _stop();
    }
    if (_ipc != null && !(_channel?.sameAs(channel) ?? false)) {
      await _record(null);
      unawaited(MediaLibrary.instance.playerStreamEnded());
    }
    _channel = channel;
    MediaLibrary.instance.playing = channel.isLocal ? null : channel;
    MediaLibrary.instance.closePlayer = _stop;
    MediaLibrary.instance.playerRecord = _record;
    _properties.clear();
    _feeds = feeds.where((f) => f.variant == null).toList();
    _retries = 0;
    _failedAlternates.clear();
    // Start the stream immediately; HLS discovery can take eight seconds.
    final discovery = _settings!.autoQualityDiscovery
        ? loadFeeds(channel)
        : Future.value(_feeds);
    _discoveredChannel = _settings!.autoQualityDiscovery ? channel : null;
    await _load(_feeds.first);
    unawaited(
      discovery
          .then((discovered) {
            if (identical(_channel, channel)) {
              _feeds = discovered.where((f) => f.variant == null).toList();
            }
          })
          .catchError((_) {}),
    );
  }

  Future<void> _load(Feed feed) async {
    await _savePosition();
    if (_ipc != null && !_armingRecord) {
      // Loading again would overwrite the file mpv is recording into.
      await _record(null);
      unawaited(MediaLibrary.instance.playerStreamEnded(reloading: true));
    }
    await _start();
    final ipc = _ipc!;
    for (final option in recordingOscOptions(
      live: feed.channel.mediaType == MediaType.livestream,
    )) {
      await ipc.command(['change-list', 'script-opts', 'append', option]);
    }
    final headers =
        feed.channel.playbackHeaders ??
        (feed.channel.id == null
            ? null
            : await NativeBridge.instance.getChannelHeaders(feed.channel.id!));
    await ipc.command(['set_property', 'user-agent', headers?.userAgent ?? '']);
    await ipc.command(['set_property', 'referrer', headers?.referrer ?? '']);
    await ipc.command([
      'set_property',
      'http-header-fields',
      [
        if (headers?.httpOrigin?.isNotEmpty == true)
          'Origin: ${headers!.httpOrigin}',
      ],
    ]);
    final title =
        _settings?.showProgrammes == true &&
            _settings?.guidePlayerTitles == true
        ? _guide.playbackTitle(feed.channel)
        : feed.channel.name;
    await ipc.command(['set_property', 'force-media-title', title]);
    _displayedTitle = title;
    await ipc.command([
      'set_property',
      'hls-bitrate',
      feed.maxBitrate?.toString() ?? 'max',
    ]);
    final position =
        _channel!.mediaType == MediaType.movie && !_channel!.transient
        ? await NativeBridge.instance.getMoviePosition(_channel!.id!)
        : null;
    await ipc.command([
      'set_property',
      'start',
      position == null ? '0' : '$position',
    ]);
    _progressReady = false;
    _highWater = null;
    _forwardProgress = 0;
    _feed = feed;
    _guideInvalidation ??= NativeBridge.instance.catalogChanges.listen(
      (_) => _reloadGuide(),
    );
    _guide.setVisible([feed.channel]);
    _guide.setActive(guideEnabled(feed.channel, _settings!, player: true));
    _properties.clear();
    final loaded = Completer<Map<String, dynamic>>();
    final subscription = ipc.events.listen(
      (event) {
        if (!loaded.isCompleted &&
            (event['event'] == 'file-loaded' ||
                (event['event'] == 'end-file' &&
                    (event['reason'] == 'error' ||
                        event['reason'] == 'eof')))) {
          loaded.complete(event);
        }
      },
      onDone: () {
        if (!loaded.isCompleted) loaded.complete({'event': 'shutdown'});
      },
    );
    late Map<String, dynamic> event;
    try {
      final results = await Future.wait<dynamic>([
        ipc.command(['loadfile', feed.url, 'replace']).then((reply) {
          _entryId = reply is Map ? reply['playlist_entry_id'] as int? : null;
          return reply;
        }),
        loaded.future.timeout(const Duration(seconds: 30)),
      ]);
      event = results[1] as Map<String, dynamic>;
    } finally {
      await subscription.cancel();
    }
    if (event['event'] != 'file-loaded' &&
        _channel!.mediaType != MediaType.livestream) {
      throw StateError('Stream failed');
    }
    if (event['event'] == 'file-loaded') {
      unawaited(MediaLibrary.instance.resumePlayerRecordings());
    }
  }

  void _event(Map<String, dynamic> event) {
    if (event['event'] == 'file-loaded') {
      _progressReady = true;
    } else if (event['event'] == 'property-change' && event['data'] != null) {
      _properties[event['name'] as String] = event['data'];
      final position = event['data'];
      if (_progressReady &&
          event['name'] == 'time-pos' &&
          position is num &&
          position.isFinite) {
        final current = position.toDouble();
        final previous = _highWater;
        if (previous == null) {
          _highWater = current;
        } else if (current > previous) {
          _forwardProgress += current - previous;
          _highWater = current;
          if (_forwardProgress >= 3) _retries = 0;
        }
      }
    } else if (event['event'] == 'client-message') {
      final args = event['args'] as List;
      if (args.isNotEmpty) {
        unawaited(_serial(() => _key(args.first as String)).catchError((_) {}));
      }
    } else if (event['event'] == 'end-file') {
      unawaited(_savePosition().catchError((_) {}));
      _progressReady = false;
      if ((event['reason'] == 'error' || event['reason'] == 'eof') &&
          _channel?.mediaType == MediaType.livestream) {
        final generation = _generation;
        final entryId = event['playlist_entry_id'] as int?;
        unawaited(
          _serial(() => _retry(generation, entryId)).catchError((_) {}),
        );
      }
    }
  }

  Future<void> _retry(int generation, int? entryId) async {
    bool current() =>
        generation == _generation &&
        (entryId == null || _entryId == null || entryId == _entryId);
    if (!current()) return;
    if (_retries < 3) {
      _retries++;
      await _osd('Reconnecting ($_retries/3)');
      await Future<void>.delayed(Duration(seconds: 1 << (_retries - 1)));
      if (!current()) return;
      await _load(_feed!);
    } else {
      _failedAlternates.add(_feed!.channel.id);
      final next = _feeds.where(
        (f) => f.alternate && !_failedAlternates.contains(f.channel.id),
      );
      if (next.isEmpty) {
        await _osd('Stream unavailable. Try another channel.');
      } else {
        _retries = 0;
        await _osd('Trying alternate feed');
        await _load(next.first);
      }
    }
  }

  Future<void> _osd(String message, {int milliseconds = 3000}) async {
    try {
      await _ipc?.command(['show-text', message, milliseconds]);
    } catch (_) {
      // Closing mpv while an OSD command is queued is normal.
    }
  }

  Future<void> _changeChannel(
    Channel channel, {
    List<Channel>? siblings,
  }) async {
    if (channel.sameAs(_navigationChannel)) {
      _pendingRecordingSwitch = null;
      if (siblings != null) _siblings = siblings;
      await _osd(channel.name);
      return;
    }
    await _savePosition();
    _generation++;
    if (!(await offlineChannel(channel)).transient) {
      await NativeBridge.instance.addLastWatched(channel.id!);
    }
    await _selectChannel(channel, siblings: siblings);
    if (_pendingRecordingSwitch == null) await _osd(channel.name);
  }

  Future<void> _key(String key) async {
    if (_ipc == null) return;
    if (key == 'brentv-record' || key == 'brentv-record-button') {
      final context = _context;
      if (context == null ||
          !context.mounted ||
          _feed == null ||
          (key == 'brentv-record' &&
              _settings?.keyboardShortcuts != true &&
              _pendingRecordingSwitch == null &&
              _confirmRecordUntil < unixNow)) {
        return;
      }
      final library = MediaLibrary.instance;
      final pending = _pendingRecordingSwitch;
      _pendingRecordingSwitch = null;
      if (pending != null && pending.until >= unixNow) {
        await library.stopRecording(pending.stop);
        await _selectChannel(pending.channel, siblings: pending.siblings);
        return;
      }
      final channel = _feed!.channel;
      if (channel.mediaType != MediaType.livestream || channel.id == null) {
        return;
      }
      if (library.recordingFor(channel) case final RecordingJob job) {
        await library.stopRecording(job);
        await _osd('Recording saved in DVR');
        return;
      }
      if (!await library.ffmpegAvailable()) {
        await _osd(
          'Install ffmpeg to record: pacman -S ffmpeg',
          milliseconds: 8000,
        );
        return;
      }
      final data = await library.info(channel.id!);
      var stop = unixNow + 3600;
      if (_settings?.showProgrammes == true) {
        try {
          final guide = await NativeBridge.instance.getNowNext(channel.id!);
          if (guide.hasNow() && guide.now.stop.toInt() > unixNow) {
            stop = guide.now.stop.toInt();
          }
        } catch (_) {
          /* Default to one hour without usable EPG. */
        }
      }
      await library.downloads.yieldConnections(
        channel.sourceId,
        (library.connections(channel.sourceId) + 1 - data.maxConnections).clamp(
          0,
          64,
        ),
      );
      final probe = RecordingJob(
        id: 'pending',
        channelId: channel.id!,
        sourceId: channel.sourceId,
        channelName: channel.name,
        title: 'Live TV',
        identity: data.identity,
        start: unixNow,
        stop: stop,
        maxConnections: data.maxConnections,
      );
      final conflicts = probe.conflicts(library.recordings).isNotEmpty;
      // With no connection to spare, mpv saves the stream it is showing.
      final viaPlayer =
          !conflicts &&
          library.connections(channel.sourceId) >= data.maxConnections &&
          library.playing?.id == channel.id &&
          library.playerRecord != null;
      if (!viaPlayer &&
          (library.connections(channel.sourceId) >= data.maxConnections ||
              conflicts)) {
        if (_confirmRecordChannel != channel.id ||
            _confirmRecordUntil < unixNow) {
          _confirmRecordChannel = channel.id;
          _confirmRecordUntil = unixNow + 8;
          await _osd(
            'Provider or schedule conflict. Press R or click Record again within 8 seconds to close the player and choose recording options.',
            milliseconds: 8000,
          );
          return;
        }
        await _stop();
      }
      if (context.mounted) {
        await toggleRecording(context, channel, stopAt: stop);
      }
      if (library.recordings.any(
        (j) => j.channelId == channel.id && j.reserved,
      )) {
        await _osd(
          viaPlayer
              ? 'Recording · R stops it\nIt ends if you change channel'
              : 'Recording · R stops it',
          milliseconds: 5000,
        );
      }
      return;
    }
    if (key.startsWith('brentv-number-')) {
      if (!_settings!.numberKeySwitching) return;
      final digit = key.substring('brentv-number-'.length);
      if (digit == 'cancel') {
        if (_numberInput.isEmpty) {
          await _ipc!.command(['set_property', 'fullscreen', false]);
        }
        _numberInput = '';
        await _osd('');
        return;
      }
      if (digit == 'go') {
        final number = int.tryParse(_numberInput);
        _numberInput = '';
        if (number == null || number < 1) return;
        final sources = await NativeBridge.instance.getEnabledSourcesMinimal();
        final channels = await NativeBridge.instance.getChannels(
          Filters(
            sourceIds: sources,
            mediaTypes: [MediaType.livestream],
            viewType: ViewType.all,
            page: (number - 1) ~/ 36 + 1,
          ),
        );
        final index = (number - 1) % 36;
        if (index >= channels.length) {
          await _osd('No channel at position $number');
          return;
        }
        await _changeChannel(channels[index], siblings: channels);
        return;
      }
      if (RegExp(r'^\d$').hasMatch(digit) && _numberInput.length < 6) {
        _numberInput += digit;
      }
      await _osd('Channel $_numberInput (provider order) · Enter to play');
      return;
    }
    if (key == 'brentv-last' && _numberInput.isNotEmpty) {
      _numberInput = _numberInput.substring(0, _numberInput.length - 1);
      await _osd('Channel $_numberInput · Enter to play');
      return;
    }
    _numberInput = '';
    if (key == 'brentv-next' || key == 'brentv-prev') {
      final channels = _siblings
          .where((c) => c.isPlayable && (!c.transient || c.isLocal))
          .toList();
      if (channels.isEmpty) return;
      final index = channels.indexWhere((c) => c.sameAs(_navigationChannel));
      if (index < 0) return;
      final channel =
          channels[(index + (key == 'brentv-next' ? 1 : -1)) % channels.length];
      await _changeChannel(channel);
    } else if (key == 'brentv-last') {
      final previous = _previousChannel;
      if (previous == null) {
        await _osd('No previous channel yet');
        return;
      }
      await _changeChannel(previous.channel, siblings: previous.siblings);
    } else if (key.startsWith('brentv-favorite-')) {
      final number = int.tryParse(key.substring('brentv-favorite-'.length));
      if (number == null || number < 1 || number > 9) return;
      final sources = await NativeBridge.instance.getEnabledSourcesMinimal();
      final favorites = (await NativeBridge.instance.getAllChannels(
        Filters(
          sourceIds: sources,
          mediaTypes: [MediaType.livestream],
          viewType: ViewType.favorites,
        ),
      )).where((channel) => channel.id != null && channel.isPlayable).toList();
      if (number > favorites.length) {
        await _osd('Favorite $number is not set');
        return;
      }
      await _changeChannel(favorites[number - 1], siblings: favorites);
    } else if (key == 'brentv-feed-next' || key == 'brentv-feed-prev') {
      if (_feeds.length < 2 &&
          !_settings!.autoQualityDiscovery &&
          !identical(_discoveredChannel, _channel)) {
        final channel = _channel!;
        _discoveredChannel = channel;
        unawaited(
          loadFeeds(channel)
              .then((feeds) {
                if (identical(_channel, channel)) {
                  _feeds = feeds.where((f) => f.variant == null).toList();
                }
              })
              .catchError((_) {
                if (identical(_channel, channel)) {
                  _osd('Quality lookup failed; reopen the channel to retry');
                }
              }),
        );
        await _osd('Checking qualities · press again when ready');
        return;
      }
      if (_feeds.length < 2) {
        await _osd('No alternate feeds available yet');
        return;
      }
      _generation++;
      _retries = 0;
      _failedAlternates.clear();
      final index = _feeds.indexWhere((f) => f.sameAs(_feed!));
      await _load(
        _feeds[(index + (key == 'brentv-feed-next' ? 1 : -1)) % _feeds.length],
      );
      await _osd(_feed!.label);
    } else if (key == 'brentv-info') {
      final video = _properties['video-params'] as Map?;
      final fps =
          _properties['estimated-vf-fps'] ?? _properties['container-fps'];
      final bitrate = _properties['video-bitrate'];
      final programmes = _settings?.showProgrammes == true
          ? _guide.describe(_feed?.channel.id).$2
          : '';
      await _osd(
        [
          [
            _feed?.label ?? 'Auto',
            if (video != null) '${video['w']}×${video['h']}',
            if (fps is num) '${fps.toStringAsFixed(1)} fps',
            if (bitrate is num) '${(bitrate / 1e6).toStringAsFixed(1)} Mb/s',
          ].join(' · '),
          if (programmes.isNotEmpty) programmes,
        ].join('\n'),
      );
    }
  }
}
