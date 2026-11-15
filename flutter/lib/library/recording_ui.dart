import 'dart:io';
import 'package:flutter/material.dart';
import 'package:brentv/generated/generated_proto.pb.dart' as pb;
import 'package:brentv/models/channel.dart';
import 'package:brentv/models/media_type.dart';
import 'package:brentv/models/view_type.dart';
import 'package:brentv/confirm_delete.dart';
import 'package:brentv/playback/playback.dart';
import 'package:brentv/native_bridge.dart';
import 'media_library.dart';
import 'models.dart';

void libraryMessage(BuildContext context, String text) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

Future<void> showMediaTip(BuildContext context, String feature) async {
  if (!Platform.isLinux && feature == 'recording') return;
  final library = MediaLibrary.instance;
  if (!library.initialized ||
      library.preferences.dismissedTips.contains(feature)) {
    return;
  }
  library.preferences.dismissedTips.add(feature);
  // Someone who already records or downloads does not need the introduction.
  if (library.preferences.usedFeatures.contains(
    feature == 'recording' ? 'recordings' : 'downloads',
  )) {
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(feature == 'recording' ? 'Record live TV' : 'Watch offline'),
      content: Text(
        feature == 'recording'
            ? 'Press R to record what you are watching, or pick a show in the guide to record it later. Keep brenTV open while it records.'
            : 'Use Download on a movie or episode, or Download season. Pause and resume from Downloads; completed videos play offline.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
  await library.savePreferences();
}

Future<int?> recordingDuration(BuildContext context, Channel channel) async {
  final choice = await showDialog<int>(
    context: context,
    builder: (c) => SimpleDialog(
      title: const Text('Record now'),
      children: [
        for (final option in [
          (30, '30 minutes'),
          (60, '1 hour'),
          (120, '2 hours'),
          (-1, 'Until program ends'),
          (-2, 'Custom duration…'),
        ])
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, option.$1),
            child: Text(option.$2),
          ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return null;
  if (choice > 0) return unixNow + choice * 60;
  if (choice == -1) {
    try {
      final data = await NativeBridge.instance.getNowNext(channel.id!);
      if (data.hasNow() && data.now.stop.toInt() > unixNow) {
        return data.now.stop.toInt();
      }
    } catch (_) {
      /* No usable EPG. */
    }
    if (context.mounted) {
      libraryMessage(
        context,
        'No current program end time is available. Choose a duration.',
      );
    }
    return null;
  }
  final controller = TextEditingController(text: '90');
  final minutes = await showDialog<int>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Recording duration'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Minutes (1–1440)'),
        onSubmitted: (text) {
          final n = int.tryParse(text);
          if (n != null && n >= 1 && n <= 1440) Navigator.pop(c, n);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final n = int.tryParse(controller.text);
            if (n != null && n >= 1 && n <= 1440) Navigator.pop(c, n);
          },
          child: const Text('Record'),
        ),
      ],
    ),
  );
  // Dispose after the dialog's route animation has released its TextField.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  controller.dispose();
  return minutes == null ? null : unixNow + minutes * 60;
}

