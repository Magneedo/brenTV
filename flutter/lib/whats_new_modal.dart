import 'package:flutter/material.dart';
import 'package:brentv/native_bridge.dart';
import 'package:package_info_plus/package_info_plus.dart';

class WhatsNewModal extends StatelessWidget {
  final String version;
  const WhatsNewModal({super.key, required this.version});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("What's new: update $version"),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () async {
            await NativeBridge.instance.updateLastSeenVersion(
              (await PackageInfo.fromPlatform()).version,
            );
            if (!context.mounted) return;
            Navigator.pop(context, true);
          },
          child: const Text("Don't show again"),
        ),
      ],
      content: const Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: Text('''
brenTV: what's in this build
- iPhone: MKV movies and episodes now stream; live channels that played audio only or would not open are converted on the phone; converted downloads replace their originals
- Download movies, episodes and seasons for offline viewing; pause and resume in Downloads
- Linux DVR: record what you are watching with R, schedule from the guide, and manage recordings in DVR; ffmpeg required
- Customize the bottom bar: reorder or hide pages in Settings; Local media now has its own destination
- Number keys follow your visible bottom-bar order
- Organized Settings sections and a Local media browser for your Linux Videos folder
- Choose which media types each source imports (live TV, movies, series)
- Include or exclude categories per source
- Text-only lists: no channel artwork is downloaded at all
- Favorite channels and categories (⋮ menu, right-click, long-press or F) in your own order (Ctrl+↑/↓); pick the start page
- UI scale (Ctrl+= / Ctrl+- / Ctrl+0) and a keyboard shortcut list (?)
- Quality selector for HLS variants and alternate feeds
- Alternate feeds (FHD/HD/SD/backup) grouped with instant switching
- Linux: external mpv with IPC, hardware decoding and dwl swallowing
- iOS: background audio, lock-screen controls and Picture-in-Picture
- Faster imports and searches; refresh keeps favorites and history and reports what it imported
'''),
          ),
        ),
      ),
    );
  }
}
