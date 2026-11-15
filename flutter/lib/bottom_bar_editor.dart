import 'dart:io';
import 'package:flutter/material.dart';
import 'bottom_nav.dart';
import 'models/bottom_bar.dart';
import 'models/view_type.dart';
import 'native_bridge.dart';

class BottomBarEditor extends StatefulWidget {
  final BottomBarConfig configuration;
  const BottomBarEditor({super.key, required this.configuration});
  @override
  State<BottomBarEditor> createState() => _BottomBarEditorState();
}

class _BottomBarEditorState extends State<BottomBarEditor> {
  late List<BottomBarPage> pages = [...widget.configuration.pages];
  bool saving = false;
  void move(int from, int to) => setState(() {
    pages.insert(to, pages.removeAt(from));
  });
  Future<void> save() async {
    setState(() => saving = true);
    try {
      await NativeBridge.instance.setBottomBar(BottomBarConfig(pages));
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the bottom bar. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Bottom bar'),
      actions: [
        TextButton(onPressed: saving ? null : save, child: const Text('Save')),
      ],
    ),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Drag pages or use Move up / Move down. Settings stays last. Keep at least one other page visible.',
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: pages.length,
            onReorderItem: (from, to) {
              if (saving || from == pages.length - 1) return;
              move(from, to.clamp(0, pages.length - 2));
            },
            itemBuilder: (context, i) {
              final entry = pages[i];
              final pinned = entry.page == ViewType.settings;
              final supported =
                  Platform.isLinux ||
                  ![ViewType.recordings].contains(entry.page);
              final lastVisible =
                  entry.visible &&
                  BottomBarConfig(pages)
                          .visiblePages()
                          .where((p) => p != ViewType.settings)
                          .length <=
                      1;
              return ListTile(
                key: ValueKey(entry.page),
                leading: Icon(pageIcon(entry.page)),
                title: Text(viewTypeToString(entry.page)),
                subtitle: !supported
                    ? const Text('Available on Linux')
                    : pinned
                    ? const Text('Always visible')
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Move up',
                      onPressed: saving || pinned || i == 0
                          ? null
                          : () => move(i, i - 1),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: 'Move down',
                      onPressed: saving || pinned || i >= pages.length - 2
                          ? null
                          : () => move(i, i + 1),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                    Switch(
                      value: entry.visible && supported,
                      onChanged: saving || pinned || !supported || lastVisible
                          ? null
                          : (v) => setState(
                              () => pages[i] = BottomBarPage(entry.page, v),
                            ),
                    ),
                    if (!pinned)
                      ReorderableDragStartListener(
                        index: i,
                        child: const Icon(Icons.drag_handle),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        TextButton(
          onPressed: saving
              ? null
              : () => setState(
                  () => pages = [...BottomBarConfig.defaults().pages],
                ),
          child: const Text('Reset to default'),
        ),
      ],
    ),
  );
}
