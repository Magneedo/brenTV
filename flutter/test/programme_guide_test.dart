import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixnum/fixnum.dart';
import 'package:brentv/generated/generated_proto.pb.dart' as pb;
import 'package:brentv/models/channel.dart';
import 'package:brentv/models/filters.dart';
import 'package:brentv/models/home_manager.dart';
import 'package:brentv/models/media_type.dart';
import 'package:brentv/models/settings.dart';
import 'package:brentv/models/view_type.dart';
import 'package:brentv/home.dart';
import 'package:brentv/channel_tile.dart';
import 'package:brentv/native_bridge.dart';
import 'package:brentv/programme_guide.dart';
import 'package:brentv/playback/external_mpv.dart';
import 'package:brentv/playback/mpv/ipc.dart';

extension _ReadMpv on MpvIpc {
  Future<dynamic> get(String name) => command(['get_property', name]);
}

Channel channel(int id, {int source = 1, int? stream}) => Channel(
  id: id,
  name: 'Channel $id',
  url: 'av://lavfi:testsrc=size=320x240:rate=25',
  sourceId: source,
  mediaType: MediaType.livestream,
  favorite: false,
  streamId: stream ?? id,
);
pb.NowNext guideData(String title, {int? boundary}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return pb.NowNext(
    supported: true,
    now: pb.Programme(
      title: title,
      start: Int64(now - 60),
      stop: Int64(boundary ?? now + 60),
    ),
    next: pb.Programme(
      title: 'Next programme',
      start: Int64(boundary ?? now + 60),
      stop: Int64(now + 180),
    ),
  );
}

Future<void> until(
  bool Function() ready, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  final end = DateTime.now().add(timeout);
  while (!ready()) {
    if (DateTime.now().isAfter(end)) fail('Probe did not reach expected state');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

Future<void> frames(WidgetTester tester, int milliseconds) async {
  for (var i = 0; i < milliseconds; i += 50) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

// The Rust core takes its database path once per process, so the native tests
// share one database and empty it between tests.
Directory? _database;

Future<(Directory, HttpServer, List<int>)> fixture(
  int count, {
  Future<void>? hold,
  Future<void> Function()? beforeResponse,
}) async {
  var dir = _database;
  if (dir == null) {
    dir = _database = await Directory.systemTemp.createTemp('brentv-guide-');
    await NativeBridge.instance.initialize(
      pb.InitMessage(dbPath: dir.path, tempPath: dir.path),
    );
  }
  final requests = <int>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final id = int.parse(request.uri.queryParameters['stream_id']!);
    requests.add(id);
    if (hold != null) await hold;
    await beforeResponse?.call();
    final data = guideData('Programme $id');
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'epg_listings': [
          for (final p in [data.now, data.next])
            {
              'title': base64Encode(utf8.encode(p.title)),
              'start_timestamp': '${p.start}',
              'stop_timestamp': '${p.stop}',
            },
        ],
      }),
    );
    await request.response.close();
  });
  final rows = [
    for (var id = 1; id <= count; id++)
      "($id,'Channel $id','av://lavfi:testsrc=size=320x240:rate=25',0,1,$id,$id,'0:$id',0)",
  ].join(',');
  final result = await Process.run('sqlite3', [
    '${dir.path}/db_rust.sqlite',
    '''
DELETE FROM channels; DELETE FROM sources;
INSERT INTO sources(id,name,source_type,enabled,url,username,password,import_live) VALUES
(1,'Local guide',2,1,'http://127.0.0.1:${server.port}/player_api.php','fixture','fixture',1);
INSERT INTO channels(id,name,url,media_type,source_id,stream_id,position,ext_key,favorite) VALUES $rows;
INSERT OR REPLACE INTO settings(key,value) VALUES('refreshOnStart','false'),('showProgrammes','true');
''',
  ]);
  expect(result.exitCode, 0, reason: result.stderr.toString());
  return (dir, server, requests);
}

