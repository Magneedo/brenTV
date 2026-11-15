import 'dart:async';
import 'package:brentv/playback/ios/live_relay.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:ui' show AppExitResponse;
import 'package:brentv/generated/generated_proto.pb.dart' as pb;
import 'package:brentv/models/bottom_bar.dart';
import 'package:brentv/models/channel.dart';
import 'package:brentv/models/view_type.dart';
import 'package:brentv/native_bridge.dart';
import 'models.dart';
import 'download_queue.dart';
import 'media_converter.dart';

class MediaLibrary extends ChangeNotifier with WidgetsBindingObserver {
  static final instance = MediaLibrary();
  final Future<pb.TransferInfo> Function(int) resolve;
  final Future<void> Function(pb.Settings) save;
  final NativeTransfer? nativeTransfer;
  MediaLibrary({
    Future<pb.TransferInfo> Function(int)? resolve,
    Future<void> Function(pb.Settings)? save,
    NativeTransfer? nativeTransfer,
  }) : nativeTransfer =
           nativeTransfer ??
           (resolve == null && save == null ? coreTransfer : null),
       resolve = resolve ?? ((id) => NativeBridge.instance.getTransferInfo(id)),
       save = save ?? ((state) => NativeBridge.instance.saveMediaState(state));
  late final DownloadQueue downloads = DownloadQueue(
    resolve: info,
    save: (value) => save(pb.Settings(downloadJobs: value)),
    preferences: () => preferences,
    freeSpace: (folder) => NativeBridge.instance.getDiskSpace(folder),
    native: nativeTransfer,
    makePlayable: Platform.isIOS ? MediaConverter.instance.prepare : null,
    cancelConversion: Platform.isIOS ? MediaConverter.instance.cancel : null,
    conversionFinished: Platform.isIOS
        ? MediaConverter.instance.finished
        : null,
    canStart: (source, extra) =>
        connections(source) + extra <= (limits[source] ?? 1),
  );
  MediaPreferences preferences = MediaPreferences();
  final List<RecordingJob> recordings = [];
  final Map<String, Process> _processes = {};
  final Map<String, Future<void>> _finishing = {};
  final Set<String> _starting = {};
  final Set<String> _cancelRequested = {};
  final Map<int, int> limits = {};
  Channel? playing;
  Future<void> Function()? closePlayer;

  /// Set by the player that is showing [playing]: saves its stream to the
  /// given file, or stops saving when given null.
  Future<bool> Function(String? file)? playerRecord;
  final List<RecordingJob> _interrupted = [];

  /// Something the library did by itself that the user should be told.
  final notice = ValueNotifier<String?>(null);
  Timer? _timer;
  bool _busy = false, _closing = false;
  Future<void>? _write;
  bool initialized = false;
  String? storageError;
  Iterable<RecordingJob> get activeRecordings =>
      recordings.where((j) => j.active);
  RecordingJob? recordingFor(Channel c) =>
      recordings.where((j) => j.channelId == c.id && j.active).firstOrNull;

