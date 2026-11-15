import 'package:brentv/bottom_nav.dart';
import 'package:brentv/bottom_bar_editor.dart';
import 'package:brentv/models/bottom_bar.dart';
import 'package:brentv/models/view_type.dart';
import 'package:brentv/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'reordered bar selects by identity and reveals Settings on compact screens',
    (tester) async {
      tester.view.physicalSize = const Size(280, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ViewType? picked;
      final config = BottomBarConfig([
        const BottomBarPage(ViewType.history, true),
        const BottomBarPage(ViewType.all, true),
        const BottomBarPage(ViewType.downloads, true),
        const BottomBarPage(ViewType.settings, true),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          theme: dwlTheme(showFocusOutline: true),
          home: Scaffold(
            bottomNavigationBar: BottomNav(
              configuration: config,
              startingView: ViewType.settings,
              updateViewMode: (v) => picked = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Settings'));
      expect(picked, ViewType.settings);
      await tester.drag(find.byType(NavigationBar), const Offset(400, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('History'));
      expect(picked, ViewType.history);
    },
  );
  testWidgets('Move down and visibility controls work without dragging', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: dwlTheme(showFocusOutline: true),
        home: BottomBarEditor(configuration: BottomBarConfig.defaults()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Move down').first);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Categories')).dy,
      lessThan(tester.getTopLeft(find.text('All')).dy),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'editor fits a compact phone and retains a visible content page',
    (tester) async {
      tester.view.physicalSize = const Size(280, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final config = BottomBarConfig([
        for (final p in BottomBarConfig.defaults().pages)
          BottomBarPage(
            p.page,
            p.page == ViewType.all || p.page == ViewType.settings,
          ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          theme: dwlTheme(showFocusOutline: true),
          home: BottomBarEditor(configuration: config),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Switch>(find.byType(Switch).first).onChanged,
        isNull,
      );
    },
  );
}
