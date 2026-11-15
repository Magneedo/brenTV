import 'library/recording_ui.dart';
// Raw key data distinguishes Android soft-keyboard events from D-pad input.
// ignore_for_file: deprecated_member_use

import 'package:brentv/models/settings.dart';
import 'package:brentv/refresh_stats.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:brentv/native_bridge.dart';
import 'package:brentv/bottom_nav.dart';
import 'package:brentv/channel_tile.dart';
import 'package:brentv/programme_guide.dart';
import 'package:brentv/full_guide.dart';
import 'package:brentv/library/media_page.dart';
import 'package:brentv/settings_view.dart';
import 'package:brentv/loading.dart';
import 'package:brentv/models/channel.dart';
import 'package:brentv/models/custom_shortcut.dart';
import 'package:brentv/models/filters.dart';
import 'package:brentv/models/media_type.dart';
import 'package:brentv/models/home_manager.dart';
import 'package:brentv/models/id_data.dart';
import 'package:brentv/models/no_push_animation_material_page_route.dart';
import 'package:brentv/models/node.dart';
import 'package:brentv/models/node_type.dart';
import 'package:brentv/models/sort_type.dart';
import 'package:brentv/models/view_type.dart';
import 'package:brentv/select_dialog.dart';
import 'package:brentv/shortcuts_dialog.dart';
import 'package:brentv/error.dart';
import 'package:brentv/utils.dart';

class Home extends StatefulWidget {
  final HomeManager home;
  final bool refresh;
  final bool firstLaunch;
  final bool tvMode;

  /// Opened on top once loaded (the start page category), so Back returns here.
  final Node? openNode;
  const Home({
    super.key,
    required this.home,
    this.refresh = false,
    this.firstLaunch = false,
    this.tvMode = false,
    this.openNode,
  });
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  Settings? settings;
  Timer? _debounce;
  bool reachedMax = false;
  int _loadGeneration = 0;
  final int pageSize = 36;
  List<Channel> channels = [];
  TextEditingController searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _keywordsFocusNode = FocusNode(skipTraversal: true);
  final FocusNode _sortFocusNode = FocusNode(skipTraversal: true);
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _searchHeader = GlobalKey();
  final GlobalKey _favoritesHeader = GlobalKey();
  late final _guide = ProgrammeGuide(NativeBridge.instance.getNowNext);
  StreamSubscription<void>? _guideInvalidation;
  int _gridColumns = 1;
  double _rowHeight = 64;
  bool _foreground = true;
  int currentlyFocusedChannel = 0;
  bool isLoading = false;
  Size? _viewportSize;
  bool blockSettings = false;
  int? previousScroll;
  bool scrolledDeepEnough = false;
  MediaType _favoriteMediaType = MediaType.livestream;
  bool _moving = false;
  int? _movedTo;

  bool get _favoritesRoot =>
      widget.home.filters.viewType == ViewType.favorites &&
      widget.home.filters.groupId == null &&
      widget.home.filters.seriesId == null;

  bool get _canReorder =>
      _favoritesRoot && widget.home.filters.sort == SortType.provider;

