import 'package:flutter/material.dart';
import 'package:brentv/generated/generated_proto.pb.dart' as pb;
import 'package:brentv/models/media_type.dart';
import 'package:brentv/models/source.dart';
import 'package:brentv/models/source_type.dart';
import 'package:brentv/native_bridge.dart';
import 'package:brentv/error.dart';
import 'package:brentv/refresh_stats.dart';

class CategorySelection {
  final Map<int, Set<String>> listed = {};
  final Map<int, pb.CategoryMode> modes = {};
  CategorySelection(pb.CategoryList categories) {
    merge(categories);
  }
  void merge(pb.CategoryList categories) {
    modes.putIfAbsent(0, () => categories.liveMode);
    modes.putIfAbsent(1, () => categories.moviesMode);
    modes.putIfAbsent(2, () => categories.seriesMode);
    for (var i = 0; i < 3; i++) {
      listed.putIfAbsent(
        i,
        () => {
          for (final c in categories.categories.where(
            (c) => c.mediaType == i && c.listed,
          ))
            c.name,
        },
      );
    }
  }

  void toggle(int type, String name, bool selected) {
    if (selected) {
      listed[type]!.add(name);
    } else {
      listed[type]!.remove(name);
    }
  }
}

class CategoriesView extends StatefulWidget {
  final Source source;
  final bool offerRefreshAfterSave;
  const CategoriesView({
    super.key,
    required this.source,
    this.offerRefreshAfterSave = true,
  });
  @override
  State<CategoriesView> createState() => _CategoriesViewState();
}

class _CategoriesViewState extends State<CategoriesView> {
  pb.CategoryList? categories;
  CategorySelection? selection;
  String query = '';
  bool busy = false;
  List<int> get types => [
    if (widget.source.importLive) 0,
    if (widget.source.importMovies) 1,
    if (widget.source.importSeries) 2,
  ];
  @override
  void initState() {
    super.initState();
    load(false);
  }

  Future<void> load(bool provider) async {
    setState(() => busy = true);
    await Error.tryAsyncNoLoading(() async {
      final data = await (provider
          ? NativeBridge.instance.fetchSourceCategories(widget.source.id!)
          : NativeBridge.instance.getSourceCategories(widget.source.id!));
      if (!mounted) return;
      setState(() {
        selection ??= CategorySelection(data);
        selection!.merge(data);
        // Keep stored and unsaved selections even when absent at the provider.
        final merged = {
          for (final c in categories?.categories ?? <pb.Category>[])
            '${c.mediaType}\t${c.name}': c,
        };
        for (final c in data.categories) {
          merged['${c.mediaType}\t${c.name}'] = c;
        }
        categories = pb.CategoryList(categories: merged.values);
      });
    }, context);
    if (mounted) setState(() => busy = false);
  }

  Future<void> save() async {
    setState(() => busy = true);
    final result = await Error.tryAsyncNoLoading(() async {
      for (final type in types) {
        await NativeBridge.instance.setSourceCategories(
          widget.source.id!,
          MediaType.values[type],
          selection!.modes[type]!,
          selection!.listed[type]!,
        );
      }
    }, context);
    if (!mounted) return;
    setState(() => busy = false);
    if (!result.success) return;
    if (widget.offerRefreshAfterSave) {
      await offerRefresh(context, widget.source);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: types.length,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Category filters'),
        actions: [
          TextButton(
            onPressed: busy || selection == null ? null : save,
            child: const Text('Save'),
          ),
        ],
        bottom: types.isEmpty
            ? null
            : TabBar(tabs: [for (final t in types) Tab(text: mediaLabels[t])]),
      ),
      body: Column(
        children: [
          if (widget.source.sourceType == SourceType.xtream)
            TextButton.icon(
              onPressed: busy ? null : () => load(true),
              icon: const Icon(Icons.download),
              label: const Text('Load from provider'),
            ),
          if (busy) const LinearProgressIndicator(),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search categories',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => query = value.toLowerCase()),
          ),
          if (types.isEmpty)
            const Text('Enable a media type in the source settings first.'),
          if (selection != null && types.isNotEmpty)
            Expanded(
              child: TabBarView(children: [for (final t in types) typeView(t)]),
            ),
        ],
      ),
    ),
  );
  Future<void> addCategory(int type) async {
    var name = '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add category name'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Exact provider category name',
          ),
          onChanged: (value) => name = value.trim(),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, name),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (!mounted || result == null || result.isEmpty) return;
    setState(() {
      if (!categories!.categories.any(
        (c) => c.mediaType == type && c.name == result,
      )) {
        categories!.categories.add(pb.Category(mediaType: type, name: result));
      }
      selection!.toggle(type, result, true);
    });
  }

  Widget typeView(int type) {
    final all =
        categories!.categories.where((c) => c.mediaType == type).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final visible = all
        .where((c) => c.name.toLowerCase().contains(query))
        .toList();
    return Column(
      children: [
        DropdownButton<pb.CategoryMode>(
          isExpanded: true,
          value: selection!.modes[type],
          items: const [
            DropdownMenuItem(
              value: pb.CategoryMode.CATEGORY_MODE_EXCLUDE,
              child: Text('Exclude selected'),
            ),
            DropdownMenuItem(
              value: pb.CategoryMode.CATEGORY_MODE_INCLUDE,
              child: Text('Only import selected'),
            ),
          ],
          onChanged: busy
              ? null
              : (value) => setState(() => selection!.modes[type] = value!),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(
                      () => selection!.listed[type] = all
                          .map((c) => c.name)
                          .toSet(),
                    ),
              child: const Text('Select all'),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() => selection!.listed[type]!.clear()),
              child: const Text('Select none'),
            ),
            TextButton(
              onPressed: busy ? null : () => addCategory(type),
              child: const Text('Add name…'),
            ),
          ],
        ),
        Expanded(
          child: ListView.builder(
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final c = visible[index];
              return CheckboxListTile(
                title: Text(c.name),
                subtitle: Text(
                  c.hasStreamCount()
                      ? '${c.streamCount} streams'
                      : 'Stream count unknown',
                ),
                value: selection!.listed[type]!.contains(c.name),
                onChanged: busy
                    ? null
                    : (value) => setState(
                        () => selection!.toggle(type, c.name, value!),
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}
