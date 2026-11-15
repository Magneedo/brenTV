import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brentv/generated/generated_proto.pb.dart' as pb;
import 'package:brentv/models/channel.dart';
import 'package:brentv/models/filters.dart';
import 'package:brentv/models/home_manager.dart';
import 'package:brentv/models/media_type.dart';
import 'package:brentv/models/settings.dart';
import 'package:brentv/models/view_type.dart';
import 'package:brentv/home.dart';
import 'package:brentv/channel_tile.dart';
import 'package:brentv/full_guide.dart';
import 'package:brentv/hidden_items.dart';
import 'package:brentv/settings_view.dart';
import 'package:brentv/native_bridge.dart';
import 'package:brentv/programme_guide.dart';
import 'package:brentv/playback/playback.dart';
import 'package:brentv/playback/mpv/ipc.dart';
import 'programme_guide_test.dart' as helpers;

final native =
    Platform.isLinux && Platform.environment['BRENTV_NATIVE_TESTS'] == '1';
final root = Directory.systemTemp;
Directory? db;
Future<String> sql(String query) async {
  final r = await Process.run('sqlite3', ['${db!.path}/db_rust.sqlite', query]);
  expect(r.exitCode, 0, reason: '${r.stderr}');
  return r.stdout.toString().trim();
}

Filters filters() => Filters(
  sourceIds: [1],
  mediaTypes: [MediaType.livestream],
  viewType: ViewType.all,
);

class Fixture {
  late HttpServer server;
  final requests = <Uri>[];
  final headers = <Map<String, String>>[];
  Completer<void>? hold;
  bool archive = true, error = false;
  int active = 0, peak = 0;
  // A non-minute start requires one extra archive minute after date truncation.
  final start =
      (DateTime.now().millisecondsSinceEpoch ~/ 60000) * 60 - 7200 + 17;
  int get stop => start + 1800;
  String get localDate => DateTime.fromMillisecondsSinceEpoch(
    (start - 5 * 3600) * 1000,
    isUtc: true,
  ).toIso8601String().substring(0, 19).replaceFirst('T', ' ');
  List<int> clip = [];
  Future<void> init({int count = 60}) async {
    if (db == null) {
      db = await root.createTemp('db-');
      await NativeBridge.instance.initialize(
        pb.InitMessage(dbPath: db!.path, tempPath: db!.path),
      );
    }
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) async {
      requests.add(r.uri);
      headers.add({
        for (final k in ['user-agent', 'referer', 'origin'])
          k: r.headers.value(k) ?? '',
      });
      active++;
      if (active > peak) peak = active;
      try {
        if (hold != null) await hold!.future;
        if (r.uri.path.endsWith('.m3u8')) {
          r.response.write(
            '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=160x120\n/variant.ts\n',
          );
        } else if (r.uri.path.endsWith('.ts')) {
          r.response.headers.contentType = ContentType('video', 'mp2t');
          r.response.contentLength = clip.length;
          r.response.add(clip);
        } else if (error) {
          r.response.statusCode = 503;
        } else {
          final hour =
              (DateTime.now().millisecondsSinceEpoch ~/ 3600000) * 3600;
          r.response.headers.contentType = ContentType.json;
          r.response.write(
            jsonEncode({
              'epg_listings': [
                {
                  'title': 'Archived fixture',
                  'start_timestamp': '$start',
                  'stop_timestamp': '$stop',
                  'start': localDate,
                  'has_archive': archive ? 1 : 0,
                },
                {
                  'title': 'Visible fixture',
                  'start_timestamp': '$hour',
                  'stop_timestamp': '${hour + 3600}',
                  'has_archive': 0,
                },
              ],
            }),
          );
        }
        await r.response.close();
      } finally {
        active--;
      }
    });
    final rows = [
      for (var id = 1; id <= count; id++)
        "($id,'Channel $id','av://lavfi:testsrc=size=160x120:rate=25',0,1,$id,$id,1,1,7,1,12345)",
    ].join(',');
    await sql(
      '''DELETE FROM channel_http_headers; DELETE FROM movie_positions; DELETE FROM channels; DELETE FROM groups; DELETE FROM sources; DELETE FROM settings;
INSERT INTO sources(id,name,source_type,enabled,url,username,password,import_live) VALUES(1,'Fixture',2,1,'http://127.0.0.1:${server.port}/player_api.php','fixture','fixture',1);
INSERT INTO groups(id,name,source_id,media_type) VALUES(1,'Fixture group',1,0);
INSERT INTO channels(id,name,url,media_type,source_id,stream_id,position,group_id,tv_archive,archive_days,favorite,last_watched) VALUES $rows;
INSERT INTO channel_http_headers(channel_id,user_agent,referrer,http_origin) VALUES(1,'ExpansionFixture','http://fixture.invalid/ref','http://fixture.invalid');
INSERT INTO movie_positions(channel_id,position) VALUES(1,42);
''',
    );
    await NativeBridge.instance.updateSettings(
      Settings(
        autoQualityDiscovery: false,
        hwdec: 'no',
        mpvExtraArgs: '--no-config --vo=null --ao=null --pause',
      ),
    );
  }

  Future<void> close() async {
    if (hold != null && !hold!.isCompleted) hold!.complete();
    await server.close(force: true);
  }
}

Future<void> waitFor(Future<bool> Function() ready) async {
  for (var i = 0; i < 200; i++) {
    if (await ready()) return;
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }
  fail('Expected external outcome not observed');
}

Future<void> frames(WidgetTester tester, [int ms = 800]) =>
    helpers.frames(tester, ms);
const stateQuery =
    'SELECT id,favorite,last_watched,hidden FROM channels ORDER BY id; SELECT channel_id,position FROM movie_positions ORDER BY channel_id;';
