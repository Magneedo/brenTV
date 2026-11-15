import 'dart:convert';
import 'dart:io';
import 'view_type.dart';

class BottomBarPage {
  final ViewType page;
  final bool visible;
  const BottomBarPage(this.page, this.visible);
  Map<String, Object> toJson() => {'page': page.name, 'visible': visible};
}

class BottomBarConfig {
  final List<BottomBarPage> pages;
  BottomBarConfig(Iterable<BottomBarPage> pages)
    : pages = List.unmodifiable(pages);
  factory BottomBarConfig.defaults() => BottomBarConfig([
    for (final page in [
      ViewType.all,
      ViewType.categories,
      ViewType.favorites,
      ViewType.history,
      ViewType.downloads,
      ViewType.recordings,
      ViewType.settings,
    ])
      BottomBarPage(page, page != ViewType.recordings),
  ]);
  factory BottomBarConfig.decode(String? value) {
    final defaults = BottomBarConfig.defaults().pages;
    final result = <BottomBarPage>[];
    try {
      for (final entry in jsonDecode(value ?? '[]') as List) {
        final name = entry['page'] == 'localMedia'
            ? 'downloads'
            : entry['page'];
        final matches = ViewType.values.where((v) => v.name == name);
        if (matches.isEmpty ||
            matches.first == ViewType.settings ||
            entry['visible'] is! bool) {
          continue;
        }
        if (!result.any((p) => p.page == matches.first)) {
          result.add(BottomBarPage(matches.first, entry['visible'] as bool));
        } else if (matches.first == ViewType.downloads &&
            entry['visible'] == true) {
          final index = result.indexWhere((p) => p.page == ViewType.downloads);
          result[index] = const BottomBarPage(ViewType.downloads, true);
        }
      }
    } catch (_) {
      /* Old or invalid settings use defaults. */
    }
    for (final page in defaults) {
      if (page.page != ViewType.settings &&
          !result.any((p) => p.page == page.page)) {
        result.add(page);
      }
    }
    if (!result.any((p) => p.visible)) {
      final i = result.indexWhere((p) => p.page == ViewType.all);
      result[i] = const BottomBarPage(ViewType.all, true);
    }
    return BottomBarConfig([
      ...result,
      const BottomBarPage(ViewType.settings, true),
    ]);
  }
  List<ViewType> visiblePages({bool? linux}) {
    final visible = [
      for (final entry in pages)
        if (entry.visible &&
            ((linux ?? Platform.isLinux) ||
                (entry.page != ViewType.localMedia &&
                    entry.page != ViewType.recordings)))
          entry.page,
    ];
    // A Linux-only configuration still has a usable home when opened on iOS.
    if (visible.every((p) => p == ViewType.settings)) {
      visible.insert(0, ViewType.all);
    }
    return visible;
  }

  ViewType startPage(ViewType requested) {
    if (requested == ViewType.localMedia) requested = ViewType.downloads;
    final visible = visiblePages();
    return visible.contains(requested) ? requested : visible.first;
  }

  String encode() => jsonEncode(pages.map((p) => p.toJson()).toList());
}
