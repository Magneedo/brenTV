import 'dart:io';

import 'package:brentv/error.dart';
import 'package:brentv/models/channel.dart';
import 'package:brentv/models/custom_shortcut.dart';
import 'package:brentv/models/media_type.dart';
import 'package:brentv/playback/playback.dart';
import 'package:brentv/library/media_library.dart';
import 'package:brentv/library/download_queue.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A folder browser without indexing; iOS can prepare compatible MP4 copies.
class LocalMediaPage extends StatefulWidget {
  final Directory? rootDirectory;
  final bool embedded;
  final Listenable? refresh;
  final VoidCallback? onExit;
  final Future<void> Function(
    BuildContext context,
    Channel channel,
    List<Channel> siblings,
  )?
  onPlay;

  const LocalMediaPage({
    super.key,
    this.rootDirectory,
    this.embedded = false,
    this.refresh,
    this.onPlay,
    this.onExit,
  });

  @override
  State<LocalMediaPage> createState() => _LocalMediaPageState();
}

class _LocalMediaPageState extends State<LocalMediaPage> {
  static const _extensions = {
    'mp4',
    'mkv',
    'webm',
    'mov',
    'avi',
    'm4v',
    'mpeg',
    'mpg',
    'ts',
    'm2ts',
    'mts',
    'vob',
    'ogv',
    'ogm',
    'wmv',
    'flv',
    '3gp',
    'mp3',
    'm4a',
    'aac',
    'flac',
    'ogg',
    'oga',
    'opus',
    'wav',
    'aiff',
    'aif',
    'wma',
    'ape',
    'alac',
  };
  // Paths stay logical (root plus listed names), so a symlinked folder such
  // as Videos/Movies -> /mnt/media still goes Up to Videos.
  Directory? _root, _directory;
  String? _error, _playing, _focusPath;
  List<FileSystemEntity> _entries = [];
  bool _loading = true;
  int _generation = 0;

  String _name(FileSystemEntity entry) =>
      entry.path.split(Platform.pathSeparator).lastWhere((p) => p.isNotEmpty);
  String _label(String text) => text.replaceAll(RegExp(r'[\r\n\t]'), ' ');
  bool get _atRoot => _directory == null || _directory!.path == _root?.path;

  @override
  void initState() {
    super.initState();
    _initialize();
    widget.refresh?.addListener(_refresh);
  }