  Future<void> initialize(
    pb.Settings state, {
    String? documentsDirectory,
  }) async {
    if (initialized) return;
    String Function(String)? restoreDownloadPath;
    // Refuse mutations if saved state cannot be decoded; never overwrite it.
    try {
      preferences = MediaPreferences.decode(state.mediaPreferences);
      if (documentsDirectory != null) {
        final oldMovies = preferences.moviesFolder;
        final oldSeries = preferences.seriesFolder;
        preferences.moviesFolder = '$documentsDirectory/Movies';
        preferences.seriesFolder = '$documentsDirectory/Series';
        restoreDownloadPath = (file) {
          for (final (oldFolder, currentFolder) in [
            (oldMovies, preferences.moviesFolder),
            (oldSeries, preferences.seriesFolder),
          ]) {
            if (file.startsWith('$oldFolder/')) {
              return '$currentFolder/${file.substring(oldFolder.length + 1)}';
            }
          }
          // Stored jobs can have a newer container prefix than preferences
          // if an update interrupted the two independent persistence writes.
          final suffix = RegExp(r'/Documents/(.+)$').firstMatch(file);
          return suffix == null ? file : '$documentsDirectory/${suffix[1]}';
        };
        await Directory(preferences.moviesFolder).create(recursive: true);
        await Directory(preferences.seriesFolder).create(recursive: true);
      }
      final jobs = state.recordingJobs.isEmpty
          ? []
          : jsonDecode(state.recordingJobs) as List;
      recordings.addAll(
        jobs.map((j) => RecordingJob.fromJson(Map<String, dynamic>.from(j))),
      );
      for (final j in recordings) {
        j.recover(unixNow);
      }
      await persist();
    } catch (_) {
      storageError =
          'Could not load the saved DVR library. Restart the app before making changes.';
    }
    if (Platform.isIOS) {
      await MediaConverter.instance.clearInterruptedFiles();
      await LiveRelay.clearStale();
    }
    await downloads.initialize(
      state.downloadJobs,
      restorePath: restoreDownloadPath,
    );
    if (restoreDownloadPath != null &&
        storageError == null &&
        downloads.storageError == null) {
      try {
        await savePreferences();
      } catch (_) {
        storageError =
            'Could not save the current download folders. Restart the app before downloading.';
      }
    }
    downloads.addListener(notifyListeners);
    initialized = true;
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isLinux) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  Future<void> persist() {
    final snapshot = pb.Settings(
      recordingJobs: jsonEncode(recordings.map((j) => j.toJson()).toList()),
    );
    final next = (_write ?? Future<void>.value())
        .catchError((_) {})
        .then((_) => save(snapshot));
    _write = next;
    return next;
  }

  Future<void> savePreferences() =>
      save(pb.Settings(mediaPreferences: preferences.encode()));
  Future<void> _featureWrites = Future<void>.value();
  Future<bool> firstUse(ViewType page) {
    final next = _featureWrites.then((_) => _firstUse(page));
    _featureWrites = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return next;
  }

  Future<bool> _firstUse(ViewType page) async {
    if (preferences.usedFeatures.contains(page.name)) return false;
    final settings = await NativeBridge.instance.getSettings();
    final hidden = !settings.bottomBar.visiblePages().contains(page);
    if (hidden) {
      await NativeBridge.instance.setBottomBar(
        BottomBarConfig([
          for (final entry in settings.bottomBar.pages)
            BottomBarPage(entry.page, entry.page == page || entry.visible),
        ]),
      );
    }
    preferences.usedFeatures.add(page.name);
    await savePreferences();
    return hidden;
  }

  void changed() {
    notifyListeners();
  }

  int connections(int source, {bool includePlayer = true}) =>
      recordings
          .where(
            (j) =>
                j.sourceId == source &&
                !j.viaPlayer &&
                (j.active || _starting.contains(j.id)),
          )
          .length +
      (includePlayer && playing?.sourceId == source ? 1 : 0) +
      downloads.connections(source);
  Future<pb.TransferInfo> info(int id) async {
    final value = await resolve(id);
    if (preferences.connectionLimit > 0) {
      value.maxConnections = preferences.connectionLimit;
    }
    limits[value.channel.sourceId.toInt()] = value.maxConnections.clamp(1, 64);
    return value;
  }

  Future<bool> ffmpegAvailable() async {
    try {
      return (await Process.run('ffmpeg', [
            '-version',
          ]).timeout(const Duration(seconds: 5))).exitCode ==
          0;
    } catch (_) {
      return false;
    }
  }

