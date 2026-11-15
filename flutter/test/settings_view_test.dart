import 'package:brentv/categories_view.dart';
import 'package:brentv/edit_dialog.dart';
import 'package:brentv/home.dart';
import 'package:brentv/local_media.dart';
import 'package:brentv/models/view_type.dart';
import 'package:brentv/native_bridge.dart';
import 'package:brentv/settings_view.dart';
import 'package:brentv/theme.dart';
import 'package:brentv/ui_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'expansion_test.dart' as fixture;

const sections = [
  'Appearance and navigation',
  'Recordings',
  'Downloads',
  'Playback',
  'Program guide',
  'Keyboard and search',
  'Library visibility',
  'Sources',
  'About',
];

Future<void> showSection(WidgetTester tester, String name) async {
  await tester.scrollUntilVisible(
    find.text(name),
    250,
    scrollable: find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

Future<void> visible(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> mount(WidgetTester tester, {bool scaled = false}) async {
  final f = fixture.Fixture();
  // Each widget test has its own FakeAsync zone. Keep callback/queue state local.
  await tester.runAsync(() async {
    NativeBridge.instance.dispose();
    await f.init(count: 3);
  });
  addTearDown(f.close);
  await tester.runAsync(() async {
    await fixture.sql('UPDATE sources SET import_movies=0,import_series=0');
    final s = await NativeBridge.instance.getSettings();
    s.showProgrammes = false;
    await NativeBridge.instance.updateSettings(s);
  });
  final appKey = UniqueKey();
  await tester.pumpWidget(
    ValueListenableBuilder<bool>(
      valueListenable: squareCorners,
      builder: (_, square, _) => MaterialApp(
        key: appKey,
        theme: dwlTheme(showFocusOutline: true, squareCorners: square),
        builder: scaled ? (_, child) => UiScaled(child: child!) : null,
        home: const SettingsView(),
      ),
    ),
  );
  await fixture.frames(tester, 350);
}

void main() {
  tearDownAll(() async {
    if (fixture.db != null) {
      NativeBridge.instance.dispose();
      await fixture.db!.delete(recursive: true);
    }
  });

  testWidgets(
    'all Settings sections fit narrow and scaled layouts',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => uiScale.value = 100);
      for (final width in [1400.0, 360.0, 280.0]) {
        tester.view.physicalSize = Size(width, 1000);
        uiScale.value = 125;
        await mount(tester, scaled: true);
        expect(find.text('Media'), findsOneWidget);
        expect(find.text('Show movies'), findsNothing);
        for (final name in sections) {
          await showSection(tester, name);
          expect(tester.takeException(), isNull, reason: '$name at $width');
          if (name == 'Sources') {
            await visible(tester, find.text('Fixture'));
            expect(find.textContaining('Imports: Live'), findsOneWidget);
          }
          await visible(tester, find.text(name));
          await tester.tap(find.text(name));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$name collapsed at $width',
          );
        }
        await tester.pumpWidget(const SizedBox());
      }
    },
    skip: !fixture.native,
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'section controls persist without changing source imports',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester);
      await showSection(tester, 'Library visibility');
      final movies = find.widgetWithText(SwitchListTile, 'Show movies');
      await visible(tester, movies);
      await tester.tap(movies);
      // Leave before the native save callback, then immediately return.
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1, character: '1');
      await fixture.frames(tester, 350);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit6, character: '6');
      await fixture.frames(tester, 350);
      await showSection(tester, 'Library visibility');
      expect(tester.widget<SwitchListTile>(movies).value, isFalse);
      await tester.runAsync(() async {
        expect((await NativeBridge.instance.getSettings()).showMovies, isFalse);
        expect(
          await fixture.sql(
            'SELECT import_live,import_movies,import_series FROM sources',
          ),
          '1|0|0',
        );
      });
      await showSection(tester, 'Keyboard and search');
      await visible(tester, find.text('Search update delay'));
      await tester.tap(find.text('Search update delay'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('300 ms'));
      await fixture.frames(tester, 250);
      await tester.runAsync(() async {
        expect((await NativeBridge.instance.getSettings()).searchDelayMs, 300);
      });
      await tester.pumpWidget(const SizedBox());
    },
    skip: !fixture.native,
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'corner style updates immediately and survives stale settings saves',
    (tester) async {
      addTearDown(() => squareCorners.value = false);
      await mount(tester);
      final stale = await tester.runAsync(NativeBridge.instance.getSettings);
      expect(stale!.squareCorners, isFalse);
      await showSection(tester, 'Appearance and navigation');
      Future<void> select(String style) async {
        final row = find.widgetWithText(ListTile, 'Corner style');
        await visible(tester, row);
        await tester.tap(row);
        await tester.pumpAndSettle();
        await tester.tap(find.text(style).last);
        await fixture.frames(tester, 300);
        expect(tester.takeException(), isNull);
      }

      await select('Square');
      expect(squareCorners.value, isTrue);
      expect(
        (Theme.of(tester.element(find.byType(SettingsView))).cardTheme.shape!
                as RoundedRectangleBorder)
            .borderRadius,
        BorderRadius.zero,
      );
      await tester.runAsync(() async {
        await NativeBridge.instance.updateSettings(stale);
        expect(
          (await NativeBridge.instance.getSettings()).squareCorners,
          isTrue,
        );
        expect(
          await fixture.sql(
            "SELECT value FROM settings WHERE key='squareCorners'",
          ),
          'true',
        );
      });
      // Reopening Settings preserves the stored choice without resetting its route.
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1, character: '1');
      await fixture.frames(tester, 300);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit6, character: '6');
      await fixture.frames(tester, 300);
      await showSection(tester, 'Appearance and navigation');
      expect(find.widgetWithText(ListTile, 'Square'), findsOneWidget);
      await select('Rounded');
      expect(squareCorners.value, isFalse);
      expect(
        (Theme.of(tester.element(find.byType(SettingsView))).cardTheme.shape!
                as RoundedRectangleBorder)
            .borderRadius,
        BorderRadius.circular(12),
      );
      await tester.runAsync(() async {
        expect(
          (await NativeBridge.instance.getSettings()).squareCorners,
          isFalse,
        );
        expect(
          await fixture.sql(
            "SELECT value FROM settings WHERE key='squareCorners'",
          ),
          'false',
        );
      });
      await tester.pumpWidget(const SizedBox());
    },
    skip: !fixture.native,
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'source menu edits, filters, enable state and delete cancellation',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester);
      await showSection(tester, 'Sources');
      Future<void> menu(String action) async {
        final button = find.byTooltip('Source actions');
        await visible(tester, button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.text(action));
        await fixture.frames(tester, 350);
      }

      await menu('Edit source');
      expect(find.byType(EditDialog), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Edit source at 360px');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await menu('Category filters');
      expect(find.byType(CategoriesView), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: 'Category filters at 360px',
      );
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await fixture.frames(tester, 350);
      await menu('Disable source');
      await tester.runAsync(() async {
        expect(await fixture.sql('SELECT enabled FROM sources'), '0');
      });
      await visible(tester, find.byTooltip('Source actions'));
      await tester.tap(find.byTooltip('Source actions'));
      await tester.pumpAndSettle();
      final refresh = tester.widget<PopupMenuItem<VoidCallback>>(
        find.widgetWithText(PopupMenuItem<VoidCallback>, 'Refresh source'),
      );
      expect(refresh.enabled, isFalse);
      await tester.tap(find.text('Enable source'));
      await fixture.frames(tester, 350);
      await menu('Remove source');
      expect(find.text('Confirm deletion'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        expect(await fixture.sql('SELECT COUNT(*) FROM sources'), '1');
        expect(await fixture.sql('SELECT enabled FROM sources'), '1');
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !fixture.native,
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'source refresh actions use their loading overlay and retain rows on failure',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester);
      await showSection(tester, 'Sources');
      await visible(tester, find.text('Refresh all'));
      await tester.tap(find.text('Refresh all'));
      await fixture.frames(tester, 600);
      expect(find.text('Refresh results'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await visible(tester, find.byTooltip('Source actions'));
      await tester.tap(find.byTooltip('Source actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh source'));
      await fixture.frames(tester, 600);
      expect(find.text('Refresh results'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        expect(await fixture.sql('SELECT COUNT(*) FROM channels'), '3');
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !fixture.native,
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'playback numeric fields reject invalid or overflowing values',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester);
      await showSection(tester, 'Playback');
      await visible(tester, find.text('Cache seconds'));
      await tester.tap(find.text('Cache seconds'));
      await tester.pumpAndSettle();
      for (final invalid in ['-1', 'not a number', '4294967296']) {
        await tester.enterText(find.byType(TextFormField), invalid);
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.text('Enter a whole number from 0 to 4294967295'),
          findsOneWidget,
        );
      }
      await tester.enterText(find.byType(TextFormField), '0');
      await tester.tap(find.text('Save'));
      await fixture.frames(tester, 300);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.runAsync(() async {
        expect((await NativeBridge.instance.getSettings()).cacheSecs, 0);
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !fixture.native,
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'initial load can fail and retry, and numeric keys still navigate',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = fixture.Fixture();
      // A bridge from an earlier test's fake zone would never deliver here.
      await tester.runAsync(() async {
        NativeBridge.instance.dispose();
        await f.init(count: 3);
      });
      addTearDown(f.close);
      await tester.runAsync(() => fixture.sql('DROP TABLE settings'));
      addTearDown(
        () => tester.runAsync(
          () => fixture.sql(
            'CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY,value TEXT)',
          ),
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: SettingsView()));
      await fixture.frames(tester, 300);
      expect(find.text('Unable to load settings.'), findsOneWidget);
      await tester.runAsync(
        () => fixture.sql(
          'CREATE TABLE settings (key TEXT PRIMARY KEY,value TEXT)',
        ),
      );
      await tester.tap(find.text('Retry'));
      await fixture.frames(tester, 300);
      expect(find.text('Appearance and navigation'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2, character: '2');
      await fixture.frames(tester, 350);
      expect(
        tester.widget<Home>(find.byType(Home)).home.filters.viewType,
        ViewType.categories,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !fixture.native,
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'a failed save puts the switch back to the saved value',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester);
      await showSection(tester, 'Library visibility');
      final movies = find.widgetWithText(SwitchListTile, 'Show movies');
      await visible(tester, movies);
      final saved = tester.widget<SwitchListTile>(movies).value;
      await tester.runAsync(
        () => fixture.sql(
          "CREATE TRIGGER reject_settings_insert BEFORE INSERT ON settings BEGIN SELECT RAISE(ABORT,'fixture save failure'); END; CREATE TRIGGER reject_settings_update BEFORE UPDATE ON settings BEGIN SELECT RAISE(ABORT,'fixture save failure'); END;",
        ),
      );
      await tester.tap(movies);
      await tester.pump();
      expect(tester.widget<SwitchListTile>(movies).value, !saved);
      await fixture.frames(tester, 400);
      expect(find.textContaining('An error occurred'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(movies).value, saved);
      await tester.runAsync(() async {
        await fixture.sql(
          'DROP TRIGGER reject_settings_insert; DROP TRIGGER reject_settings_update',
        );
        expect((await NativeBridge.instance.getSettings()).showMovies, saved);
      });
      // The next save works again.
      await tester.tap(movies);
      await fixture.frames(tester, 400);
      expect(tester.widget<SwitchListTile>(movies).value, !saved);
      await tester.runAsync(() async {
        expect((await NativeBridge.instance.getSettings()).showMovies, !saved);
      });
      await tester.pumpWidget(const SizedBox());
    },
    skip: !fixture.native,
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'Home opens unified Media from the bottom bar and L key',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1, character: '1');
      await fixture.frames(tester, 350);
      expect(find.byType(Home), findsOneWidget);
      await tester.tap(find.byIcon(Icons.video_library));
      await fixture.frames(tester, 300);
      expect(find.byType(LocalMediaPage), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      // Let the route finish its exit transition.
      await fixture.frames(tester, 700);
      expect(find.byType(LocalMediaPage), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL, character: 'l');
      await fixture.frames(tester, 300);
      expect(find.byType(LocalMediaPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !fixture.native,
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
}