Future<void> toggleRecording(
  BuildContext context,
  Channel channel, {
  pb.Programme? programme,
  int? stopAt,
}) async {
  if (!Platform.isLinux ||
      channel.mediaType != MediaType.livestream ||
      channel.id == null) {
    return;
  }
  final library = MediaLibrary.instance;
  // The caller may be a player control that hides while a dialog is open.
  context = Navigator.of(context, rootNavigator: true).context;
  try {
    final current = library.recordingFor(channel);
    if (current != null && programme == null) {
      await library.stopRecording(current);
      return;
    }
    if (!await library.ffmpegAvailable()) {
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('ffmpeg is required to record'),
            content: const SelectableText(
              'Install ffmpeg, then try again:\n\npacman -S ffmpeg',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;
    final stop =
        programme?.stop.toInt() ??
        stopAt ??
        await recordingDuration(context, channel);
    if (stop == null || !context.mounted) return;
    final data = await library.info(channel.id!);
    if (!context.mounted) return;
    final start = programme?.start.toInt() ?? unixNow;
    final times = programme == null
        ? (start, stop)
        : RecordingJob.padded(
            start,
            stop,
            library.preferences.paddingBefore,
            library.preferences.paddingAfter,
          );
    final job = RecordingJob(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      channelId: channel.id!,
      sourceId: channel.sourceId,
      channelName: channel.name,
      title: programme?.title ?? 'Live TV',
      identity: data.identity,
      start: times.$1,
      stop: times.$2,
      maxConnections: data.maxConnections.clamp(1, 64),
    );
    if (library.recordings.any(
      (j) =>
          j.channelId == job.channelId &&
          j.title == job.title &&
          j.start == job.start &&
          j.reserved,
    )) {
      libraryMessage(context, 'This program is already scheduled.');
      return;
    }
    while (job.conflicts(library.recordings).isNotEmpty) {
      final conflicts = job.conflicts(library.recordings);
      final cancel = await showDialog<RecordingJob>(
        context: context,
        builder: (c) => SimpleDialog(
          title: Text('Provider limit: ${job.maxConnections} connection(s)'),
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'These recordings overlap. Cancel one to make room, or keep your existing schedule.',
              ),
            ),
            for (final conflict in conflicts)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(c, conflict),
                child: Text(
                  'Cancel ${conflict.channelName} · ${conflict.title}',
                ),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c),
              child: const Text('Keep existing schedule'),
            ),
          ],
        ),
      );
      if (cancel == null) return;
      await library.stopRecording(cancel);
      if (!context.mounted) return;
    }
    if (job.start <= unixNow) {
      await library.downloads.yieldConnections(
        job.sourceId,
        (library.connections(job.sourceId) + 1 - job.maxConnections).clamp(
          0,
          64,
        ),
      );
    }
    if (!context.mounted) return;
    var fromPlayer = false;
    if (job.start <= unixNow &&
        library.connections(job.sourceId) >= job.maxConnections) {
      if (library.playing?.id == job.channelId &&
          library.playerRecord != null) {
        // The player saves the stream it is showing; nothing to free.
        fromPlayer = true;
      } else if (library.playing?.sourceId == job.sourceId &&
          library.closePlayer != null) {
        final close = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Provider connection limit'),
            content: const Text(
              'Close the player to free a connection for this recording? The recording will continue in DVR.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Close player and record'),
              ),
            ],
          ),
        );
        if (close != true) return;
        await library.closePlayer!();
        library.playing = null;
      } else {
        libraryMessage(
          context,
          'Provider connection limit reached. Stop another transfer and try again.',
        );
        return;
      }
    }
    await library.addRecording(job);
    final enabled = await library.firstUse(ViewType.recordings);
    if (context.mounted) {
      libraryMessage(
        context,
        enabled
            ? 'DVR added to the bottom bar — change in Settings > Appearance'
            : fromPlayer
            ? 'Recording what you are watching. It ends if you change channel or close the player.'
            : job.start <= unixNow
            ? 'Recording. It continues if you close the player.'
            : 'Recording scheduled. Keep brenTV open.',
      );
    }
  } catch (_) {
    if (context.mounted) {
      libraryMessage(
        context,
        'Could not save this recording. Check the destination and available disk space.',
      );
    }
  }
}

