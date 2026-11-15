import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:brentv/generated/generated_proto.pb.dart' as pb;
import 'package:brentv/native_bridge.dart';
import 'package:brentv/playback/ios/live_relay.dart';
import 'package:brentv/playback/ios_player.dart';
import 'package:flutter_test/flutter_test.dart';

import 'expansion_test.dart' as fixture;

void main() {
  test(
    'only streams Apple cannot play are repackaged, copying when it can',
    () {
      bool required(String video, String audio) =>
          LivePlan(video, audio).required;
      expect(required('h264', 'aac'), isFalse);
      expect(required('h264', 'ac3'), isFalse);
      expect(required('h264', 'eac3'), isFalse);
      expect(required('h264', ''), isFalse);
      // Radio and anything unidentified is left to Apple's player.
      expect(required('', 'aac'), isFalse);
      expect(required('', ''), isFalse);
      expect(required('hevc', 'aac'), isTrue);
      expect(required('h264', 'mp2'), isTrue);
      expect(required('mpeg2video', 'ac3'), isTrue);

      final hevc = const LivePlan('hevc', 'aac').arguments('IN', '/tmp/x');
      String after(List<String> args, String flag) =>
          args[args.indexOf(flag) + 1];
      expect(after(hevc, '-c:v'), 'copy');
      expect(after(hevc, '-tag:v'), 'hvc1');
      expect(after(hevc, '-c:a'), 'copy');
      expect(after(hevc, '-bsf:a'), 'aac_adtstoasc');
      expect(after(hevc, '-hls_segment_type'), 'fmp4');
      // The bundled FFmpeg has no TLS; it must only ever read the loopback.
      expect(after(hevc, '-protocol_whitelist'), 'file,http,tcp');
      expect(hevc.last, '/tmp/x/live.m3u8');

      final silent = const LivePlan('h264', 'mp2').arguments('IN', '/tmp/x');
      expect(after(silent, '-c:v'), 'copy');
      expect(silent, isNot(contains('-tag:v')));
      expect(after(silent, '-c:a'), 'aac');

      final old = const LivePlan('mpeg2video', 'ac3').arguments('IN', '/tmp/x');
      expect(after(old, '-c:v'), 'h264_videotoolbox');
      expect(old, containsAll(['-realtime', '-allow_sw']));
      expect(after(old, '-c:a'), 'copy');
      expect(old, isNot(contains('-bsf:a')));
    },
  );

  test('a movie is copied where it can be, from where it was left', () {
    const plan = MoviePlan({
      'streams': [
        {
          'index': 0,
          'codec_type': 'video',
          'codec_name': 'h264',
          'pix_fmt': 'yuv420p',
        },
        {'index': 1, 'codec_type': 'audio', 'codec_name': 'eac3'},
        {'index': 2, 'codec_type': 'audio', 'codec_name': 'aac'},
        {
          'index': 3,
          'codec_type': 'subtitle',
          'codec_name': 'hdmv_pgs_subtitle',
        },
        {
          'index': 4,
          'codec_type': 'subtitle',
          'codec_name': 'subrip',
          'tags': {'language': 'spa'},
        },
        {
          'index': 5,
          'codec_type': 'subtitle',
          'codec_name': 'ass',
          'tags': {'language': 'eng'},
        },
      ],
      'format': {'size': '4469926250'},
    });
    expect(plan.size, 4469926250);
    final args = plan.arguments('IN', '/tmp/x', start: 1234.5);
    String after(String flag) => args[args.indexOf(flag) + 1];
    // Seeking happens on the input, before it is read.
    expect(args.indexOf('-ss'), lessThan(args.indexOf('-i')));
    expect(after('-ss'), '1234.500');
    expect(after('-c:v'), 'copy');
    expect(after('-c:a'), 'copy');
    expect(after('-c:s'), 'webvtt');
    expect(
      [
        for (var i = 0; i < args.length; i++)
          if (args[i] == '-map') args[i + 1],
      ],
      ['0:0', '0:1', '0:5'],
    );
    expect(after('-hls_playlist_type'), 'event');
    expect(after('-var_stream_map'), 'v:0,a:0,s:0,sgroup:subs');

    final old = const MoviePlan({
      'streams': [
        {
          'index': 0,
          'codec_type': 'video',
          'codec_name': 'mpeg4',
          'pix_fmt': 'yuv420p',
        },
        {'index': 1, 'codec_type': 'audio', 'codec_name': 'mp3'},
      ],
    }).arguments('IN', '/tmp/x');
    expect(old[old.indexOf('-c:v') + 1], 'h264_videotoolbox');
    expect(old[old.indexOf('-c:a') + 1], 'aac');
    expect(old, isNot(contains('-ss')));
    expect(old, isNot(contains('-master_pl_name')));
    expect(IosPlayer.appleContainer('https://x/movie/u/p/1.mp4?t=1'), isTrue);
    expect(IosPlayer.appleContainer('https://x/movie/u/p/1.mkv'), isFalse);
    expect(IosPlayer.appleContainer('https://x/movie/u/p/1'), isTrue);
    expect(IosPlayer.appleContainer('https://x/watch?id=1'), isTrue);
  });

  test(
    'finished movies restart and unknown durations preserve valid resume',
    () {
      const plan = MoviePlan({
        'format': {'duration': '120'},
      });
      expect(plan.resumePosition(42), 42);
      for (final saved in [90.0, 119.5, 120.0, 150.0, -1.0, double.nan]) {
        expect(plan.resumePosition(saved), 0);
      }
      for (final value in [null, 'N/A', '0', 'NaN']) {
        expect(
          MoviePlan({
            'format': {'duration': value},
          }).resumePosition(42),
          42,
        );
      }
    },
  );

  test('a completed one-segment movie is playable', () async {
    final relay = await LiveRelay.open(
      'http://127.0.0.1/clip.mkv',
      openRelay: (_) async => pb.RelayInfo(token: 't', port: 1),
      closeRelay: (_) async {},
      invoke: (method, args) async {
        if (method == 'stream') {
          final arguments = (args['arguments'] as List).cast<String>();
          await File(arguments.last).writeAsString(
            '#EXTM3U\n#EXTINF:2,\nseg00000.m4s\n#EXT-X-ENDLIST\n',
          );
          return {'status': 'success'};
        }
        return null;
      },
    );
    try {
      expect(await relay.start(), isTrue);
    } finally {
      await relay.close();
    }
  });

  test(
    'an MKV movie streams through the relay with seeking, resume and its subtitle',
    () async {
      final f = fixture.Fixture();
      await f.init(count: 1);
      final root = await Directory.systemTemp.createTemp('brentv-movie-src-');
      final processes = <String, Process>{};
      HttpServer? provider;
      try {
        final film = File('${root.path}/film.mkv');
        await File('${root.path}/s.srt').writeAsString(
          '1\n00:00:01,000 --> 00:00:04,000\nHello\n\n2\n00:00:20,000 --> 00:00:24,000\nLater\n',
        );
        final made = await Process.run('ffmpeg', [
          '-hide_banner',
          '-loglevel',
          'error',
          '-f',
          'lavfi',
          '-i',
          'testsrc2=size=320x180:rate=24',
          '-f',
          'lavfi',
          '-i',
          'sine=frequency=440',
          '-i',
          '${root.path}/s.srt',
          '-t',
          '80',
          '-c:v',
          'libx264',
          '-preset',
          'ultrafast',
          '-pix_fmt',
          'yuv420p',
          '-g',
          '48',
          '-c:a',
          'eac3',
          '-c:s',
          'srt',
          film.path,
        ]);
        expect(made.exitCode, 0, reason: '${made.stderr}');
        final bytes = await film.readAsBytes();
        final ranges = <String?>[];
        provider = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        provider.listen((request) async {
          final range = request.headers.value('range');
          ranges.add(range);
          var from = 0;
          if (range != null) {
            from = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)![1]!);
            request.response.statusCode = 206;
            request.response.headers.set(
              'content-range',
              'bytes $from-${bytes.length - 1}/${bytes.length}',
            );
          }
          request.response.contentLength = bytes.length - from;
          try {
            request.response.add(bytes.sublist(from));
            await request.response.close();
          } catch (_) {
            /* The reader moved on. */
          }
        });
        Future<dynamic> invoke(String method, Map<String, dynamic> args) async {
          final id = args['id'] as String;
          if (method == 'cancel') {
            processes[id]?.kill(ProcessSignal.sigint);
            return null;
          }
          final process = await Process.start(
            method == 'probe' ? 'ffprobe' : 'ffmpeg',
            (args['arguments'] as List).cast<String>(),
          );
          processes[id] = process;
          final output = process.stdout.transform(utf8.decoder).join();
          unawaited(process.stderr.drain<void>());
          final code = await process.exitCode;
          processes.remove(id);
          if (method == 'probe') return 'log line\n${await output}\ntrailer';
          return {'status': code == 0 ? 'success' : 'failed'};
        }

        final url = 'http://127.0.0.1:${provider.port}/movie/u/p/film.mkv';
        Future<double> duration(String playlist) async {
          final probe = await Process.run('ffprobe', [
            '-v',
            'error',
            '-show_entries',
            'format=duration',
            '-of',
            'csv=p=0',
            playlist,
          ]);
          expect(probe.exitCode, 0, reason: '${probe.stderr}');
          return double.parse((probe.stdout as String).trim());
        }

        for (final start in [0.0, 24.0, 79.0, 90.0]) {
          final prepared = await LivePreparation.movie(
            url,
            const {},
            ignoreSsl: false,
            start: start,
            open: () => LiveRelay.open(
              url,
              seekable: true,
              invoke: invoke,
              videoEncoder: 'libx264',
            ),
            freeSpace: (_) async => 1 << 40,
          );
          final relay = prepared.relay!;
          final expectedStart = start >= 50 ? 0.0 : start;
          expect(prepared.offset, expectedStart);
          expect(relay.playlistUrl, endsWith('/play.m3u8'));
          await relay.ended;
          final folder = relay.directory.path;
          final master = await File('$folder/play.m3u8').readAsString();
          expect(master, contains('TYPE=SUBTITLES'));
          expect(master, contains('DEFAULT=NO,AUTOSELECT=YES'));
          expect(master, contains('ec-3'));
          final media = await File('$folder/live.m3u8').readAsString();
          expect(media, contains('#EXT-X-PLAYLIST-TYPE:EVENT'));
          expect(media, contains('#EXT-X-ENDLIST'));
          expect(
            await File('$folder/live_vtt.m3u8').readAsString(),
            contains('.vtt'),
          );
          // Played back over the loopback server, the whole remainder is there.
          expect(
            await duration(relay.playlistUrl.replaceFirst('play.', 'live.')),
            closeTo(80 - expectedStart, 2.5),
          );
          await relay.close();
          expect(await Directory(folder).exists(), isFalse);
        }

        // Exercise real FFmpeg's one-segment output near EOF, independently
        // of the completed-film restart policy above.
        final tail = await LiveRelay.open(
          url,
          seekable: true,
          invoke: invoke,
          videoEncoder: 'libx264',
        );
        try {
          final info = await tail.probe('mkv');
          expect(
            await tail.startMovie(MoviePlan(info!), 'mkv', start: 78),
            isTrue,
          );
          await tail.ended;
          final media = await File(
            '${tail.directory.path}/live.m3u8',
          ).readAsString();
          expect('#EXTINF'.allMatches(media), hasLength(1));
          expect(media, contains('#EXT-X-ENDLIST'));
        } finally {
          await tail.close();
        }
        // FFmpeg really seeks in the remote file: it asks for ranges.
        expect(ranges.whereType<String>(), isNotEmpty);

        // Too little space is said plainly, and nothing is left running.
        final full = await LivePreparation.movie(
          url,
          const {},
          ignoreSsl: false,
          start: 0,
          open: () => LiveRelay.open(url, seekable: true, invoke: invoke),
          freeSpace: (_) async => 1024,
        );
        expect(full.relay, isNull);
        expect(full.message, contains('Not enough free space'));
        expect(processes, isEmpty);
      } finally {
        for (final process in processes.values) {
          process.kill();
        }
        await provider?.close(force: true);
        await root.delete(recursive: true);
        await f.close();
      }
    },
    skip: !fixture.native,
    timeout: const Timeout(Duration(seconds: 120)),
  );

  test(
    'a repackager that produces nothing is reported and cleaned up',
    () async {
      var closed = 0;
      late Directory folder;
      final relay = await LiveRelay.open(
        'http://127.0.0.1/1.ts',
        openRelay: (request) async {
          folder = Directory(request.directory);
          return pb.RelayInfo(token: 't', port: 1, video: 'hevc', audio: 'aac');
        },
        closeRelay: (_) async => closed++,
        invoke: (method, _) async => {'status': 'failed'},
      );
      expect(await folder.exists(), isTrue);
      expect(await relay.start(timeout: const Duration(seconds: 2)), isFalse);
      await relay.close();
      await relay.close();
      expect(closed, 1);
      expect(await folder.exists(), isFalse);

      // An unreachable stream leaves nothing behind either.
      final before = await Directory.systemTemp
          .list()
          .where((e) => e.path.contains('brentv-live-'))
          .length;
      await expectLater(
        LiveRelay.open(
          'http://127.0.0.1/1.ts',
          openRelay: (_) async => throw StateError('offline'),
          closeRelay: (_) async {},
          invoke: (_, _) async => null,
        ),
        throwsStateError,
      );
      expect(
        await Directory.systemTemp
            .list()
            .where((e) => e.path.contains('brentv-live-'))
            .length,
        before,
      );
    },
  );

  test(
    'the core relay and FFmpeg turn live HEVC and MPEG-2 into fragmented-MP4 HLS',
    () async {
      final f = fixture.Fixture();
      await f.init(count: 1);
      final root = await Directory.systemTemp.createTemp('brentv-relay-src-');
      final processes = <String, Process>{};
      HttpServer? provider;
      try {
        Future<File> source(String name, List<String> codecs) async {
          final file = File('${root.path}/$name.ts');
          final made = await Process.run('ffmpeg', [
            '-hide_banner',
            '-loglevel',
            'error',
            '-f',
            'lavfi',
            '-i',
            'testsrc2=size=320x180:rate=25',
            '-f',
            'lavfi',
            '-i',
            'sine=frequency=440',
            '-t',
            '12',
            ...codecs,
            '-g',
            '25',
            '-f',
            'mpegts',
            file.path,
          ]);
          expect(made.exitCode, 0, reason: '${made.stderr}');
          return file;
        }

        final files = {
          'hevc': await source('hevc', [
            '-c:v',
            'libx265',
            '-preset',
            'ultrafast',
            '-x265-params',
            'log-level=error',
            '-c:a',
            'aac',
          ]),
          'old': await source('old', ['-c:v', 'mpeg2video', '-c:a', 'mp2']),
        };
        // A provider that sends the stream in real time over one response.
        provider = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        provider.listen((request) async {
          final file = files[request.uri.pathSegments.last.split('.').first]!;
          request.response.headers.contentType = ContentType('video', 'mp2t');
          try {
            final bytes = await file.readAsBytes();
            const step = 64 * 1024;
            for (var i = 0; i < bytes.length; i += step) {
              request.response.add(
                bytes.sublist(i, (i + step).clamp(0, bytes.length)),
              );
              await request.response.flush();
              await Future<void>.delayed(const Duration(milliseconds: 40));
            }
            await request.response.close();
          } catch (_) {
            /* The relay closed first. */
          }
        });
        Future<dynamic> invoke(String method, Map<String, dynamic> args) async {
          final id = args['id'] as String;
          if (method == 'cancel') {
            processes[id]?.kill(ProcessSignal.sigint);
            return null;
          }
          final process = await Process.start(
            'ffmpeg',
            (args['arguments'] as List).cast<String>(),
          );
          processes[id] = process;
          unawaited(process.stdout.drain<void>());
          unawaited(process.stderr.drain<void>());
          final code = await process.exitCode;
          processes.remove(id);
          return {'status': code == 0 ? 'success' : 'failed'};
        }

        for (final (name, video, audio, outVideo, outAudio) in [
          ('hevc', 'hevc', 'aac', 'hevc', 'aac'),
          ('old', 'mpeg2video', 'mp2', 'h264', 'aac'),
        ]) {
          final relay = await LiveRelay.open(
            'http://127.0.0.1:${provider.port}/live/u/p/$name.ts',
            invoke: invoke,
            videoEncoder: 'libx264',
          );
          expect((relay.info.video, relay.info.audio), (video, audio));
          expect(relay.plan.required, isTrue);
          expect(await relay.start(), isTrue, reason: name);
          // Read it back the way a player would: over the loopback server.
          final probe = await Process.run('ffprobe', [
            '-v',
            'error',
            '-show_entries',
            'stream=codec_name,codec_tag_string,codec_type',
            '-of',
            'json',
            relay.playlistUrl,
          ]);
          expect(probe.exitCode, 0, reason: '${probe.stderr}');
          final streams =
              (jsonDecode(probe.stdout as String)['streams'] as List)
                  .cast<Map>();
          final v = streams.firstWhere((s) => s['codec_type'] == 'video');
          final a = streams.firstWhere((s) => s['codec_type'] == 'audio');
          expect(v['codec_name'], outVideo);
          expect(a['codec_name'], outAudio);
          if (outVideo == 'hevc') expect(v['codec_tag_string'], 'hvc1');
          final playlist = await File(
            '${relay.directory.path}/live.m3u8',
          ).readAsString();
          expect(playlist, contains('#EXT-X-MAP:URI="init.mp4"'));
          expect(playlist, contains('#EXT-X-INDEPENDENT-SEGMENTS'));
          expect(playlist, isNot(contains('#EXT-X-ENDLIST')));
          expect(playlist, contains('.m4s'));
          final folder = relay.directory;
          await relay.close();
          expect(processes, isEmpty);
          expect(await folder.exists(), isFalse);
        }
      } finally {
        for (final process in processes.values) {
          process.kill();
        }
        await provider?.close(force: true);
        await root.delete(recursive: true);
        await f.close();
        NativeBridge.instance.dispose();
        if (fixture.db != null) await fixture.db!.delete(recursive: true);
      }
    },
    skip: !fixture.native,
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
