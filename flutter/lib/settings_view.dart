import 'library/recording_ui.dart';
import 'dart:io';
import 'library/library_settings.dart';
import 'library/media_library.dart';
import 'bottom_bar_editor.dart';
import 'package:brentv/models/source_type.dart';
import 'package:brentv/player_settings.dart';
import 'package:brentv/categories_view.dart';
import 'package:brentv/refresh_stats.dart';
import 'package:flutter/material.dart';
import 'package:brentv/native_bridge.dart';
import 'package:brentv/bottom_nav.dart';
import 'package:brentv/confirm_delete.dart';
import 'package:brentv/models/filters.dart';
import 'package:brentv/select_dialog.dart';
import 'package:brentv/edit_dialog.dart';
import 'package:brentv/home.dart';
import 'package:brentv/loading.dart';
import 'package:brentv/models/home_manager.dart';
import 'package:brentv/models/id_data.dart';
import 'package:brentv/models/settings.dart';
import 'package:brentv/models/source.dart';
import 'package:brentv/models/sort_type.dart';
import 'package:brentv/models/view_type.dart';
import 'package:brentv/error.dart';
import 'package:brentv/setup.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:brentv/hidden_items.dart';
import 'package:brentv/models/custom_shortcut.dart';
import 'package:brentv/shortcuts_dialog.dart';
import 'package:brentv/ui_scale.dart';
import 'package:brentv/theme.dart';

class SettingsView extends StatefulWidget {
  final bool tvMode;

  const SettingsView({super.key, this.tvMode = false});

  @override
  State<SettingsView> createState() => _SettingsState();
}

