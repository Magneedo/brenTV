import 'dart:io';
import 'package:flutter/material.dart';
import 'package:brentv/models/channel.dart';
import 'package:brentv/models/media_type.dart';
import 'package:brentv/models/view_type.dart';
import 'package:brentv/confirm_delete.dart';
import 'package:brentv/theme.dart';
import 'package:brentv/playback/playback.dart';
import 'package:brentv/native_bridge.dart';
import 'package:brentv/models/filters.dart';
import 'media_library.dart';
import 'models.dart';
import 'download_queue.dart';
import 'recording_ui.dart';

Future<void> downloadVideo(BuildContext context, Channel channel) async {
  if (channel.id == null ||
      !channel.isPlayable ||
      channel.mediaType == MediaType.livestream) {
    return;
  }
  try {
    final library = MediaLibrary.instance;
    final data = await library.info(channel.id!);
    final uri = Uri.parse(data.channel.url);
    if (uri.path.toLowerCase().endsWith('.m3u8')) {
      throw const DownloadFailure(
        'Downloads need a direct video file. HLS playlists cannot be saved as a single resumable file.',
      );
    }
    final job = DownloadJob(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: channel.name,
      channelId: channel.id!,
      sourceId: channel.sourceId,
      identity: data.identity,
      file: downloadFilename(
        channel.name,
        data.channel.url,
        library.preferences,
        show: data.showName.isNotEmpty
            ? data.showName
            : (channel.mediaType == MediaType.serie ? channel.name : ''),
        season: data.season,
        episode: data.episode,
        mp4: Platform.isIOS,
      ),
    );
    await library.downloads.add(job);
    final added = await library.firstUse(ViewType.downloads);
    if (context.mounted) {
      libraryMessage(
        context,
        added
            ? 'Downloads added to the bottom bar — change in Settings > Appearance'
            : 'Added to Downloads.',
      );
    }
  } catch (e) {
    if (context.mounted) {
      libraryMessage(
        context,
        e is DownloadFailure
            ? e.message
            : 'Could not add this download. Check the source and try again.',
      );
    }
  }
}

Future<Channel> offlineChannel(Channel channel) async {
  final jobs = MediaLibrary.instance.downloads.jobs.where(
    (j) =>
        j.channelId == channel.id &&
        j.sourceId == channel.sourceId &&
        j.offlineFile != null,
  );
  for (final job in jobs) {
    if (await File(job.offlineFile!).exists()) {
      return Channel(
        name: channel.name,
        url: File(job.offlineFile!).uri.toString(),
        mediaType: channel.mediaType,
        sourceId: 0,
        favorite: false,
      );
    }
  }
  return channel;
}

String byteLabel(num bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}

class DownloadControl extends StatelessWidget {
  final Channel channel;
  const DownloadControl({super.key, required this.channel});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: MediaLibrary.instance.downloads,
    builder: (context, _) {
      final downloaded = MediaLibrary.instance.downloads.jobs.any(
        (j) =>
            j.channelId == channel.id &&
            j.sourceId == channel.sourceId &&
            j.offlineFile != null &&
            File(j.offlineFile!).existsSync(),
      );
      return IconButton(
        tooltip: downloaded
            ? 'Downloaded · Play watches offline'
            : 'Download video',
        onPressed: downloaded ? null : () => downloadVideo(context, channel),
        icon: Icon(
          downloaded ? Icons.download_done : Icons.download_outlined,
          size: 20,
        ),
      );
    },
  );
}

