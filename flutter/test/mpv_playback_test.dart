import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brentv/generated/generated_proto.pb.dart' as pb;
import 'package:brentv/models/channel.dart';
import 'package:brentv/models/media_type.dart';
import 'package:brentv/models/settings.dart';
import 'package:brentv/native_bridge.dart';
import 'package:brentv/playback/external_mpv.dart';
import 'package:brentv/playback/mpv/ipc.dart';

Future<void> waitFor(Future<bool> Function() check) async {
  for (var i = 0; i < 300; i++) {
    if (await check()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  fail('Playback did not reach the expected state');
}

void main() {
  testWidgets(
    'external player uses native headers, keys, positions and restarts',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('brentv-native-');
        final root = Directory(
          '${Platform.environment['XDG_RUNTIME_DIR']}/brentv',
        );
        final bridge = NativeBridge.instance;
        await bridge.initialize(
          pb.InitMessage(dbPath: dir.path, tempPath: dir.path),
        );
        final fixture = await Process.run('sqlite3', [
          '${dir.path}/db_rust.sqlite',
          '''
INSERT INTO sources (id,name,source_type,enabled) VALUES (1,'Local',0,1);
INSERT INTO channels (id,name,url,media_type,source_id,favorite) VALUES
(1,'Fixture one','av://lavfi:testsrc=size=320x240:rate=25',1,1,0),
(2,'Fixture two','av://lavfi:testsrc=size=640x360:rate=25',1,1,0);
INSERT INTO channels (id,name,url,media_type,source_id,favorite,position) VALUES
(4,'Favorite one','av://lavfi:testsrc=size=320x240:rate=25',0,1,1,1),
(5,'Favorite two','av://lavfi:testsrc=size=640x360:rate=25',0,1,1,2);
INSERT INTO channel_http_headers (channel_id,user_agent,referrer,http_origin)
VALUES (1,'FixtureAgent','http://localhost/fixture','http://localhost');
''',
        ]);
        expect(fixture.exitCode, 0);
        final one = Channel(
          id: 1,
          name: 'Fixture one',
          url: 'av://lavfi:testsrc=size=320x240:rate=25',
          mediaType: MediaType.movie,
          sourceId: 1,
          favorite: false,
        );
        final two = Channel(
          id: 2,
          name: 'Fixture two',
          url: 'av://lavfi:testsrc=size=640x360:rate=25',
          mediaType: MediaType.movie,
          sourceId: 1,
          favorite: false,
        );
        final group = Channel(
          name: 'Group',
          mediaType: MediaType.group,
          sourceId: 1,
          favorite: false,
        );
        final settings = Settings(
          hwdec: 'no',
          mpvExtraArgs:
              '--no-config --vo=null --ao=null --demuxer-lavf-o=seekable=0',
        );
        final player = ExternalMpv.instance;
        MpvIpc? ipc;
        try {
          await player.play(
            context,
            one,
            settings,
            siblings: [one, group, two],
          );
          var instances = await root.list().toList();
          expect(
            instances,
            hasLength(1),
            reason: 'Use a private XDG_RUNTIME_DIR for this test',
          );
          final socket = '${instances.single.path}/ipc';
          expect((await instances.single.stat()).mode & 0x1ff, 0x1c0);
          ipc = await MpvIpc.connect(socket);
          expect(
            await ipc.command(['get_property', 'user-agent']),
            'FixtureAgent',
          );
          expect(await ipc.command(['get_property', 'http-header-fields']), [
            'Origin: http://localhost',
          ]);
          await Future<void>.delayed(const Duration(milliseconds: 1200));
          await ipc.command(['script-message', 'brentv-next']);
          await waitFor(
            () async =>
                await ipc!.command(['get_property', 'force-media-title']) ==
                'Fixture two',
          );
          expect(await ipc.command(['get_property', 'user-agent']), '');
          expect(await ipc.command(['get_property', 'referrer']), '');
          expect(
            await ipc.command(['get_property', 'http-header-fields']),
            isEmpty,
          );
          await waitFor(
            () async => (await bridge.getMoviePosition(1) ?? 0) >= 1,
          );
          final watched = await Process.run('sqlite3', [
            '${dir.path}/db_rust.sqlite',
            'SELECT last_watched IS NOT NULL FROM channels WHERE id=2;',
          ]);
          expect(watched.stdout.toString().trim(), '1');
          Future<void> keyTo(String key, String title) async {
            await ipc!.command(['script-message', key]);
            await waitFor(
              () async =>
                  await ipc!.command(['get_property', 'force-media-title']) ==
                  title,
            );
          }

          await keyTo('brentv-last', 'Fixture one');
          await keyTo('brentv-last', 'Fixture two');
          await keyTo('brentv-favorite-1', 'Favorite one');
          await keyTo('brentv-last', 'Fixture two');
          await keyTo('brentv-prev', 'Fixture one');
          await keyTo('brentv-favorite-1', 'Favorite one');
          await keyTo('brentv-next', 'Favorite two');
          await keyTo('brentv-last', 'Favorite one');
          await keyTo('brentv-last', 'Favorite two');
          final entry = await ipc.command(['get_property', 'playlist/0/id']);
          await ipc.command(['script-message', 'brentv-favorite-9']);
          await ipc.command(['script-message', 'brentv-favorite-2']);
          await Future<void>.delayed(const Duration(milliseconds: 300));
          expect(await ipc.command(['get_property', 'playlist/0/id']), entry);
          await ipc.command(['quit']);
          ipc.close();
          await waitFor(() async => !(await File(socket).exists()));
          await player.play(context, one, settings);
          instances = await root.list().toList();
          expect(instances, hasLength(1));
          expect(
            instances.single.path,
            isNot(socket.substring(0, socket.length - 4)),
          );
          ipc = await MpvIpc.connect('${instances.single.path}/ipc');
          expect(
            await ipc.command(['get_property', 'force-media-title']),
            'Fixture one',
          );
          await ipc.command(['quit']);
          await waitFor(() async => (await root.list().toList()).isEmpty);
          // Real close-delimited HTTP MPEG-TS: mpv reports EOF, not error.
          final clips = <List<int>>[];
          for (final seconds in [1, 5]) {
            final path = '${dir.path}/$seconds.ts';
            final generated = await Process.run('ffmpeg', [
              '-v',
              'error',
              '-f',
              'lavfi',
              '-i',
              'testsrc=size=160x120:rate=25',
              '-t',
              '$seconds',
              '-c:v',
              'mpeg2video',
              '-threads',
              '1',
              '-f',
              'mpegts',
              path,
            ]);
            expect(generated.exitCode, 0, reason: '${generated.stderr}');
            clips.add(await File(path).readAsBytes());
          }
          final server = await ServerSocket.bind(
            InternetAddress.loopbackIPv4,
            0,
          );
          var opens = 0;
          final openedAt = <DateTime>[];
          final sockets = <Socket>[];
          server.listen((socket) async {
            sockets.add(socket);
            try {
              final request = await socket
                  .cast<List<int>>()
                  .transform(utf8.decoder)
                  .first;
              final playback = request.toLowerCase().contains(
                'icy-metadata: 1',
              );
              if (playback) {
                opens++;
                debugPrint("HTTP playback open $opens");
                openedAt.add(DateTime.now());
              }
              socket.add(
                ascii.encode(
                  'HTTP/1.0 200 OK\r\n'
                  'Content-Type: video/mp2t\r\nConnection: close\r\n\r\n',
                ),
              );
              socket.add(clips[playback && opens == 2 ? 1 : 0]);
              await socket.flush();
              await socket.close();
            } catch (_) {
              socket.destroy();
            }
          });
          final url = 'http://127.0.0.1:${server.port}/stream';
          final setup = await Process.run('sqlite3', [
            '${dir.path}/db_rust.sqlite',
            "INSERT INTO channels (id,name,url,media_type,source_id,favorite) "
                "VALUES (3,'Interrupted','$url',0,1,0); "
                "INSERT INTO channel_http_headers (channel_id,user_agent) "
                "VALUES (3,'FixtureAgent');",
          ]);
          expect(setup.exitCode, 0);
          final interrupted = Channel(
            id: 3,
            name: 'Interrupted',
            url: url,
            mediaType: MediaType.livestream,
            sourceId: 1,
            favorite: false,
          );
          try {
            await player.play(context, interrupted, settings);
            instances = await root.list().toList();
            ipc = await MpvIpc.connect('${instances.single.path}/ipc');
            var eof = 0;
            final endedAt = <DateTime>[];
            ipc.events.listen((event) {
              if (event['event'] == 'end-file' && event['reason'] == 'eof') {
                eof++;
                endedAt.add(DateTime.now());
                debugPrint("mpv EOF $eof");
              }
            });
            await waitFor(() async => opens >= 3);
            await waitFor(() async => opens == 5);
            await waitFor(() async => eof >= 5);
            await Future<void>.delayed(const Duration(seconds: 5));
            expect(
              opens,
              5,
              reason:
                  'Recovery renews budget after 5s playback, '
                  'then exhausts three retries after short opens',
            );
            expect(
              openedAt[2].difference(endedAt[1]).inMilliseconds,
              greaterThanOrEqualTo(900),
            );
            expect(
              openedAt[3].difference(endedAt[2]).inMilliseconds,
              greaterThanOrEqualTo(1900),
            );
            expect(
              openedAt[4].difference(endedAt[3]).inMilliseconds,
              greaterThanOrEqualTo(3900),
            );
            await ipc.command(['quit']);
            await waitFor(() async => (await root.list().toList()).isEmpty);
            final beforeVod = opens;
            final vod = Channel(
              id: 3,
              name: 'VOD',
              url: url,
              mediaType: MediaType.movie,
              sourceId: 1,
              favorite: false,
            );
            await player.play(context, vod, settings);
            instances = await root.list().toList();
            ipc = await MpvIpc.connect('${instances.single.path}/ipc');
            await Future<void>.delayed(const Duration(seconds: 6));
            expect(
              opens,
              beforeVod + 1,
              reason: 'Natural VOD EOF never retries',
            );
            await ipc.command(['quit']);
            await waitFor(() async => (await root.list().toList()).isEmpty);
          } finally {
            for (final socket in sockets) {
              socket.destroy();
            }
            await server.close();
          }
          final live = Channel(
            id: 4,
            name: 'Unavailable local fixture',
            url: 'av://lavfi:brentv_nonexistent_filter',
            mediaType: MediaType.livestream,
            sourceId: 1,
            favorite: false,
          );
          await player.play(context, live, settings);
          instances = await root.list().toList();
          ipc = await MpvIpc.connect('${instances.single.path}/ipc');
          var failures = 0;
          ipc.events.listen((event) {
            if (event['event'] == 'end-file' && event['reason'] == 'error') {
              failures++;
            }
          });
          await waitFor(() async => failures == 3);
          await ipc.command(['quit']);
          await waitFor(() async => (await root.list().toList()).isEmpty);
        } finally {
          try {
            await ipc?.command(['quit']);
          } catch (_) {}
          ipc?.close();
          await dir.delete(recursive: true);
        }
      });
    },
    skip: Platform.environment['BRENTV_NATIVE_TESTS'] != '1',
  );
}
