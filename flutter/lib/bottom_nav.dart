import 'package:brentv/theme.dart';
import 'package:flutter/material.dart';
import 'package:brentv/models/view_type.dart';
import 'package:brentv/models/bottom_bar.dart';

IconData pageIcon(ViewType page) => switch (page) {
  ViewType.all => Icons.list,
  ViewType.categories => Icons.dashboard,
  ViewType.favorites => Icons.star,
  ViewType.history => Icons.history,
  ViewType.localMedia => Icons.video_library,
  ViewType.recordings => Icons.fiber_manual_record,
  ViewType.downloads => Icons.video_library,
  ViewType.settings => Icons.settings,
};

class BottomNav extends StatefulWidget {
  final ValueChanged<ViewType> updateViewMode;
  final ViewType startingView;
  final BottomBarConfig? configuration;
  final bool blockSettings;
  final bool tvMode;
  const BottomNav({
    super.key,
    required this.updateViewMode,
    this.startingView = ViewType.all,
    this.configuration,
    this.blockSettings = false,
    this.tvMode = false,
  });

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  final _scroll = ScrollController();
  final _selectedKey = GlobalKey();
  bool _revealSelection = true;
  double? _width;
  @override
  void didUpdateWidget(BottomNav old) {
    super.didUpdateWidget(old);
    if (old.startingView != widget.startingView ||
        old.configuration != widget.configuration) {
      _revealSelection = true;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = (widget.configuration ?? BottomBarConfig.defaults())
        .visiblePages();
    final selected = pages.indexOf(widget.startingView);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceBright,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: borderWidth,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, size) {
          if (_width != size.maxWidth) {
            _width = size.maxWidth;
            _revealSelection = true;
          }
          if (_revealSelection) {
            _revealSelection = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final selectedContext = _selectedKey.currentContext;
              if (mounted && selectedContext != null) {
                Scrollable.ensureVisible(selectedContext, alignment: 0.5);
              }
            });
          }
          return SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: size.maxWidth.clamp(pages.length * 92.0, double.infinity),
              child: NavigationBar(
                destinations: [
                  for (final page in pages)
                    NavigationDestination(
                      key: page == pages[selected < 0 ? 0 : selected]
                          ? _selectedKey
                          : null,
                      icon: Icon(pageIcon(page)),
                      label: viewTypeToString(page),
                    ),
                ],
                selectedIndex: selected < 0 ? 0 : selected,
                onDestinationSelected: (index) {
                  final page = pages[index];
                  if (widget.blockSettings && page == ViewType.settings) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Settings disabled while refreshing on start',
                        ),
                      ),
                    );
                  } else {
                    widget.updateViewMode(page);
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