class DownloadsPage extends StatelessWidget {
  final bool activeOnly;
  const DownloadsPage({super.key, this.activeOnly = false});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Downloads')),
    body: ListenableBuilder(
      listenable: MediaLibrary.instance.downloads,
      builder: (context, _) {
        final queue = MediaLibrary.instance.downloads;
        if (queue.storageError != null) {
          return Center(child: Text(queue.storageError!));
        }
        if (activeOnly &&
            !queue.jobs.any(
              (j) =>
                  j.state != DownloadState.completed &&
                  j.state != DownloadState.canceled,
            )) {
          return const Center(
            child: Text('All downloads finished. Your files are in Media.'),
          );
        }
        if (queue.jobs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Save movies and episodes to watch offline.\n\nUse Download on a movie or episode, or Download season in a series.\nPause and resume here; the queue survives app restarts.\nCompleted videos play from your Movies and Series folders.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final sections =
            [
              (
                'In progress',
                {
                  DownloadState.downloading,
                  DownloadState.converting,
                  DownloadState.paused,
                },
              ),
              ('Queued', {DownloadState.queued}),
              ('Failed', {DownloadState.failed}),
              if (!activeOnly) ('Completed', {DownloadState.completed}),
            ].map(
              (section) => (
                section.$1,
                queue.jobs.where((j) => section.$2.contains(j.state)).toList(),
              ),
            );
        return CustomScrollView(
          slivers: [
            for (final (title, jobs) in sections)
              if (jobs.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                SliverList.builder(
                  itemCount: jobs.length,
                  itemBuilder: (context, index) {
                    final job = jobs[index];
                    return Card(
                      key: ValueKey(job.id),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(job.title),
                            if (job.state == DownloadState.downloading ||
                                job.state == DownloadState.paused) ...[
                              LinearProgressIndicator(
                                value: job.total > 0
                                    ? (job.bytes / job.total).clamp(0.0, 1.0)
                                    : null,
                              ),
                              Text(
                                '${byteLabel(job.bytes)} / ${job.total > 0 ? byteLabel(job.total) : "checking size"} · ${byteLabel(job.speed)}/s${job.eta == null ? '' : ' · ${job.eta! ~/ 60}m ${job.eta! % 60}s left'}',
                              ),
                            ],
                            if (job.state == DownloadState.converting) ...[
                              LinearProgressIndicator(
                                value: job.conversionProgress,
                              ),
                              Text(
                                'Preparing MP4${job.conversionProgress == null ? '' : ' · ${(job.conversionProgress! * 100).floor()}%'}',
                              ),
                              const Text(
                                'Keep brenTV open. The original is removed once the MP4 is ready.',
                              ),
                            ],
                            if (job.error != null) Text(job.error!),
                            if (job.state == DownloadState.queued)
                              const Text(
                                'Waiting for a download slot or a provider connection',
                              ),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (job.state == DownloadState.downloading ||
                                    job.state == DownloadState.converting)
                                  TextButton.icon(
                                    onPressed: () => _action(
                                      context,
                                      () => queue.pause(job),
                                    ),
                                    icon: const Icon(Icons.pause),
                                    label: const Text('Pause'),
                                  ),
                                if (job.state == DownloadState.paused ||
                                    job.state == DownloadState.failed)
                                  TextButton.icon(
                                    onPressed: () => _action(
                                      context,
                                      () => queue.resume(job),
                                    ),
                                    icon: const Icon(Icons.play_arrow),
                                    label: Text(
                                      job.state == DownloadState.failed
                                          ? 'Retry'
                                          : 'Resume',
                                    ),
                                  ),
                                if (job.state == DownloadState.queued) ...[
                                  IconButton(
                                    tooltip: 'Move up in queue',
                                    onPressed: () => _action(
                                      context,
                                      () => queue.move(job, -1),
                                    ),
                                    icon: const Icon(Icons.arrow_upward),
                                  ),
                                  IconButton(
                                    tooltip: 'Move down in queue',
                                    onPressed: () => _action(
                                      context,
                                      () => queue.move(job, 1),
                                    ),
                                    icon: const Icon(Icons.arrow_downward),
                                  ),
                                ],
                                if (job.state == DownloadState.completed)
                                  TextButton.icon(
                                    onPressed: () async {
                                      if (!await File(job.file).exists()) {
                                        if (context.mounted) {
                                          libraryMessage(
                                            context,
                                            'This video has moved or been deleted.',
                                          );
                                        }
                                        return;
                                      }
                                      if (context.mounted) {
                                        await Playback.play(
                                          context,
                                          Channel(
                                            name: job.title,
                                            url: File(job.file).uri.toString(),
                                            mediaType: MediaType.movie,
                                            sourceId: 0,
                                            favorite: false,
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('Play offline'),
                                  ),
                                if (job.state == DownloadState.completed)
                                  TextButton.icon(
                                    onPressed: () => openMediaFolder(
                                      context,
                                      File(job.file).parent.path,
                                    ),
                                    icon: const Icon(Icons.folder_open),
                                    label: const Text('Open folder'),
                                  ),
                                TextButton.icon(
                                  onPressed: () {
                                    if (job.state != DownloadState.completed &&
                                        (!job.readyToConvert ||
                                            (job.conversionSource != null &&
                                                !job.conversionSourceIsPartial))) {
                                      _action(context, () => queue.cancel(job));
                                      return;
                                    }
                                    showDialog(
                                      context: context,
                                      builder: (c) => ConfirmDelete(
                                        name: job.title,
                                        type: 'download',
                                        confirm: () => _action(
                                          context,
                                          () => queue.cancel(
                                            job,
                                            deleteCompleted:
                                                job.state ==
                                                DownloadState.completed,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                  label: Text(
                                    job.state == DownloadState.completed
                                        ? 'Delete'
                                        : 'Cancel',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
          ],
        );
      },
    ),
  );
  Future<void> _action(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        libraryMessage(
          context,
          'Could not update this download. Check folder access and available disk space.',
        );
      }
    }
  }
}

Future<void> downloadSeason(BuildContext context, Channel season) async {
  try {
    final episodes = await NativeBridge.instance.getAllChannels(
      Filters(
        viewType: ViewType.all,
        sourceIds: [season.sourceId],
        seriesId: season.seriesId,
        seasonId: season.id,
        mediaTypes: [MediaType.serie],
      ),
    );
    if (!context.mounted) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Download ${season.name}?'),
        content: Text('Queue ${episodes.length} episodes for offline viewing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Download season'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    final library = MediaLibrary.instance;
    var count = 0, failed = 0;
    for (final episode in episodes) {
      if (library.downloads.jobs.any(
        (j) => j.channelId == episode.id && j.sourceId == episode.sourceId,
      )) {
        continue;
      }
      try {
        final data = await library.info(episode.id!);
        if (Uri.parse(data.channel.url).path.endsWith('.m3u8')) {
          throw const DownloadFailure('HLS playlist');
        }
        await library.downloads.add(
          DownloadJob(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            title: episode.name,
            channelId: episode.id!,
            sourceId: episode.sourceId,
            identity: data.identity,
            file: downloadFilename(
              episode.name,
              data.channel.url,
              library.preferences,
              show: data.showName,
              season: data.season,
              episode: data.episode,
              mp4: Platform.isIOS,
            ),
          ),
        );
        count++;
      } catch (_) {
        failed++;
      }
    }
    final added = count > 0 && await library.firstUse(ViewType.downloads);
    if (context.mounted) {
      libraryMessage(
        context,
        '${added ? 'Downloads added to the bottom bar — change in Settings > Appearance. ' : ''}$count episodes queued${failed == 0 ? '' : '; $failed could not be added'}.',
      );
    }
  } catch (_) {
    if (context.mounted) {
      libraryMessage(
        context,
        'Could not load episodes for this season. Try opening the series first.',
      );
    }
  }
}

/// A compact queue control; completed files are browsed from Media.
class DownloadProgressIndicator extends StatelessWidget {
  final VoidCallback onOpen;
  const DownloadProgressIndicator({super.key, required this.onOpen});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: MediaLibrary.instance.downloads,
    builder: (context, _) {
      final jobs = MediaLibrary.instance.downloads.jobs
          .where(
            (j) =>
                j.state != DownloadState.completed &&
                j.state != DownloadState.canceled,
          )
          .toList();
      if (jobs.isEmpty) return const SizedBox.shrink();
      final bytes = jobs.fold<int>(0, (sum, j) => sum + j.bytes);
      final total = jobs.fold<int>(0, (sum, j) => sum + j.total);
      final converting = jobs.any((j) => j.state == DownloadState.converting);
      final value = !converting && total > 0 && jobs.every((j) => j.total > 0)
          ? (bytes / total).clamp(0.0, 1.0)
          : null;
      final failed = jobs.any((j) => j.state == DownloadState.failed);
      return Material(
        elevation: 6,
        borderRadius: cornerRadius(context, 12),
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: failed
                      ? const Icon(Icons.error_outline, size: 22)
                      : CircularProgressIndicator(value: value, strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  failed
                      ? 'Download needs attention'
                      : converting
                      ? 'Preparing MP4'
                      : '${jobs.length} download${jobs.length == 1 ? '' : 's'}${value == null ? '' : ' · ${(value * 100).floor()}%'}',
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
