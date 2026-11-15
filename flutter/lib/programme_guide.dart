import 'dart:async';

import 'package:flutter/material.dart';
import 'package:brentv/generated/generated_proto.pb.dart' as pb;
import 'package:brentv/models/channel.dart';
import 'package:brentv/models/media_type.dart';
import 'package:brentv/models/settings.dart';

bool guideEnabled(Channel channel, Settings settings, {bool player = false}) =>
    settings.showProgrammes &&
    (player ? settings.guidePlayerTitles : settings.guideTileText) &&
    channel.mediaType == MediaType.livestream &&
    channel.isPlayable &&
    ((channel.streamId ?? 0) > 0 ||
        (settings.enableXmltv && channel.epgId?.isNotEmpty == true));

/// When to ask the provider again: at the next programme change (at least a
/// minute apart, before the 10-minute display expiry), every 5 minutes for a
/// channel without listings, every 10 minutes when the source has no guide.
int nextRefresh(pb.NowNext data, int fetched) {
  if (!data.supported) return fetched + 600;
  final changes = [
    if (data.hasNow()) data.now.stop.toInt(),
    if (data.hasNext()) data.next.start.toInt(),
  ].where((t) => t > fetched);
  if (changes.isEmpty) return fetched + 300;
  return changes
      .reduce((a, b) => a < b ? a : b)
      .clamp(fetched + 60, fetched + 540);
}

class _GuideEntry {
  pb.NowNext? data;
  int fetched = 0, retryAt = 0;
}

/// One small cache and request scheduler per visible catalog route.
class ProgrammeGuide extends ChangeNotifier {
  final Future<pb.NowNext> Function(int) fetch;
  ProgrammeGuide(this.fetch);

