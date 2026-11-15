import 'package:brentv/models/settings.dart';

List<String> splitMpvArgs(String text) {
  final args = <String>[];
  var word = StringBuffer();
  String? quote;
  var escaped = false;
  var started = false;
  for (final c in text.split('')) {
    if (escaped) {
      word.write(c);
      escaped = false;
    } else if (c == r'\' && quote != "'") {
      escaped = true;
      started = true;
    } else if (quote != null) {
      if (c == quote) {
        quote = null;
      } else {
        word.write(c);
      }
    } else if (c == '"' || c == "'") {
      quote = c;
      started = true;
    } else if (c.trim().isEmpty) {
      if (started) args.add(word.toString());
      word = StringBuffer();
      started = false;
    } else {
      word.write(c);
      started = true;
    }
  }
  if (quote != null || escaped) {
    throw const FormatException('Unclosed mpv argument');
  }
  if (started) args.add(word.toString());
  return args;
}

const mpvKeyBindings = {
  'PGUP': 'brentv-next',
  'PGDWN': 'brentv-prev',
  'CHANNEL_UP': 'brentv-next',
  'CHANNEL_DOWN': 'brentv-prev',
  'a': 'brentv-feed-next',
  'A': 'brentv-feed-prev',
  'i': 'brentv-info',
  'r': 'brentv-record',
  'BS': 'brentv-last',
  'F1': 'brentv-favorite-1',
  'F2': 'brentv-favorite-2',
  'F3': 'brentv-favorite-3',
  'F4': 'brentv-favorite-4',
  'F5': 'brentv-favorite-5',
  'F6': 'brentv-favorite-6',
  'F7': 'brentv-favorite-7',
  'F8': 'brentv-favorite-8',
  'F9': 'brentv-favorite-9',
};

/// mpv's built-in OSC supports custom buttons in its bar layouts.
List<String> recordingOscOptions({required bool live}) => [
  'osc-layout=bottombar',
  'osc-custom_button_1_content=${live ? r"{\c&H0000FF&}●" : ""}',
  'osc-custom_button_1_mbtn_left_command=script-message brentv-record-button',
  'osc-custom_button_1_mbtn_right_command=show-text "Record or stop live TV (R)"',
];

List<String> mpvArguments(
  Settings settings,
  String socket, {
  required bool live,
}) => [
  ...splitMpvArgs(settings.mpvExtraArgs),
  '--input-ipc-server=$socket',
  '--idle=${settings.mpvReuseWindow ? 'yes' : 'once'}',
  '--force-window=immediate',
  if (settings.hwdec.isNotEmpty) '--hwdec=${settings.hwdec}',
  '--cache=yes',
  '--cache-secs=${settings.cacheSecs}',
  '--demuxer-readahead-secs=${settings.cacheSecs}',
  '--demuxer-max-bytes=${settings.demuxerMaxMb}MiB',
  if (live && settings.lowLatency) '--profile=low-latency',
];