void main() {
  tearDownAll(() async {
    if (db != null) {
      NativeBridge.instance.dispose();
      await db!.delete(recursive: true);
    }
  });
  testWidgets('Favorites tabs paginate categories and preserve channel state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = Fixture();
    await tester.runAsync(() => f.init(count: 90));
    addTearDown(f.close);
    final groups = [
      for (var i = 1; i <= 73; i++)
        "(${i + 1},'Favorite category ${i.toString().padLeft(2, '0')}',1,0,1)",
    ].join(',');
    late String before;
    await tester.runAsync(() async {
      await sql(
        '''INSERT INTO groups(id,name,source_id,media_type,favorite) VALUES $groups;
UPDATE channels SET favorite=0,group_id=2 WHERE id=1;
INSERT INTO channels(id,name,url,media_type,source_id,favorite,series_id) VALUES
(101,'Favorite movie','fixture://movie',1,1,1,NULL),
(102,'Favorite series','fixture://series',2,1,1,NULL),
(103,'Favorite episode','fixture://episode',1,1,1,102),
(104,'Other movie','fixture://other',1,1,0,NULL);''',
      );
      final settings = await NativeBridge.instance.getSettings();
      settings.showProgrammes = false;
      await NativeBridge.instance.updateSettings(settings);
      before = await sql(stateQuery);
    });
    final selection = Filters(
      viewType: ViewType.favorites,
      sourceIds: [1],
      mediaTypes: [MediaType.livestream],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Home(home: HomeManager(filters: selection)),
      ),
    );
    await frames(tester, 600);
    Finder tab(String text) =>
        find.descendant(of: find.byType(ChoiceChip), matching: find.text(text));
    expect(find.text('Channel 2'), findsOneWidget);
    expect(find.text('Favorite category 01'), findsNothing);
    expect(find.text('Favorite movie'), findsNothing);
    expect(find.text('Favorite series'), findsNothing);
    await tester.tap(tab('Movies'));
    await frames(tester, 400);
    expect(find.text('Favorite movie'), findsOneWidget);
    expect(find.text('Other movie'), findsNothing);
    expect(find.text('Channel 2'), findsNothing);
    expect(find.text('Favorite episode'), findsNothing);
    await tester.enterText(find.byType(TextField), 'missing');
    await frames(tester, 400);
    expect(find.text('No matching favorites'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(tab('Series'));
    await frames(tester, 400);
    expect(find.text('Favorite series'), findsOneWidget);
    expect(find.text('Favorite episode'), findsOneWidget);
    expect(find.text('Favorite movie'), findsNothing);
    expect(find.text('Channel 2'), findsNothing);
    // Tab filters must not leak into category contents or other bottom pages.
    expect(selection.mediaTypes, [MediaType.livestream]);
    await tester.tap(tab('Categories'));
    await frames(tester, 600);
    final seen = <int>{};
    for (var i = 0; i < 10 && seen.length < 73; i++) {
      final tiles = tester.widgetList<ChannelTile>(find.byType(ChannelTile));
      expect(
        tiles.every((t) => t.channel.mediaType == MediaType.group),
        isTrue,
      );
      seen.addAll(tiles.map((t) => t.channel.id!));
      if (seen.length < 73) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
        await frames(tester, 300);
      }
    }
    expect(seen, hasLength(73));
    expect(selection.page, 3);
    expect(find.text('Fixture group'), findsNothing);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 6000));
    await frames(tester, 300);
    await tester.tap(find.text('Favorite category 01'));
    await frames(tester, 500);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Channel 1'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await frames(tester, 400);
    await tester.tap(
      find.descendant(
        of: find.byType(ChannelTile),
        matching: find.text('Favorite category 01'),
      ),
      buttons: kSecondaryMouseButton,
    );
    await frames(tester, 250);
    await tester.tap(find.text('Remove from favorites (F)'));
    await frames(tester, 500);
    expect(find.text('Favorite category 01'), findsNothing);
    expect(
      await tester.runAsync(
        () => sql('SELECT favorite FROM groups WHERE id=2'),
      ),
      '0',
    );
    await tester.enterText(find.byType(TextField), '73');
    await frames(tester, 400);
    expect(find.text('Favorite category 73'), findsOneWidget);
    await tester.tap(tab('Channels'));
    await tester.tap(tab('Categories'));
    await tester.tap(tab('Channels'));
    await frames(tester, 500);
    expect(find.text('Channel 73'), findsOneWidget);
    expect(find.text('Favorite category 73'), findsNothing);
    expect(selection.favoriteGroups, isFalse);
    await tester.enterText(find.byType(TextField), '');
    await frames(tester, 300);
    await tester.runAsync(() => sql('UPDATE groups SET favorite=0'));
    await tester.tap(tab('Categories'));
    tester.view.physicalSize = const Size(360, 700);
    await frames(tester, 500);
    expect(
      find.text(
        'No favorite categories yet. Star a category from Categories to add it here.',
      ),
      findsOneWidget,
    );
    expect(await tester.runAsync(() => sql(stateQuery)), before);
    for (final label in ['Channels', 'Movies', 'Series', 'Categories']) {
      final bounds = tester.getRect(tab(label));
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(360));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, skip: !native);
  testWidgets(
    'Clear history confirms and preserves favorites and playback positions',
    (tester) async {
      final fixture = Fixture();
      await tester.runAsync(() => fixture.init(count: 3));
      addTearDown(fixture.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Home(
            home: HomeManager(
              filters: Filters(
                viewType: ViewType.history,
                sourceIds: [1],
                mediaTypes: [MediaType.livestream],
              ),
            ),
          ),
        ),
      );
      await frames(tester, 400);
      final saved = await tester.runAsync(
        () => sql(
          'SELECT id,favorite FROM channels ORDER BY id; SELECT channel_id,position FROM movie_positions;',
        ),
      );
      await tester.tap(find.byTooltip('Clear history'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        await tester.runAsync(
          () => sql(
            'SELECT count(*) FROM channels WHERE last_watched IS NOT NULL',
          ),
        ),
        '3',
      );
      await tester.tap(find.byTooltip('Clear history'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Clear history'));
      await frames(tester, 400);
      expect(
        await tester.runAsync(
          () => sql(
            'SELECT count(*) FROM channels WHERE last_watched IS NOT NULL',
          ),
        ),
        '0',
      );
      expect(
        await tester.runAsync(
          () => sql(
            'SELECT id,favorite FROM channels ORDER BY id; SELECT channel_id,position FROM movie_positions;',
          ),
        ),
        saved,
      );
      expect(find.text('Channel 1'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !native,
  );

  testWidgets('iOS status-bar tap returns the catalog to the top', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 24);
    addTearDown(tester.view.resetPadding);
    final fixture = Fixture();
    await tester.runAsync(() => fixture.init(count: 90));
    addTearDown(fixture.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Home(
          home: HomeManager(
            filters: Filters(
              viewType: ViewType.all,
              sourceIds: [1],
              mediaTypes: [MediaType.livestream],
            ),
          ),
        ),
      ),
    );
    await frames(tester, 400);
    final list = find.byType(CustomScrollView);
    await tester.drag(list, const Offset(0, -600));
    await frames(tester, 400);
    final scrollable = find
        .descendant(of: list, matching: find.byType(Scrollable))
        .first;
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.pixels, greaterThan(0));
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.statusBar.name,
      SystemChannels.statusBar.codec.encodeMethodCall(
        const MethodCall('handleScrollToTop'),
      ),
      (_) {},
    );
    await frames(tester, 1200);
    expect(position.pixels, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, skip: !native);

  testWidgets('favorites reorder by keyboard and menu; focus follows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = Fixture();
    await tester.runAsync(() => f.init(count: 5));
    addTearDown(f.close);
    await tester.runAsync(() async {
      await sql('UPDATE channels SET favorite=0 WHERE id>3');
      final settings = await NativeBridge.instance.getSettings();
      settings.showProgrammes = false;
      await NativeBridge.instance.updateSettings(settings);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Home(
          home: HomeManager(
            filters: Filters(
              viewType: ViewType.favorites,
              sourceIds: [1],
              mediaTypes: [MediaType.livestream],
            ),
          ),
        ),
      ),
    );
    await frames(tester, 600);
    List<String> shown() => tester
        .widgetList<ChannelTile>(find.byType(ChannelTile))
        .map((t) => t.channel.name)
        .toList();
    String? focused() => FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<ChannelTile>()
        ?.channel
        .name;
    expect(shown(), ['Channel 1', 'Channel 2', 'Channel 3']);
    expect(focused(), 'Channel 1');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await frames(tester, 400);
    expect(shown(), ['Channel 2', 'Channel 1', 'Channel 3']);
    expect(focused(), 'Channel 1');
    await tester.tap(find.byTooltip('Channel options').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move earlier (Ctrl+↑)'));
    await frames(tester, 400);
    expect(shown(), ['Channel 2', 'Channel 3', 'Channel 1']);
    expect(focused(), 'Channel 3');
    await tester.runAsync(() async {
      expect(
        await sql('SELECT id FROM channels WHERE favorite>0 ORDER BY favorite'),
        '2\n3\n1',
      );
      final f1to3 = await NativeBridge.instance.getAllChannels(
        Filters(
          sourceIds: [1],
          mediaTypes: [MediaType.livestream],
          viewType: ViewType.favorites,
        ),
      );
      expect(f1to3.map((c) => c.id), [2, 3, 1]);
    });
    await tester.pumpWidget(const SizedBox());
  }, skip: !native);
  test('fresh visible guide sleeps on a single one-shot deadline', () async {
    final timers = <Timer>[];
    var periodic = 0, calls = 0, notifications = 0;
    late ProgrammeGuide guide;
    await runZoned(
      () async {
        guide = ProgrammeGuide((_) async {
          calls++;
          return helpers.guideData(
            'Fresh',
            boundary: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300,
          );
        });
        guide.addListener(() => notifications++);
        guide.setVisible([helpers.channel(1)]);
        guide.setActive(true);
        await helpers.until(() => guide.describe(1).$1 == 'Fresh');
      },
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) {
          final t = parent.createTimer(zone, duration, callback);
          timers.add(t);
          return t;
        },
        createPeriodicTimer: (self, parent, zone, duration, callback) {
          periodic++;
          return parent.createPeriodicTimer(zone, duration, callback);
        },
      ),
    );
    final before = notifications;
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(periodic, 0);
    expect(calls, 1);
    expect(notifications, before);
    expect(timers.where((t) => t.isActive), hasLength(1));
    guide.setActive(false);
    expect(timers.where((t) => t.isActive), isEmpty);
    guide.dispose();
  });
  test(
    'FFI expansion toggles persist and global off sends zero HTTP',
    () async {
      final f = Fixture();
      await f.init();
      try {
        final b = NativeBridge.instance;
        final defaults = await b.getSettings();
        expect(defaults.numberKeySwitching, isFalse);
        expect(defaults.searchDelayMs, 0);
        await b.updateSettings(
          Settings(
            numberKeySwitching: true,
            enableCatchup: false,
            enableFullGuide: false,
            enableXmltv: true,
            keyboardShortcuts: false,
            guidePlayerTitles: false,
            guideTileText: false,
            autoQualityDiscovery: false,
            searchDelayMs: 175,
          ),
        );
        final s = await b.getSettings();
        expect(
          [
            s.numberKeySwitching,
            s.enableCatchup,
            s.enableFullGuide,
            s.enableXmltv,
            s.keyboardShortcuts,
            s.guidePlayerTitles,
            s.guideTileText,
            s.autoQualityDiscovery,
            s.searchDelayMs,
          ],
          [true, false, false, true, false, false, false, false, 175],
        );
        s.showProgrammes = false;
        await b.updateSettings(s);
        expect((await b.getNowNext(1)).supported, isFalse);
        await b.getSchedule(1, f.start, f.stop);
        await expectLater(b.getCatchup(1, f.start, f.stop), throwsException);
        expect(f.requests, isEmpty);
      } finally {
        await f.close();
      }
    },
    skip: !native,
  );
  testWidgets(
    'catch-up refetches local date and plays HTTP with headers without SQLite writes',
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
      await tester.runAsync(() async {
        final f = Fixture();
        await f.init();
        MpvIpc? ipc;
        try {
          final b = NativeBridge.instance;
          final schedule = await b.getSchedule(1, f.start, f.stop);
          expect(schedule.programmes.single.catchupAvailable, isTrue);
          final before = await sql(stateQuery);
          final catchup = await b.getCatchup(1, f.start, f.stop);
          expect(
            f.requests.where(
              (u) => u.queryParameters['action'] == 'get_simple_data_table',
            ),
            hasLength(2),
          );
          expect(catchup.id, isNull);
          expect(catchup.transient, isTrue);
          expect(catchup.playbackHeaders?.userAgent, 'ExpansionFixture');
          final date = f.localDate
              .substring(0, 16)
              .replaceFirst(' ', ':')
              .replaceRange(13, 14, '-');
          expect(
            Uri.parse(catchup.url!).path,
            '/timeshift/fixture/fixture/31/$date/1.ts',
          );
          final generated = await Process.run('ffmpeg', [
            '-v',
            'error',
            '-f',
            'lavfi',
            '-i',
            'testsrc=size=160x120:rate=25',
            '-t',
            '12',
            '-c:v',
            'mpeg2video',
            '-threads',
            '1',
            '-f',
            'mpegts',
            '-y',
            '${db!.path}/catchup.ts',
          ]);
          expect(generated.exitCode, 0, reason: '${generated.stderr}');
          f.clip = await File('${db!.path}/catchup.ts').readAsBytes();
          await Playback.play(
            context,
            catchup,
            settings: await b.getSettings(),
          );
          final runtime = Directory(
            '${Platform.environment['XDG_RUNTIME_DIR']}/brentv',
          );
          final instances = await runtime.list().toList();
          ipc = await MpvIpc.connect('${instances.single.path}/ipc');
          Future<dynamic> get(String p) => ipc!.command(['get_property', p]);
          await waitFor(() async => await get('duration') is num);
          final index = f.requests.indexWhere(
            (u) => u.path.startsWith('/timeshift/'),
          );
          expect(index, greaterThanOrEqualTo(0));
          expect(f.headers[index], {
            'user-agent': 'ExpansionFixture',
            'referer': 'http://fixture.invalid/ref',
            'origin': 'http://fixture.invalid',
          });
          await ipc.command(['set_property', 'pause', false]);
          await waitFor(() async => (await get('time-pos') as num? ?? 0) > 0.1);
          await ipc.command(['seek', 5, 'absolute+exact']);
          await waitFor(() async => (await get('time-pos') as num? ?? 0) >= 5);
          await ipc.command(['quit']);
          ipc.close();
          ipc = null;
          await waitFor(() async => (await runtime.list().toList()).isEmpty);
          expect(await sql(stateQuery), before);
          f.archive = false;
          await expectLater(b.getCatchup(1, f.start, f.stop), throwsException);
          expect(
            (await b.getSchedule(
              1,
              f.start,
              f.stop,
            )).programmes.single.catchupAvailable,
            isFalse,
          );
        } finally {
          try {
            await ipc?.command(['quit']);
          } catch (_) {}
          ipc?.close();
          await f.close();
        }
      });
    },
    skip: !native,
  );
  testWidgets('guide window changes do not strand an in-flight channel page', (
    tester,
  ) async {
    final f = Fixture();
    await tester.runAsync(() => f.init());
    addTearDown(f.close);
    final held = Completer<List<Channel>>();
    final pages = <int>[];
    late List<Channel> firstPage;
    await tester.runAsync(() async {
      firstPage = await NativeBridge.instance.getChannels(filters());
    });
    await tester.pumpWidget(
      MaterialApp(
        home: FullGuide(
          settings: Settings(),
          loadChannels: (query) {
            pages.add(query.page);
            return query.page == 1
                ? held.future
                : NativeBridge.instance.getChannels(query);
          },
        ),
      ),
    );
    await frames(tester, 300);
    expect(pages, [1]);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.tap(find.byTooltip('Next six hours'));
    await tester.tap(find.text('Now'));
    await tester.tap(find.byTooltip('Previous six hours'));
    held.complete(firstPage);
    await frames(tester, 700);
    expect(find.text('Channel 1'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await frames(tester, 700);
    expect(pages, [1, 2]);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, skip: !native);
  testWidgets(
    'guide retains all visible schedules above the ordinary cache cap',
    (tester) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = Fixture();
      await tester.runAsync(() => f.init());
      addTearDown(f.close);
      await tester.pumpWidget(
        MaterialApp(home: FullGuide(settings: Settings())),
      );
      await frames(tester, 300);
      final visible = find.textContaining('Channel ').evaluate().length;
      expect(visible, greaterThan(32));
      for (var i = 0; i < 240 && f.requests.length < visible; i++) {
        await frames(tester, 100);
      }
      await frames(tester, 100);
      expect(f.requests, hasLength(visible));
      expect(
        f.requests.map((u) => u.queryParameters['stream_id']).toSet(),
        hasLength(visible),
      );
      await frames(tester, 1500);
      expect(f.requests, hasLength(visible));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !native,
  );
  testWidgets(
    'FullGuide viewport serial HTTP, six-hour controls, manual retry and hot disable',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = Fixture();
      await tester.runAsync(() => f.init());
      addTearDown(f.close);
      await tester.pumpWidget(
        MaterialApp(home: FullGuide(settings: Settings())),
      );
      await frames(tester, 3400);
      final visible = {
        for (final e in find.textContaining('Channel ').evaluate())
          int.parse((e.widget as Text).data!.split(' ').last),
      };
      final ids = f.requests
          .map((u) => int.parse(u.queryParameters['stream_id']!))
          .toList();
      expect(ids, isNotEmpty);
      expect(ids.every(visible.contains), isTrue);
      expect(ids.toSet().length, ids.length);
      expect(f.peak, 1);
      expect(find.text('Visible fixture'), findsWidgets);
      expect(
        tester.getSize(find.text('Visible fixture').first).width,
        greaterThan(180),
      );
      tester.view.physicalSize = const Size(900, 600);
      await frames(tester, 200);
      expect(
        tester.getSize(find.text('Visible fixture').first).width,
        lessThan(180),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Next six hours'));
      await frames(tester, 700);
      expect(find.text('Visible fixture'), findsNothing);
      await tester.tap(find.text('Now'));
      await frames(tester, 700);
      expect(find.text('Visible fixture'), findsWidgets);
      f.error = true;
      await tester.tap(find.byTooltip('Previous six hours'));
      await frames(tester, 3400);
      expect(find.text('Guide unavailable · tap to retry'), findsWidgets);
      final count = f.requests.length;
      await frames(tester, 1200);
      expect(f.requests.length, count);
      f.error = false;
      await tester.tap(find.text('Guide unavailable · tap to retry').first);
      await frames(tester, 700);
      expect(f.requests.length, count + 1);
      await tester.runAsync(() async {
        final s = await NativeBridge.instance.getSettings();
        s.enableFullGuide = false;
        await NativeBridge.instance.updateSettings(s);
      });
      await frames(tester, 300);
      expect(find.text('Enable the program guide in Settings'), findsOneWidget);
      final off = f.requests.length;
      await frames(tester, 1000);
      expect(f.requests.length, off);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !native,
  );
  testWidgets(
    'Home immediate search and hide restore preserve favorites history and positions',
    (tester) async {
      final f = Fixture();
      await tester.runAsync(() => f.init(count: 20));
      addTearDown(f.close);
      await tester.runAsync(() async {
        final s = await NativeBridge.instance.getSettings();
        s.showProgrammes = false;
        await NativeBridge.instance.updateSettings(s);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Home(home: HomeManager(filters: filters())),
        ),
      );
      await frames(tester);
      await tester.enterText(find.byType(TextField), 'Channel 20');
      await frames(tester, 100);
      expect(find.byType(ChannelTile), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit5, character: '5');
      await tester.pump();
      expect(find.byType(Home), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await frames(tester, 100);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      final tile = find.byType(ChannelTile).first;
      final focus = find
          .descendant(of: tile, matching: find.byType(Focus))
          .first;
      tester.widget<Focus>(focus).focusNode!.requestFocus();
      await tester.pump();
      final id = tester.widget<ChannelTile>(tile).channel.id!;
      late String before;
      await tester.runAsync(() async {
        before = await sql(stateQuery);
      });
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await frames(tester, 300);
      await tester.runAsync(() async {
        expect(
          (await NativeBridge.instance.getAllChannels(
            filters(),
          )).any((c) => c.id == id),
          isFalse,
        );
      });
      await tester.pumpWidget(const MaterialApp(home: HiddenItems()));
      await frames(tester, 300);
      expect(find.text('Channel $id'), findsOneWidget);
      await tester.tap(find.text('Restore all'));
      await frames(tester, 300);
      expect(find.text('No hidden items'), findsOneWidget);
      await tester.runAsync(() async {
        expect(
          (await NativeBridge.instance.getAllChannels(filters())).length,
          20,
        );
        await NativeBridge.instance.setHidden(1, true, group: true);
        expect(await NativeBridge.instance.getAllChannels(filters()), isEmpty);
        await NativeBridge.instance.restoreAllHidden();
        expect(
          (await NativeBridge.instance.getAllChannels(filters())).length,
          20,
        );
        expect(await sql(stateQuery), before);
      });
      await tester.pumpWidget(const SizedBox());
    },
    skip: !native,
  );
  testWidgets(
    'FullGuide rejects held results after window, source, lifecycle and disposal changes',
    (tester) async {
      final f = Fixture();
      await tester.runAsync(() => f.init());
      addTearDown(f.close);
      f.hold = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(home: FullGuide(settings: Settings())),
      );
      await frames(tester, 300);
      expect(f.requests, hasLength(1));
      await tester.tap(find.byTooltip('Next six hours'));
      await tester.pump();
      await tester.runAsync(() async {
        f.hold!.complete();
      });
      await frames(tester, 700);
      expect(find.text('Visible fixture'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      final paused = f.requests.length;
      await frames(tester, 900);
      expect(f.requests.length, paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.runAsync(
        () => NativeBridge.instance.setSourceEnabled(1, false),
      );
      await frames(tester, 300);
      expect(find.text('No live channels'), findsOneWidget);
      final disabled = f.requests.length;
      await frames(tester, 800);
      expect(f.requests.length, disabled);
      await tester.runAsync(
        () => NativeBridge.instance.setSourceEnabled(1, true),
      );
      await frames(tester, 300);
      f.hold = Completer<void>();
      await tester.tap(find.text('Now'));
      await frames(tester, 600);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        f.hold!.complete();
      });
      await frames(tester, 600);
      expect(tester.takeException(), isNull);
    },
    skip: !native,
  );

  testWidgets(
    'actual mpv number keys select provider pages, edit and cancel without reloading, and preserve old keys',
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
      await tester.runAsync(() async {
        final f = Fixture();
        await f.init();
        MpvIpc? ipc;
        try {
          final b = NativeBridge.instance;
          final s = await b.getSettings();
          s.numberKeySwitching = true;
          s.showProgrammes = false;
          await b.updateSettings(s);
          final channels = await b.getAllChannels(filters());
          await Playback.play(
            context,
            channels.first,
            settings: s,
            siblings: channels,
          );
          final runtime = Directory(
            '${Platform.environment['XDG_RUNTIME_DIR']}/brentv',
          );
          final instances = await runtime.list().toList();
          ipc = await MpvIpc.connect('${instances.single.path}/ipc');
          Future<dynamic> get(String p) => ipc!.command(['get_property', p]);
          Future<void> key(String k) async {
            await ipc!.command(['keypress', k]);
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }

          await key('3');
          await key('7');
          await key('ENTER');
          await waitFor(
            () async => await get('force-media-title') == 'Channel 37',
          );
          final entry = await get('playlist/0/id');
          await key('3');
          await key('8');
          await key('BS');
          await key('7');
          await key('ENTER');
          await Future<void>.delayed(const Duration(milliseconds: 250));
          expect(await get('playlist/0/id'), entry);
          await key('9');
          await key('ESC');
          await key('ENTER');
          expect(await get('playlist/0/id'), entry);
          await key('PGUP');
          await waitFor(
            () async => await get('force-media-title') == 'Channel 38',
          );
          await key('BS');
          await waitFor(
            () async => await get('force-media-title') == 'Channel 37',
          );
          await key('F1');
          await waitFor(
            () async => await get('force-media-title') == 'Channel 1',
          );
          await ipc.command(['quit']);
          await waitFor(() async => (await runtime.list().toList()).isEmpty);
        } finally {
          try {
            await ipc?.command(['quit']);
          } catch (_) {}
          ipc?.close();
          await f.close();
        }
      });
    },
    skip: !native,
  );

  testWidgets(
    'Home optional debounce, numeric routes, Home End and menu hiding',
    (tester) async {
      final f = Fixture();
      await tester.runAsync(() => f.init(count: 60));
      addTearDown(f.close);
      await tester.runAsync(() async {
        final s = await NativeBridge.instance.getSettings();
        s.showProgrammes = false;
        s.searchDelayMs = 200;
        await NativeBridge.instance.updateSettings(s);
      });
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          home: Home(tvMode: true, home: HomeManager(filters: filters())),
        ),
      );
      await frames(tester);
      final initial = find.byType(ChannelTile).evaluate().length;
      await tester.enterText(find.byType(TextField), 'Channel 60');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ChannelTile).evaluate().length, initial);
      await frames(tester, 350);
      expect(find.byType(ChannelTile), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await frames(tester, 350);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      for (final number in [1, 2, 3, 4, 5]) {
        await tester.sendKeyEvent(
          LogicalKeyboardKey.findKeyByKeyId(
            LogicalKeyboardKey.digit1.keyId + number - 1,
          )!,
          character: '$number',
        );
        await frames(tester, 400);
        if (number == 5) {
          expect(find.text('Settings'), findsWidgets);
        } else {
          expect(
            tester.widget<Home>(find.byType(Home)).home.filters.viewType,
            ViewType.values[number - 1],
          );
        }
        if (nav.currentState!.canPop()) nav.currentState!.pop();
        await frames(tester, 300);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await frames(tester, 200);
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(scroll.position.pixels, greaterThan(0));
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await frames(tester, 600);
      expect(scroll.position.pixels, 0);
      await tester.tap(find.byTooltip('Channel options').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hide (H)'));
      await frames(tester, 300);
      await tester.runAsync(() async {
        expect(
          (await NativeBridge.instance.getAllChannels(filters())).length,
          59,
        );
        await NativeBridge.instance.restoreAllHidden();
      });
      await frames(tester, 300);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2, character: '2');
      await frames(tester, 400);
      await tester.tap(find.byTooltip('Channel options').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hide (H)'));
      await frames(tester, 300);
      await tester.runAsync(() async {
        expect(await NativeBridge.instance.getAllChannels(filters()), isEmpty);
        await NativeBridge.instance.restoreAllHidden();
        expect(
          (await NativeBridge.instance.getAllChannels(filters())).length,
          60,
        );
      });
      await tester.pumpWidget(const SizedBox());
    },
    skip: !native,
  );
  testWidgets(
    'quality discovery off has no background HLS probe; repeated manual keys bound pending discovery',
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
      await tester.runAsync(() async {
        final f = Fixture();
        await f.init();
        MpvIpc? ipc;
        try {
          final generated = await Process.run('ffmpeg', [
            '-v',
            'error',
            '-f',
            'lavfi',
            '-i',
            'testsrc=size=160x120:rate=25',
            '-t',
            '12',
            '-c:v',
            'mpeg2video',
            '-threads',
            '1',
            '-f',
            'mpegts',
            '-y',
            '${db!.path}/quality.ts',
          ]);
          expect(generated.exitCode, 0, reason: '${generated.stderr}');
          f.clip = await File('${db!.path}/quality.ts').readAsBytes();
          await sql(
            "UPDATE channels SET url='http://127.0.0.1:${f.server.port}/live/fixture/fixture/1.ts' WHERE id=1;",
          );
          final b = NativeBridge.instance;
          final s = await b.getSettings();
          s.showProgrammes = false;
          await b.updateSettings(s);
          await Playback.play(
            context,
            (await b.getAllChannels(filters())).first,
            settings: s,
          );
          final runtime = Directory(
            '${Platform.environment['XDG_RUNTIME_DIR']}/brentv',
          );
          final instances = await runtime.list().toList();
          ipc = await MpvIpc.connect('${instances.single.path}/ipc');
          await waitFor(() async {
            try {
              return await ipc!.command(['get_property', 'duration']) is num;
            } on StateError {
              // mpv reports "property unavailable" before loading metadata.
              return false;
            }
          });
          await Future<void>.delayed(const Duration(milliseconds: 700));
          expect(f.requests.where((u) => u.path.endsWith('.m3u8')), isEmpty);
          f.hold = Completer<void>();
          for (var i = 0; i < 10; i++) {
            await ipc.command(['keypress', 'a']);
          }
          await waitFor(
            () async => f.requests.any((u) => u.path.endsWith('.m3u8')),
          );
          await Future<void>.delayed(const Duration(milliseconds: 500));
          expect(
            f.requests.where((u) => u.path.endsWith('.m3u8')),
            hasLength(1),
          );
          f.hold!.complete();
          await Future<void>.delayed(const Duration(milliseconds: 300));
          await ipc.command(['quit']);
          await waitFor(() async => (await runtime.list().toList()).isEmpty);
        } finally {
          try {
            await ipc?.command(['quit']);
          } catch (_) {}
          ipc?.close();
          await f.close();
        }
      });
    },
    skip: !native,
  );

  testWidgets('FullGuide dialog offers catch-up only for archived programmes', (
    tester,
  ) async {
    final f = Fixture();
    await tester.runAsync(() => f.init(count: 1));
    addTearDown(f.close);
    tester.view.physicalSize = const Size(1400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: FullGuide(settings: Settings())));
    await frames(tester, 300);
    await tester.tap(find.byTooltip('Previous six hours'));
    await frames(tester, 700);
    await tester.tap(find.text('Archived fixture'));
    await tester.pumpAndSettle();
    expect(find.text('Play catch-up'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    f.archive = false;
    await tester.tap(find.text('Now'));
    await frames(tester, 600);
    await tester.tap(find.byTooltip('Previous six hours'));
    await frames(tester, 700);
    await tester.tap(find.text('Archived fixture'));
    await tester.pumpAndSettle();
    expect(find.text('Play catch-up'), findsNothing);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  }, skip: !native);
  test(
    'catch-up rejects in-flight source disable and setting disable',
    () async {
      final f = Fixture();
      await f.init();
      try {
        final b = NativeBridge.instance;
        for (final disableSource in [true, false]) {
          f.hold = Completer<void>();
          final before = f.requests.length;
          final pending = b.getCatchup(1, f.start, f.stop);
          final rejected = expectLater(pending, throwsException);
          await waitFor(() async => f.requests.length > before);
          if (disableSource) {
            await b.setSourceEnabled(1, false);
          } else {
            final s = await b.getSettings();
            s.enableCatchup = false;
            await b.updateSettings(s);
          }
          f.hold!.complete();
          await rejected;
          await b.setSourceEnabled(1, true);
        }
      } finally {
        await f.close();
      }
    },
    skip: !native,
  );
  test(
    'bridge disposal drains a held native callback and rejects reuse',
    () async {
      final f = Fixture();
      await f.init(count: 1);
      final old = NativeBridge.instance;
      f.hold = Completer<void>();
      final pending = old.getNowNext(1);
      final rejected = expectLater(pending, throwsStateError);
      try {
        await waitFor(() async => f.active == 1);
        old.dispose();
        old.dispose();
        await rejected;
        await expectLater(old.getSettings(), throwsStateError);
        f.hold!.complete();
        await waitFor(() async => f.active == 0);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(await NativeBridge.instance.getSettings(), isA<Settings>());
      } finally {
        await f.close();
      }
    },
    skip: !native,
  );
  test(
    'XMLTV FFI matches exact IDs, reads gzip and sends zero HTTP while off',
    () async {
      final f = Fixture();
      await f.init(count: 1);
      final xmlServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requests = 0;
      var release = Completer<void>();
      String stamp(DateTime d) =>
          '${d.toUtc().toIso8601String().replaceAll(RegExp(r'[-:T]'), '').substring(0, 14)} +0000';
      final now = DateTime.now();
      final from = stamp(now.subtract(const Duration(minutes: 1)));
      final to = stamp(now.add(const Duration(hours: 1)));
      xmlServer.listen((r) async {
        requests++;
        await release.future;
        final title = r.uri.path == '/guide.xml.gz'
            ? 'Exact fixture'
            : 'Second fixture';
        r.response.add(
          gzip.encode(
            utf8.encode(
              '<!DOCTYPE tv SYSTEM "xmltv.dtd"><tv><programme channel="exact.extra" start="$from" stop="$to"><title>Wrong ID</title></programme><programme channel="exact" start="$from" stop="$to"><title>$title</title><title lang="de">Ignored translation</title></programme></tv>',
            ),
          ),
        );
        await r.response.close();
      });
      try {
        await sql(
          "UPDATE sources SET source_type=0,epg_url='http://127.0.0.1:${xmlServer.port}/guide.xml.gz'; UPDATE channels SET stream_id=NULL,epg_id='exact';",
        );
        final b = NativeBridge.instance;
        expect((await b.getNowNext(1)).supported, isFalse);
        expect(requests, 0);
        final s = await b.getSettings();
        s.enableXmltv = true;
        await b.updateSettings(s);
        final pending = [for (var i = 0; i < 3; i++) b.getNowNext(1)];
        await waitFor(() async => requests == 1);
        release.complete();
        final results = await Future.wait(pending);
        expect(
          results.every(
            (result) => result.supported && result.now.title == 'Exact fixture',
          ),
          isTrue,
        );
        expect(requests, 1);
        for (var id = 2; id <= 5; id++) {
          await sql(
            "INSERT INTO sources(id,name,source_type,enabled,url,epg_url,import_live) VALUES($id,'Other $id',0,1,'http://fixture.invalid','http://127.0.0.1:${xmlServer.port}/$id.xml.gz',1); INSERT INTO channels(id,name,url,source_id,media_type,epg_id) VALUES($id,'Other $id','http://fixture.invalid',$id,0,'exact');",
          );
          if (id == 2) {
            for (final channel in [2, 1, 2, 1]) {
              expect(
                (await b.getNowNext(channel)).now.title,
                channel == 1 ? 'Exact fixture' : 'Second fixture',
              );
            }
            expect(
              requests,
              2,
              reason: 'Two sources must retain separate documents',
            );
          } else {
            expect((await b.getNowNext(id)).now.title, 'Second fixture');
          }
        }
        expect(requests, 5);
        // Source 2 was the oldest of five; the four-source cap evicts it.
        expect((await b.getNowNext(2)).now.title, 'Second fixture');
        expect(requests, 6);
        s.enableXmltv = false;
        await b.updateSettings(s);
        expect((await b.getNowNext(1)).supported, isFalse);
        expect(requests, 6);
        s.enableXmltv = true;
        await b.updateSettings(s);
        expect((await b.getNowNext(1)).now.title, 'Exact fixture');
        expect(requests, 7, reason: 'Off must drop all source documents');
        s.enableXmltv = false;
        await b.updateSettings(s);
        s.enableXmltv = true;
        await b.updateSettings(s);
        release = Completer<void>();
        final gated = [
          for (var i = 0; i < 3; i++)
            b
                .getNowNext(1)
                .then<void>(
                  (data) => expect(data.supported, isFalse),
                  onError: (_) {},
                ),
        ];
        await waitFor(() async => requests == 8);
        s.showProgrammes = false;
        await b.updateSettings(s);
        release.complete();
        await Future.wait(gated);
        expect(
          requests,
          8,
          reason: 'Waiters must recheck the master switch before HTTP',
        );
      } finally {
        if (!release.isCompleted) release.complete();
        await xmlServer.close(force: true);
        await f.close();
      }
    },
    skip: !native,
  );
  testWidgets(
    'tile and player guide switches independently stop requests while hot',
    (tester) async {
      final f = Fixture();
      await tester.runAsync(() => f.init(count: 1));
      addTearDown(f.close);
      await tester.runAsync(() async {
        final s = await NativeBridge.instance.getSettings();
        s.guideTileText = false;
        await NativeBridge.instance.updateSettings(s);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Home(home: HomeManager(filters: filters())),
        ),
      );
      await frames(tester, 700);
      expect(f.requests, isEmpty);
      await tester.runAsync(() async {
        final s = await NativeBridge.instance.getSettings();
        s.guideTileText = true;
        await NativeBridge.instance.updateSettings(s);
      });
      await frames(tester, 700);
      expect(f.requests, isNotEmpty);
      expect(find.text('Visible fixture'), findsOneWidget);
      await tester.runAsync(() async {
        final s = await NativeBridge.instance.getSettings();
        s.guideTileText = false;
        await NativeBridge.instance.updateSettings(s);
      });
      await frames(tester, 300);
      final off = f.requests.length;
      await frames(tester, 700);
      expect(f.requests.length, off);
      expect(find.text('Visible fixture'), findsNothing);
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
        final b = NativeBridge.instance;
        MpvIpc? ipc;
        try {
          await Playback.play(
            context,
            (await b.getAllChannels(filters())).single,
            settings: await b.getSettings(),
          );
          final runtime = Directory(
            '${Platform.environment['XDG_RUNTIME_DIR']}/brentv',
          );
          final instances = await runtime.list().toList();
          ipc = await MpvIpc.connect('${instances.single.path}/ipc');
          await waitFor(
            () async =>
                await ipc!.command(['get_property', 'force-media-title']) ==
                'Channel 1 · Visible fixture',
          );
          expect(f.requests.length, greaterThan(off));
          final s = await b.getSettings();
          s.guidePlayerTitles = false;
          await b.updateSettings(s);
          await waitFor(
            () async =>
                await ipc!.command(['get_property', 'force-media-title']) ==
                'Channel 1',
          );
          final count = f.requests.length;
          await Future<void>.delayed(const Duration(milliseconds: 700));
          expect(f.requests.length, count);
          await ipc.command(['quit']);
          await waitFor(() async => (await runtime.list().toList()).isEmpty);
        } finally {
          try {
            await ipc?.command(['quit']);
          } catch (_) {}
          ipc?.close();
        }
      });
      await tester.pumpWidget(const SizedBox());
    },
    skip: !native,
  );
  testWidgets('Visible page keys and ? work on pages where nothing has focus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = Fixture();
    await tester.runAsync(() => f.init(count: 3));
    addTearDown(f.close);
    await tester.runAsync(() async {
      await sql('UPDATE channels SET favorite=0');
      final settings = await NativeBridge.instance.getSettings();
      settings.showProgrammes = false;
      await NativeBridge.instance.updateSettings(settings);
    });
    ViewType? shown() {
      if (find.byType(SettingsView).evaluate().isNotEmpty) {
        return ViewType.settings;
      }
      return tester.widget<Home>(find.byType(Home)).home.filters.viewType;
    }

    Future<void> press(LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await frames(tester, 300);
    }

    await tester.pumpWidget(const MaterialApp(home: SettingsView()));
    await frames(tester, 300);
    expect(shown(), ViewType.settings);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: '?');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await press(LogicalKeyboardKey.digit3);
    expect(shown(), ViewType.favorites);
    expect(find.textContaining('No favorite channels yet'), findsOneWidget);
    await press(LogicalKeyboardKey.digit6);
    expect(shown(), ViewType.settings);
    await press(LogicalKeyboardKey.digit1);
    expect(shown(), ViewType.all);
    expect(find.byType(ChannelTile), findsNWidgets(3));
    await tester.pumpWidget(const SizedBox());
  }, skip: !native);
}
