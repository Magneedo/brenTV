import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:brentv/local_media.dart';
import 'media_library.dart';
import 'models.dart';

/// One local library, refreshed when completed downloads become playable files.
class MediaPage extends StatefulWidget {
  final Directory? rootDirectory;
  final VoidCallback? onExit;
  const MediaPage({super.key, this.rootDirectory, this.onExit});
  @override
  State<MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends State<MediaPage> {
  final _refresh = ValueNotifier(0);
  late String _completed;
  late final Future<Directory> _root = widget.rootDirectory != null
      ? Future.value(widget.rootDirectory!)
      : Platform.isIOS
      ? getApplicationDocumentsDirectory()
      : Future.value(Directory('${Platform.environment['HOME']}/Videos'));

  String get _signature => MediaLibrary.instance.downloads.jobs
      .where((j) => j.state == DownloadState.completed)
      .map((j) => j.id)
      .join('|');

  @override
  void initState() {
    super.initState();
    _completed = _signature;
    MediaLibrary.instance.downloads.addListener(_changed);
  }

  void _changed() {
    final completed = _signature;
    if (completed != _completed) {
      _completed = completed;
      _refresh.value++;
    }
  }

  @override
  void dispose() {
    MediaLibrary.instance.downloads.removeListener(_changed);
    _refresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Directory>(
    future: _root,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Scaffold(
          body: Center(child: Text('Could not open your media folder.')),
        );
      }
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return LocalMediaPage(
        rootDirectory: snapshot.data,
        embedded: true,
        refresh: _refresh,
        onExit: widget.onExit,
      );
    },
  );
}