void main() {
  tearDownAll(() async => _database?.delete(recursive: true));
  test('refresh waits for the next programme change', () {
    pb.Programme p(int start, int stop) =>
        pb.Programme(title: 'P', start: Int64(start), stop: Int64(stop));
    expect(nextRefresh(pb.NowNext(), 1000), 1600);
    expect(nextRefresh(pb.NowNext(supported: true), 1000), 1300);
    expect(
      nextRefresh(pb.NowNext(supported: true, now: p(900, 1200)), 1000),
      1200,
    );
    expect(
      nextRefresh(pb.NowNext(supported: true, now: p(900, 1010)), 1000),
      1060,
    );
    expect(
      nextRefresh(pb.NowNext(supported: true, now: p(900, 9000)), 1000),
      1540,
    );
    expect(
      nextRefresh(pb.NowNext(supported: true, next: p(1100, 1200)), 1000),
      1100,
    );
  });

  test(
    'scheduler serializes, pauses and rejects invalidated/disposed completions',
    () async {
      final calls = <int>[];
      final pending = <int, Completer<pb.NowNext>>{};
      final guide = ProgrammeGuide((id) {
        calls.add(id);
        return (pending[id] = Completer<pb.NowNext>()).future;
      });
      guide.setVisible([channel(1), channel(2)]);
      guide.setActive(true);
      await until(() => calls.isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(calls, [1]);
      guide.setVisible([channel(2)]);
      guide.invalidate();
      pending[1]!.complete(guideData('Stale'));
      await until(() => calls.contains(2));
      expect(guide.describe(1).$1, isNull);
      pending[2]!.complete(guideData('Visible'));
      await until(() => guide.describe(2).$1 == 'Visible');
      guide.setActive(false);
      final length = calls.length;
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(calls.length, length);
      guide.dispose();
      final late = Completer<pb.NowNext>();
      final disposed = ProgrammeGuide((_) => late.future);
      disposed.setVisible([channel(3)]);
      disposed.setActive(true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      disposed.dispose();
      late.complete(guideData('After disposal'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final filtered = <int>[];
      final unsupported = ProgrammeGuide((id) async {
        filtered.add(id);
        return pb.NowNext();
      });
      unsupported.setVisible([
        channel(4)..streamId = null,
        channel(5)..mediaType = MediaType.movie,
      ]);
      unsupported.setActive(true);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(filtered, isEmpty);
      unsupported.dispose();
    },
  );

  testWidgets('programme boundary and accessible compact title', (
    tester,
  ) async {
    late ProgrammeGuide guide;
    final end = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3;
    await tester.runAsync(() async {
      guide = ProgrammeGuide(
        (_) async => guideData('Current programme', boundary: end),
      );
      guide.setVisible([channel(1)]);
      guide.setActive(true);
      await until(() => guide.describe(1).$1 == 'Current programme');
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            height: 64,
            child: ChannelProgramme(
              name: 'Channel 1',
              channelId: 1,
              guide: guide,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Current programme'), findsOneWidget);
    await tester.runAsync(
      () => until(() => guide.describe(1).$1 == 'Next programme'),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 600)),
    );
    await tester.pump();
    expect(find.text('Next programme'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Center(
            child: SizedBox(
              width: 300,
              height: 128,
              child: ChannelProgramme(
                name: 'Channel 1',
                channelId: 1,
                guide: guide,
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    guide.dispose();
  });

  testWidgets(
    'native Home requests visible only, pauses and honors global off',
    (tester) async {
      late (Directory, HttpServer, List<int>) f;
      Completer<void>? hold, admitted;
      await tester.runAsync(() async {
        f = await fixture(
          200,
          beforeResponse: () async {
            final pending = hold;
            if (pending != null) {
              if (!admitted!.isCompleted) admitted!.complete();
              await pending.future;
            }
          },
        );
      });
      Future<void> holdNextRequest() async {
        hold = Completer<void>();
        admitted = Completer<void>();
        for (var i = 0; i < 60 && !admitted!.isCompleted; i++) {
          await frames(tester, 50);
        }
        expect(admitted!.isCompleted, isTrue);
      }

      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          home: Home(
            home: HomeManager(
              filters: Filters(
                sourceIds: [1],
                mediaTypes: [MediaType.livestream],
                viewType: ViewType.all,
              ),
            ),
          ),
        ),
      );
      await frames(tester, 1800);
      expect(f.$3, isNotEmpty);
      expect(find.textContaining('Programme '), findsWidgets);
      Set<int> visible() {
        final viewport = tester.getRect(find.byType(CustomScrollView));
        return {
          for (final element in find.byType(ChannelTile).evaluate())
            if (tester
                .getRect(find.byWidget(element.widget))
                .overlaps(viewport))
              (element.widget as ChannelTile).channel.id!,
        };
      }

      expect(visible().length, greaterThan(36));
      final search = tester.widget<TextField>(find.byType(TextField));
      expect(search.focusNode!.hasFocus, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: '/');
      await tester.pump();
      expect(search.focusNode!.hasFocus, isTrue);
      expect(search.controller!.text, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(search.focusNode!.hasFocus, isFalse);

      expect(
        f.$3.every(visible().contains),
        isTrue,
        reason: 'Requests ${f.$3}; visible ${visible()}',
      );
      // Pause with a known in-flight request. Count after server admission so
      // a request launched before the pause cannot race the assertion.
      await holdNextRequest();
      unawaited(
        nav.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Covered')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final covered = f.$3.length;
      hold!.complete();
      hold = null;
      await frames(tester, 1200);
      expect(f.$3.length, covered);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      await frames(tester, 600);
      await holdNextRequest();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      final inactive = f.$3.length;
      hold!.complete();
      hold = null;
      await frames(tester, 1200);
      expect(f.$3.length, inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pumpAndSettle();
      final afterScroll = f.$3.length;
      final nextVisible = visible();
      await frames(tester, 1200);
      expect(f.$3.skip(afterScroll).every(nextVisible.contains), isTrue);
      await tester.runAsync(() async {
        final settings = await NativeBridge.instance.getSettings();
        settings.showProgrammes = false;
        await NativeBridge.instance.updateSettings(settings);
        expect(
          (await NativeBridge.instance.getSettings()).showProgrammes,
          isFalse,
        );
        expect(
          (await NativeBridge.instance.getNowNext(100)).supported,
          isFalse,
        );
      });
      await tester.pump();
      final off = f.$3.length;
      await frames(tester, 1200);
      expect(f.$3.length, off);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await frames(tester, 300);
      expect(tester.takeException(), isNull);
      expect(f.$3.length, off);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await f.$2.close(force: true);
        NativeBridge.instance.dispose();
      });
    },
    skip:
        !Platform.isLinux || Platform.environment['BRENTV_NATIVE_TESTS'] != '1',
  );

  testWidgets(
    'real mpv receives actual feed programme without reloading',
    (tester) async {
      late Completer<void> release;
      late (Directory, HttpServer, List<int>) f;
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
      await tester.runAsync(() async {
        release = Completer<void>();
        f = await fixture(2, hold: release.future);
        final grouped = await Process.run('sqlite3', [
          '${f.$1.path}/db_rust.sqlite',
          "UPDATE channels SET alt_key='fixture';",
        ]);
        expect(grouped.exitCode, 0);
        await NativeBridge.instance.setAltOverride(
          2,
          pb.AltOverrideKind.ALT_OVERRIDE_PREFERRED,
        );
        final channels = await NativeBridge.instance.getAllChannels(
          Filters(
            sourceIds: [1],
            mediaTypes: [MediaType.livestream],
            viewType: ViewType.all,
          ),
        );
        final settings = Settings(
          hwdec: 'no',
          mpvExtraArgs: '--vo=null --ao=null',
        );
        await ExternalMpv.instance.play(
          context,
          channels.first,
          settings,
          siblings: channels,
        );
        final runtime = Directory(
          '${Platform.environment['XDG_RUNTIME_DIR']}/brentv',
        );
        final paths = await runtime
            .list()
            .where((e) => e is Directory)
            .toList();
        final ipc = await MpvIpc.connect('${paths.single.path}/ipc');
        final entry = await ipc.get('playlist/0/id');
        expect(await ipc.get('force-media-title'), 'Channel 2');
        await until(() => f.$3.isNotEmpty);
        expect(f.$3.toSet(), {2});
        release.complete();
        for (
          var i = 0;
          i < 100 &&
              await ipc.get('force-media-title') != 'Channel 2 · Programme 2';
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        }
        expect(await ipc.get('force-media-title'), 'Channel 2 · Programme 2');
        expect(await ipc.get('playlist/0/id'), entry);
        final off = await NativeBridge.instance.getSettings();
        off.showProgrammes = false;
        await NativeBridge.instance.updateSettings(off);
        for (
          var i = 0;
          i < 50 && await ipc.get('force-media-title') != 'Channel 2';
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        }
        expect(await ipc.get('force-media-title'), 'Channel 2');
        expect(await ipc.get('playlist/0/id'), entry);
        final count = f.$3.length;
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        expect(f.$3.length, count);
        await ipc.command(['quit']);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        ipc.close();
        await f.$2.close(force: true);
        NativeBridge.instance.dispose();
      });
    },
    skip:
        !Platform.isLinux || Platform.environment['BRENTV_NATIVE_TESTS'] != '1',
  );
}
