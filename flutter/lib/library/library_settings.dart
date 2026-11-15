import 'dart:io';
import 'package:flutter/material.dart';
import 'media_library.dart';
import 'recording_ui.dart';

Future<void> editLibraryValue(
  BuildContext context,
  String title,
  String current,
  Future<void> Function(String) apply, {
  bool number = false,
}) async {
  final controller = TextEditingController(text: current);
  final value = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: number ? 'Number' : 'Absolute folder path',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 300));
  controller.dispose();
  if (value == null || !context.mounted) return;
  try {
    await apply(value);
    MediaLibrary.instance.changed();
  } catch (_) {
    if (context.mounted) {
      libraryMessage(
        context,
        'Could not save. Enter a valid value and check the folder permissions.',
      );
    }
  }
}

class RecordingSettings extends StatelessWidget {
  const RecordingSettings({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: MediaLibrary.instance,
    builder: (context, _) {
      final library = MediaLibrary.instance;
      final p = library.preferences;
      Future<void> save(String key, String value) async {
        if (key == 'folder') {
          if (!value.startsWith('/') || value.contains('\u0000')) {
            throw ArgumentError();
          }
          final old = p.recordingFolder;
          p.recordingFolder = value;
          try {
            await library.savePreferences();
          } catch (_) {
            p.recordingFolder = old;
            rethrow;
          }
        } else {
          final n = int.tryParse(value);
          if (n == null || n < 0 || n > (key == 'before' ? 60 : 120)) {
            throw ArgumentError();
          }
          final old = key == 'before' ? p.paddingBefore : p.paddingAfter;
          if (key == 'before') {
            p.paddingBefore = n;
          } else {
            p.paddingAfter = n;
          }
          try {
            await library.savePreferences();
          } catch (_) {
            if (key == 'before') {
              p.paddingBefore = old;
            } else {
              p.paddingAfter = old;
            }
            rethrow;
          }
        }
      }

      return Column(
        children: [
          ListTile(
            title: const Text('Recording folder'),
            subtitle: Text(p.recordingFolder),
            onTap: () => editLibraryValue(
              context,
              'Recording folder',
              p.recordingFolder,
              (v) => save('folder', v),
            ),
          ),
          ListTile(
            title: const Text('Padding before (0–60 minutes)'),
            subtitle: Text('${p.paddingBefore} minutes'),
            onTap: () => editLibraryValue(
              context,
              'Padding before',
              '${p.paddingBefore}',
              (v) => save('before', v),
              number: true,
            ),
          ),
          ListTile(
            title: const Text('Padding after (0–120 minutes)'),
            subtitle: Text('${p.paddingAfter} minutes'),
            onTap: () => editLibraryValue(
              context,
              'Padding after',
              '${p.paddingAfter}',
              (v) => save('after', v),
              number: true,
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Requires ffmpeg: pacman -S ffmpeg\nSchedules run while brenTV is open. Missed starts are marked Missed.',
            ),
          ),
        ],
      );
    },
  );
}

class DownloadSettings extends StatelessWidget {
  const DownloadSettings({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: MediaLibrary.instance,
    builder: (context, _) {
      final library = MediaLibrary.instance;
      final p = library.preferences;
      Future<void> folder(String value, bool movies) async {
        if (!value.startsWith('/') || value.contains('\u0000')) {
          throw ArgumentError();
        }
        final old = movies ? p.moviesFolder : p.seriesFolder;
        if (movies) {
          p.moviesFolder = value;
        } else {
          p.seriesFolder = value;
        }
        try {
          await library.savePreferences();
        } catch (_) {
          if (movies) {
            p.moviesFolder = old;
          } else {
            p.seriesFolder = old;
          }
          rethrow;
        }
      }

      return Column(
        children: [
          ListTile(
            title: const Text('Movies folder'),
            subtitle: Text(
              Platform.isIOS
                  ? 'On My iPhone → brenTV → Movies'
                  : p.moviesFolder,
            ),
            onTap: Platform.isIOS
                ? null
                : () => editLibraryValue(
                    context,
                    'Movies folder',
                    p.moviesFolder,
                    (v) => folder(v, true),
                  ),
          ),
          ListTile(
            title: const Text('Series folder'),
            subtitle: Text(
              Platform.isIOS
                  ? 'On My iPhone → brenTV → Series'
                  : p.seriesFolder,
            ),
            onTap: Platform.isIOS
                ? null
                : () => editLibraryValue(
                    context,
                    'Series folder',
                    p.seriesFolder,
                    (v) => folder(v, false),
                  ),
          ),
          ListTile(
            title: const Text('Concurrent downloads'),
            subtitle: Text(
              '${p.concurrentDownloads} · also limited by provider connections',
            ),
            onTap: () => editLibraryValue(
              context,
              'Concurrent downloads (1–4)',
              '${p.concurrentDownloads}',
              (v) async {
                final n = int.tryParse(v);
                if (n == null || n < 1 || n > 4) throw ArgumentError();
                final old = p.concurrentDownloads;
                p.concurrentDownloads = n;
                try {
                  await library.savePreferences();
                } catch (_) {
                  p.concurrentDownloads = old;
                  rethrow;
                }
              },
              number: true,
            ),
          ),
          ListTile(
            title: const Text('Provider streams at once'),
            subtitle: Text(
              p.connectionLimit == 0
                  ? 'Automatic · what the provider reports'
                  : '${p.connectionLimit} · playback, recordings and downloads share ${p.connectionLimit == 1 ? 'it' : 'them'}',
            ),
            onTap: () => editLibraryValue(
              context,
              'Provider streams at once (0 = automatic, 1–8)',
              '${p.connectionLimit}',
              (v) async {
                final n = int.tryParse(v);
                if (n == null || n < 0 || n > 8) throw ArgumentError();
                final old = p.connectionLimit;
                p.connectionLimit = n;
                try {
                  await library.savePreferences();
                  library.limits.clear();
                  library.changed();
                } catch (_) {
                  p.connectionLimit = old;
                  rethrow;
                }
              },
              number: true,
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Set Provider streams at once to 1 if a recording, a download or playback cuts another one off: some providers allow fewer streams than they report. With one stream, the player records the channel you are watching, and downloads wait their turn.',
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Folder changes apply to new downloads. Active jobs keep their destination. Recordings and playback take priority over queued downloads.',
            ),
          ),
        ],
      );
    },
  );
}