  @override
  void didUpdateWidget(LocalMediaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refresh != widget.refresh) {
      oldWidget.refresh?.removeListener(_refresh);
      widget.refresh?.addListener(_refresh);
    }
    if (oldWidget.rootDirectory?.path != widget.rootDirectory?.path) {
      _initialize();
    }
  }

  void _refresh() => _load(_directory);

  @override
  void dispose() {
    widget.refresh?.removeListener(_refresh);
    super.dispose();
  }

  void _initialize() {
    final home = Platform.environment['HOME'];
    final root =
        widget.rootDirectory ??
        (Platform.isLinux && home != null && home.isNotEmpty
            ? Directory('$home/Videos')
            : null);
    _root = root;
    _directory = _root;
    _load(_root);
  }

  Future<void> _load(Directory? directory) async {
    final generation = ++_generation;
    final root = _root;
    setState(() {
      _directory = directory;
      _entries = [];
      _error = null;
      _loading = true;
    });
    try {
      if (root == null || directory == null) {
        throw const FileSystemException('Local media unavailable');
      }
      final entries = <FileSystemEntity>[];
      // Links are listed as their targets; broken ones come back as Link.
      await for (final entry in directory.list(followLinks: true)) {
        if (!mounted || generation != _generation) return;
        final name = _name(entry);
        if (name.startsWith('.')) continue;
        if (entry is Directory ||
            (entry is File &&
                name.contains('.') &&
                _extensions.contains(name.split('.').last.toLowerCase()))) {
          entries.add(entry);
        }
      }
      entries.sort((a, b) {
        if ((a is Directory) != (b is Directory)) {
          return a is Directory ? -1 : 1;
        }
        final order = _name(a).toLowerCase().compareTo(_name(b).toLowerCase());
        return order == 0 ? _name(a).compareTo(_name(b)) : order;
      });
      if (!mounted || generation != _generation) return;
      setState(() {
        _entries = entries;
        _loading = false;
        if (!entries.any((e) => e.path == _focusPath)) _focusPath = null;
      });
    } on FileSystemException {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = root == null
            ? 'Local media is available on Linux in your Videos folder.'
            : 'This folder could not be read. Check that it exists and that you have access.';
      });
    }
  }

  void _back() {
    if (_atRoot) {
      if (widget.onExit != null) {
        widget.onExit!();
      } else {
        Navigator.of(context).maybePop();
      }
    } else {
      _focusPath = _directory!.path;
      _load(_directory!.parent);
    }
  }

  void _open(Directory folder) {
    _focusPath = null;
    _load(folder);
  }

  Channel _channel(File file) => Channel(
    name: _label(_name(file)),
    url: file.uri.toString(),
    mediaType: MediaType.movie,
    sourceId: 0,
    favorite: false,
  );

  Future<void> _play(File file) async {
    if (_playing != null) return;
    if (Platform.isIOS &&
        {
          'mkv',
          'avi',
          'webm',
          'mpeg',
          'mpg',
          'ts',
          'm2ts',
          'mts',
          'vob',
          'wmv',
          'flv',
          'ogv',
          'ogm',
        }.contains(file.path.split('.').last.toLowerCase())) {
      final mp4 = File(
        '${file.path.replaceFirst(RegExp(r'\.[^./]+$'), '')}.mp4',
      );
      if (await mp4.exists()) {
        file = mp4;
      } else {
        try {
          await MediaLibrary.instance.downloads.convertFile(file.path);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Preparing MP4. Keep brenTV open; progress is in the bottom corner. The MP4 replaces the original when it is ready.',
                ),
              ),
            );
          }
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  error is DownloadFailure
                      ? error.message
                      : 'Could not prepare this file. Check folder access and free space.',
                ),
              ),
            );
          }
        }
        return;
      }
    }
    final generation = _generation;
    setState(() => _playing = file.path);
    try {
      try {
        if (!await file.exists()) {
          throw const FileSystemException('Media file unavailable');
        }
        await (await file.open()).close();
      } on FileSystemException {
        if (mounted && generation == _generation) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not open this media file. It may have moved or access changed.',
              ),
            ),
          );
        }
        return;
      }
      if (!mounted || generation != _generation) return;
      final siblings = _entries.whereType<File>().map(_channel).toList();
      final selected =
          siblings.where((c) => c.url == file.uri.toString()).firstOrNull ??
          _channel(file);
      if (!siblings.any((c) => c.sameAs(selected))) siblings.add(selected);
      // Player errors show their own message, not the file-access one above.
      await Error.tryAsyncNoLoading(() async {
        if (widget.onPlay case final play?) {
          await play(context, selected, siblings);
        } else {
          await Playback.play(context, selected, siblings: siblings);
        }
        return null;
      }, context);
    } finally {
      if (mounted) setState(() => _playing = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final relative = _atRoot
        ? ''
        : _directory!.path.substring(_root!.path.length);
    return PageShortcuts(
      bindings: {
        const CustomShortcut(SingleActivator(LogicalKeyboardKey.escape)): _back,
        const CustomShortcut(SingleActivator(LogicalKeyboardKey.backspace)):
            _back,
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: widget.embedded && _atRoot
              ? null
              : BackButton(onPressed: _back),
          title: Text(widget.embedded ? 'Media' : 'Local media'),
          actions: [
            TextButton.icon(
              onPressed: _loading ? null : () => _load(_directory),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _atRoot || _loading
                          ? null
                          : () => _open(_root!),
                      child: Text(Platform.isIOS ? 'brenTV' : 'Videos'),
                    ),
                    Expanded(
                      child: Text(
                        _label(relative),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!_atRoot)
                      TextButton.icon(
                        onPressed: _loading ? null : _back,
                        icon: const Icon(Icons.arrow_upward),
                        label: const Text('Up'),
                      ),
                  ],
                ),
              ),
              Expanded(child: _content()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _load(_directory),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No media here yet.\nAdd videos or music to this folder, then refresh.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    // Each folder keeps its own scroll offset, so Up shows (and can focus)
    // the folder it came from even far down a long list.
    return ListView.builder(
      key: PageStorageKey(_directory?.path),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final folder = entry is Directory;
        return ListTile(
          key: ValueKey(entry.path),
          autofocus: _focusPath == null ? index == 0 : entry.path == _focusPath,
          leading: Icon(
            folder ? Icons.folder_outlined : Icons.play_circle_outline,
          ),
          title: Text(
            _label(_name(entry)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: folder ? const Icon(Icons.chevron_right) : null,
          onTap: folder
              ? () => _open(entry)
              : _playing != null
              ? null
              : () => _play(entry as File),
        );
      },
    );
  }
}
