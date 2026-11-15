import 'package:brentv/categories_view.dart';
import 'package:brentv/player.dart';
import 'package:brentv/channel_tile.dart';
import 'package:brentv/generated/generated_proto.pb.dart' as pb;
import 'package:brentv/models/channel.dart';
import 'package:brentv/models/media_type.dart';
import 'package:brentv/models/proto_extensions.dart';
import 'package:brentv/models/settings.dart';
import 'package:brentv/models/source.dart';
import 'package:brentv/models/source_type.dart';
import 'package:brentv/playback/feeds.dart';
import 'package:brentv/player_settings.dart';
import 'package:brentv/refresh_stats.dart';
import 'package:brentv/shortcuts_dialog.dart';
import 'package:brentv/theme.dart';
import 'package:brentv/ui_scale.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Channel channel(int id, {int quality = 0}) => Channel(
  id: id,
  name: 'Test $id',
  url: 'http://127.0.0.1/master.m3u8',
  mediaType: MediaType.livestream,
  sourceId: 1,
  favorite: false,
  quality: quality,
);

void main() {
  test(
    'live reconnect stops after 1/2/4 seconds and recovery renews budget',
    () {
      final budget = ReconnectBudget();
      expect(
        [budget.nextDelay(), budget.nextDelay(), budget.nextDelay()],
        [
          const Duration(seconds: 1),
          const Duration(seconds: 2),
          const Duration(seconds: 4),
        ],
      );
      expect(budget.nextDelay(), isNull);
      budget.reset();
      expect(budget.nextDelay(), const Duration(seconds: 1));
    },
  );
  test('navigation excludes containers and accepts direct M3U series URLs', () {
    expect((channel(1)..url = null).isPlayable, isFalse);
    expect((channel(1)..mediaType = MediaType.group).isPlayable, isFalse);
    expect((channel(1)..mediaType = MediaType.season).isPlayable, isFalse);
    expect(
      (channel(1)
            ..mediaType = MediaType.serie
            ..url = '42')
          .isPlayable,
      isFalse,
    );
    expect(
      (channel(1)
            ..mediaType = MediaType.serie
            ..url = 'http://local/series/1.mp4')
          .isPlayable,
      isTrue,
    );
  });
  test('variant and alternate labels use only known metadata', () {
    expect(
      variantLabel(
        pb.StreamVariant(
          height: 1080,
          frameRate: 59.94,
          bandwidth: Int64(6200000),
        ),
      ),
      '1080p60 · 6.2 Mb/s',
    );
    expect(
      variantLabel(pb.StreamVariant(name: 'Audio', bandwidth: Int64(128000))),
      'Audio · 0.1 Mb/s',
    );
    expect(variantLabel(pb.StreamVariant()), 'Variant');
    expect(
      variantLabel(
        pb.StreamVariant(
          height: 720,
          bandwidth: Int64(4000000),
          averageBandwidth: Int64(3200000),
        ),
      ),
      '720p · 3.2 Mb/s',
    );
    expect(Feed(channel(1), 'local').label, 'Auto');
    expect(
      Feed(channel(1, quality: 3), 'local', alternate: true).label,
      'FHD · Test 1',
    );
  });
  test('Xtream HLS twin preserves query and ignores non-live/non-ts URLs', () {
    expect(
      xtreamHlsUrl('http://127.0.0.1/live/fixture/channel.ts?test=1'),
      'http://127.0.0.1/live/fixture/channel.m3u8?test=1',
    );
    expect(xtreamHlsUrl('http://127.0.0.1/movie/fixture/channel.ts'), isNull);
    expect(xtreamHlsUrl('http://127.0.0.1/live/fixture/channel.m3u8'), isNull);
    expect(xtreamHlsUrl('http://127.0.0.1/file.ts'), isNull);
  });
  test('feeds order Auto, variants by resolution/bitrate, then alternates', () {
    final original = channel(1);
    final list = pb.StreamVariantList(
      masterUrl: 'http://127.0.0.1/master.m3u8',
      variants: [
        pb.StreamVariant(height: 720, bandwidth: Int64(2000000)),
        pb.StreamVariant(height: 1080, bandwidth: Int64(4000000)),
        pb.StreamVariant(height: 1080, bandwidth: Int64(6000000)),
      ],
    );
    final feeds = buildFeeds(original, list, [channel(1), channel(2)]);
    expect(feeds.map((f) => f.label), [
      'Auto',
      '1080p · 6.0 Mb/s',
      '1080p · 4.0 Mb/s',
      '720p · 2.0 Mb/s',
      'Test 2',
    ]);
    expect(feeds.take(4).every((f) => f.url == list.masterUrl), isTrue);
    expect(feeds[1].maxBitrate, 6000000);
    expect(feeds.first.maxBitrate, isNull);
    expect(feeds[1].sameAs(feeds[2]), isFalse);
    expect(
      buildFeeds(original, pb.StreamVariantList(), []).single.url,
      original.url,
    );
  });
  test(
    'Settings round-trip every new field including false and empty hwdec',
    () {
      final settings = Settings(
        linuxPlayer: LinuxPlayer.builtIn,
        mpvPath: '/local/mpv',
        hwdec: '',
        cacheSecs: 0,
        demuxerMaxMb: 42,
        mpvExtraArgs: '--no-border',
        mpvReuseWindow: false,
        iosNativePlayer: false,
        iosPreferHls: false,
        backgroundAudio: false,
        autoPip: false,
        startGroupId: 7,
        startGroupName: 'Sports',
      );
      final wire = settings.toProto();
      final decoded = pb.Settings.fromBuffer(wire.writeToBuffer()).toDomain();
      expect(decoded.toProto().toProto3Json(), wire.toProto3Json());
      expect(decoded.startGroupId, 7);
      expect(decoded.startGroupName, 'Sports');
      expect(decoded.hwdec, '');
      expect(decoded.cacheSecs, 0);
      final defaults = pb.Settings().toDomain();
      expect(defaults.squareCorners, isFalse);
      expect(pb.Settings(squareCorners: true).toDomain().squareCorners, isTrue);
      expect(
        Settings(squareCorners: true).toProto().hasSquareCorners(),
        isFalse,
      );
      expect(
        defaults.mpvReuseWindow &&
            defaults.autoPip &&
            defaults.startGroupId == null,
        isTrue,
      );
    },
  );
  test('Source round-trip retains selective import, metadata and stats', () {
    final source = Source(
      id: 7,
      name: 'Fixture',
      sourceType: SourceType.m3u,
      enabled: false,
      url: '/tmp/fixture.m3u',
      urlOrigin: 'fixture',
      userAgent: 'Fixture',
      streamUserAgent: 'Player',
      importLive: false,
      importMovies: true,
      importSeries: false,
      lastRefreshStats: pb.RefreshStats(
        success: false,
        error: 'fixture failure',
      ),
    );
    final wire = source.toProto();
    final decoded = pb.Source.fromBuffer(wire.writeToBuffer()).toDomain();
    expect(decoded.toProto().toProto3Json(), wire.toProto3Json());
    expect(decoded.importLive, isFalse);
    expect(decoded.importMovies, isTrue);
    expect(decoded.importSeries, isFalse);
    expect(decoded.lastRefreshStats!.error, 'fixture failure');
    expect(pb.Source().toDomain().importLive, isTrue);
  });
  test('refresh summaries include partial failures, exclusions and age', () {
    final stats = pb.RefreshStats(
      success: true,
      finishedAt: Int64(1000),
      types: [
        pb.MediaTypeStats(
          mediaType: 0,
          enabled: true,
          imported: 1234,
          excluded: 312,
        ),
        pb.MediaTypeStats(
          mediaType: 1,
          enabled: true,
          failed: true,
          error: 'offline',
        ),
        pb.MediaTypeStats(mediaType: 2, enabled: false),
      ],
    );
    final summary = refreshSummary(
      stats,
      now: DateTime.fromMillisecondsSinceEpoch(1300000),
    );
    expect(summary, contains('Live 1234'));
    expect(summary, contains('Movies failed: offline'));
    expect(summary, contains('312 excluded'));
    expect(summary, contains('5 min ago'));
    expect(summary, isNot(contains('Series')));
    expect(
      refreshSummary(pb.RefreshStats(success: false, error: 'Unavailable')),
      'Unavailable',
    );
  });
  test('category selections survive provider reload and mode changes', () {
    final selection = CategorySelection(
      pb.CategoryList(
        liveMode: pb.CategoryMode.CATEGORY_MODE_INCLUDE,
        categories: [
          pb.Category(mediaType: 0, name: 'Missing', listed: true),
          pb.Category(mediaType: 1, name: 'Movies', listed: true),
        ],
      ),
    );
    selection.toggle(0, 'New', true);
    selection.toggle(1, 'Movies', false);
    selection.merge(
      pb.CategoryList(categories: [pb.Category(mediaType: 0, name: 'New')]),
    );
    expect(selection.listed[0], {'Missing', 'New'});
    expect(selection.listed[1], isEmpty);
    expect(selection.modes[0], pb.CategoryMode.CATEGORY_MODE_INCLUDE);
    selection.modes[0] = pb.CategoryMode.CATEGORY_MODE_EXCLUDE;
    expect(selection.listed[0], {'Missing', 'New'});
  });
  testWidgets('tiles show only the name: no image or placeholder icon', (
    tester,
  ) async {
    final item = channel(1)..image = 'http://127.0.0.1/never-request.png';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => SizedBox(
              height: 100,
              child: ChannelTile(
                channel: item,
                parentContext: context,
                setNode: (_) {},
                onSelect: () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(Image), findsNothing);
    expect(find.byType(RawImage), findsNothing);
    expect(find.byIcon(Icons.tv), findsNothing);
    expect(find.text(item.name), findsOneWidget);
  });
  testWidgets('remove-from-history button only on the History page', (
    tester,
  ) async {
    Future<void> pump(VoidCallback? onRemoved) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => SizedBox(
              height: 100,
              child: ChannelTile(
                channel: channel(1),
                parentContext: context,
                setNode: (_) {},
                onSelect: () {},
                onRemovedFromHistory: onRemoved,
              ),
            ),
          ),
        ),
      ),
    );
    await pump(null);
    expect(find.byIcon(Icons.close), findsNothing);
    await pump(() {});
    expect(find.byIcon(Icons.close), findsOneWidget);
  });
  testWidgets('tile menu offers favorite and history actions', (tester) async {
    Future<void> pump(Channel item, [VoidCallback? onRemoved]) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => SizedBox(
                  height: 100,
                  child: ChannelTile(
                    key: ValueKey(item),
                    channel: item,
                    parentContext: context,
                    setNode: (_) {},
                    onSelect: () {},
                    onRemovedFromHistory: onRemoved,
                  ),
                ),
              ),
            ),
          ),
        );
    await pump(channel(1));
    await tester.tap(find.byTooltip('Channel options'));
    await tester.pumpAndSettle();
    expect(find.text('Add to favorites (F)'), findsOneWidget);
    expect(find.text('Remove from history (Delete)'), findsNothing);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    await pump(channel(2)..favorite = true, () {});
    await tester.tap(find.byTooltip('Channel options'));
    await tester.pumpAndSettle();
    expect(find.text('Remove from favorites (F)'), findsOneWidget);
    expect(find.text('Remove from history (Delete)'), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    await pump(channel(3)..mediaType = MediaType.season);
    expect(find.byTooltip('Channel options'), findsNothing);
  });
  testWidgets('favorite move: menu items and Ctrl+arrows only when allowed', (
    tester,
  ) async {
    final moves = <int>[];
    Future<void> pump(void Function(int)? onMove) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => SizedBox(
              height: 100,
              child: ChannelTile(
                key: ValueKey(onMove != null),
                channel: channel(1)..favorite = true,
                parentContext: context,
                setNode: (_) {},
                onSelect: () {},
                onMove: onMove,
                autofocus: true,
              ),
            ),
          ),
        ),
      ),
    );
    await pump(null);
    await tester.tap(find.byTooltip('Channel options'));
    await tester.pumpAndSettle();
    expect(find.text('Move earlier (Ctrl+↑)'), findsNothing);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    await pump(moves.add);
    await tester.pump();
    for (final key in [
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowRight,
    ]) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    }
    await tester.tap(find.byTooltip('Channel options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move later (Ctrl+↓)'));
    await tester.pumpAndSettle();
    expect(moves, [-1, 1, 1]);
  });
  testWidgets('UI scale enlarges the whole app and halves its canvas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => uiScale.value = 100);
    Size? canvas;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => UiScaled(child: child!),
        home: Builder(
          builder: (context) {
            canvas = MediaQuery.sizeOf(context);
            return const Align(
              alignment: Alignment.topLeft,
              child: SizedBox(key: Key('box'), width: 100, height: 50),
            );
          },
        ),
      ),
    );
    expect(tester.getRect(find.byKey(const Key('box'))).width, 100);
    uiScale.value = 200;
    await tester.pump();
    expect(canvas, const Size(400, 300));
    expect(
      tester.getRect(find.byKey(const Key('box'))),
      const Rect.fromLTWH(0, 0, 200, 100),
    );
    // A small phone caps the zoom so the layout stays 280 px wide.
    tester.view.physicalSize = const Size(320, 568);
    await tester.pump();
    expect(canvas!.width, closeTo(280, 0.01));
  });
  testWidgets('shortcut list opens and lists the favorite move keys', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showShortcuts(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Keyboard shortcuts'), findsOneWidget);
    expect(find.text('Move a favorite earlier / later'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('shortcut list keeps Close on a small phone at every scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 20);
    addTearDown(tester.view.reset);
    addTearDown(() => uiScale.value = 100);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => UiScaled(child: child!),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showShortcuts(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    for (final percent in uiScaleSteps) {
      uiScale.value = percent;
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$percent%');
      final close = tester.getRect(find.text('Close'));
      expect(close.bottom, lessThanOrEqualTo(568), reason: '$percent%');
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    }
  });
  test('dwl theme: exact palette, readable text, progress and disabled', () {
    final theme = dwlTheme(showFocusOutline: true);
    final scheme = theme.colorScheme;
    expect(scheme.surface, const Color(0xff222222));
    expect(scheme.outline, const Color(0xff444444));
    expect(scheme.primary, const Color(0xff005577));
    // #005577 is never used as text on #222222.
    final label = WidgetStateProperty.resolveAs(
      theme.inputDecorationTheme.floatingLabelStyle!,
      {WidgetState.focused},
    );
    expect(label.color, const Color(0xffeeeeee));
    expect(theme.tabBarTheme.labelColor, const Color(0xffeeeeee));
    final progress = theme.progressIndicatorTheme;
    expect(progress.color, isNot(progress.linearTrackColor));
    final text = theme.textButtonTheme.style!.foregroundColor!;
    expect(text.resolve({WidgetState.disabled}), isNot(text.resolve({})));
  });
  test('corner style preserves rounded defaults and squares surfaces', () {
    for (final square in [false, true]) {
      final theme = dwlTheme(showFocusOutline: true, squareCorners: square);
      final radius = square ? BorderRadius.zero : BorderRadius.circular(12);
      for (final shape in [
        theme.cardTheme.shape,
        theme.dialogTheme.shape,
        theme.popupMenuTheme.shape,
      ]) {
        expect((shape! as RoundedRectangleBorder).borderRadius, radius);
      }
      expect(
        (theme.inputDecorationTheme.border! as OutlineInputBorder).borderRadius,
        radius,
      );
      expect(
        theme.filledButtonTheme.style!.shape?.resolve({}),
        square ? const RoundedRectangleBorder() : isNull,
      );
      expect(
        theme.navigationBarTheme.indicatorShape,
        square ? const RoundedRectangleBorder() : isNull,
      );
      expect(
        theme.bottomSheetTheme.shape,
        square ? const RoundedRectangleBorder() : isNull,
      );
      expect(
        theme.textButtonTheme.style!.side!.resolve({
          WidgetState.focused,
        })!.width,
        borderWidth,
      );
    }
  });
  for (final mode in NavigationMode.values) {
    testWidgets('remove button adds no focus stop (${mode.name} navigation)', (
      tester,
    ) async {
      Future<int> focusStops(VoidCallback? onRemoved) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(navigationMode: mode),
              child: Scaffold(
                body: Builder(
                  builder: (context) => Column(
                    children: [
                      for (final id in [1, 2])
                        SizedBox(
                          height: 64,
                          child: ChannelTile(
                            key: ValueKey('$id-${onRemoved != null}'),
                            channel: channel(id),
                            parentContext: context,
                            setNode: (_) {},
                            onSelect: () {},
                            onRemovedFromHistory: onRemoved,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        return FocusManager.instance.rootScope.traversalDescendants
            .where((n) => n.canRequestFocus)
            .length;
      }

      final without = await focusStops(null);
      expect(await focusStops(() {}), without);
    });
  }
  for (final platform in [
    TargetPlatform.linux,
    TargetPlatform.iOS,
    TargetPlatform.android,
  ]) {
    testWidgets('player settings sections on ${platform.name}', (tester) async {
      debugDefaultTargetPlatformOverride = platform;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlayerSettings(settings: Settings(), onChanged: () {}),
            ),
          ),
        ),
      );
      expect(
        find.text('Linux'),
        platform == TargetPlatform.linux ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('iOS'),
        platform == TargetPlatform.iOS ? findsOneWidget : findsNothing,
      );
      expect(find.text('Native player'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
