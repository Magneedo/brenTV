import 'dart:convert';
import 'package:brentv/models/bottom_bar.dart';
import 'package:brentv/models/view_type.dart';
import 'package:brentv/models/proto_extensions.dart';
import 'package:brentv/generated/generated_proto.pb.dart' as pb;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'old settings migrate without changing IDs or enabling optional pages',
    () {
      final config = pb.Settings(defaultView: 3).toDomain();
      expect(config.defaultView, ViewType.history);
      expect(config.bottomBar.visiblePages(linux: true), [
        ViewType.all,
        ViewType.categories,
        ViewType.favorites,
        ViewType.history,
        ViewType.downloads,
        ViewType.settings,
      ]);
      expect(config.bottomBar.visiblePages(linux: false), [
        ViewType.all,
        ViewType.categories,
        ViewType.favorites,
        ViewType.history,
        ViewType.downloads,
        ViewType.settings,
      ]);
    },
  );
  test(
    'legacy local files and downloads merge into one visible Media page',
    () {
      final config = BottomBarConfig.decode(
        jsonEncode([
          {'page': 'history', 'visible': true},
          {'page': 'localMedia', 'visible': true},
          {'page': 'downloads', 'visible': false},
        ]),
      );
      expect(
        config.pages.where((p) => p.page == ViewType.downloads),
        hasLength(1),
      );
      expect(config.pages.any((p) => p.page == ViewType.localMedia), false);
      expect(config.startPage(ViewType.localMedia), ViewType.downloads);
      expect(config.visiblePages(linux: false), contains(ViewType.downloads));
      expect(BottomBarConfig.decode(config.encode()).encode(), config.encode());
    },
  );
  test(
    'reordered pages retain identity, hidden start falls back, settings pinned',
    () {
      final config = BottomBarConfig.decode(
        jsonEncode([
          {'page': 'settings', 'visible': false},
          {'page': 'history', 'visible': true},
          {'page': 'all', 'visible': false},
          {'page': 'history', 'visible': false},
          {'page': 'unknown', 'visible': true},
        ]),
      );
      expect(config.visiblePages(linux: true).first, ViewType.history);
      expect(config.pages.last.page, ViewType.settings);
      expect(config.pages.last.visible, true);
      expect(config.startPage(ViewType.all), ViewType.history);
      expect(BottomBarConfig.decode(config.encode()).encode(), config.encode());
    },
  );
  test(
    'corrupt config recovers and at least one cross-platform page stays visible',
    () {
      expect(BottomBarConfig.decode('{').visiblePages(linux: false).length, 6);
      final config = BottomBarConfig.decode(
        jsonEncode([
          for (final v in ViewType.values) {'page': v.name, 'visible': false},
        ]),
      );
      expect(config.visiblePages(linux: false), [
        ViewType.all,
        ViewType.settings,
      ]);
    },
  );
  test('a DVR-only Linux bar remains valid and falls back safely on iOS', () {
    final config = BottomBarConfig.decode(
      jsonEncode([
        for (final v in ViewType.values)
          {
            'page': v.name,
            'visible': v == ViewType.recordings || v == ViewType.settings,
          },
      ]),
    );
    expect(config.visiblePages(linux: true), [
      ViewType.recordings,
      ViewType.settings,
    ]);
    expect(config.visiblePages(linux: false), [
      ViewType.all,
      ViewType.settings,
    ]);
  });
}