class _SettingsState extends State<SettingsView> {
  Widget _feature(
    String title,
    bool value,
    ValueChanged<bool> change, {
    String? subtitle,
  }) => SwitchListTile(
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle),
    value: value,
    onChanged: (v) {
      setState(() => change(v));
      updateSettings();
    },
  );

  Future<void> _searchDelay() async {
    final value = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Search update delay'),
        children: [
          for (final ms in [0, 100, 300, 500])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, ms),
              child: Text(ms == 0 ? 'Immediate' : '$ms ms'),
            ),
        ],
      ),
    );
    if (value != null && mounted) {
      setState(() => settings.searchDelayMs = value);
      await updateSettings();
    }
  }

  Future<void> _uiScale() async {
    final value = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('UI scale'),
        children: [
          for (final percent in uiScaleSteps)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, percent),
              child: Text('$percent%'),
            ),
        ],
      ),
    );
    if (value != null) await setUiScale(value);
  }

  Future<void> _cornerStyle() async {
    final value = await showDialog<bool>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Corner style'),
        children: [
          for (final square in [false, true])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, square),
              child: Text(square ? 'Square' : 'Rounded'),
            ),
        ],
      ),
    );
    if (value == null || !mounted) return;
    await Error.tryAsyncNoLoading(() async {
      await NativeBridge.instance.setSquareCorners(value);
      squareCorners.value = value;
    }, context);
  }

  Settings settings = Settings();
  List<Source> sources = [];
  bool loading = true;
  bool loadFailed = false;
  @override
  void initState() {
    super.initState();
    initAsync();
  }

  Future<void> initAsync() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      loadFailed = false;
    });
    try {
      final results = await Future.wait([
        NativeBridge.instance.getSettings(),
        NativeBridge.instance.getSources(),
      ]);
      if (!mounted) return;
      setState(() {
        settings = results[0] as Settings;
        sources = results[1] as List<Source>;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadFailed = true;
      });
    }
  }

  void updateView(ViewType view) {
    if (view == ViewType.settings) return;
    final route = PageRouteBuilder(
      pageBuilder: (_, _, _) => Home(
        tvMode: widget.tvMode,
        home: HomeManager(filters: Filters(viewType: view)),
      ),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    );
    // Like Home: TV mode keeps the stack so Back returns to the TV home.
    if (widget.tvMode) {
      Navigator.push(context, route);
      return;
    }
    Navigator.pushAndRemoveUntil(context, route, (route) => false);
  }

  Future<void> showEditDialog(
    BuildContext parentContext,
    final Source source,
  ) async {
    await showDialog(
      barrierDismissible: true,
      context: parentContext,
      builder: (builder) => EditDialog(
        source: source,
        afterSave: reloadSources,
        parentContext: parentContext,
      ),
    );
  }

  String get _startPage =>
      settings.defaultView == ViewType.categories &&
          settings.startGroupId != null
      ? "Category: ${settings.startGroupName}"
      : viewTypeToString(settings.defaultView);

  /// The page brenTV opens to: a main page or one of the favourite categories.
  Future<void> _showStartPageDialog(BuildContext context) async {
    final groups =
        (await Error.tryAsyncNoLoading(
          () async => NativeBridge.instance.getAllChannels(
            Filters(
              sourceIds: sources
                  .where((s) => s.enabled)
                  .map((s) => s.id!)
                  .toList(),
              mediaTypes: settings.getMediaTypes(),
              viewType: ViewType.categories,
              favoriteGroups: true,
            ),
          ),
          context,
        )).data ??
        [];
    if (!context.mounted) return;
    final visible = settings.bottomBar
        .visiblePages()
        .where((p) => p != ViewType.settings)
        .toList();
    final pagesById = {for (final page in visible) page.index: page};
    const pages = 100;
    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (BuildContext context) {
        return SelectDialog(
          title: "Start page",
          data: [
            for (final x in visible)
              IdData(id: x.index, data: viewTypeToString(x)),
            if (visible.contains(ViewType.categories))
              for (final (i, g) in groups.indexed)
                IdData(id: pages + i, data: "Category: ${g.name}"),
          ],
          action: (id) {
            setState(() {
              final group = id >= pages ? groups[id - pages] : null;
              settings.defaultView = group == null
                  ? pagesById[id]!
                  : ViewType.categories;
              settings.startGroupId = group?.id;
              settings.startGroupName = group?.name;
              updateSettings();
            });
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  Future<void> _showDefaultSortDialog(BuildContext context) async {
    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (BuildContext context) {
        return SelectDialog(
          title: "Default sort",
          data: SortType.values
              .map((x) => IdData(id: x.index, data: sortTypeToString(x)))
              .toList(),
          action: (sort) {
            setState(() {
              settings.defaultSort = SortType.values[sort];
              updateSettings();
            });
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  Future<void> toggleSource(Source source) async {
    final result = await Error.tryAsyncNoLoading(
      () async => await NativeBridge.instance.setSourceEnabled(
        source.id!,
        !source.enabled,
      ),
      context,
    );
    if (!mounted || !result.success) return;
    await reloadSources();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Source ${!source.enabled ? "enabled" : "disabled"}"),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  Future<void> _refreshSource(Source source, BuildContext actionContext) async {
    final result = await Error.tryAsync(
      () => NativeBridge.instance.refreshSource(source),
      actionContext,
      null,
      true,
      false,
    );
    if (!mounted) return;
    if (result.data != null) await showRefreshStats(context, [result.data!]);
    if (mounted) await reloadSources();
  }

  Widget getSource(Source source, BuildContext actionContext) {
    final imported = [
      if (source.importLive) 'Live',
      if (source.importMovies) 'Movies',
      if (source.importSeries) 'Series',
    ].join(', ');
    return ListTile(
      onTap: () => showEditDialog(context, source),
      title: Text(source.name),
      subtitle: Text(
        '${source.sourceType.label} · ${source.enabled ? 'Enabled' : 'Disabled'}'
        '\nImports: ${imported.isEmpty ? 'None' : imported}'
        '${source.lastRefreshStats == null ? '' : '\n${refreshSummary(source.lastRefreshStats!)}'}',
      ),
      trailing: PopupMenuButton<VoidCallback>(
        tooltip: 'Source actions',
        onSelected: (action) => action(),
        itemBuilder: (_) => [
          PopupMenuItem(
            enabled: source.enabled,
            value: () => _refreshSource(source, actionContext),
            child: const Text('Refresh source'),
          ),
          PopupMenuItem(
            value: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoriesView(source: source),
                ),
              );
              if (mounted) await reloadSources();
            },
            child: const Text('Category filters'),
          ),
          PopupMenuItem(
            value: () => showEditDialog(context, source),
            child: const Text('Edit source'),
          ),
          PopupMenuItem(
            value: () => toggleSource(source),
            child: Text(source.enabled ? 'Disable source' : 'Enable source'),
          ),
          PopupMenuItem(
            value: () => showConfirmDeleteDialog(source, actionContext),
            child: const Text('Remove source'),
          ),
        ],
      ),
    );
  }

  Future<void> showConfirmDeleteDialog(
    Source source,
    BuildContext actionContext,
  ) async {
    await showDialog(
      barrierDismissible: true,
      context: context,
      builder: (builder) => ConfirmDelete(
        type: "source",
        name: source.name,
        confirm: () async {
          await Error.tryAsync(
            () async => await NativeBridge.instance.deleteSource(source.id!),
            actionContext,
            "Successfully deleted source",
          );
          await reloadSources();
          if (!mounted) return;
          if (sources.isEmpty) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => Setup(tvMode: widget.tvMode),
              ),
              (route) => false,
            );
          }
        },
      ),
    );
  }

  Future<void> reloadSources() async {
    await Error.tryAsyncNoLoading(
      () async => sources = await NativeBridge.instance.getSources(),
      context,
    );
    if (mounted) setState(() {});
  }

  Future<void> updateSettings() async {
    final result = await Error.tryAsyncNoLoading(
      () async => await NativeBridge.instance.updateSettings(settings),
      context,
    );
    if (result.success || !mounted) return;
    // Show what is saved, not the change that failed.
    final saved = await Error.tryAsyncNoLoading(
      () => NativeBridge.instance.getSettings(),
      context,
    );
    if (mounted && saved.data != null) setState(() => settings = saved.data!);
  }

  @override
  Widget build(BuildContext context) => PageShortcuts(
    bindings: {
      if (settings.keyboardShortcuts)
        for (var i = 0; i < settings.bottomBar.visiblePages().length; i++)
          CustomShortcut(CharacterActivator('${i + 1}')): () =>
              updateView(settings.bottomBar.visiblePages()[i]),
      if (settings.keyboardShortcuts)
        const CustomShortcut(CharacterActivator('?')): () =>
            showShortcuts(context),
    },
    child: _buildSettings(context),
  );

  Widget _section(
    String title,
    String summary,
    IconData icon,
    List<Widget> children,
  ) => Card(
    margin: const EdgeInsets.symmetric(vertical: 6),
    // Keeps the header's hover and focus fill inside the rounded border.
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      key: PageStorageKey(title),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(summary),
      textColor: Theme.of(context).colorScheme.onSurface,
      collapsedTextColor: Theme.of(context).colorScheme.onSurface,
      iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
      collapsedIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
      shape: const Border(),
      collapsedShape: const Border(),
      children: children,
    ),
  );

  Widget _settingsList(BuildContext actionContext) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Settings',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          _section(
            'Appearance and navigation',
            'Start page, scale, corners and TV layout',
            Icons.tune,
            [
              ListTile(
                title: const Text('Bottom bar'),
                subtitle: const Text('Show, hide and reorder pages'),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          BottomBarEditor(configuration: settings.bottomBar),
                    ),
                  );
                  if (mounted) await initAsync();
                },
              ),
              ListTile(
                title: const Text('Start page'),
                subtitle: Text('$_startPage · star a category to start in it'),
                onTap: () => _showStartPageDialog(context),
              ),
              ListTile(
                title: const Text('Default sort'),
                subtitle: Text(sortTypeToString(settings.defaultSort)),
                onTap: () => _showDefaultSortDialog(context),
              ),
              ValueListenableBuilder(
                valueListenable: uiScale,
                builder: (context, percent, _) => ListTile(
                  title: const Text('UI scale'),
                  subtitle: Text(
                    Platform.isLinux
                        ? '$percent% · Ctrl+= / Ctrl+- / Ctrl+0'
                        : '$percent%',
                  ),
                  onTap: _uiScale,
                ),
              ),
              ValueListenableBuilder(
                valueListenable: squareCorners,
                builder: (context, square, _) => ListTile(
                  title: const Text('Corner style'),
                  subtitle: Text(square ? 'Square' : 'Rounded'),
                  onTap: _cornerStyle,
                ),
              ),
              _feature(
                'Force TV Mode',
                settings.forceTVMode,
                (v) => settings.forceTVMode = v,
              ),
              ListTile(
                title: const Text('Reset tips'),
                subtitle: const Text('Show recording and download tips again'),
                onTap: () async {
                  final library = MediaLibrary.instance;
                  final messenger = ScaffoldMessenger.of(context);
                  library.preferences.dismissedTips.clear();
                  try {
                    await library.savePreferences();
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Tips reset.')),
                      );
                    }
                  } catch (_) {
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Could not reset tips.')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          if (Platform.isLinux)
            _section(
              'Recordings',
              'DVR folder and schedule padding',
              Icons.fiber_manual_record,
              const [RecordingSettings()],
            ),
          _section(
            'Downloads',
            'Movie and series folders, queue limits',
            Icons.download_outlined,
            const [DownloadSettings()],
          ),
          _section(
            'Playback',
            'Player, quality and buffering',
            Icons.play_circle_outline,
            [
              if (Platform.isLinux)
                _feature(
                  'Low latency livestreams',
                  settings.lowLatency,
                  (v) => settings.lowLatency = v,
                ),
              if (Platform.isLinux)
                _feature(
                  'Automatic quality discovery',
                  settings.autoQualityDiscovery,
                  (v) => settings.autoQualityDiscovery = v,
                  subtitle:
                      'Find HLS playlists and alternate feeds in the background',
                ),
              if (Platform.isIOS)
                ListenableBuilder(
                  listenable: MediaLibrary.instance,
                  builder: (context, _) {
                    final library = MediaLibrary.instance;
                    return SwitchListTile(
                      title: const Text('Convert every live channel'),
                      subtitle: const Text(
                        'Channels Apple’s player cannot show are converted on this iPhone automatically. Turn this on to convert all of them if some still fail to open.',
                      ),
                      value: library.preferences.relayAlways,
                      onChanged: (value) async {
                        library.preferences.relayAlways = value;
                        library.changed();
                        try {
                          await library.savePreferences();
                        } catch (_) {
                          library.preferences.relayAlways = !value;
                          library.changed();
                        }
                      },
                    );
                  },
                ),
              PlayerSettings(
                settings: settings,
                onChanged: () {
                  setState(() {});
                  updateSettings();
                },
              ),
            ],
          ),
          _section(
            'Program guide',
            settings.showProgrammes
                ? 'Live guide enabled'
                : 'Live guide disabled',
            Icons.live_tv,
            [
              _feature(
                'Live program guide',
                settings.showProgrammes,
                (v) => settings.showProgrammes = v,
                subtitle:
                    'Now/next from Xtream; turn off to stop live guide requests',
              ),
              _feature(
                'Program text on tiles',
                settings.guideTileText,
                (v) => settings.guideTileText = v,
              ),
              _feature(
                'Program titles in players',
                settings.guidePlayerTitles,
                (v) => settings.guidePlayerTitles = v,
              ),
              _feature(
                'Full program guide',
                settings.enableFullGuide,
                (v) => settings.enableFullGuide = v,
                subtitle: 'Loads schedules only when opened',
              ),
              _feature(
                'Catch-up playback',
                settings.enableCatchup,
                (v) => settings.enableCatchup = v,
                subtitle: 'Available for archived Xtream programs',
              ),
              _feature(
                'XMLTV for M3U sources',
                settings.enableXmltv,
                (v) => settings.enableXmltv = v,
                subtitle: 'Configure the guide URL in the source',
              ),
            ],
          ),
          _section(
            Platform.isLinux ? 'Keyboard and search' : 'Search',
            Platform.isLinux
                ? 'Shortcuts, channel numbers and search timing'
                : 'Search timing',
            Icons.keyboard_outlined,
            [
              if (Platform.isLinux) ...[
                _feature(
                  'Keyboard shortcuts',
                  settings.keyboardShortcuts,
                  (v) => settings.keyboardShortcuts = v,
                  subtitle:
                      '1–5 changes pages; Home/End moves through loaded items',
                ),
                ListTile(
                  title: const Text('Keyboard shortcut list'),
                  subtitle: const Text('Also ? outside text fields'),
                  onTap: () => showShortcuts(context),
                ),
                _feature(
                  'MPV channel number entry',
                  settings.numberKeySwitching,
                  (v) => settings.numberKeySwitching = v,
                  subtitle:
                      'Digits then Enter, in provider order; applies next launch',
                ),
              ],
              ListTile(
                title: const Text('Search update delay'),
                subtitle: Text(
                  settings.searchDelayMs == 0
                      ? 'Immediate'
                      : '${settings.searchDelayMs} ms',
                ),
                onTap: _searchDelay,
              ),
            ],
          ),
          _section(
            'Library visibility',
            'Choose what appears in the channel lists',
            Icons.filter_list,
            [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'These switches change visibility. Choose imported media in each source.',
                ),
              ),
              _feature(
                'Show livestreams',
                settings.showLivestreams,
                (v) => settings.showLivestreams = v,
              ),
              _feature(
                'Show movies',
                settings.showMovies,
                (v) => settings.showMovies = v,
              ),
              _feature(
                'Show series',
                settings.showSeries,
                (v) => settings.showSeries = v,
              ),
              ListTile(
                title: const Text('Hidden channels and categories'),
                subtitle: const Text(
                  'Restore items without losing favorites or history',
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HiddenItems()),
                ),
              ),
            ],
          ),
          _section(
            'Sources',
            '${sources.where((s) => s.enabled).length} enabled · imports and category filters',
            Icons.playlist_add,
            [
              _feature(
                'Refresh sources on start',
                settings.refreshOnStart,
                (v) => settings.refreshOnStart = v,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh all'),
                      onPressed: sources.any((s) => s.enabled)
                          ? () async {
                              final result = await Error.tryAsync(
                                () => NativeBridge.instance.refreshAll(),
                                actionContext,
                                null,
                                true,
                                false,
                              );
                              if (!mounted) return;
                              if (result.data != null) {
                                await showRefreshStats(context, result.data!);
                              }
                              if (mounted) await reloadSources();
                            }
                          : null,
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add source'),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                Setup(showAppBar: true, tvMode: widget.tvMode),
                          ),
                        );
                        if (mounted) await reloadSources();
                      },
                    ),
                  ],
                ),
              ),
              if (sources.isEmpty)
                const ListTile(title: Text('No sources yet')),
              ...sources.map((source) => getSource(source, actionContext)),
            ],
          ),
          _section('About', 'Project and license', Icons.info_outline, [
            ListTile(
              title: const Text('About brenTV'),
              subtitle: const Text('AGPL-3.0 · Based on Fred TV by Fredolx'),
              onTap: () => launchUrl(
                Uri.parse('https://github.com/Fredolx/fred-tv-mobile'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ]),
        ],
      ),
    ),
  );

  Widget _buildSettings(BuildContext context) => Scaffold(
    body: Loading(
      child: Builder(
        builder: (actionContext) => SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : loadFailed
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Unable to load settings.'),
                      TextButton(
                        onPressed: initAsync,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _settingsList(actionContext),
        ),
      ),
    ),
    bottomNavigationBar: LibraryNavigation(
      onOpen: () => updateView(ViewType.recordings),
      child: !widget.tvMode
          ? BottomNav(
              updateViewMode: updateView,
              startingView: ViewType.settings,
              configuration: settings.bottomBar,
              tvMode: widget.tvMode,
            )
          : const SizedBox.shrink(),
    ),
  );
}
