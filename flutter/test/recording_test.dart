import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:brentv/library/models.dart';
import 'package:brentv/library/media_library.dart';
import 'package:brentv/generated/generated_proto.pb.dart' as pb;
import 'package:fixnum/fixnum.dart';
import 'package:brentv/models/proto_extensions.dart';
import 'package:flutter_test/flutter_test.dart';

RecordingJob job(
  String id,
  int start,
  int stop, {
  int limit = 1,
  int source = 1,
  int channel = 1,
}) => RecordingJob(
  id: id,
  channelId: channel,
  sourceId: source,
  channelName: 'Channel',
  title: 'Program',
  identity: 'test',
  start: start,
  stop: stop,
  maxConnections: limit,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('padding, overlap capacity and adjacent programs', () {
    expect(RecordingJob.padded(1000, 2000, 2, 5), (880, 2300));
    final a = job('a', 100, 200),
        b = job('b', 200, 300),
        c = job('c', 199, 201);
    expect(a.conflicts([b]), isEmpty);
    expect(a.conflicts([c]), [c]);
    expect(job('d', 100, 300, limit: 2).conflicts([a, b]), isEmpty);
    expect(job('d', 100, 300, limit: 2).conflicts([a, c]), hasLength(2));
    expect(a.conflicts([job('x', 100, 200, source: 2)]), isEmpty);
    final finishing = job('finishing', 100, 200)
      ..state = RecordingState.finishing
      ..viaPlayer = true;
    expect(a.conflicts([finishing]), isEmpty);
    finishing.state = RecordingState.recording;
    expect(a.conflicts([finishing]), [finishing]);
  });
  test(
    'restart marks missed starts and interrupted recordings, retains future',
    () {
      final missed = job('a', 100, 300)..recover(150);
      expect(missed.state, RecordingState.missed);
      final future = job('b', 200, 300)..recover(150);
      expect(future.state, RecordingState.scheduled);
      final interrupted = job('c', 100, 300)..state = RecordingState.recording;
      interrupted.recover(150);
      expect(interrupted.state, RecordingState.failed);
      expect(
        RecordingJob.fromJson(jsonDecode(jsonEncode(missed.toJson()))).state,
        RecordingState.missed,
      );
    },
  );
  test('filenames cannot escape folders or contain control characters', () {
    expect(safeFilename('../bad/name:\nshow*'), '_bad_name__show_');
    expect(safeFilename('..'), 'Untitled');
    expect(utf8.encode(safeFilename('é' * 200)).length, 100);
    expect(
      recordingFilename('News', 'Tonight', DateTime(2026, 11, 14, 9, 5)),
      'News - Tonight - 2026-11-14 0905',
    );
    expect(MediaPreferences().recordingFolder.endsWith('/Videos/DVR'), true);
  });
  test(
    'a full provider records from the player, or takes its connection',
    () async {
      final library = MediaLibrary(
        save: (_) async {},
        resolve: (id) async => pb.TransferInfo(
          identity: 'test',
          maxConnections: 2,
          channel: pb.Channel(
            id: Int64(id),
            sourceId: Int64(1),
            url: 'http://127.0.0.1:9/unused',
          ),
        ),
      );
      final folder = await Directory.systemTemp.createTemp('brentv-player-');
      await library.initialize(pb.Settings());
      library.preferences
        ..recordingFolder = folder.path
        ..connectionLimit = 1; // The provider's "2" is not to be trusted.
      expect((await library.info(1)).maxConnections, 1);
      final files = <String?>[];
      var closed = false;
      library.playing = pb.Channel(id: Int64(1), sourceId: Int64(1)).toDomain();
      library.playerRecord = (file) async {
        files.add(file);
        if (file != null) await File(file).writeAsBytes([1, 2, 3]);
        return true;
      };
      library.closePlayer = () async => closed = true;
      final same = job('same', unixNow, unixNow + 60);
      await library.addRecording(same);
      for (var i = 0; i < 100 && same.state == RecordingState.scheduled; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(same.state, RecordingState.recording);
      expect(same.viaPlayer, true);
      expect(files.single, endsWith('.ts'));
      expect(closed, false);
      expect(library.connections(1), 1, reason: 'only the player is counted');
      await library.stopRecording(same);
      expect(files.last, isNull);

      // Another channel is on screen: the recording wins the connection.
      library.playing = pb.Channel(id: Int64(2), sourceId: Int64(1)).toDomain();
      final other = job('other', unixNow, unixNow + 60);
      await library.addRecording(other);
      for (var i = 0; i < 300 && !closed; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(closed, true);
      expect(other.viaPlayer, false);
      await library.shutdown();
      library.dispose();
      await folder.delete(recursive: true);
    },
  );
  for (final limit in [1, 2]) {
    test(
      'recording reconnect continues during remux with $limit provider streams',
      () async {
        final folder = await Directory.systemTemp.createTemp(
          'brentv-reconnect-',
        );
        final finishing = Completer<void>(), release = Completer<void>();
        final library = MediaLibrary(
          save: (state) async {
            if (state.recordingJobs.contains('"state":"failed"') &&
                !release.isCompleted) {
              if (!finishing.isCompleted) finishing.complete();
              await release.future;
            }
          },
          resolve: (id) async => pb.TransferInfo(
            identity: 'test',
            maxConnections: limit,
            channel: pb.Channel(
              id: Int64(id),
              sourceId: Int64(1),
              url: 'http://127.0.0.1:9/unused',
            ),
          ),
        );
        try {
          await library.initialize(pb.Settings());
          library.preferences.recordingFolder = folder.path;
          if (limit == 2) {
            // Occupy the other slot so both cases record via the player.
            final otherFile = File('${folder.path}/Other.ts');
            await otherFile.writeAsBytes([]);
            library.recordings.add(
              job(
                  'other-slot',
                  unixNow,
                  unixNow + 120,
                  limit: limit,
                  channel: 2,
                )
                ..state = RecordingState.recording
                ..file = otherFile.path,
            );
          }
          library.playing = pb.Channel(
            id: Int64(1),
            sourceId: Int64(1),
          ).toDomain();
          library.playerRecord = (file) async {
            if (file != null) await File(file).writeAsBytes([]);
            return true;
          };
          final first = job('first', unixNow, unixNow + 120, limit: limit);
          await library.addRecording(first);
          for (
            var i = 0;
            i < 300 && first.state != RecordingState.recording;
            i++
          ) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
          expect(first.state, RecordingState.recording);
          expect(first.viaPlayer, true);
          final ended = library.playerStreamEnded(reloading: true);
          final resumed = library.resumePlayerRecordings();
          await finishing.future.timeout(const Duration(seconds: 5));
          expect(library.recordings, hasLength(limit + 1));
          release.complete();
          await Future.wait([ended, resumed]);
          expect(library.recordings, hasLength(limit + 1));
          final continuation = library.recordings.last;
          for (
            var i = 0;
            i < 300 && continuation.state != RecordingState.recording;
            i++
          ) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
          expect(continuation.state, RecordingState.recording);
          expect(continuation.viaPlayer, true);
          expect(continuation.stop, first.stop);
          expect(library.connections(1), limit);
        } finally {
          if (!release.isCompleted) release.complete();
          await library.shutdown();
          library.dispose();
          await folder.delete(recursive: true);
        }
      },
    );
  }
  test(
    'remux preserves an existing destination and the original recording',
    () async {
      final folder = await Directory.systemTemp.createTemp('brentv-remux-');
      final input = File('${folder.path}/Recording.ts');
      final existing = File('${folder.path}/Recording.mkv');
      await input.writeAsBytes([1, 2, 3]);
      await existing.writeAsBytes([9, 8, 7]);
      final library = MediaLibrary(save: (_) async {});
      final recording = job('collision', unixNow, unixNow + 60)
        ..state = RecordingState.recording
        ..viaPlayer = true
        ..file = input.path;
      library.recordings.add(recording);
      library.playerRecord = (_) async => true;
      try {
        await library.stopRecording(recording);
        expect(recording.state, RecordingState.failed);
        expect(recording.file, input.path);
        expect(await input.readAsBytes(), [1, 2, 3]);
        expect(await existing.readAsBytes(), [9, 8, 7]);
      } finally {
        await library.shutdown();
        library.dispose();
        await folder.delete(recursive: true);
      }
    },
  );
  test(
    'scheduler persists before launching and refuses a busy provider',
    () async {
      final writes = <pb.Settings>[];
      final library = MediaLibrary(
        save: (s) async {
          writes.add(s);
        },
        resolve: (id) async => pb.TransferInfo(
          identity: 'test',
          maxConnections: 1,
          channel: pb.Channel(
            id: Int64(1),
            sourceId: Int64(1),
            url: 'http://127.0.0.1/unused',
          ),
        ),
      );
      await library.initialize(pb.Settings());
      library.playing = pb.Channel(id: Int64(2), sourceId: Int64(1)).toDomain();
      final j = job('a', unixNow, unixNow + 60);
      await library.addRecording(j);
      for (var i = 0; i < 100 && j.state == RecordingState.scheduled; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(j.state, RecordingState.failed);
      expect(j.error, contains('connection limit'));
      expect(writes.any((s) => s.recordingJobs.contains('scheduled')), true);
      await library.shutdown();
      library.dispose();
    },
  );
  test(
    'concurrent ffmpeg recordings reserve unique names and remux without a player',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'brentv-dvr-test-',
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sources = <Process>[];
      final writes = <pb.Settings>[];
      server.listen((request) async {
        final source = await Process.start('ffmpeg', [
          '-hide_banner',
          '-loglevel',
          'error',
          '-filter_threads',
          '1',
          '-re',
          '-f',
          'lavfi',
          '-i',
          'testsrc2=size=320x180:rate=25',
          '-c:v',
          'mpeg2video',
          '-threads',
          '1',
          '-f',
          'mpegts',
          'pipe:1',
        ]);
        sources.add(source);
        unawaited(source.stderr.drain<void>());
        request.response.headers.contentType = ContentType('video', 'mp2t');
        try {
          await request.response.addStream(source.stdout);
          await request.response.close();
        } catch (_) {
          /* Recorder closed the fixture stream. */
        } finally {
          source.kill();
        }
      });
      final library = MediaLibrary(
        save: (state) async {
          writes.add(state);
        },
        resolve: (id) async => pb.TransferInfo(
          identity: 'test',
          maxConnections: 2,
          channel: pb.Channel(
            id: Int64(id),
            sourceId: Int64(1),
            url: 'http://127.0.0.1:${server.port}/live.ts',
          ),
        ),
      );
      try {
        await library.initialize(
          pb.Settings(
            mediaPreferences: MediaPreferences(
              recordingFolder: directory.path,
            ).encode(),
          ),
        );
        final start = unixNow;
        final first = job('real', start, start + 120, limit: 2);
        final second = job(
          'collision',
          start,
          start + 120,
          limit: 2,
          channel: 2,
        );
        final recordings = [first, second];
        await Future.wait(recordings.map(library.addRecording));
        for (var i = 0; i < 400; i++) {
          final ready = await Future.wait(
            recordings.map(
              (j) async =>
                  j.file != null &&
                  await File(j.file!).exists() &&
                  await File(j.file!).length() > 0,
            ),
          );
          if (ready.every((value) => value)) break;
          for (final j in recordings) {
            if (j.state == RecordingState.failed) fail(j.error!);
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        expect(first.file, isNot(second.file));
        expect(library.playing, isNull);
        for (final j in recordings) {
          expect(j.state, RecordingState.recording);
          expect(j.file, endsWith('.ts'));
        }
        await Future.wait(recordings.map(library.stopRecording));
        for (final j in recordings) {
          expect(j.state, RecordingState.completed, reason: j.error);
          expect(j.file, endsWith('.mkv'));
          expect(await File(j.file!).length(), greaterThan(0));
          expect(
            await File(j.file!.replaceFirst('.mkv', '.ts')).exists(),
            false,
          );
        }
        expect(
          writes.map((s) => s.recordingJobs).join(),
          isNot(contains('http://')),
        );
      } finally {
        await library.shutdown();
        library.dispose();
        for (final source in sources) {
          source.kill();
          await source.exitCode;
        }
        await server.close(force: true);
        await directory.delete(recursive: true);
      }
    },
    skip:
        !Platform.isLinux ||
        Platform.environment['BRENTV_RECORDING_TESTS'] != '1',
    timeout: const Timeout(Duration(seconds: 45)),
  );
}