  Future<void> addRecording(RecordingJob job) async {
    if (storageError != null || _closing) {
      throw StateError(storageError ?? 'The app is closing.');
    }
    if (job.stop <= unixNow || job.stop <= job.start) {
      throw StateError('This program has already ended.');
    }
    if (job.conflicts(recordings).isNotEmpty) {
      throw StateError(
        'Schedules overlap; cancel an existing recording in DVR first.',
      );
    }
    recordings.add(job);
    try {
      await persist();
    } catch (_) {
      recordings.remove(job);
      rethrow;
    }
    notifyListeners();
    unawaited(_tick());
  }

  Future<void> _tick() async {
    if (_busy || _closing || storageError != null) return;
    _busy = true;
    try {
      final now = unixNow;
      for (final j in [...recordings]) {
        if (j.state == RecordingState.scheduled && j.start <= now) {
          if (j.stop <= now) {
            j.state = RecordingState.missed;
            j.error =
                'The scheduled time passed while the app was unavailable.';
            await persist();
          } else {
            await _start(j);
          }
        } else if (j.state == RecordingState.recording && j.stop <= now) {
          await stopRecording(j);
        }
      }
      if (activeRecordings.isNotEmpty) notifyListeners();
    } catch (_) {
      storageError =
          'DVR state could not be saved. Check available disk space and restart the app.';
      notifyListeners();
    } finally {
      _busy = false;
    }
  }

  Future<void> _start(RecordingJob j) async {
    _starting.add(j.id);
    try {
      final data = await info(j.channelId);
      if (_cancelRequested.contains(j.id) ||
          j.state != RecordingState.scheduled) {
        return;
      }
      if (data.identity != j.identity ||
          data.channel.sourceId.toInt() != j.sourceId) {
        throw StateError(
          'The source or channel changed. Schedule this recording again.',
        );
      }
      if (connections(j.sourceId) > data.maxConnections) {
        await downloads.yieldConnections(
          j.sourceId,
          connections(j.sourceId) - data.maxConnections,
        );
      }
      // Out of connections: record from the player if it shows this channel,
      // otherwise the recording takes the player's connection.
      if (connections(j.sourceId) > data.maxConnections &&
          playing?.sourceId == j.sourceId) {
        if (playing?.id == j.channelId && playerRecord != null) {
          j.viaPlayer = true;
        } else if (closePlayer != null) {
          await closePlayer!();
          playing = null;
          notice.value =
              'Closed the player to record ${j.channelName} · ${j.title}. Your provider allows one stream at a time.';
        }
      }
      if (connections(j.sourceId) > data.maxConnections) {
        throw StateError(
          'Provider connection limit reached. Stop playback or another transfer before scheduling again.',
        );
      }
      final directory = Directory(preferences.recordingFolder);
      await directory.create(recursive: true);
      final base = recordingFilename(
        j.channelName,
        j.title,
        DateTime.fromMillisecondsSinceEpoch(j.start * 1000),
      );
      var file = '${directory.path}/$base.ts';
      var suffix = 2;
      while (recordings.any((other) => other != j && other.file == file) ||
          await File(file).exists() ||
          await File(file.replaceFirst(RegExp(r'\.ts$'), '.mkv')).exists()) {
        file = '${directory.path}/$base (${suffix++}).ts';
      }
      j.file = file;
      j.actualStart = unixNow;
      j.state = RecordingState.recording;
      await persist();
      if (_cancelRequested.contains(j.id)) {
        j.state = RecordingState.canceled;
        await persist();
        return;
      }
      if (j.viaPlayer) {
        if (!await (playerRecord?.call(file) ?? Future.value(false))) {
          throw StateError('The player could not record this channel.');
        }
        return;
      }
      final c = data.channel;
      final h = c.playbackHeaders;
      final process = await Process.start('ffmpeg', [
        '-hide_banner',
        '-loglevel',
        'error',
        '-n',
        // Providers close live connections and replay their buffer; reconnect
        // rather than ending the recording at the first hiccup.
        '-reconnect',
        '1',
        '-reconnect_at_eof',
        '1',
        '-reconnect_streamed',
        '1',
        '-reconnect_on_network_error',
        '1',
        '-reconnect_delay_max',
        '10',
        if (h.hasUserAgent()) ...['-user_agent', h.userAgent],
        if (h.hasReferrer() || h.hasHttpOrigin()) ...[
          '-headers',
          '${h.hasReferrer() ? 'Referer: ${h.referrer}\r\n' : ''}${h.hasHttpOrigin() ? 'Origin: ${h.httpOrigin}\r\n' : ''}',
        ],
        '-i',
        c.url,
        // -t counts stream time, and providers send up to a minute of
        // buffered video at once, so it would end the recording early. The
        // scheduler stops ffmpeg at the wall-clock end; this is a backstop.
        '-t',
        '${(j.stop - unixNow).clamp(1, 86400 * 14) + 3600}',
        '-map',
        '0:v?',
        '-map',
        '0:a?',
        '-c',
        'copy',
        '-f',
        'mpegts',
        file,
      ]);
      _processes[j.id] = process;
      unawaited(process.stdout.drain<void>());
      unawaited(
        process.stderr.drain<void>(),
      ); // ffmpeg errors can include credentials.
      unawaited(
        process.exitCode
            .then((code) async {
              _processes.remove(j.id);
              if (j.state == RecordingState.recording) {
                await _ended(
                  j,
                  'The stream ended early; the part that was recorded is saved.',
                );
              }
            })
            .catchError((_) {
              storageError = 'Could not save the recording result.';
              notifyListeners();
            }),
      );
    } catch (e) {
      j.state = RecordingState.failed;
      j.error = e is StateError
          ? e.message.toString()
          : 'Could not start recording. Install ffmpeg (pacman -S ffmpeg) and check the destination folder.';
      await persist();
    } finally {
      _starting.remove(j.id);
      notifyListeners();
    }
  }