  /// Swaps a favorite with its neighbour in the shown list; focus follows it.
  /// Ignored while a page loads, so a result read before the swap can't
  /// undo it on screen.
  Future<void> _moveFavorite(int index, int step) async {
    final to = index + step;
    if (_moving || isLoading || to < 0 || to >= channels.length) return;
    _moving = true;
    final generation = _loadGeneration;
    final a = channels[index], b = channels[to];
    final result = await Error.tryAsyncNoLoading(
      () => NativeBridge.instance.swapFavorites(
        a.id!,
        b.id!,
        group: a.mediaType == MediaType.group,
      ),
      context,
    );
    _moving = false;
    if (!mounted || !result.success) return;
    // A load started meanwhile may predate the swap: reload instead.
    if (isLoading || generation != _loadGeneration) return load();
    setState(() {
      channels[index] = b;
      channels[to] = a;
      currentlyFocusedChannel = _movedTo = to;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _movedTo = null);
  }

  MediaType get _selectedFavorites =>
      widget.home.filters.favoriteGroups ? MediaType.group : _favoriteMediaType;

  void _selectFavorites(MediaType type) {
    if (_selectedFavorites == type) return;
    _debounce?.cancel();
    setState(() {
      widget.home.filters.favoriteGroups = type == MediaType.group;
      if (type != MediaType.group) _favoriteMediaType = type;
      widget.home.filters.query = searchController.text;
      channels = [];
      currentlyFocusedChannel = 0;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    load();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _guideInvalidation = NativeBridge.instance.catalogChanges.listen(
      (_) => _reloadGuideSettings(),
    );
    _scrollController.addListener(_scrollListener);
    _searchFocusNode.onKey = _handleSearchRawKey;
    _keywordsFocusNode.onKeyEvent = _handleKeywordsKeyEvent;
    _sortFocusNode.onKeyEvent = _handleSortKeyEvent;
    initializeAsync();
  }

  Future<void> initializeAsync() async {
    if (widget.home.filters.sourceIds == null) {
      final sources = await NativeBridge.instance.getEnabledSourcesMinimal();
      widget.home.filters.sourceIds = sources;
    }
    settings = await NativeBridge.instance.getSettings();
    if (!mounted) return;
    if (widget.home.filters.mediaTypes == null) {
      widget.home.filters.mediaTypes = settings!.getMediaTypes();
      widget.home.filters.sort = settings!.defaultSort;
    }
    setState(() {});
    if ([
      ViewType.all,
      ViewType.categories,
      ViewType.favorites,
      ViewType.history,
    ].contains(widget.home.filters.viewType)) {
      await load();
    }
    if (!mounted) return;
    if (channels.any(
      (c) => c.mediaType == MediaType.movie || c.mediaType == MediaType.serie,
    )) {
      await showMediaTip(context, 'downloads');
    }
    if (!mounted) return;
    if (widget.firstLaunch) {
      await Utils.maybeShowWhatsNew(context);
    }
    if (!mounted) return;
    if (widget.refresh) {
      setState(() => blockSettings = true);
      final result = await Error.tryAsyncNoLoading(
        () => NativeBridge.instance.refreshAll(),
        context,
      );
      if (!mounted) return;
      setState(() => blockSettings = false);
      final stats = result.data;
      // Quiet when every source refreshed; the full report only on failures.
      if (stats != null && stats.any((s) => !s.success)) {
        await showRefreshStats(context, stats);
      } else if (stats != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(stats.map(refreshSummary).join("\n")),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      if (mounted) await load();
    }
    if (mounted && widget.openNode != null) setNode(widget.openNode!);
  }

  Future<void> _reloadGuideSettings() async {
    _guide.setActive(false);
    _guide.invalidate();
    try {
      final updated = await NativeBridge.instance.getSettings();
      if (!mounted) return;
      setState(() => settings = updated);
      _checkScrollAfterLayout();
    } catch (_) {
      /* Keep guide requests stopped when settings cannot be read. */
    }
  }

  void showSortDialog() {
    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (context) => SelectDialog(
        title: "Sort by",
        data: SortType.values
            .map((x) => IdData(id: x.index, data: sortTypeToString(x)))
            .toList(),
        action: (sort) {
          setState(() {
            widget.home.filters.sort = SortType.values[sort];
          });
          Navigator.of(context).pop();
          load(false);
        },
      ),
    );
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text(
          'Remove all viewing history? Favorites and saved playback positions will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear history'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await Error.tryAsyncNoLoading(
      () => NativeBridge.instance.clearHistory(),
      context,
    );
    if (mounted && result.success) await load();
  }

  void scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Future<void> load([bool more = false]) async {
    if (!mounted || (more && (isLoading || reachedMax || channels.isEmpty))) {
      return;
    }
    final generation = more ? _loadGeneration : ++_loadGeneration;
    if (!more) _guide.setVisible([]);
    setState(() => isLoading = true);
    final page = more ? widget.home.filters.page + 1 : 1;
    final f = widget.home.filters;
    final request = Filters(
      query: f.query,
      sourceIds: f.sourceIds?.toList(),
      mediaTypes: _favoritesRoot && !f.favoriteGroups
          ? [_favoriteMediaType]
          : f.mediaTypes?.toList(),
      viewType: f.viewType,
      page: page,
      seriesId: f.seriesId,
      seasonId: f.seasonId,
      groupId: f.groupId,
      useKeywords: f.useKeywords,
      sort: f.sort,
      favoriteGroups: _favoritesRoot && f.favoriteGroups,
    );
    final response = await Error.tryAsyncNoLoading(() async {
      final result = await NativeBridge.instance.getChannels(request);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        channels = more ? [...channels, ...result] : result;
        widget.home.filters.page = page;
        reachedMax = result.length < pageSize;
      });
    }, context);
    if (!mounted || generation != _loadGeneration) return;
    setState(() => isLoading = false);
    if (response.success) _checkScrollAfterLayout();
  }

  void _checkScrollAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollListener();
    });
  }

  void _updateGuideVisibility() {
    if (!_scrollController.hasClients) return;
    final header =
        _searchHeader.currentContext?.findRenderObject() as RenderBox?;
    if (header == null || !header.hasSize) return;
    final position = _scrollController.position;
    final top = position.pixels;
    final bottom = top + position.viewportDimension;
    final favoritesHeader =
        _favoritesHeader.currentContext?.findRenderObject() as RenderBox?;
    final gridTop =
        header.size.height +
        ((favoritesHeader?.hasSize ?? false)
            ? favoritesHeader!.size.height
            : 0) +
        5;
    final stride = _rowHeight + 12;
    final first = math.max(0, ((top - gridTop) / stride).floor());
    final last = math.min(
      (channels.length - 1) ~/ _gridColumns,
      ((bottom - gridTop) / stride).floor(),
    );
    _guide.setVisible([
      for (var row = first; row <= last; row++)
        if (gridTop + row * stride + _rowHeight > top &&
            gridTop + row * stride < bottom)
          for (var column = 0; column < _gridColumns; column++)
            if (row * _gridColumns + column < channels.length)
              if (settings != null &&
                  guideEnabled(
                    channels[row * _gridColumns + column],
                    settings!,
                  ))
                channels[row * _gridColumns + column],
    ]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _guide.setActive(
      _foreground &&
          (settings?.showProgrammes ?? false) &&
          (settings?.guideTileText ?? false) &&
          (ModalRoute.of(context)?.isCurrent ?? true),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _guideInvalidation?.cancel();
    _guide.dispose();
    searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    _searchFocusNode.dispose();
    _keywordsFocusNode.dispose();
    _sortFocusNode.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    _updateGuideVisibility();
    final bool shouldShow = _scrollController.offset > 200;

    if (scrolledDeepEnough != shouldShow) {
      setState(() => scrolledDeepEnough = shouldShow);
    }

    final position = _scrollController.position;
    if (position.extentAfter < position.viewportDimension * 0.25) {
      load(true);
    }
  }

  void clearSearch() {
    widget.home.filters.query = null;
    searchController.clear();
  }

  bool _focusChannelsBelow() {
    return FocusScope.of(context).focusInDirection(TraversalDirection.down);
  }

  static const int _androidFlagSoftKeyboard = 0x2;

  bool _isFromSoftKeyboard(RawKeyEvent event) {
    final data = event.data;
    return data is RawKeyEventDataAndroid &&
        (data.flags & _androidFlagSoftKeyboard) != 0;
  }

  KeyEventResult _handleSearchRawKey(FocusNode node, RawKeyEvent event) {
    if (_isFromSoftKeyboard(event)) {
      return KeyEventResult.ignored;
    }
    if (event is RawKeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.escape ||
          key == LogicalKeyboardKey.goBack) {
        bool moved = FocusScope.of(
          context,
        ).focusInDirection(TraversalDirection.down);
        if (!moved) {
          node.unfocus();
        }
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        bool moved = FocusScope.of(
          context,
        ).focusInDirection(TraversalDirection.down);
        if (moved) {
          return KeyEventResult.handled;
        }
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        _keywordsFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleKeywordsKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.arrowLeft) {
        _searchFocusNode.requestFocus();
        searchController.selection = TextSelection.fromPosition(
          TextPosition(offset: searchController.text.length),
        );
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        _sortFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        bool moved = FocusScope.of(
          context,
        ).focusInDirection(TraversalDirection.down);
        if (moved) {
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleSortKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.arrowLeft) {
        _keywordsFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        bool moved = FocusScope.of(
          context,
        ).focusInDirection(TraversalDirection.down);
        if (moved) {
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  void _openLocalMedia() => updateViewMode(ViewType.downloads);
  void _leaveMedia() {
    if (widget.tvMode) {
      Navigator.of(context).maybePop();
    } else {
      updateViewMode(
        settings?.bottomBar
                .visiblePages()
                .where((p) => p != ViewType.downloads && p != ViewType.settings)
                .firstOrNull ??
            ViewType.all,
      );
    }
  }

  ViewType getStartingView() {
    if (widget.home.filters.groupId != null) {
      return ViewType.categories;
    }
    return widget.home.filters.viewType;
  }

  void updateViewMode(ViewType type) {
    if (type == widget.home.filters.viewType &&
        widget.home.filters.groupId == null &&
        widget.home.filters.seriesId == null) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    if (blockSettings && type == ViewType.settings) return;
    final route = NoPushAnimationMaterialPageRoute(
      builder: (context) => type == ViewType.settings
          ? SettingsView(tvMode: widget.tvMode)
          : Home(
              tvMode: widget.tvMode,
              home: HomeManager(
                filters: Filters(
                  viewType: type,
                  mediaTypes: widget.home.filters.mediaTypes,
                  sourceIds: widget.home.filters.sourceIds,
                ),
              ),
            ),
    );
    if (widget.tvMode) {
      Navigator.of(context).push(route);
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(route, (route) => false);
  }

  void setNode(Node node) {
    final home = HomeManager(
      node: node,
      filters: Filters(
        viewType: ViewType.all,
        mediaTypes: widget.home.filters.mediaTypes,
        sourceIds: widget.home.filters.sourceIds,
      ),
    );
    if (widget.home.filters.groupId != null) {
      home.filters.groupId = widget.home.filters.groupId;
    } else if (node.type == NodeType.category) {
      home.filters.groupId = node.id;
    }
    if (node.type == NodeType.series) home.filters.seriesId = node.id;
    if (node.type == NodeType.season) {
      home.filters.seriesId = widget.home.filters.seriesId;
      home.filters.seasonId = node.id;
    }
    Navigator.of(context).push(
      NoPushAnimationMaterialPageRoute(
        builder: (context) => Home(home: home, tvMode: widget.tvMode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rowHeight = math.max(
      64.0,
      64 * MediaQuery.textScalerOf(context).scale(16) / 16,
    );
    if (_rowHeight != rowHeight) {
      _rowHeight = rowHeight;
      _checkScrollAfterLayout();
    }
    _guide.setActive(
      _foreground &&
          (settings?.showProgrammes ?? false) &&
          (settings?.guideTileText ?? false) &&
          (ModalRoute.isCurrentOf(context) ?? true),
    );
    return PageShortcuts(
      bindings: {
        if (settings?.keyboardShortcuts ?? true) ...{
          const CustomShortcut(CharacterActivator('/')):
              _searchFocusNode.requestFocus,
          const CustomShortcut(CharacterActivator('?')): () =>
              showShortcuts(context),
          if (Platform.isLinux)
            const CustomShortcut(CharacterActivator('l')): _openLocalMedia,
          for (
            var i = 0;
            i < (settings?.bottomBar.visiblePages().length ?? 0);
            i++
          )
            CustomShortcut(CharacterActivator('${i + 1}')): () =>
                updateViewMode(settings!.bottomBar.visiblePages()[i]),
          const CustomShortcut(SingleActivator(LogicalKeyboardKey.home)):
              scrollToTop,
          const CustomShortcut(SingleActivator(LogicalKeyboardKey.end)): () {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(
                _scrollController.position.maxScrollExtent,
              );
            }
          },
        },
      },
      child: _buildPage(context),
    );
  }

  Widget _buildPage(BuildContext context) {
    if ([
      ViewType.localMedia,
      ViewType.recordings,
      ViewType.downloads,
    ].contains(widget.home.filters.viewType)) {
      return Scaffold(
        body: widget.home.filters.viewType == ViewType.recordings
            ? const RecordingsPage()
            : MediaPage(onExit: _leaveMedia),
        bottomNavigationBar: LibraryNavigation(
          onOpen: () => updateViewMode(ViewType.recordings),
          child: BottomNav(
            startingView: widget.home.filters.viewType,
            configuration: settings?.bottomBar,
            updateViewMode: updateViewMode,
            tvMode: widget.tvMode,
          ),
        ),
      );
    }
    return PrimaryScrollController(
      controller: _scrollController,
      child: Scaffold(
        appBar: widget.home.node != null
            ? AppBar(
                title: Text(widget.home.node.toString()),
                automaticallyImplyLeading: !widget.tvMode,
                leading: !widget.tvMode
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).pop(),
                      )
                    : null,
              )
            : null,
        body: Loading(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (_viewportSize != constraints.biggest) {
                  _viewportSize = constraints.biggest;
                  _checkScrollAfterLayout();
                }
                final double width = constraints.maxWidth;
                final int crossAxisCount = (width / 300).floor().clamp(1, 4);
                _gridColumns = crossAxisCount;
                return CustomScrollView(
                  controller: null,
                  primary: true,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        key: _searchHeader,
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: TextField(
                            focusNode: _searchFocusNode,
                            style: TextStyle(
                              fontSize: Theme.of(
                                context,
                              ).textTheme.titleMedium?.fontSize!,
                            ),
                            controller: searchController,
                            textInputAction: TextInputAction.search,
                            onTapOutside: (_) => _searchFocusNode.unfocus(),
                            onEditingComplete: () {
                              _searchFocusNode.unfocus();
                              if (Platform.isLinux) _focusChannelsBelow();
                            },
                            onChanged: (query) {
                              _debounce?.cancel();
                              void search() {
                                if (!mounted ||
                                    widget.home.filters.query == query) {
                                  return;
                                }
                                widget.home.filters.query = query;
                                load(false);
                              }

                              final delay = settings?.searchDelayMs ?? 0;
                              if (delay == 0) {
                                search();
                              } else {
                                _debounce = Timer(
                                  Duration(milliseconds: delay.clamp(0, 1000)),
                                  search,
                                );
                              }
                            },
                            decoration: InputDecoration(
                              hintText: "Search...",
                              hintStyle: TextStyle(
                                fontSize: Theme.of(
                                  context,
                                ).textTheme.titleMedium?.fontSize!,
                              ),
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: !Platform.isLinux
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (searchController.text.isNotEmpty)
                                          IconButton(
                                            tooltip: 'Clear search',
                                            onPressed: () {
                                              _debounce?.cancel();
                                              clearSearch();
                                              load();
                                            },
                                            icon: const Icon(Icons.close),
                                          ),
                                        PopupMenuButton<String>(
                                          tooltip: 'List options',
                                          onSelected: (action) {
                                            _searchFocusNode.unfocus();
                                            switch (action) {
                                              case 'sort':
                                                showSortDialog();
                                              case 'words':
                                                widget
                                                    .home
                                                    .filters
                                                    .useKeywords = !widget
                                                    .home
                                                    .filters
                                                    .useKeywords;
                                                load();
                                              case 'history':
                                                _clearHistory();
                                              case 'guide':
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) => FullGuide(
                                                      settings: settings!,
                                                      sourceIds: widget
                                                          .home
                                                          .filters
                                                          .sourceIds,
                                                      groupId: widget
                                                          .home
                                                          .filters
                                                          .groupId,
                                                      favorites:
                                                          widget
                                                              .home
                                                              .filters
                                                              .viewType ==
                                                          ViewType.favorites,
                                                    ),
                                                  ),
                                                );
                                            }
                                          },
                                          itemBuilder: (_) => [
                                            const PopupMenuItem(
                                              value: 'sort',
                                              child: Text('Sort'),
                                            ),
                                            CheckedPopupMenuItem(
                                              value: 'words',
                                              checked: widget
                                                  .home
                                                  .filters
                                                  .useKeywords,
                                              child: const Text(
                                                'Match all words',
                                              ),
                                            ),
                                            if (settings?.enableFullGuide ==
                                                    true &&
                                                settings?.showProgrammes ==
                                                    true)
                                              const PopupMenuItem(
                                                value: 'guide',
                                                child: Text('Program guide'),
                                              ),
                                            if (widget.home.filters.viewType ==
                                                ViewType.history)
                                              const PopupMenuItem(
                                                value: 'history',
                                                child: Text('Clear history'),
                                              ),
                                          ],
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (settings?.enableFullGuide == true &&
                                            settings?.showProgrammes == true)
                                          IconButton(
                                            tooltip: 'Program guide',
                                            icon: const Icon(
                                              Icons.view_timeline,
                                            ),
                                            onPressed: () =>
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) => FullGuide(
                                                      settings: settings!,
                                                      sourceIds: widget
                                                          .home
                                                          .filters
                                                          .sourceIds,
                                                      groupId: widget
                                                          .home
                                                          .filters
                                                          .groupId,
                                                      favorites:
                                                          widget
                                                              .home
                                                              .filters
                                                              .viewType ==
                                                          ViewType.favorites,
                                                    ),
                                                  ),
                                                ),
                                          ),
                                        if (widget.home.filters.viewType ==
                                            ViewType.history)
                                          IconButton(
                                            tooltip: 'Clear history',
                                            onPressed: _clearHistory,
                                            icon: const Icon(
                                              Icons.delete_sweep_outlined,
                                            ),
                                          ),
                                        if (searchController.text.isNotEmpty)
                                          ExcludeFocus(
                                            child: IconButton(
                                              tooltip: 'Clear search',
                                              icon: const Icon(Icons.close),
                                              onPressed: () {
                                                _debounce?.cancel();
                                                clearSearch();
                                                load();
                                              },
                                            ),
                                          ),
                                        IconButton(
                                          focusNode: _keywordsFocusNode,
                                          tooltip:
                                              'Match all words in any order',
                                          onPressed: () {
                                            widget.home.filters.useKeywords =
                                                !widget
                                                    .home
                                                    .filters
                                                    .useKeywords;
                                            load(false);
                                          },
                                          icon: Icon(
                                            widget.home.filters.useKeywords
                                                ? Icons.label
                                                : Icons.label_outline,
                                          ),
                                        ),
                                        IconButton(
                                          focusNode: _sortFocusNode,
                                          tooltip: 'Sort',
                                          onPressed: showSortDialog,
                                          icon: const Icon(Icons.sort),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_favoritesRoot)
                      SliverToBoxAdapter(
                        child: Padding(
                          key: _favoritesHeader,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Center(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final tab in const [
                                  (
                                    MediaType.livestream,
                                    'Channels',
                                    Icons.live_tv,
                                  ),
                                  (MediaType.movie, 'Movies', Icons.movie),
                                  (
                                    MediaType.serie,
                                    'Series',
                                    Icons.video_library,
                                  ),
                                  (
                                    MediaType.group,
                                    'Categories',
                                    Icons.folder_special,
                                  ),
                                ])
                                  ChoiceChip(
                                    label: Text(tab.$2),
                                    avatar: Icon(tab.$3, size: 18),
                                    showCheckmark: false,
                                    selected: _selectedFavorites == tab.$1,
                                    onSelected: (_) => _selectFavorites(tab.$1),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (settings != null && !isLoading && channels.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            widget.home.filters.query?.isNotEmpty == true
                                ? (_favoritesRoot
                                      ? 'No matching favorites'
                                      : 'No results')
                                : !_favoritesRoot
                                ? 'Nothing here yet'
                                : widget.home.filters.favoriteGroups
                                ? 'No favorite categories yet. Star a category from Categories to add it here.'
                                : switch (_favoriteMediaType) {
                                    MediaType.movie =>
                                      'No favorite movies yet. Star a movie to add it here.',
                                    MediaType.serie =>
                                      'No favorite series yet. Star a series or episode to add it here.',
                                    _ =>
                                      'No favorite channels yet. Star a channel to add it here.',
                                  },
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(10, 5, 10, 10),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final channel = channels[index];
                          return ChannelTile(
                            channel: channel,
                            guide:
                                settings?.showProgrammes == true &&
                                    settings?.guideTileText == true
                                ? _guide
                                : null,
                            settings: settings,
                            parentContext: context,
                            setNode: setNode,
                            autofocus: index == currentlyFocusedChannel,
                            siblings: channels,
                            onSelect: () => currentlyFocusedChannel = index,
                            onMove: _canReorder
                                ? (step) => _moveFavorite(index, step)
                                : null,
                            requestFocus: index == _movedTo,
                            onHiddenChanged: () => load(),
                            onRemovedFromHistory:
                                widget.home.filters.viewType == ViewType.history
                                ? () => load()
                                : null,
                            onFavoriteChanged: () {
                              if (channel.mediaType == MediaType.group ||
                                  widget.home.filters.viewType ==
                                      ViewType.favorites) {
                                load();
                              }
                            },
                          );
                        }, childCount: channels.length),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisExtent: _rowHeight,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        bottomNavigationBar: LibraryNavigation(
          onOpen: () => updateViewMode(ViewType.recordings),
          child: !widget.tvMode
              ? BottomNav(
                  startingView: getStartingView(),
                  configuration: settings?.bottomBar,
                  blockSettings: blockSettings,
                  updateViewMode: updateViewMode,
                  tvMode: widget.tvMode,
                )
              : const SizedBox.shrink(),
        ),
        floatingActionButton: !widget.tvMode
            ? IgnorePointer(
                ignoring: !scrolledDeepEnough,
                child: AnimatedOpacity(
                  opacity: scrolledDeepEnough ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: FloatingActionButton(
                    onPressed: scrollToTop,
                    shape:
                        Theme.of(context).floatingActionButtonTheme.shape ??
                        const CircleBorder(),
                    tooltip: 'Scroll to Top',
                    child: const Icon(Icons.arrow_upward),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
