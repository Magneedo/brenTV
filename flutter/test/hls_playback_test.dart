import 'dart:io';

import 'package:brentv/generated/generated_proto.pb.dart' as pb;
import 'package:brentv/models/filters.dart';
import 'package:brentv/models/media_type.dart';
import 'package:brentv/models/source.dart';
import 'package:brentv/models/source_type.dart';
import 'package:brentv/models/view_type.dart';
import 'package:brentv/native_bridge.dart';
import 'package:brentv/playback/feeds.dart';
import 'package:brentv/playback/mpv/ipc.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> waitFor(Future<bool> Function() check) async {
  for (var n = 0; n < 200; n++) {
    if (await check()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  fail('HLS rendition/audio did not become active');
}

void main() {
  test(
    'real HLS low/high/Auto retain a separate audio rendition',
    () async {
      final dir = await Directory.systemTemp.createTemp('brentv-hls-playback-');
      HttpServer? server;
      Process? process;
      MpvIpc? ipc;
      try {
        for (final size in ['640x360', '1280x720', 'audio']) {
          final audio = size == 'audio';
          final name = audio
              ? 'audio'
              : size == '640x360'
              ? 'low'
              : 'high';
          final built = await Process.run('ffmpeg', [
            '-hide_banner',
            '-loglevel',
            'error',
            '-f',
            'lavfi',
            '-i',
            audio ? 'sine=frequency=440' : 'testsrc=size=$size:rate=25',
            '-t',
            '8',
            if (audio) ...[
              '-vn',
              '-c:a',
              'aac',
            ] else ...[
              '-an',
              '-c:v',
              'libx264',
              '-pix_fmt',
              'yuv420p',
              '-preset',
              'ultrafast',
              '-g',
              '25',
            ],
            '-f',
            'hls',
            '-hls_time',
            '1',
            '-hls_list_size',
            '0',
            '${dir.path}/$name.m3u8',
          ]);
          expect(built.exitCode, 0, reason: built.stderr.toString());
        }
        await File('${dir.path}/master.m3u8').writeAsString('''#EXTM3U
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="English",DEFAULT=YES,AUTOSELECT=YES,URI="audio.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=300000,RESOLUTION=640x360,AUDIO="audio"
low.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1500000,RESOLUTION=1280x720,AUDIO="audio"
high.m3u8
''');
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final requests = <String>[];
        server.listen((request) async {
          requests.add(request.uri.path);
          final file = File('${dir.path}${request.uri.path}');
          if (await file.exists()) {
            request.response.headers.contentType = ContentType.parse(
              request.uri.path.endsWith('.m3u8')
                  ? 'application/vnd.apple.mpegurl'
                  : 'video/mp2t',
            );
            await request.response.addStream(file.openRead());
          } else {
            request.response.statusCode = 404;
          }
          await request.response.close();
        });
        final master = 'http://127.0.0.1:${server.port}/master.m3u8';
        final fixture = File('${dir.path}/fixture.m3u');
        await fixture.writeAsString('#EXTM3U\n#EXTINF:-1,Fixture\n$master\n');
        final bridge = NativeBridge.instance;
        await bridge.initialize(
          pb.InitMessage(dbPath: dir.path, tempPath: dir.path),
        );
        final source = await bridge.saveSource(
          Source(name: 'HLS', url: fixture.path, sourceType: SourceType.m3u),
        );
        await bridge.processSource(source);
        final channels = await bridge.getChannels(
          Filters(
            viewType: ViewType.all,
            sourceIds: [source.id!],
            mediaTypes: [MediaType.livestream],
          ),
        );
        final variants = await bridge.getStreamVariants(
          channels.single.id!,
          master,
        );
        final feeds = buildFeeds(channels.single, variants, []);
        expect(feeds, hasLength(3));
        expect(feeds.every((f) => f.url == master), isTrue);
        final socket = '${dir.path}/ipc';
        process = await Process.start('mpv', [
          '--no-config',
          '--idle=yes',
          '--vo=null',
          '--ao=null',
          '--hwdec=no',
          '--cache=no',
          '--input-ipc-server=$socket',
        ]);
        process.stdout.drain<void>();
        process.stderr.drain<void>();
        await waitFor(() async => File(socket).exists());
        ipc = await MpvIpc.connect(socket);
        for (final feed in [feeds.last, feeds[1], feeds.first]) {
          await ipc.command([
            'set_property',
            'hls-bitrate',
            feed.maxBitrate?.toString() ?? 'max',
          ]);
          await ipc.command(['loadfile', feed.url, 'replace']);
          final expectedWidth = feed.maxBitrate == 300000 ? 640 : 1280;
          await waitFor(() async {
            try {
              final width = await ipc!.command(['get_property', 'width']);
              final tracks =
                  await ipc.command(['get_property', 'track-list']) as List;
              return width == expectedWidth &&
                  tracks.any(
                    (t) => t['type'] == 'audio' && t['selected'] == true,
                  );
            } catch (_) {
              return false;
            }
          });
        }
        expect(requests, contains('/low.m3u8'));
        expect(requests, contains('/high.m3u8'));
        expect(
          requests.any((p) => p.startsWith('/audio') && p.endsWith('.ts')),
          isTrue,
        );
        expect(
          await ipc.command(['get_property', 'hls-bitrate']),
          isIn(['max', -1]),
        );
      } finally {
        try {
          await ipc?.command(['quit']);
        } catch (_) {
          process?.kill();
        }
        ipc?.close();
        if (process != null) await process.exitCode;
        await server?.close(force: true);
        await dir.delete(recursive: true);
      }
    },
    skip: Platform.environment['BRENTV_NATIVE_TESTS'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