  /// The source of a running recording stopped by itself.
  Future<void> _ended(RecordingJob j, String earlyNote) async {
    final early = unixNow < j.stop - 3;
    final file = File(j.file!);
    if (await file.exists() && await file.length() > 0) {
      // Keep what was captured as a normal, playable recording.
      await _finish(j);
      if (early && j.state == RecordingState.completed) {
        j.error = earlyNote;
        await persist();
        notifyListeners();
      }
    } else {
      if (await file.exists()) await file.delete();
      j.file = null;
      j.state = RecordingState.failed;
      j.error =
          'The stream could not be recorded. Check that the channel plays.';
      await persist();
      notifyListeners();
    }
  }

  /// The player stopped saving its stream: it closed, changed channel, or is
  /// about to reload the same channel ([reloading]). Call it after the player
  /// has let go of the file.
  Future<void> playerStreamEnded({bool reloading = false}) async {
    for (final j in [...recordings]) {
      if (j.viaPlayer && j.state == RecordingState.recording) {
        j.state = RecordingState.finishing; // A second call must skip it.
        if (reloading) _interrupted.add(j);
        await _ended(
          j,
          reloading
              ? 'The stream reconnected; the recording continues in a new file.'
              : 'Recording ended when the player closed or changed channel.',
        );
      }
    }
  }

  /// After a reload of the same channel, carry on what [playerStreamEnded]
  /// cut short.
  Future<void> resumePlayerRecordings() async {
    final pending = [..._interrupted];
    _interrupted.clear();
    for (final j in pending) {
      if (_closing || playing?.id != j.channelId || j.stop <= unixNow + 10) {
        continue;
      }
      try {
        await addRecording(
          RecordingJob(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            channelId: j.channelId,
            sourceId: j.sourceId,
            channelName: j.channelName,
            title: j.title,
            identity: j.identity,
            start: unixNow,
            stop: j.stop,
            maxConnections: j.maxConnections,
          ),
        );
      } catch (_) {
        /* The first part is saved; its note says why it ended. */
      }
    }
  }