  final Map<int, _GuideEntry> _cache = {};
  final Map<int, int> _sourceRetry = {};
  List<Channel> _visible = [];
  Timer? _timer;
  bool _active = false, _busy = false, _disposed = false;
  int _generation = 0, _nextFetch = 0;
  int _lastSecond = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  void setActive(bool active) {
    if (_active == active || _disposed) return;
    _active = active;
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (!_active || _disposed || _visible.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    int? deadline;
    void consider(int time) {
      if (deadline == null || time < deadline!) deadline = time;
    }

    for (final channel in _visible) {
      final entry = _cache[channel.id];
      if (!_busy) {
        var requestAt = (entry?.retryAt ?? 0) * 1000;
        final sourceAt = (_sourceRetry[channel.sourceId] ?? 0) * 1000;
        if (requestAt < sourceAt) requestAt = sourceAt;
        if (requestAt < _nextFetch) requestAt = _nextFetch;
        consider(requestAt);
      }
      final data = entry?.data;
      if (data == null) continue;
      for (final time in [
        if (data.hasNow()) data.now.start.toInt(),
        if (data.hasNow()) data.now.stop.toInt(),
        if (data.hasNext()) data.next.start.toInt(),
        if (data.hasNext()) data.next.stop.toInt(),
        entry!.fetched + 600,
      ]) {
        if (time * 1000 > now) consider(time * 1000);
      }
    }
    if (deadline != null) {
      // A timer also keeps notifications outside the current widget build.
      _timer = Timer(
        Duration(milliseconds: (deadline! - now).clamp(0, 1 << 31)),
        _tick,
      );
    }
  }

  void setVisible(Iterable<Channel> channels) {
    final visible = channels
        .where(
          (c) =>
              c.id != null &&
              c.mediaType == MediaType.livestream &&
              ((c.streamId ?? 0) > 0 || c.epgId?.isNotEmpty == true),
        )
        .take(128)
        .toList();
    final changed =
        visible.length != _visible.length ||
        Iterable<int>.generate(
          visible.length,
        ).any((i) => visible[i].id != _visible[i].id);
    _visible = visible;
    if (changed) _schedule();
  }

  void invalidate() {
    _generation++;
    _cache.clear();
    _sourceRetry.clear();
    _schedule();
    if (!_disposed) notifyListeners();
  }

  void _tick() {
    if (_disposed || !_active) return;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final boundary =
        now < _lastSecond ||
        _visible.any((c) {
          final entry = _cache[c.id];
          final data = entry?.data;
          if (data == null) return false;
          return [
                data.now.start,
                data.now.stop,
                data.next.start,
                data.next.stop,
              ].any((t) => t.toInt() > _lastSecond && t.toInt() <= now) ||
              (entry!.fetched + 600 > _lastSecond &&
                  entry.fetched + 600 <= now);
        });
    _lastSecond = now;
    if (boundary) notifyListeners();
    if (!_busy && DateTime.now().millisecondsSinceEpoch >= _nextFetch) {
      _request(now);
    }
    _schedule();
  }

  Future<void> _request(int now) async {
    Channel? channel;
    int? earliest;
    for (final c in _visible) {
      final retryAt = _cache[c.id]?.retryAt ?? 0;
      if (retryAt <= now &&
          (_sourceRetry[c.sourceId] ?? 0) <= now &&
          (earliest == null || retryAt < earliest)) {
        channel = c;
        earliest = retryAt;
      }
    }
    if (channel == null) return;
    _busy = true;
    _nextFetch = DateTime.now().millisecondsSinceEpoch + 500;
    final generation = _generation;
    final id = channel.id!;
    final entry = _cache[id] ?? _GuideEntry();
    if (_cache.length >= 128 && !_cache.containsKey(id)) {
      final visibleIds = _visible.map((c) => c.id).toSet();
      final oldest = _cache.keys.firstWhere(
        (key) => !visibleIds.contains(key),
        orElse: () => _cache.keys.first,
      );
      _cache.remove(oldest);
    }
    _cache[id] = entry;
    try {
      final data = await fetch(id);
      if (_disposed || generation != _generation) return;
      entry.data = data;
      entry.fetched = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      entry.retryAt = nextRefresh(data, entry.fetched);
    } catch (_) {
      if (_disposed || generation != _generation) return;
      final failedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      entry.retryAt = failedAt + 30;
      _sourceRetry[channel.sourceId] = failedAt + 30;
    } finally {
      _busy = false;
      _schedule();
    }
    if (!_disposed) notifyListeners();
  }

  (String?, String) describe(int? id) {
    final entry = _cache[id];
    final data = entry?.data;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (data == null || now >= entry!.fetched + 600) return (null, '');
    final programmes = [
      if (data.hasNow()) data.now,
      if (data.hasNext()) data.next,
    ];
    pb.Programme? current, next;
    for (final p in programmes) {
      if (p.start.toInt() <= now && now < p.stop.toInt()) current = p;
      if (p.start.toInt() > now && (next == null || p.start < next.start)) {
        next = p;
      }
    }
    String time(pb.Programme p) {
      final t = DateTime.fromMillisecondsSinceEpoch(p.start.toInt() * 1000);
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }

    final label =
        current?.title ??
        (next == null ? null : 'Next ${time(next)} · ${next.title}');
    return (
      label,
      [
        if (current != null) 'Now ${time(current)} · ${current.title}',
        if (next != null) 'Next ${time(next)} · ${next.title}',
      ].join('\n'),
    );
  }

  String playbackTitle(Channel channel) {
    final entry = _cache[channel.id];
    final data = entry?.data;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (data != null && now < entry!.fetched + 600) {
      for (final p in [
        if (data.hasNow()) data.now,
        if (data.hasNext()) data.next,
      ]) {
        if (p.start.toInt() <= now && now < p.stop.toInt()) {
          return '${channel.name} · ${p.title}';
        }
      }
    }
    return channel.name;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _visible = [];
    super.dispose();
  }
}

/// Updates only when this channel's programme changes; no extra focus target.
class ChannelProgramme extends StatefulWidget {
  final String name;
  final int? channelId;
  final ProgrammeGuide? guide;
  const ChannelProgramme({
    super.key,
    required this.name,
    this.channelId,
    this.guide,
  });

  @override
  State<ChannelProgramme> createState() => _ChannelProgrammeState();
}

class _ChannelProgrammeState extends State<ChannelProgramme> {
  (String?, String) _text = (null, '');
  (String?, String) get _current =>
      widget.guide?.describe(widget.channelId) ?? (null, '');

  @override
  void initState() {
    super.initState();
    _text = _current;
    widget.guide?.addListener(_update);
  }

  void _update() {
    final text = _current;
    if (text != _text && mounted) setState(() => _text = text);
  }

  @override
  void didUpdateWidget(ChannelProgramme oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.guide != widget.guide) {
      oldWidget.guide?.removeListener(_update);
      widget.guide?.addListener(_update);
    }
    _text = _current;
  }

  @override
  void dispose() {
    widget.guide?.removeListener(_update);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final programme = _text.$1;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.name,
          maxLines: programme == null ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (programme != null)
          Tooltip(
            message: _text.$2,
            child: Text(
              programme,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
