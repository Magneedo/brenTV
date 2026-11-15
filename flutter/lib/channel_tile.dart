import 'library/download_ui.dart';
import 'dart:io';
import 'library/recording_ui.dart';
import 'package:brentv/models/settings.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:brentv/models/channel.dart';
import 'package:brentv/error.dart';
import 'package:brentv/models/media_type.dart';
import 'package:brentv/models/node.dart';
import 'package:brentv/models/node_type.dart';
import 'package:brentv/native_bridge.dart';
import 'package:brentv/playback/playback.dart';
import 'package:brentv/programme_guide.dart';
import 'package:brentv/full_guide.dart';
import 'package:brentv/theme.dart';

class ChannelTile extends StatefulWidget {
  final Channel channel;
  final ProgrammeGuide? guide;
  final Settings? settings;
  final BuildContext parentContext;
  final Function(Node node) setNode;
  final VoidCallback? onFocusNavbar;
  final VoidCallback onSelect;
  final VoidCallback? onFavoriteChanged;
  final VoidCallback? onHiddenChanged;

  /// Set on the History page: shows a remove button (and Delete key); called
  /// after the channel was removed from history.
  final VoidCallback? onRemovedFromHistory;

  /// Set on Favorites in provider order: moves this favorite one place
  /// earlier (-1) or later (1).
  final void Function(int step)? onMove;

  /// Turns true on the tile a favorite just moved to, so focus follows it.
  final bool requestFocus;
  final bool autofocus;

  /// The list this tile is part of, for next/previous channel in the player.
  final List<Channel> siblings;
  const ChannelTile({
    super.key,
    required this.channel,
    this.guide,
    this.settings,
    required this.setNode,
    required this.parentContext,
    required this.onSelect,
    this.onFavoriteChanged,
    this.onHiddenChanged,
    this.onRemovedFromHistory,
    this.onMove,
    this.requestFocus = false,
    this.onFocusNavbar,
    this.autofocus = false,
    this.siblings = const [],
  });

  @override
  State<ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends State<ChannelTile> {
  static final _selectionKeys = {
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
  };

  final FocusNode _focusNode = FocusNode();
  final _statesController = WidgetStatesController();
  Timer? _longPressTimer;
  bool _longPressTriggered = false;
  bool _selectKeyDown = false;
  InteractiveInkFeature? _inkFeature;
  BuildContext? _innerContext;

  @override
  void initState() {
    super.initState();
    _focusNode.onKeyEvent = _handleKeyEvent;
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(ChannelTile old) {
    super.didUpdateWidget(old);
    if (widget.requestFocus && !old.requestFocus) {
      _focusNode.requestFocus();
      // Scrolls only if the tile is off either edge.
      for (final policy in [
        ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      ]) {
        Scrollable.ensureVisible(context, alignmentPolicy: policy);
      }
    }
  }

  void _showSplash() {
    final context = _innerContext;
    if (context == null) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    _inkFeature?.cancel();

    final theme = Theme.of(context);
    final splashFactory = theme.splashFactory;

    _inkFeature = splashFactory.create(
      controller: Material.of(context),
      referenceBox: renderBox,
      position: renderBox.size.center(Offset.zero),
      color: theme.splashColor,
      textDirection: Directionality.of(context),
      containedInkWell: true,
      rectCallback: () => Offset.zero & renderBox.size,
      borderRadius: cornerRadius(context),
    );
  }

  void _confirmSplash() {
    _inkFeature?.confirm();
    _inkFeature = null;
  }

  void _cancelSplash() {
    _inkFeature?.cancel();
    _inkFeature = null;
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _longPressTimer?.cancel();
      _longPressTriggered = false;
      _selectKeyDown = false;
      _cancelSplash();
      _statesController.update(WidgetState.pressed, false);
    }
    setState(() {});
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_focusNode.hasPrimaryFocus) return KeyEventResult.ignored;
    if (event is! KeyUpEvent &&
        widget.onMove != null &&
        HardwareKeyboard.instance.isControlPressed &&
        (widget.settings?.keyboardShortcuts ?? true)) {
      final step = switch (event.logicalKey) {
        LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.arrowLeft => -1,
        LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.arrowRight => 1,
        _ => 0,
      };
      if (step != 0) {
        widget.onMove!(step);
        return KeyEventResult.handled;
      }
    }
    if (event is KeyDownEvent && (widget.settings?.keyboardShortcuts ?? true)) {
      if (Platform.isLinux &&
          event.logicalKey == LogicalKeyboardKey.keyR &&
          widget.channel.mediaType == MediaType.livestream) {
        toggleRecording(context, widget.channel);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyH &&
          widget.onHiddenChanged != null &&
          widget.channel.mediaType != MediaType.season) {
        _hide();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyG && _hasGuide) {
        _openGuide();
        return KeyEventResult.handled;
      }
    }
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyF) {
      favorite();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.delete &&
        widget.onRemovedFromHistory != null) {
      removeFromHistory();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (!FocusScope.of(context).focusInDirection(TraversalDirection.right)) {
        widget.onFocusNavbar?.call();
      }
      return KeyEventResult.handled;
    }