  Future<void> stopRecording(RecordingJob j) async {
    if (_starting.contains(j.id)) {
      _cancelRequested.add(j.id);
      while (_starting.contains(j.id)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      _cancelRequested.remove(j.id);
    }
    if (_finishing.containsKey(j.id)) return _finishing[j.id];
    if (!j.active) {
      j.state = RecordingState.canceled;
      await persist();
      notifyListeners();
      return;
    }
    j.state = RecordingState.finishing;
    final process = _processes[j.id];
    notifyListeners();
    if (j.viaPlayer) {
      try {
        await playerRecord?.call(null);
      } catch (_) {
        /* The player may already have closed. */
      }
      // mpv finishes writing the file just after the property is cleared.
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    if (process != null) {
      try {
        process.stdin.writeln('q');
        await process.stdin.flush();
      } catch (_) {
        /* The stream may already have ended. */
      }
      try {
        await process.exitCode.timeout(const Duration(seconds: 8));
      } on TimeoutException {
        process.kill(ProcessSignal.sigint);
        try {
          await process.exitCode.timeout(const Duration(seconds: 3));
        } on TimeoutException {
          process.kill(ProcessSignal.sigkill);
          await process.exitCode;
        }
      }
    }
    await _finish(j);
  }

  Future<void> _finish(RecordingJob j) {
    final existing = _finishing[j.id];
    if (existing != null) return existing;
    final future = _remux(j);
    _finishing[j.id] = future;
    return future.whenComplete(() => _finishing.remove(j.id));
  }

  Future<void> _remux(RecordingJob j) async {
    j.state = RecordingState.finishing;
    notifyListeners();
    try {
      final input = File(j.file!);
      if (!await input.exists() || await input.length() == 0) {
        throw StateError('Empty recording');
      }
      final output = File(input.path.replaceFirst(RegExp(r'\.ts$'), '.mkv'));
      // Reserve atomically: a file created while recording must never be
      // overwritten or removed by cleanup after ffmpeg refuses the output.
      await output.create(exclusive: true);
      try {
        final process = await Process.start('ffmpeg', [
          '-hide_banner',
          '-loglevel',
          'error',
          '-y', // This output belongs to us after the exclusive create above.
          '-i',
          input.path,
          '-map',
          '0',
          '-c',
          'copy',
          output.path,
        ]);
        unawaited(process.stdout.drain<void>());
        unawaited(process.stderr.drain<void>());
        final code = await process.exitCode.timeout(
          const Duration(minutes: 5),
          onTimeout: () {
            process.kill();
            return -1;
          },
        );
        if (code != 0 || !await output.exists() || await output.length() == 0) {
          throw StateError('Remux failed');
        }
      } catch (_) {
        if (await output.exists()) await output.delete();
        rethrow;
      }
      j.file = output.path;
      j.state = RecordingState.completed;
      await persist(); // Commit the finished file before removing the original.
      await input.delete();
    } catch (_) {
      j.state = RecordingState.failed;
      j.error =
          'Could not finish this recording. Any original TS file is retained and can be played from Local media.';
      await persist();
    }
    notifyListeners();
  }

  Future<void> deleteRecording(RecordingJob j) async {
    if (j.reserved) await stopRecording(j);
    if (j.file != null && await File(j.file!).exists()) {
      await File(j.file!).delete();
    }
    recordings.remove(j);
    await persist();
    notifyListeners();
  }

  Future<void> shutdown() async {
    _closing = true;
    _timer?.cancel();
    await downloads.shutdown();
    while (_busy) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    for (final j in [...activeRecordings]) {
      await stopRecording(j);
    }
    if (_write != null) await _write;
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await shutdown();
    return AppExitResponse.exit;
  }

  @override
  void dispose() {
    _timer?.cancel();
    downloads.removeListener(notifyListeners);
    downloads.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final coreTransfer = NativeTransfer(
  start: (request) => NativeBridge.instance.downloadFile(request),
  progress: (id) => NativeBridge.instance.downloadProgress(id),
  stop: (id) => NativeBridge.instance.stopDownload(id),
);
