import 'dart:async';
import 'bottom_nav.dart';
import 'models/bottom_bar.dart';
import 'native_bridge.dart';
import 'library/recording_ui.dart';
import 'package:flutter/material.dart';
import 'package:brentv/home.dart';
import 'package:brentv/menu_tile.dart';
import 'package:brentv/models/filters.dart';
import 'package:brentv/models/home_manager.dart';
import 'package:brentv/models/media_type.dart';
import 'package:brentv/models/view_type.dart';
import 'package:brentv/settings_view.dart';
import 'package:brentv/utils.dart';

class TvHome extends StatefulWidget {
  final bool nested;
  final ViewType? previousViewType;
  const TvHome({super.key, this.nested = false, this.previousViewType});

  @override
  State<TvHome> createState() => _TvHomeState();
}

class _TvHomeState extends State<TvHome> {
  BottomBarConfig _bottomBar = BottomBarConfig.defaults();
  StreamSubscription<void>? _changes;
  Future<void> _loadNavigation() async {
    try {
      final settings = await NativeBridge.instance.getSettings();
      if (mounted) setState(() => _bottomBar = settings.bottomBar);
    } catch (_) {
      /* Keep Settings available if settings cannot be read. */
    }
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadNavigation();
    _changes = NativeBridge.instance.catalogChanges.listen(
      (_) => _loadNavigation(),
    );
    if (!widget.nested) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Utils.maybeShowWhatsNew(context),
      );
    }
  }

  void navigateHome(Filters filters) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            Home(home: HomeManager(filters: filters), tvMode: true),
      ),
    );
  }

  void navNested(ViewType viewType) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TvHome(nested: true, previousViewType: viewType),
      ),
    );
  }

  void navSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsView(tvMode: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: RecordingIndicator(
        onOpen: () => navigateHome(Filters(viewType: ViewType.recordings)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Wrap(
              alignment: WrapAlignment.center,
              children: widget.nested ? getMediaTypeSelectNested() : getHome(),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> getMediaTypeSelectNested() {
    return [
      MenuTile(
        autofocus: true,
        icon: Icons.list,
        label: "All",
        color: const LinearGradient(
          colors: [Colors.blueGrey, Colors.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => navigateHome(
          Filters(
            viewType: widget.previousViewType!,
            mediaTypes: [
              MediaType.livestream,
              MediaType.movie,
              MediaType.serie,
            ],
          ),
        ),
      ),
      MenuTile(
        icon: Icons.live_tv,
        label: "Live",
        color: const LinearGradient(
          colors: [Colors.amber, Colors.deepOrange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => navigateHome(
          Filters(
            viewType: widget.previousViewType!,
            mediaTypes: [MediaType.livestream],
          ),
        ),
      ),
      MenuTile(
        icon: Icons.movie,
        label: "Vods",
        color: LinearGradient(
          colors: [Colors.red, Colors.red.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => navigateHome(
          Filters(
            viewType: widget.previousViewType!,
            mediaTypes: [MediaType.movie],
          ),
        ),
      ),
      MenuTile(
        icon: Icons.local_movies,
        label: "Series",
        color: const LinearGradient(
          colors: [Colors.purple, Colors.deepPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => navigateHome(
          Filters(
            viewType: widget.previousViewType!,
            mediaTypes: [MediaType.serie],
          ),
        ),
      ),
    ];
  }

  List<Widget> getHome() => [
    for (final (i, page) in _bottomBar.visiblePages().indexed)
      MenuTile(
        autofocus: i == 0,
        icon: pageIcon(page),
        label: viewTypeToString(page),
        color: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.primary,
          ],
        ),
        onTap: () {
          if (page == ViewType.settings) {
            navSettings();
          } else if ([ViewType.recordings, ViewType.downloads].contains(page)) {
            navigateHome(Filters(viewType: page));
          } else {
            navNested(page);
          }
        },
      ),
  ];
}
