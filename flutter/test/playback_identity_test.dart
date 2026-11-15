import 'package:brentv/library/media_library.dart';
import 'package:brentv/library/models.dart';
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brentv/main.dart';
import 'package:brentv/models/channel.dart';
import 'package:brentv/models/media_type.dart';
import 'package:brentv/models/settings.dart';
import 'package:brentv/native_bridge.dart';
import 'package:brentv/playback/playback.dart';
import 'package:brentv/playback/mpv/ipc.dart';
import 'package:brentv/player.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:package_info_plus/package_info_plus.dart';
import 'expansion_test.dart' as fixture;

Channel local(String name, String url) => Channel(
  name: name,
  url: url,
  mediaType: MediaType.movie,
  sourceId: 0,
  favorite: false,
);

void main() {
  test(
    'playback identity distinguishes transient URLs and stable catalog rows',
    () {
      final one = local('One', 'file:///Videos/one.mp4');
      final two = local('Two', 'file:///Videos/two.mp4');
      expect(one.isLocal, isTrue);
      expect(one.sameAs(two), isFalse);
      expect(one.sameAs(local('Renamed', one.url!)), isTrue);
      expect(one.sameAs(null), isFalse);
      expect(local('Missing', '').sameAs(local('Missing too', '')), isFalse);
      final catalog = local('Catalog', one.url!)..id = 12;
      expect(one.sameAs(catalog), isFalse);
      expect(catalog.sameAs(local('New URL', two.url!)..id = 12), isTrue);
      expect(catalog.sameAs(local('Another row', one.url!)..id = 13), isFalse);
      expect(
        one.sameAs(local('Another source', one.url!)..sourceId = 9),
        isFalse,
      );
      expect(
        local('Catch-up', 'https://fixture.invalid/archive').isLocal,
        isFalse,
      );
    },
  );
  tearDownAll(() async {
    if (fixture.db != null) {
      NativeBridge.instance.dispose();
      await fixture.db!.delete(recursive: true);
    }
  });
  Future<fixture.Fixture> setup(WidgetTester tester) async {
    final f = fixture.Fixture();
    await tester.runAsync(() => f.init(count: 3));
    addTearDown(f.close);
    return f;
  }

  for (final downloaded in [false, true]) {
    testWidgets(
      downloaded
          ? 'downloaded catalog items navigate offline without provider requests or state writes'
          : 'local file mpv next previous and last keep catalog state untouched',
      (tester) async {
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (c) {
                context = c;
                return const SizedBox();
              },
            ),
          ),
        );
        final f = await setup(tester);
        await tester.runAsync(() async {
          final dir = await Directory.systemTemp.createTemp(
            'brentv-local-player-',
          );
          MpvIpc? ipc;
          try {
            final files = <Channel>[];
            for (final (index, name) in [
              'one #?% 你好.mkv',
              '-two sample.MKV',
            ].indexed) {
              final file = File('${dir.path}/$name');
              final r = await Process.run('ffmpeg', [
                '-v',
                'error',
                '-f',
                'lavfi',
                '-i',
                'testsrc=size=${index == 0 ? '160x120' : '320x180'}:rate=10',
                '-t',
                '3',
                '-c:v',
                'mpeg4',
                '-threads',
                '1',
                '-f',
                'matroska',
                file.path,
              ]);
              expect(r.exitCode, 0, reason: '${r.stderr}');
              if (downloaded) {
                files.add(
                  Channel(
                    id: index + 1,
                    name: name,
                    url: 'http://fixture.invalid/movie/$index.mp4',
                    mediaType: MediaType.movie,
                    sourceId: 1,
                    favorite: false,
                  ),
                );
                MediaLibrary.instance.downloads.jobs.add(
                  DownloadJob(
                    id: 'offline-$index',
                    title: name,
                    identity: 'fixture',
                    file: file.path,
                    channelId: index + 1,
                    sourceId: 1,
                    state: DownloadState.completed,
                  ),
                );
              } else {
                files.add(local(name, file.uri.toString()));
              }
            }
            final before = await fixture.sql(fixture.stateQuery);
            final settings = await NativeBridge.instance.getSettings();
            settings.showProgrammes = false;
            await Playback.play(
              context,
              files[0],
              settings: settings,
              siblings: files,
            );
            final runtime = Directory(
              '${Platform.environment['XDG_RUNTIME_DIR']}/brentv',
            );
            final instances = await runtime.list().toList();
            ipc = await MpvIpc.connect('${instances.single.path}/ipc');
            debugPrint('Local mpv connected');
            Future<dynamic> get(String property) async {
              try {
                return await ipc!.command(['get_property', property]);
              } on StateError {
                return null; // Video properties appear after the file opens.
              }
            }

            await fixture.waitFor(
              () async => await get('video-params/w') == 160,
            );
            debugPrint('Local mpv first file decoded');
            expect(
              await get('path'),
              anyOf(
                File('${dir.path}/${files[0].name}').uri.toString(),
                '${dir.path}/${files[0].name}',
              ),
            );
            for (final (key, width, title) in [
              ('PGUP', 320, files[1].name),
              ('BS', 160, files[0].name),
              ('BS', 320, files[1].name),
              ('PGDWN', 160, files[0].name),
            ]) {
              debugPrint('Local mpv key $key');
              await ipc.command(['keypress', key]);
              await fixture.waitFor(
                () async =>
                    await get('force-media-title') == title &&
                    await get('video-params/w') == width,
              );
            }
            debugPrint('Local mpv navigation complete; checking headers');
            expect(await get('user-agent'), '');
            expect(await get('referrer'), '');
            expect(await get('http-header-fields'), isEmpty);
            expect(f.requests, isEmpty);
            expect(await fixture.sql(fixture.stateQuery), before);
            debugPrint('Local mpv state checked; quitting');
            await ipc.command(['quit']);
            await fixture.waitFor(
              () async => (await runtime.list().toList()).isEmpty,
            );
          } finally {
            try {
              await ipc?.command(['quit']);
            } catch (_) {}
            ipc?.close();
            MediaLibrary.instance.downloads.jobs.removeWhere(
              (job) => job.file.startsWith('${dir.path}/'),
            );
            await dir.delete(recursive: true);
          }
        });
        await tester.pumpWidget(const SizedBox());
      },
      skip: !fixture.native,
    );
  }

  testWidgets(
    'a reused mpv window reconnects live EOF after playing a local file',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final f = await setup(tester);
      await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('brentv-idle-');
        MpvIpc? ipc;
        try {
          Future<void> clip(String path, String size, String format) async {
            final r = await Process.run('ffmpeg', [
              '-v',
              'error',
              '-f',
              'lavfi',
              '-i',
              'testsrc=size=$size:rate=10',
              '-t',
              '2',
              '-c:v',
              format == 'mpegts' ? 'mpeg2video' : 'mpeg4',
              '-threads',
              '1',
              '-f',
              format,
              '-y',
              path,
            ]);
            expect(r.exitCode, 0, reason: '${r.stderr}');
          }

          final file = File('${dir.path}/Local clip.mkv');
          await clip(file.path, '160x120', 'matroska');
          await clip('${dir.path}/live.ts', '320x180', 'mpegts');
          f.clip = await File('${dir.path}/live.ts').readAsBytes();
          await fixture.sql(
            "UPDATE channels SET url='http://127.0.0.1:${f.server.port}/live.ts' WHERE id=1",
          );
          final live = (await NativeBridge.instance.getAllChannels(
            fixture.filters(),
          )).firstWhere((c) => c.id == 1);
          final localFile = local('Local clip.mkv', file.uri.toString());
          final settings = await NativeBridge.instance.getSettings();
          settings.showProgrammes = false;
          settings.lowLatency = false;
          settings.mpvReuseWindow = true;
          await Playback.play(context, localFile, settings: settings);
          final runtime = Directory(
            '${Platform.environment['XDG_RUNTIME_DIR']}/brentv',
          );
          ipc = await MpvIpc.connect(
            '${(await runtime.list().toList()).single.path}/ipc',
          );
          Future<dynamic> get(String property) async {
            try {
              return await ipc!.command(['get_property', property]);
            } on StateError {
              return null;
            }
          }

          await fixture.waitFor(() async => await get('video-params/w') == 160);
          // The window was opened for a local file; live EOF must still
          // leave it running for the bounded reconnects.
          await Playback.play(context, live, settings: settings);
          int liveRequests() =>
              f.requests.where((u) => u.path == '/live.ts').length;
          // The fixture launches mpv paused; let the live clip reach EOF.
          await fixture.waitFor(() async => await get('video-params/w') == 320);
          await ipc.command(['set_property', 'pause', false]);
          await fixture.waitFor(() async => liveRequests() >= 2);
          await ipc.command(['quit']);
          await fixture.waitFor(
            () async => (await runtime.list().toList()).isEmpty,
          );
        } finally {
          try {
            await ipc?.command(['quit']);
          } catch (_) {}
          ipc?.close();
          await dir.delete(recursive: true);
        }
      });
      await tester.pumpWidget(const SizedBox());
    },
    skip: !fixture.native,
  );

  testWidgets(
    'built-in local next previous reset position and skip nonlocal transients',
    (tester) async {
      const video = MethodChannel('com.alexmercerind/media_kit_video');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(video, (
        call,
      ) async {
        if (call.method == 'VideoOutputManager.Create') {
          final dynamic current = tester.state(find.byType(Player));
          final native = current.player.platform as mk.NativePlayer;
          // Configure headless output before completing video-controller setup.
          await native.setProperty('vo', 'null', waitForInitialization: false);
          await native.setProperty('ao', 'null', waitForInitialization: false);
          await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
            video.name,
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('VideoOutput.Resize', {
                'handle': int.parse(call.arguments['handle']),
                'id': 1,
                'rect': const {'left': 0, 'top': 0, 'width': 32, 'height': 32},
              }),
            ),
            (_) {},
          );
        }
        return null;
      });
      final f = await setup(tester);
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('brentv-local-built-in-'),
      ))!;
      addTearDown(() => dir.delete(recursive: true));
      final files = <Channel>[];
      await tester.runAsync(() async {
        mk.MediaKit.ensureInitialized();
        for (var i = 0; i < 2; i++) {
          final file = File('${dir.path}/$i.mkv');
          final r = await Process.run('ffmpeg', [
            '-v',
            'error',
            '-f',
            'lavfi',
            '-i',
            'testsrc=size=${i == 0 ? '160x120' : '320x180'}:rate=10',
            '-t',
            '30',
            '-c:v',
            'mpeg4',
            '-threads',
            '1',
            file.path,
          ]);
          expect(r.exitCode, 0, reason: '${r.stderr}');
          files.add(local('Local $i', file.uri.toString()));
        }
      });
      final before = await tester.runAsync(
        () => fixture.sql(fixture.stateQuery),
      );
      await tester.runAsync(
        () => tester.pumpWidget(
          MaterialApp(
            home: Player(
              channel: files[0],
              settings: Settings(
                showProgrammes: false,
                linuxPlayer: LinuxPlayer.builtIn,
              ),
              siblings: [
                files[0],
                local('Archive', 'http://127.0.0.1:${f.server.port}/catchup'),
                files[1],
              ],
            ),
          ),
        ),
      );
      final dynamic state = tester.state(find.byType(Player));
      Future<void> wait(bool Function() check) async {
        for (var i = 0; i < 150; i++) {
          await fixture.frames(tester, 50);
          if (check()) return;
        }
        fail('Local built-in playback state timed out');
      }

      await wait(
        () => state.opening == false && state.player.state.width == 160,
      );
      debugPrint('Built-in first local file decoded');
      await tester.runAsync(() async {
        final native = state.player.platform as mk.NativePlayer;
        await native.setProperty('pause', 'yes');
        await native.setProperty('time-pos', '12');
      });
      await tester.runAsync(() async {
        final native = state.player.platform as mk.NativePlayer;
        await fixture.waitFor(
          () async => double.parse(await native.getProperty('time-pos')) >= 10,
        );
      });
      await tester.runAsync(() => state.adjacent(1) as Future<void>);
      await wait(
        () =>
            state.channel.sameAs(files[1]) == true &&
            state.player.state.width == 320,
      );
      debugPrint('Built-in next local file decoded');
      await tester.runAsync(() async {
        expect(
          (await (state.player.platform as mk.NativePlayer).getProperty(
            'time-pos',
          )).startsWith('0'),
          isTrue,
        );
      });
      await tester.runAsync(() => state.adjacent(-1) as Future<void>);
      await wait(
        () =>
            state.channel.sameAs(files[0]) == true &&
            state.player.state.width == 160,
      );
      await tester.runAsync(() => state.adjacent(-1) as Future<void>);
      expect(state.channel.sameAs(files[0]), isTrue);
      expect(
        await tester.runAsync(() => fixture.sql(fixture.stateQuery)),
        before,
      );
      expect(f.requests, isEmpty);
      await tester.runAsync(() => tester.pumpWidget(const SizedBox()));
      await fixture.frames(tester, 300);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        video,
        null,
      );
    },
    skip: !fixture.native,
  );

  testWidgets(
    'rapid settings writes persist their final snapshot and hover labels stay hidden',
    (tester) async {
      await setup(tester);
      PackageInfo.setMockInitialValues(
        appName: 'brenTV',
        packageName: 'xyz.brendynmarroquin.brentv',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
      await tester.runAsync(() async {
        final bridge = NativeBridge.instance;
        await bridge.updateLastSeenVersion('1.0.0');
        final settings = await bridge.getSettings();
        final writes = <Future<void>>[];
        for (var i = 0; i < 30; i++) {
          settings.searchDelayMs = i;
          settings.showMovies = i.isEven;
          writes.add(bridge.updateSettings(settings));
        }
        // A read issued before awaiting the writes must observe the final snapshot.
        final read = bridge.getSettings();
        final stored = await read;
        await Future.wait(writes);
        expect(stored.searchDelayMs, 29);
        expect(stored.showMovies, isFalse);
        stored.showProgrammes = false;
        await bridge.updateSettings(stored);
      });
      final settings = (await tester.runAsync(
        () => NativeBridge.instance.getSettings(),
      ))!;
      await tester.pumpWidget(
        MyApp(skipSetup: true, settings: settings, hasTouchScreen: true),
      );
      await fixture.frames(tester, 300);
      final semantics = tester.ensureSemantics();
      final tooltip = find.byTooltip('Settings');
      expect(tooltip, findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Settings')), findsWidgets);
      final state = tester.state<TooltipState>(tooltip);
      expect(TooltipVisibility.of(tester.element(tooltip)), isFalse);
      expect(state.ensureTooltipVisible(), isFalse);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await mouse.moveTo(tester.getCenter(tooltip));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Settings'), findsOneWidget);
      await mouse.removePointer();
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
    },
    skip: !fixture.native,
  );
}
