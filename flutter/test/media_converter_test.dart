import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:brentv/library/download_queue.dart';
import 'package:brentv/library/media_converter.dart';
import 'package:brentv/library/models.dart';
import 'package:brentv/library/media_library.dart';
import 'package:brentv/library/download_ui.dart';
import 'package:brentv/models/channel.dart';
import 'package:brentv/models/media_type.dart';
import 'package:brentv/generated/generated_proto.pb.dart' as pb;
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  setUp(
    () async =>
        root = await Directory.systemTemp.createTemp('brentv-conversion-test-'),
  );
  tearDown(() async => root.delete(recursive: true));
  Future<void> command(String executable, List<String> args) async {
    final r = await Process.run(executable, args);
    expect(r.exitCode, 0, reason: '${r.stderr}');
  }

  Future<Map<String, dynamic>> inspect(String file) async {
    final r = await Process.run('ffprobe', [
      '-v',
      'error',
      '-show_streams',
      '-show_format',
      '-of',
      'json',
      file,
    ]);
    expect(r.exitCode, 0);
    return jsonDecode(r.stdout as String);
  }

  Future<List> hashes(String file) async {
    final r = await Process.run('ffprobe', [
      '-v',
      'error',
      '-select_streams',
      'v:0',
      '-show_packets',
      '-show_data_hash',
      'sha256',
      '-show_entries',
      'packet=data_hash',
      '-of',
      'json',
      file,
    ]);
    expect(r.exitCode, 0);
    return (jsonDecode(r.stdout as String)['packets'] as List)
        .map((p) => p['data_hash'])
        .toList();
  }

  DownloadJob job(String name) => DownloadJob(
    id: name,
    title: name,
    identity: 'local',
    file: '${root.path}/$name.mp4',
    channelId: 0,
    sourceId: 0,
    readyToConvert: true,
    state: DownloadState.converting,
  );
  MediaConverter backend({
    void Function()? onRun,
    bool mixedLogs = false,
  }) => MediaConverter(
    freeSpace: (_) async => 10 * 1024 * 1024 * 1024,
    videoEncoder: 'libx264',
    invoke: (method, args) async {
      if (method == 'published') return false;
      if (method == 'discardReceipt') return null;
      if (method == 'progress') {
        return <String, dynamic>{};
      }
      if (method == 'publish') {
        await command('ln', [args['source'], args['destination']]);
        return null;
      }
      if (method == 'run') onRun?.call();
      final r = await Process.run(
        method == 'probe' ? 'ffprobe' : 'ffmpeg',
        List<String>.from(args['arguments']),
      );
      if (method == 'probe') {
        expect(r.exitCode, 0, reason: r.stderr as String);
        return mixedLogs
            ? '${List.filled(252, '[h264] no frame! {warning}').join('\n')}\n${r.stderr}${r.stdout}\nwarning {tail}'
            : r.stdout;
      }
      return r.exitCode == 0;
    },
  );
  Future<void> fixture(
    DownloadJob j, {
    String video = 'libx264',
    String audio = 'aac',
    bool subtitle = false,
    bool mp4 = false,
    bool ts = false,
  }) async {
    final captions = File('${root.path}/captions.srt');
    await captions.writeAsString('1\n00:00:00,000 --> 00:00:01,500\nCaption\n');
    await command('ffmpeg', [
      '-v',
      'error',
      '-f',
      'lavfi',
      '-i',
      'testsrc=size=160x90:rate=10',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440',
      if (subtitle) ...['-i', captions.path],
      '-t',
      '2',
      '-c:v',
      video,
      '-threads',
      '1',
      '-pix_fmt',
      'yuv420p',
      if (video == 'libx265') ...[
        '-x265-params',
        'pools=1:frame-threads=1:log-level=error',
      ],
      '-c:a',
      audio,
      if (subtitle) ...['-c:s', 'srt'],
      '-f',
      ts ? 'mpegts' : (mp4 ? 'mp4' : 'matroska'),
      j.part,
    ]);
  }

  test(
    'MKV H264 EAC3 and subtitles become MP4 with identical video packets',
    () async {
      final j = job("Movie's #?% 你好");
      await fixture(j, audio: 'eac3', subtitle: true);
      var runs = 0;
      await backend(onRun: () => runs++).prepare(j, () {});
      final out = Mp4Plan(await inspect(j.file));
      expect(out.video!['codec_name'], 'h264');
      expect(
        out.streams
            .where((s) => s['codec_type'] == 'audio')
            .single['codec_name'],
        'aac',
      );
      expect(
        out.streams
            .where((s) => s['codec_type'] == 'subtitle')
            .single['codec_name'],
        'mov_text',
      );
      expect(await hashes(j.file), await hashes(j.part));
      expect(await File(j.part).exists(), isTrue);
      expect(runs, 1);
      await command('ffmpeg', ['-v', 'error', '-i', j.file, '-f', 'null', '-']);
    },
  );
  test(
    'HEVC AAC transport stream remuxes to hvc1 MP4 without video encoding',
    () async {
      final j = job('Transport stream');
      await fixture(j, video: 'libx265', ts: true);
      var runs = 0;
      await backend(onRun: () => runs++).prepare(j, () {});
      final out = Mp4Plan(await inspect(j.file));
      expect(out.video!['codec_name'], 'hevc');
      expect(out.video!['codec_tag_string'], 'hvc1');
      expect(runs, 1);
      Future<List<String>> frames(String path) async {
        final r = await Process.run('ffmpeg', [
          '-v',
          'error',
          '-i',
          path,
          '-map',
          '0:v:0',
          '-f',
          'framemd5',
          '-',
        ]);
        expect(r.exitCode, 0);
        return (r.stdout as String)
            .split('\n')
            .where((l) => l.isNotEmpty && !l.startsWith('#'))
            .map((l) => l.split(',').last.trim())
            .toList();
      }

      expect(await frames(j.file), await frames(j.part));
    },
  );
  test(
    'compatible MP4 is published byte-identically without conversion',
    () async {
      final j = job('Compatible');
      await fixture(j, mp4: true);
      final before = await File(j.part).readAsBytes();
      var runs = 0;
      await backend(onRun: () => runs++).prepare(j, () {});
      expect(await File(j.file).readAsBytes(), before);
      expect(runs, 0);
    },
  );
  test('incompatible video becomes H264 and remains decodable', () async {
    final j = job('Old codec');
    await fixture(j, video: 'mpeg4');
    await backend().prepare(j, () {});
    expect(Mp4Plan(await inspect(j.file)).video!['codec_name'], 'h264');
    await command('ffmpeg', ['-v', 'error', '-i', j.file, '-f', 'null', '-']);
  });
  test('output collision and low disk preserve originals', () async {
    final j = job('Collision');
    await fixture(j, mp4: true);
    final original = await File(j.part).readAsBytes();
    await File(j.file).writeAsBytes([8, 9]);
    await expectLater(
      backend().prepare(j, () {}),
      throwsA(isA<DownloadFailure>()),
    );
    expect(await File(j.part).readAsBytes(), original);
    expect(await File(j.file).readAsBytes(), [8, 9]);
    final low = job('Low disk');
    await fixture(low, audio: 'eac3');
    final converter = MediaConverter(
      freeSpace: (_) async => 0,
      invoke: (method, args) async {
        expect(method, 'probe');
        final r = await Process.run(
          'ffprobe',
          List<String>.from(args['arguments']),
        );
        return r.stdout;
      },
    );
    await expectLater(
      converter.prepare(low, () {}),
      throwsA(isA<DownloadFailure>()),
    );
    expect(await File(low.part).exists(), isTrue);
    expect(await File(low.file).exists(), isFalse);
  });
  test(
    'completed transfer conversion pauses and resumes without provider requests',
    () async {
      final j = job('Resume')
        ..state = DownloadState.queued
        ..bytes = 4
        ..total = 4;
      await File(j.part).writeAsBytes([1, 2, 3, 4]);
      var resolving = 0, attempts = 0;
      final started = Completer<void>(), canceled = Completer<void>();
      final queue = DownloadQueue(
        resolve: (_) async {
          resolving++;
          throw StateError('No provider');
        },
        save: (_) async {},
        preferences: () => MediaPreferences(),
        canStart: (_, _) => false,
        freeSpace: (_) async => 1024 * 1024 * 1024,
        makePlayable: (job, changed) async {
          attempts++;
          if (attempts == 1) {
            started.complete();
            await canceled.future;
            throw const DownloadFailure('Paused');
          }
          await File(job.file).writeAsBytes(await File(job.part).readAsBytes());
        },
        cancelConversion: (_) async {
          canceled.complete();
        },
      );
      try {
        await queue.initialize(jsonEncode([j.toJson()]));
        await started.future;
        final restored = queue.jobs.single;
        expect(queue.connections(0), 0);
        await queue.pause(restored);
        expect(restored.state, DownloadState.paused);
        expect(await File(j.part).readAsBytes(), [1, 2, 3, 4]);
        await queue.resume(restored);
        for (
          var i = 0;
          i < 100 && restored.state != DownloadState.completed;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(restored.state, DownloadState.completed);
        expect(await File(j.file).readAsBytes(), [1, 2, 3, 4]);
        expect(resolving, 0);
      } finally {
        await queue.shutdown();
        queue.dispose();
      }
    },
  );
  test(
    'canceling the converter keeps the source and never publishes a partial MP4',
    () async {
      final j = job('Cancel');
      await File(j.part).writeAsBytes([1, 2, 3]);
      final started = Completer<void>(), stopped = Completer<bool>();
      final converter = MediaConverter(
        freeSpace: (_) async => 1024 * 1024 * 1024,
        invoke: (method, args) async {
          if (method == 'published') return false;
          if (method == 'probe') {
            return jsonEncode({
              'streams': [
                {
                  'index': 0,
                  'codec_type': 'video',
                  'codec_name': 'h264',
                  'pix_fmt': 'yuv420p',
                },
              ],
              'format': {'format_name': 'matroska', 'duration': '5'},
            });
          }
          if (method == 'run') {
            started.complete();
            return stopped.future;
          }
          if (method == 'cancel') {
            stopped.complete(false);
            return null;
          }
          if (method == 'progress') {
            return <String, dynamic>{};
          }
          fail('Canceled conversion must not publish');
        },
      );
      final conversion = converter.prepare(j, () {});
      final rejected = expectLater(conversion, throwsA(isA<DownloadFailure>()));
      await started.future;
      j.state = DownloadState.paused;
      await converter.cancel(j.id);
      await rejected;
      expect(await File(j.part).readAsBytes(), [1, 2, 3]);
      expect(await File(j.file).exists(), isFalse);
    },
  );
  test(
    'converting an existing download updates its catalog file and replaces the original',
    () async {
      final original = File('${root.path}/Existing.mkv');
      await original.writeAsBytes([1, 2, 3]);
      final j = DownloadJob(
        id: 'existing',
        title: 'Existing',
        identity: 'catalog',
        file: original.path,
        channelId: 42,
        sourceId: 1,
        state: DownloadState.completed,
        bytes: 3,
        total: 3,
      );
      final queue = DownloadQueue(
        resolve: (_) async => throw StateError('Must stay offline'),
        save: (_) async {},
        preferences: () => MediaPreferences(),
        canStart: (_, _) => false,
        makePlayable: (job, _) async {
          await File(
            job.conversionDestination,
          ).writeAsBytes(await File(job.conversionSource!).readAsBytes());
        },
      );
      try {
        await queue.initialize(jsonEncode([j.toJson()]));
        await queue.convertFile(original.path);
        for (
          var i = 0;
          i < 100 && queue.jobs.single.state != DownloadState.completed;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(queue.jobs.single.channelId, 42);
        expect(queue.jobs.single.file, '${root.path}/Existing.mp4');
        expect(queue.jobs.single.state, DownloadState.completed);
        expect(await File(queue.jobs.single.file).readAsBytes(), [1, 2, 3]);
        for (var i = 0; i < 100 && await original.exists(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(await original.exists(), isFalse);
        expect(queue.jobs.single.conversionSource, isNull);

        // A pair left by an earlier version is tidied on the next launch.
        final old = File('${root.path}/Earlier.mkv');
        await old.writeAsBytes([9]);
        await File('${root.path}/Earlier.mp4').writeAsBytes([9, 9]);
        final earlier = DownloadJob(
          id: 'earlier',
          title: 'Earlier',
          identity: 'local',
          file: '${root.path}/Earlier.mp4',
          channelId: 0,
          sourceId: 0,
          state: DownloadState.completed,
          conversionSource: old.path,
        );
        final next = DownloadQueue(
          resolve: (_) async => throw StateError('Must stay offline'),
          save: (_) async {},
          preferences: () => MediaPreferences(),
          canStart: (_, _) => false,
          makePlayable: (_, _) async {},
        );
        await next.initialize(jsonEncode([earlier.toJson()]));
        expect(await old.exists(), isFalse);
        expect(await File('${root.path}/Earlier.mp4').exists(), isTrue);
        expect(next.jobs.single.conversionSource, isNull);
        await next.shutdown();
        next.dispose();
      } finally {
        await queue.shutdown();
        queue.dispose();
      }
    },
  );
  test('ffprobe JSON survives merged native stderr and stdout', () async {
    final j = job('Mixed diagnostics');
    await fixture(j, audio: 'eac3');
    await backend(mixedLogs: true).prepare(j, () {});
    expect(Mp4Plan(await inspect(j.file)).copyAudio, isTrue);
  });
  for (final cancel in [false, true]) {
    test(
      'existing catalog download stays offline after ${cancel ? 'cancel' : 'failure'}',
      () async {
        final original = File('${root.path}/Old.mkv');
        await original.writeAsBytes([1, 2, 3]);
        final j = DownloadJob(
          id: 'catalog',
          title: 'Movie',
          identity: 'same',
          file: original.path,
          channelId: 42,
          sourceId: 1,
          state: DownloadState.completed,
          bytes: 3,
          total: 3,
        );
        final started = Completer<void>(), stop = Completer<void>();
        final queue = DownloadQueue(
          resolve: (_) async => throw StateError('Must stay offline'),
          save: (_) async {},
          preferences: () => MediaPreferences(),
          canStart: (_, _) => false,
          makePlayable: (job, _) async {
            started.complete();
            if (cancel) await stop.future;
            throw const DownloadFailure('Cannot convert');
          },
          cancelConversion: (_) async {
            if (!stop.isCompleted) stop.complete();
          },
        );
        final global = MediaLibrary.instance.downloads.jobs;
        try {
          await queue.initialize(jsonEncode([j.toJson()]));
          await queue.convertFile(original.path);
          await started.future;
          final current = queue.jobs.single;
          global.add(current);
          if (cancel) {
            await queue.pause(current);
            expect(current.state, DownloadState.paused);
          } else {
            for (
              var i = 0;
              i < 100 && current.state != DownloadState.failed;
              i++
            ) {
              await Future<void>.delayed(const Duration(milliseconds: 10));
            }
            expect(current.state, DownloadState.failed);
          }
          expect(current.file, original.path);
          expect(current.offlineFile, original.path);
          final item = Channel(
            id: 42,
            name: 'Movie',
            url: 'https://unused.invalid/movie',
            sourceId: 1,
            mediaType: MediaType.movie,
            favorite: false,
          );
          expect((await offlineChannel(item)).url, original.uri.toString());
          if (cancel) {
            await queue.cancel(current);
            expect(queue.jobs.single.state, DownloadState.completed);
            expect(queue.jobs.single.file, original.path);
          }
          expect(await original.readAsBytes(), [1, 2, 3]);
        } finally {
          global.clear();
          await queue.shutdown();
          queue.dispose();
        }
      },
    );
  }
  for (final ready in [false, true]) {
    test(
      'old ${ready ? 'verified' : 'queued'} MKV jobs publish an MP4 with original partial retained until commit',
      () async {
        final j = job('Legacy')
          ..file = '${root.path}/Legacy.mkv'
          ..state = DownloadState.queued
          ..readyToConvert = ready
          ..bytes = ready ? 4 : 0
          ..total = ready ? 4 : 0;
        final oldPart = j.part;
        if (ready) await File(oldPart).writeAsBytes([1, 2, 3, 4]);
        var resolveCalls = 0;
        final queue = DownloadQueue(
          resolve: (_) async {
            resolveCalls++;
            return pb.TransferInfo(
              identity: 'local',
              channel: pb.Channel(
                id: Int64(0),
                sourceId: Int64(0),
                url: 'https://unused.invalid/file.mkv',
              ),
            );
          },
          save: (_) async {},
          preferences: () => MediaPreferences(),
          canStart: (_, _) => true,
          freeSpace: (_) async => 1024 * 1024 * 1024,
          native: NativeTransfer(
            start: (request) async {
              expect(request.partPath, oldPart);
              await File(oldPart).writeAsBytes([1, 2, 3, 4]);
              return pb.DownloadStatus(
                bytes: Int64(4),
                total: Int64(4),
                finished: true,
              );
            },
            progress: (_) async => pb.DownloadStatus(),
            stop: (_) async {},
          ),
          makePlayable: (job, _) async {
            expect(job.conversionDestination, '${root.path}/Legacy.mp4');
            expect(job.conversionSource, oldPart);
            expect(job.conversionSourceIsPartial, isTrue);
            await File(
              job.conversionDestination,
            ).writeAsBytes(await File(oldPart).readAsBytes());
          },
        );
        try {
          await queue.initialize(jsonEncode([j.toJson()]));
          for (
            var i = 0;
            i < 100 && queue.jobs.single.state != DownloadState.completed;
            i++
          ) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
          expect(queue.jobs.single.state, DownloadState.completed);
          expect(queue.jobs.single.file, '${root.path}/Legacy.mp4');
          expect(await File(queue.jobs.single.file).readAsBytes(), [
            1,
            2,
            3,
            4,
          ]);
          expect(await File(oldPart).exists(), isFalse);
          expect(resolveCalls, ready ? 0 : 1);
        } finally {
          await queue.shutdown();
          queue.dispose();
        }
      },
    );
  }
  test(
    'native cancellation pauses instead of starting lossy fallback',
    () async {
      final j = job('Expired')
        ..state = DownloadState.queued
        ..bytes = 3
        ..total = 3;
      await File(j.part).writeAsBytes([1, 2, 3]);
      var runs = 0;
      final converter = MediaConverter(
        freeSpace: (_) async => 1024 * 1024 * 1024,
        invoke: (method, args) async {
          if (method == 'published') return false;
          if (method == 'probe') {
            return jsonEncode({
              'streams': [
                {
                  'index': 0,
                  'codec_type': 'video',
                  'codec_name': 'h264',
                  'pix_fmt': 'yuv420p',
                },
              ],
              'format': {'format_name': 'matroska', 'duration': '5'},
            });
          }
          if (method == 'run') {
            runs++;
            expect(
              (args['arguments']
                  as List)[(args['arguments'] as List).indexOf('-c:v') + 1],
              'copy',
            );
            return {'status': 'canceled'};
          }
          fail('Unexpected method $method');
        },
      );
      final queue = DownloadQueue(
        resolve: (_) async => throw StateError('Must stay offline'),
        save: (_) async {},
        preferences: () => MediaPreferences(),
        canStart: (_, _) => false,
        makePlayable: converter.prepare,
        cancelConversion: converter.cancel,
      );
      try {
        await queue.initialize(jsonEncode([j.toJson()]));
        for (
          var i = 0;
          i < 100 && queue.jobs.single.state != DownloadState.paused;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(queue.jobs.single.state, DownloadState.paused);
        expect(runs, 1);
        expect(await File(j.part).readAsBytes(), [1, 2, 3]);
        expect(await File(j.file).exists(), isFalse);
      } finally {
        await queue.shutdown();
        queue.dispose();
      }
    },
  );
  test(
    'durable publication lookup recovers a completed MP4 without reencoding',
    () async {
      final j = job('Published');
      await File(j.file).writeAsBytes([4, 5]);
      var calls = 0;
      final converter = MediaConverter(
        invoke: (method, args) async {
          calls++;
          expect(method, 'published');
          expect(args['destination'], j.file);
          return true;
        },
      );
      await converter.prepare(j, () {});
      expect(calls, 1);
      expect(j.conversionProgress, 1);
      expect(await File(j.file).readAsBytes(), [4, 5]);
    },
  );
  test(
    'unknown-duration output hitting its byte cap is never published',
    () async {
      final j = job('Unknown duration');
      await File(j.part).writeAsBytes([1, 2, 3]);
      final converter = MediaConverter(
        freeSpace: (_) async => 80 * 1024 * 1024,
        invoke: (method, args) async {
          if (method == 'published') return false;
          if (method == 'probe') {
            return jsonEncode({
              'streams': [
                {
                  'index': 0,
                  'codec_type': 'video',
                  'codec_name': 'h264',
                  'pix_fmt': 'yuv420p',
                },
              ],
              'format': {'format_name': 'matroska'},
            });
          }
          if (method == 'run') {
            final a = List<String>.from(args['arguments']);
            final f = await File(a.last).open(mode: FileMode.write);
            await f.truncate(int.parse(a[a.indexOf('-fs') + 1]));
            await f.close();
            return true;
          }
          fail('Partial MP4 must not be published');
        },
      );
      await expectLater(
        converter.prepare(j, () {}),
        throwsA(isA<DownloadFailure>()),
      );
      expect(await File(j.file).exists(), isFalse);
      expect(await File(j.part).readAsBytes(), [1, 2, 3]);
    },
  );
  test(
    'pause during persistence never gets overwritten by converter startup',
    () async {
      final j = job('Pause during save')..state = DownloadState.queued;
      await File(j.part).writeAsBytes([1, 2, 3]);
      final saving = Completer<void>(), release = Completer<void>();
      var conversions = 0;
      final queue = DownloadQueue(
        resolve: (_) async => throw StateError('No provider'),
        save: (_) async {
          if (!saving.isCompleted) {
            saving.complete();
            await release.future;
          }
        },
        preferences: () => MediaPreferences(),
        canStart: (_, _) => false,
        makePlayable: (_, _) async {
          conversions++;
        },
        cancelConversion: (_) async {},
      );
      try {
        queue.jobs.add(j);
        await queue.pump();
        await saving.future;
        final pause = queue.pause(j);
        await Future<void>.delayed(Duration.zero);
        release.complete();
        await pause;
        expect(j.state, DownloadState.paused);
        expect(conversions, 0);
        expect(await File(j.part).readAsBytes(), [1, 2, 3]);
      } finally {
        if (!release.isCompleted) release.complete();
        await queue.shutdown();
        queue.dispose();
      }
    },
  );
  test(
    'migration leaves a completed legacy MKV linked to its existing file',
    () async {
      final j = job('Completed legacy')
        ..file = '${root.path}/Completed legacy.mkv'
        ..state = DownloadState.completed;
      await File(j.file).writeAsBytes([1, 2, 3]);
      final queue = DownloadQueue(
        resolve: (_) async => throw StateError('No provider'),
        save: (_) async {},
        preferences: () => MediaPreferences(),
        canStart: (_, _) => false,
        makePlayable: (_, _) async => fail('Completed file must not restart'),
      );
      try {
        await queue.initialize(jsonEncode([j.toJson()]));
        expect(queue.jobs.single.file, j.file);
        expect(queue.jobs.single.offlineFile, j.file);
        expect(await File(j.file).readAsBytes(), [1, 2, 3]);
      } finally {
        await queue.shutdown();
        queue.dispose();
      }
    },
  );
  test(
    'first-beta paused conversion repairs the original catalog path',
    () async {
      final original = File('${root.path}/First beta.mkv');
      await original.writeAsBytes([1, 2, 3]);
      final j = job('First beta')
        ..state = DownloadState.paused
        ..conversionSource = original.path;
      final queue = DownloadQueue(
        resolve: (_) async => throw StateError('No provider'),
        save: (_) async {},
        preferences: () => MediaPreferences(),
        canStart: (_, _) => false,
        makePlayable: (_, _) async => fail('Paused'),
      );
      try {
        await queue.initialize(jsonEncode([j.toJson()]));
        expect(queue.jobs.single.file, original.path);
        expect(queue.jobs.single.conversionTarget, j.file);
        expect(queue.jobs.single.offlineFile, original.path);
      } finally {
        await queue.shutdown();
        queue.dispose();
      }
    },
  );
  test(
    'legacy migration never claims an unrelated same-size destination',
    () async {
      final j = job('Foreign')
        ..file = '${root.path}/Foreign.mkv'
        ..state = DownloadState.queued
        ..total = 3
        ..bytes = 3;
      final source = j.part;
      await File(source).writeAsBytes([1, 2, 3]);
      final target = File('${root.path}/Foreign.mp4');
      await target.writeAsBytes([8, 9, 10]);
      var attempts = 0;
      final queue = DownloadQueue(
        resolve: (_) async => throw StateError('No provider'),
        save: (_) async {},
        preferences: () => MediaPreferences(),
        canStart: (_, _) => false,
        makePlayable: (_, _) async {
          attempts++;
          throw const DownloadFailure('Destination exists');
        },
      );
      try {
        await queue.initialize(jsonEncode([j.toJson()]));
        for (
          var i = 0;
          i < 100 && queue.jobs.single.state != DownloadState.failed;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(queue.jobs.single.state, DownloadState.failed);
        expect(attempts, 1);
        expect(await target.readAsBytes(), [8, 9, 10]);
        expect(await File(source).readAsBytes(), [1, 2, 3]);
      } finally {
        await queue.shutdown();
        queue.dispose();
      }
    },
  );
}
