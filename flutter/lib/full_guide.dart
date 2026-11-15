import 'dart:io';
import 'library/recording_ui.dart';
import 'library/media_library.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:brentv/generated/generated_proto.pb.dart' as pb;
import 'package:brentv/models/channel.dart';
import 'package:brentv/models/filters.dart';
import 'package:brentv/models/media_type.dart';
import 'package:brentv/models/settings.dart';
import 'package:brentv/models/view_type.dart';
import 'package:brentv/native_bridge.dart';
import 'package:brentv/playback/playback.dart';

class FullGuide extends StatefulWidget {
  final Settings settings;
  final Channel? initialChannel;
  final List<int>? sourceIds;
  final int? groupId;
  final bool favorites;
  final Future<List<Channel>> Function(Filters)? loadChannels;
  const FullGuide({
    super.key,
    required this.settings,
    this.initialChannel,
    this.sourceIds,
    this.groupId,
    this.favorites = false,
    this.loadChannels,
  });
  @override
  State<FullGuide> createState() => _FullGuideState();
}

class _FullGuideState extends State<FullGuide> with WidgetsBindingObserver {
  static const _hourWidth = 180.0, _nameWidth = 180.0, _rowHeight = 88.0;
  final _scroll = ScrollController();
  final _horizontal = ScrollController();
  final Map<int, pb.ProgrammeList> _data = {};
  final Map<int, String> _errors = {};
  List<Channel> _channels = [];
  List<Channel> _needed = [];
  Set<int?> _visibleIds = {};
  List<int> _sources = [];
  late Settings _settings = widget.settings;
  late int _from = (DateTime.now().millisecondsSinceEpoch ~/ 3600000) * 3600;
  int _page = 0, _generation = 0, _scheduleGeneration = 0;
  bool _loading = false,
      _end = false,
      _busy = false,
      _active = true,
      _foreground = true;
  bool _initial = true;
  int _lastStart = 0;
  StreamSubscription<void>? _changes;

