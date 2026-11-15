import 'package:flutter/material.dart';
import 'package:brentv/models/channel.dart';
import 'package:brentv/models/filters.dart';
import 'package:brentv/models/media_type.dart';
import 'package:brentv/models/view_type.dart';
import 'package:brentv/native_bridge.dart';

class HiddenItems extends StatefulWidget {
  const HiddenItems({super.key});
  @override
  State<HiddenItems> createState() => _HiddenItemsState();
}

class _HiddenItemsState extends State<HiddenItems> {
  List<Channel> _items = [];
  bool _groups = false, _loading = false, _end = false;
  int _page = 0, _generation = 0;
  List<int> _sources = [];
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _scroll.addListener(_more);
    _load();
  }

  void _more() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 200) {
      _load(more: true);
    }
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_loading || _end)) return;
    final generation = more ? _generation : ++_generation;
    final page = more ? _page + 1 : 1;
    setState(() {
      _loading = true;
      if (!more) {
        _items = [];
        _end = false;
      }
    });
    try {
      if (!more) {
        _sources = (await NativeBridge.instance.getSources())
            .map((s) => s.id!)
            .toList();
      }
      final items = await NativeBridge.instance.getChannels(
        Filters(
          sourceIds: _sources,
          mediaTypes: [MediaType.livestream, MediaType.movie, MediaType.serie],
          viewType: _groups ? ViewType.categories : ViewType.all,
          page: page,
          hiddenOnly: true,
          includeHidden: true,
        ),
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = more ? [..._items, ...items] : items;
        _page = page;
        _end = items.length < 36;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        _end = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load hidden items')),
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _more();
        });
      }
    }
  }

  Future<void> _restore(Channel item) async {
    try {
      await NativeBridge.instance.setHidden(item.id!, false, group: _groups);
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to restore this item')),
        );
      }
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Hidden items'),
      actions: [
        TextButton(
          onPressed: _loading
              ? null
              : () async {
                  try {
                    await NativeBridge.instance.restoreAllHidden();
                    if (mounted) await _load();
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Unable to restore hidden items'),
                        ),
                      );
                    }
                  }
                },
          child: const Text('Restore all'),
        ),
      ],
    ),
    body: Column(
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Channels')),
            ButtonSegment(value: true, label: Text('Categories')),
          ],
          selected: {_groups},
          onSelectionChanged: (v) {
            setState(() => _groups = v.first);
            _load();
          },
        ),
        if (_loading) const LinearProgressIndicator(),
        Expanded(
          child: _items.isEmpty && !_loading
              ? const Center(child: Text('No hidden items'))
              : ListView.builder(
                  controller: _scroll,
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return ListTile(
                      title: Text(item.name),
                      subtitle: !_groups && !item.hidden
                          ? const Text(
                              'Hidden by its category · restore the category',
                            )
                          : null,
                      trailing: TextButton(
                        onPressed: _loading || (!_groups && !item.hidden)
                            ? null
                            : () => _restore(item),
                        child: const Text('Restore'),
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}