/// All playback entry points reserve a provider connection here, including
/// channel changes inside either Linux player. Existing recordings stop only
/// after an explicit user choice.
Future<bool> prepareLibraryPlayback(
  BuildContext context,
  Channel channel,
) async {
  final library = MediaLibrary.instance;
  if (!library.initialized || channel.isLocal) {
    library.playing = null;
    return true;
  }
  try {
    var limit = library.limits[channel.sourceId] ?? 1;
    final scheme = Uri.tryParse(channel.url ?? '')?.scheme;
    if (!library.limits.containsKey(channel.sourceId) &&
        channel.id != null &&
        (scheme == 'http' || scheme == 'https')) {
      limit = (await library.info(channel.id!)).maxConnections;
    }
    if (!context.mounted) return false;
    await library.downloads.yieldConnections(
      channel.sourceId,
      (library.connections(channel.sourceId, includePlayer: false) + 1 - limit)
          .clamp(0, 64),
    );
    if (!context.mounted) return false;
    while (library.connections(channel.sourceId, includePlayer: false) >=
        limit) {
      final jobs = library.activeRecordings
          .where((j) => j.sourceId == channel.sourceId)
          .toList();
      final stop = await showDialog<RecordingJob>(
        context: context,
        builder: (c) => SimpleDialog(
          title: const Text('Provider connection limit'),
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Playback needs another connection. Choose a recording to stop, or cancel playback.',
              ),
            ),
            for (final j in jobs)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(c, j),
                child: Text('Stop ${j.channelName} · ${j.title}'),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel playback'),
            ),
          ],
        ),
      );
      if (stop == null) return false;
      await library.stopRecording(stop);
      if (!context.mounted) return false;
    }
    library.playing = channel;
    return true;
  } catch (_) {
    if (context.mounted) {
      libraryMessage(
        context,
        'Could not check the source connection limit. Try again.',
      );
    }
    return false;
  }
}

class RecordControl extends StatelessWidget {
  final Channel channel;
  const RecordControl({super.key, required this.channel});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: MediaLibrary.instance,
    builder: (context, _) {
      final job = MediaLibrary.instance.recordingFor(channel);
      final elapsed = job == null ? 0 : unixNow - (job.actualStart ?? unixNow);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: job == null ? 'Record now (R)' : 'Stop recording (R)',
            onPressed: () => toggleRecording(context, channel),
            icon: Icon(
              job == null
                  ? Icons.fiber_manual_record_outlined
                  : Icons.stop_circle,
              // Sized and colored like the player's other controls.
              size: 32,
              color: job == null
                  ? Colors.white
                  : Theme.of(context).colorScheme.error,
            ),
          ),
          if (job != null)
            Text(
              '● ${two(elapsed ~/ 60)}:${two(elapsed % 60)}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      );
    },
  );
}

class RecordingIndicator extends StatelessWidget {
  final VoidCallback onOpen;
  const RecordingIndicator({super.key, required this.onOpen});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: MediaLibrary.instance,
    builder: (context, _) {
      final count = MediaLibrary.instance.activeRecordings.length;
      if (count == 0) return const SizedBox.shrink();
      return Material(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          top: false,
          child: TextButton.icon(
            onPressed: onOpen,
            icon: Icon(
              Icons.fiber_manual_record,
              color: Theme.of(context).colorScheme.error,
              size: 14,
            ),
            label: Text('$count recording${count == 1 ? '' : 's'} · Open DVR'),
          ),
        ),
      );
    },
  );
}