  @override
  void initState() {
    super.initState();
    MediaLibrary.instance.addListener(_libraryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showMediaTip(context, "recording");
    });
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _scroll.addListener(_visible);
    _changes = NativeBridge.instance.catalogChanges.listen((_) => _reload());
    _reload();
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    _scheduleGeneration++;
    _needed = [];
    _data.clear();
    _errors.clear();
    try {
      final settings = await NativeBridge.instance.getSettings();
      final enabled = await NativeBridge.instance.getEnabledSourcesMinimal();
      if (!mounted || generation != _generation) return;
      setState(() {
        _settings = settings;
        _sources = enabled
            .where(
              (id) =>
                  widget.sourceIds == null || widget.sourceIds!.contains(id),
            )
            .toList();
        _channels = [];
        _page = 0;
        _end = false;
        _loading = false;
      });
      if (_settings.showProgrammes && _settings.enableFullGuide) await _load();
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to load the guide'),
            action: SnackBarAction(label: 'Retry', onPressed: _reload),
          ),
        );
      }
    }
  }

  Future<void> _load() async {
    if (_loading || _end || _sources.isEmpty) return;
    final generation = _generation;
    setState(() => _loading = true);
    try {
      final page =
          await (widget.loadChannels ?? NativeBridge.instance.getChannels)(
            Filters(
              sourceIds: _sources,
              mediaTypes: [MediaType.livestream],
              viewType: widget.favorites ? ViewType.favorites : ViewType.all,
              groupId: widget.groupId,
              page: _page + 1,
            ),
          );
      if (!mounted || generation != _generation) return;
      final count = page.length;
      setState(() {
        final initial = widget.initialChannel;
        if (_initial &&
            initial != null &&
            _sources.contains(initial.sourceId)) {
          _channels.add(initial);
        }
        _initial = false;
        final ids = _channels.map((c) => c.id).toSet();
        _channels.addAll(page.where((c) => !ids.contains(c.id)));
        _page++;
        _end = count < 36;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        _end = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to load guide channels'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                _end = false;
                _load();
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _visible();
        });
      }
    }
  }

  void _visible() {
    if (!_scroll.hasClients || !mounted) return;
    final p = _scroll.position;
    final first = (p.pixels / _rowHeight).floor().clamp(0, _channels.length);
    final last = ((p.pixels + p.viewportDimension) / _rowHeight).ceil().clamp(
      first,
      _channels.length,
    );
    final visible = _channels.sublist(first, last);
    _visibleIds = visible.map((c) => c.id).toSet();
    _trimCache();
    _needed = visible
        .where((c) => !_data.containsKey(c.id) && !_errors.containsKey(c.id))
        .toList();
    _drain();
    if (p.extentAfter < p.viewportDimension * 0.25) _load();
  }

  void _trimCache() {
    final limit = math.max(32, _visibleIds.length);
    for (final id in _data.keys.toList()) {
      if (_data.length <= limit) break;
      if (!_visibleIds.contains(id)) _data.remove(id);
    }
  }

  Future<void> _drain() async {
    if (_busy || !_active || !mounted) return;
    _busy = true;
    try {
      while (mounted && _active && _needed.isNotEmpty) {
        final wait = 500 - (DateTime.now().millisecondsSinceEpoch - _lastStart);
        if (wait > 0) await Future<void>.delayed(Duration(milliseconds: wait));
        if (!mounted || !_active || _needed.isEmpty) break;
        final channel = _needed.removeAt(0);
        if (_data.containsKey(channel.id) || _errors.containsKey(channel.id)) {
          continue;
        }
        final generation = _scheduleGeneration;
        final from = _from;
        _lastStart = DateTime.now().millisecondsSinceEpoch;
        try {
          final result = await NativeBridge.instance.getSchedule(
            channel.id!,
            from,
            from + 6 * 3600,
          );
          if (!mounted || generation != _scheduleGeneration) continue;
          setState(() {
            _data[channel.id!] = result;
            _trimCache();
          });
        } catch (_) {
          if (mounted && generation == _scheduleGeneration) {
            setState(
              () => _errors[channel.id!] = 'Guide unavailable · tap to retry',
            );
          }
        }
      }
    } finally {
      _busy = false;
    }
  }

  void _window(int seconds) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final from = seconds == 0 ? (now ~/ 3600) * 3600 : _from + seconds;
    if (from < now - 7 * 86400 || from > now + 7 * 86400) return;
    setState(() {
      _from = from;
      _scheduleGeneration++;
      _data.clear();
      _errors.clear();
    });
    if (_horizontal.hasClients) _horizontal.jumpTo(0);
    _visible();
  }

  String _time(int seconds) {
    final d = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _programme(
    Channel channel,
    pb.Programme programme,
    pb.ProgrammeList schedule,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final canPlay =
        _settings.enableCatchup &&
        schedule.catchupSupported &&
        programme.catchupAvailable &&
        schedule.archiveDays > 0 &&
        programme.stop.toInt() <= now &&
        programme.start.toInt() >= now - schedule.archiveDays * 86400;
    final play = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(programme.title),
        content: Text(
          '${channel.name}\n${_time(programme.start.toInt())} – ${_time(programme.stop.toInt())}',
        ),
        actions: [
          if (Platform.isLinux && programme.stop.toInt() > now)
            TextButton.icon(
              icon: const Icon(Icons.fiber_manual_record_outlined),
              label: const Text('Record this program'),
              onPressed: () {
                Navigator.pop(context, false);
                toggleRecording(this.context, channel, programme: programme);
              },
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Close'),
          ),
          if (canPlay)
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Play catch-up'),
            ),
        ],
      ),
    );
    if (play != true || !mounted) return;
    try {
      final catchup = await NativeBridge.instance.getCatchup(
        channel.id!,
        programme.start.toInt(),
        programme.stop.toInt(),
      );
      catchup.name = '${channel.name} · ${programme.title}';
      if (mounted) await Playback.play(context, catchup, settings: _settings);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Catch-up is unavailable for this program'),
          ),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _active = _foreground && (ModalRoute.of(context)?.isCurrent ?? true);
    if (_active) {
      _visible();
    } else {
      _needed = [];
    }
  }

  void _libraryChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    MediaLibrary.instance.removeListener(_libraryChanged);
    WidgetsBinding.instance.removeObserver(this);
    _changes?.cancel();
    _scroll.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _active =
        _foreground &&
        (ModalRoute.isCurrentOf(context) ?? true) &&
        _settings.showProgrammes &&
        _settings.enableFullGuide;
    if (_active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _visible();
      });
    }
    final day = DateTime.fromMillisecondsSinceEpoch(_from * 1000);
    return PrimaryScrollController(
      controller: _scroll,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Program guide'),
          actions: [
            IconButton(
              tooltip: 'Previous six hours',
              onPressed: () => _window(-21600),
              icon: const Icon(Icons.chevron_left),
            ),
            TextButton(onPressed: () => _window(0), child: const Text('Now')),
            IconButton(
              tooltip: 'Next six hours',
              onPressed: () => _window(21600),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        body: !_settings.showProgrammes || !_settings.enableFullGuide
            ? const Center(child: Text('Enable the program guide in Settings'))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')} · swipe horizontally for later programs',
                    ),
                  ),
                  if (_loading) const LinearProgressIndicator(),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, space) {
                        final hourWidth = math.max(
                          _hourWidth,
                          (space.maxWidth - _nameWidth) / 6,
                        );
                        return SingleChildScrollView(
                          controller: _horizontal,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: math.max(
                              space.maxWidth,
                              _nameWidth + 6 * hourWidth,
                            ),
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 32,
                                  child: Row(
                                    children: [
                                      const SizedBox(width: _nameWidth),
                                      for (var h = 0; h < 6; h++)
                                        SizedBox(
                                          width: hourWidth,
                                          child: Text(_time(_from + h * 3600)),
                                        ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: _channels.isEmpty && !_loading
                                      ? const Center(
                                          child: Text('No live channels'),
                                        )
                                      : ListView.builder(
                                          primary: true,
                                          scrollCacheExtent:
                                              const ScrollCacheExtent.pixels(0),
                                          itemExtent: _rowHeight,
                                          itemCount: _channels.length,
                                          itemBuilder: (context, index) {
                                            final channel = _channels[index];
                                            final data = _data[channel.id];
                                            final error = _errors[channel.id];
                                            return Row(
                                              children: [
                                                SizedBox(
                                                  width: _nameWidth,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    child: Text(
                                                      channel.name,
                                                      maxLines: 3,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 6 * hourWidth,
                                                  height: _rowHeight,
                                                  child:
                                                      data == null ||
                                                          data
                                                              .programmes
                                                              .isEmpty
                                                      ? TextButton(
                                                          onPressed:
                                                              error == null
                                                              ? null
                                                              : () {
                                                                  setState(
                                                                    () => _errors
                                                                        .remove(
                                                                          channel
                                                                              .id,
                                                                        ),
                                                                  );
                                                                  _visible();
                                                                },
                                                          child: Text(
                                                            error ??
                                                                (data == null
                                                                    ? 'Loading…'
                                                                    : 'No program data'),
                                                          ),
                                                        )
                                                      : Stack(
                                                          children: [
                                                            for (final p
                                                                in data
                                                                    .programmes)
                                                              if (p.stop
                                                                          .toInt() >
                                                                      _from &&
                                                                  p.start
                                                                          .toInt() <
                                                                      _from +
                                                                          21600)
                                                                Positioned(
                                                                  left: math.max(
                                                                    0,
                                                                    (p.start.toInt() -
                                                                            _from) /
                                                                        3600 *
                                                                        hourWidth,
                                                                  ),
                                                                  top: 4,
                                                                  bottom: 4,
                                                                  width: math.max(
                                                                    2,
                                                                    (math.min(
                                                                              p.stop.toInt(),
                                                                              _from +
                                                                                  21600,
                                                                            ) -
                                                                            math.max(
                                                                              p.start.toInt(),
                                                                              _from,
                                                                            )) /
                                                                        3600 *
                                                                        hourWidth,
                                                                  ),
                                                                  child: Card(
                                                                    child: InkWell(
                                                                      onTap: () =>
                                                                          _programme(
                                                                            channel,
                                                                            p,
                                                                            data,
                                                                          ),
                                                                      child: Padding(
                                                                        padding:
                                                                            const EdgeInsets.all(
                                                                              8,
                                                                            ),
                                                                        child: Tooltip(
                                                                          message:
                                                                              '${_time(p.start.toInt())} – ${_time(p.stop.toInt())}\n${p.title}',
                                                                          child: Text.rich(
                                                                            TextSpan(
                                                                              children: [
                                                                                if (MediaLibrary.instance.recordings.any(
                                                                                  (
                                                                                    j,
                                                                                  ) =>
                                                                                      j.reserved &&
                                                                                      j.channelId ==
                                                                                          channel.id &&
                                                                                      j.title ==
                                                                                          p.title &&
                                                                                      j.start <=
                                                                                          p.start.toInt() &&
                                                                                      j.stop >=
                                                                                          p.stop.toInt(),
                                                                                ))
                                                                                  WidgetSpan(
                                                                                    child: Tooltip(
                                                                                      message: 'Scheduled recording',
                                                                                      child: Icon(
                                                                                        Icons.fiber_manual_record,
                                                                                        size: 12,
                                                                                        color: Theme.of(
                                                                                          context,
                                                                                        ).colorScheme.error,
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                TextSpan(
                                                                                  text: p.title,
                                                                                ),
                                                                              ],
                                                                            ),
                                                                            maxLines:
                                                                                2,
                                                                            overflow:
                                                                                TextOverflow.ellipsis,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                          ],
                                                        ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