    if (_selectionKeys.contains(event.logicalKey)) {
      if (event is KeyDownEvent) {
        _selectKeyDown = true;
        _longPressTimer?.cancel();
        _statesController.update(WidgetState.pressed, true);
        _showSplash();
        _longPressTimer = Timer(const Duration(milliseconds: 500), () {
          _longPressTriggered = true;
          _confirmSplash();
          _statesController.update(WidgetState.pressed, false);
          favorite();
        });
      } else if (event is KeyUpEvent) {
        if (!_selectKeyDown) {
          return KeyEventResult.handled;
        }
        _selectKeyDown = false;
        _longPressTimer?.cancel();
        _statesController.update(WidgetState.pressed, false);
        _confirmSplash();
        if (!_longPressTriggered) {
          play();
        }
        _longPressTriggered = false;
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _cancelSplash();
    _statesController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Toggles the favorite star: tile menu, right-click, long-press, F, or
  /// holding Enter.
  /// Favorite categories have their own tab on the Favorites page.
  Future<void> favorite() async {
    final channel = widget.channel;
    if (channel.mediaType == MediaType.season) return;
    final value = !channel.favorite;
    await Error.tryAsyncNoLoading(() async {
      if (channel.mediaType == MediaType.group) {
        await NativeBridge.instance.favoriteGroup(channel.id!, value);
      } else {
        await NativeBridge.instance.favorite(channel.id!, value);
      }
      if (!mounted) return;
      setState(() => channel.favorite = value);
      widget.onFavoriteChanged?.call();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              value ? "Added to favorites" : "Removed from favorites",
            ),
            duration: const Duration(milliseconds: 800),
          ),
        );
    }, context);
  }

  Future<void> removeFromHistory() async {
    final done = widget.onRemovedFromHistory;
    if (done == null) return;
    await Error.tryAsyncNoLoading(() async {
      await NativeBridge.instance.removeLastWatched(widget.channel.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text("Removed from history"),
            duration: Duration(milliseconds: 800),
          ),
        );
      done();
    }, context);
  }

  Future<int?> _handleSeries() async {
    if (widget.channel.url?.isEmpty == true) {
      if (context.mounted) {
        Error.handleError(context, "Invalid series: series ID is null");
      }
      return null;
    }
    final seriesId = int.tryParse(widget.channel.url!);
    if (seriesId == null) {
      if (context.mounted) {
        Error.handleError(
          context,
          "Invalid series: series ID is not a valid number",
        );
      }
      return null;
    }
    await Error.tryAsync(
      () async {
        await NativeBridge.instance.getEpisodes(
          seriesId,
          widget.channel.sourceId,
          widget.channel.image,
        );
      },
      widget.parentContext,
      null,
      true,
      false,
    );
    return seriesId;
  }

  Future<void> play() async {
    widget.onSelect();
    // Xtream series URLs contain a provider ID; M3U series entries are
    // already playable URLs and do not need episode discovery.
    final groupedSeries =
        widget.channel.mediaType == MediaType.serie &&
        int.tryParse(widget.channel.url ?? '') != null;
    int? seriesId;
    if (groupedSeries) {
      seriesId = await _handleSeries();
      if (seriesId == null) return;
    }

    if (widget.channel.mediaType == MediaType.group ||
        groupedSeries ||
        widget.channel.mediaType == MediaType.season) {
      widget.setNode(
        Node(
          id:
              widget.channel.mediaType == MediaType.group ||
                  widget.channel.mediaType == MediaType.season
              ? widget.channel.id!
              : seriesId!,
          name: widget.channel.name,
          type: fromMediaType(widget.channel.mediaType),
        ),
      );
    } else {
      if (!mounted) return;
      await Playback.play(
        context,
        widget.channel,
        siblings: widget.siblings,
        settings: widget.settings,
      );
      if (mounted) _focusNode.requestFocus();
    }
  }

  bool get _hasGuide =>
      widget.channel.mediaType == MediaType.livestream &&
      widget.settings?.enableFullGuide == true &&
      widget.settings?.showProgrammes == true;
  void _openGuide() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => FullGuide(
        settings: widget.settings!,
        initialChannel: widget.channel,
        sourceIds: [widget.channel.sourceId],
      ),
    ),
  );
  Future<void> _hide() async {
    final id = widget.channel.id!;
    final group = widget.channel.mediaType == MediaType.group;
    final changed = widget.onHiddenChanged;
    final result = await Error.tryAsyncNoLoading(
      () => NativeBridge.instance.setHidden(id, true, group: group),
      context,
    );
    if (mounted && result.success) {
      changed?.call();
      // The tile is gone once the list reloads, so Undo uses only locals.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Hidden · restore from Settings → Hidden items'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await NativeBridge.instance.setHidden(id, false, group: group);
              changed?.call();
            },
          ),
        ),
      );
    }
  }

  void _channelMenu() {
    showDialog<void>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(widget.channel.name),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(c);
              favorite();
            },
            child: Text(
              widget.channel.favorite
                  ? 'Remove from favorites (F)'
                  : 'Add to favorites (F)',
            ),
          ),
          if (Platform.isLinux &&
              widget.channel.mediaType == MediaType.livestream)
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(c);
                toggleRecording(context, widget.channel);
              },
              child: const Text('Record now (R)'),
            ),
          if (_hasGuide)
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(c);
                _openGuide();
              },
              child: const Text('Program guide (G)'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      // Like dwl's window borders: #005577 when focused.
      shape: RoundedRectangleBorder(
        borderRadius: cornerRadius(context),
        side: BorderSide(
          color: _focusNode.hasFocus && showsFocus
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
          width: borderWidth,
        ),
      ),
      child: Builder(
        builder: (innerContext) {
          _innerContext = innerContext;
          return InkWell(
            focusNode: _focusNode,
            autofocus: widget.autofocus,
            statesController: _statesController,
            borderRadius: cornerRadius(context),
            onLongPress: _channelMenu,
            onSecondaryTap: _channelMenu,
            onTap: () async => await play(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ChannelProgramme(
                      name: widget.channel.name,
                      channelId: widget.channel.id,
                      guide: widget.guide,
                    ),
                  ),
                  if (widget.channel.isPlayable &&
                      widget.channel.mediaType != MediaType.livestream)
                    DownloadControl(channel: widget.channel),
                  if (widget.channel.mediaType == MediaType.season)
                    IconButton(
                      tooltip: 'Download season',
                      onPressed: () => downloadSeason(context, widget.channel),
                      icon: const Icon(Icons.download_outlined, size: 20),
                    ),
                  if (widget.channel.favorite)
                    const Icon(Icons.star, size: 20, color: Colors.amber),
                  if (widget.channel.mediaType != MediaType.season)
                    ExcludeFocus(
                      child: PopupMenuButton<VoidCallback>(
                        tooltip: 'Channel options',
                        icon: const Icon(Icons.more_vert, size: 18),
                        onSelected: (action) => action(),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: favorite,
                            child: Text(
                              widget.channel.favorite
                                  ? 'Remove from favorites (F)'
                                  : 'Add to favorites (F)',
                            ),
                          ),
                          if (widget.onMove != null) ...[
                            PopupMenuItem(
                              value: () => widget.onMove!(-1),
                              child: const Text('Move earlier (Ctrl+↑)'),
                            ),
                            PopupMenuItem(
                              value: () => widget.onMove!(1),
                              child: const Text('Move later (Ctrl+↓)'),
                            ),
                          ],
                          if (Platform.isLinux &&
                              widget.channel.mediaType == MediaType.livestream)
                            PopupMenuItem(
                              value: () =>
                                  toggleRecording(context, widget.channel),
                              child: const Text('Record now (R)'),
                            ),
                          if (widget.channel.isPlayable &&
                              widget.channel.mediaType != MediaType.livestream)
                            PopupMenuItem(
                              value: () =>
                                  downloadVideo(context, widget.channel),
                              child: const Text('Download video'),
                            ),
                          if (_hasGuide)
                            PopupMenuItem(
                              value: _openGuide,
                              child: const Text('Program guide (G)'),
                            ),
                          if (widget.onHiddenChanged != null)
                            PopupMenuItem(
                              value: _hide,
                              child: const Text('Hide (H)'),
                            ),
                          if (widget.onRemovedFromHistory != null)
                            PopupMenuItem(
                              value: removeFromHistory,
                              child: const Text('Remove from history (Delete)'),
                            ),
                        ],
                      ),
                    ),
                  if (widget.onRemovedFromHistory != null)
                    // ExcludeFocus: no extra focus stop, even in D-pad mode
                    // where InkResponse would otherwise accept focus.
                    ExcludeFocus(
                      child: InkResponse(
                        canRequestFocus: false,
                        radius: 18,
                        onTap: removeFromHistory,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Tooltip(
                            message: "Remove from history (Delete)",
                            child: Icon(Icons.close, size: 18),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
