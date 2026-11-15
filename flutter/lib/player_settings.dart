import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:brentv/models/settings.dart';

class PlayerSettings extends StatelessWidget {
  final Settings settings;
  final VoidCallback onChanged;
  const PlayerSettings({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  Widget toggle(String title, bool value, ValueChanged<bool> set) =>
      SwitchListTile(
        title: Text(title),
        value: value,
        onChanged: (value) {
          set(value);
          onChanged();
        },
      );
  Widget choice(
    String title,
    String value,
    Map<String, String> choices,
    ValueChanged<String> set,
  ) => ListTile(
    title: Text(title),
    subtitle: DropdownButton<String>(
      isExpanded: true,
      value: choices.containsKey(value) ? value : choices.keys.first,
      items: [
        for (final entry in choices.entries)
          DropdownMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: (value) {
        if (value != null) {
          set(value);
          onChanged();
        }
      },
    ),
  );
  Widget field(
    BuildContext context,
    String title,
    String value,
    ValueChanged<String> set, {
    bool numeric = false,
  }) => ListTile(
    title: Text(title),
    subtitle: Text(value.isEmpty ? 'Default' : value),
    onTap: () async {
      var edited = value;
      final form = GlobalKey<FormState>();
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Form(
            key: form,
            child: TextFormField(
              initialValue: value,
              onChanged: (value) => edited = value,
              autofocus: true,
              keyboardType: numeric ? TextInputType.number : TextInputType.text,
              validator: (value) {
                final number = int.tryParse(value ?? '');
                return numeric &&
                        (number == null || number < 0 || number > 0xffffffff)
                    ? 'Enter a whole number from 0 to 4294967295'
                    : null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(context, edited);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (result != null && context.mounted) {
        set(result);
        onChanged();
      }
    },
  );
  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (defaultTargetPlatform == TargetPlatform.linux) ...[
        const ListTile(title: Text('Linux')),
        choice(
          'Player',
          settings.linuxPlayer.name,
          {'mpv': 'External mpv', 'builtIn': 'Built-in'},
          (v) => settings.linuxPlayer = LinuxPlayer.values.byName(v),
        ),
        field(
          context,
          'mpv path',
          settings.mpvPath,
          (v) => settings.mpvPath = v.trim().isEmpty ? 'mpv' : v.trim(),
        ),
        choice('Hardware decoding', settings.hwdec, {
          for (final v in [
            'auto-safe',
            'auto',
            'vaapi',
            'nvdec',
            'vulkan',
            'no',
            '',
          ])
            v: v.isEmpty ? 'From mpv.conf' : v,
        }, (v) => settings.hwdec = v),
        field(
          context,
          'Cache seconds',
          '${settings.cacheSecs}',
          (v) => settings.cacheSecs = int.parse(v),
          numeric: true,
        ),
        field(
          context,
          'Demuxer max MiB',
          '${settings.demuxerMaxMb}',
          (v) => settings.demuxerMaxMb = int.parse(v),
          numeric: true,
        ),
        toggle(
          'Reuse one mpv window (fast switching)',
          settings.mpvReuseWindow,
          (v) => settings.mpvReuseWindow = v,
        ),
        field(
          context,
          'Extra mpv arguments',
          settings.mpvExtraArgs,
          (v) => settings.mpvExtraArgs = v,
        ),
      ],
      if (defaultTargetPlatform == TargetPlatform.iOS) ...[
        const ListTile(title: Text('iOS')),
        toggle(
          'Prefer HLS for Xtream live',
          settings.iosPreferHls,
          (v) => settings.iosPreferHls = v,
        ),
        toggle(
          'Background audio',
          settings.backgroundAudio,
          (v) => settings.backgroundAudio = v,
        ),
        toggle(
          'Picture-in-Picture',
          settings.autoPip,
          (v) => settings.autoPip = v,
        ),
      ],
    ],
  );
}