class RecordingsPage extends StatelessWidget {
  const RecordingsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('DVR')),
    body: ListenableBuilder(
      listenable: MediaLibrary.instance,
      builder: (context, _) {
        final library = MediaLibrary.instance;
        if (library.storageError != null) {
          return Center(child: Text(library.storageError!));
        }
        if (library.recordings.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Record live TV three ways:\n\nPress R or use Record in the player.\nChoose Record this program in the guide.\nOpen a channel menu and choose Record now.\n\nKeep brenTV open for schedules. Videos are saved in your DVR folder.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final sections =
            [
              (
                'Recording now',
                {RecordingState.recording, RecordingState.finishing},
              ),
              ('Scheduled', {RecordingState.scheduled}),
              ('Completed', {RecordingState.completed}),
              (
                'Missed or failed',
                {
                  RecordingState.missed,
                  RecordingState.failed,
                  RecordingState.canceled,
                },
              ),
            ].map(
              (section) => (
                section.$1,
                library.recordings
                    .where((j) => section.$2.contains(j.state))
                    .toList(),
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
                    final j = jobs[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${j.channelName} · ${j.title}'),
                            Text(
                              '${_when(j.start)} – ${_when(j.stop).split(' ').last} · ${_stateLabel(j.state)}',
                            ),
                            if (j.error != null) Text(j.error!),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (j.active ||
                                    j.state == RecordingState.scheduled)
                                  TextButton.icon(
                                    onPressed: () async {
                                      try {
                                        await library.stopRecording(j);
                                      } catch (_) {
                                        if (context.mounted) {
                                          libraryMessage(
                                            context,
                                            'Could not cancel recording.',
                                          );
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.stop),
                                    label: Text(j.active ? 'Stop' : 'Cancel'),
                                  ),
                                if (!j.reserved && j.file != null)
                                  TextButton.icon(
                                    onPressed: () async {
                                      if (!await File(j.file!).exists()) {
                                        if (context.mounted) {
                                          libraryMessage(
                                            context,
                                            'This file has moved or been deleted.',
                                          );
                                        }
                                        return;
                                      }
                                      if (context.mounted) {
                                        await Playback.play(
                                          context,
                                          Channel(
                                            name: j.title,
                                            url: File(j.file!).uri.toString(),
                                            mediaType: MediaType.movie,
                                            sourceId: 0,
                                            favorite: false,
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('Play'),
                                  ),
                                TextButton.icon(
                                  onPressed: () => openMediaFolder(
                                    context,
                                    j.file == null
                                        ? library.preferences.recordingFolder
                                        : File(j.file!).parent.path,
                                  ),
                                  icon: const Icon(Icons.folder_open),
                                  label: const Text('Open folder'),
                                ),
                                TextButton.icon(
                                  onPressed: () => showDialog(
                                    context: context,
                                    builder: (c) => ConfirmDelete(
                                      name: j.title,
                                      type: 'recording',
                                      confirm: () async {
                                        try {
                                          await library.deleteRecording(j);
                                        } catch (_) {
                                          if (context.mounted) {
                                            libraryMessage(
                                              context,
                                              'Could not delete the recording.',
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Delete'),
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
}

Future<void> openMediaFolder(BuildContext context, String folder) async {
  try {
    final p = await Process.start('xdg-open', [folder]);
    await p.stdout.drain<void>();
    await p.stderr.drain<void>();
    if (await p.exitCode != 0) throw StateError('Open failed');
  } catch (_) {
    if (context.mounted) libraryMessage(context, 'Could not open the folder.');
  }
}

class LibraryNavigation extends StatelessWidget {
  final Widget child;
  final VoidCallback onOpen;
  const LibraryNavigation({
    super.key,
    required this.child,
    required this.onOpen,
  });
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const _LibraryNotice(),
      RecordingIndicator(onOpen: onOpen),
      child,
    ],
  );
}

String _when(int seconds) {
  final t = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

String _stateLabel(RecordingState state) => switch (state) {
  RecordingState.scheduled => 'Scheduled',
  RecordingState.recording => 'Recording',
  RecordingState.finishing => 'Saving',
  RecordingState.completed => 'Completed',
  RecordingState.missed => 'Missed',
  RecordingState.failed => 'Failed',
  RecordingState.canceled => 'Canceled',
};

/// Shows what the library did on its own, such as closing the player for a
/// scheduled recording, on whichever page is open.
class _LibraryNotice extends StatefulWidget {
  const _LibraryNotice();
  @override
  State<_LibraryNotice> createState() => _LibraryNoticeState();
}

class _LibraryNoticeState extends State<_LibraryNotice> {
  @override
  void initState() {
    super.initState();
    MediaLibrary.instance.notice.addListener(_show);
    WidgetsBinding.instance.addPostFrameCallback((_) => _show());
  }

  void _show() {
    final notice = MediaLibrary.instance.notice;
    final text = notice.value;
    if (text == null || !mounted) return;
    notice.value = null;
    libraryMessage(context, text);
  }

  @override
  void dispose() {
    MediaLibrary.instance.notice.removeListener(_show);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
