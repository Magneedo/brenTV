import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' as mk;

void main() {
  test(
    'libmpv accepts and clears HLS bitrate cap while playing local video',
    () async {
      mk.MediaKit.ensureInitialized();
      final player = mk.Player(
        configuration: const mk.PlayerConfiguration(
          vo: 'null',
          muted: true,
          logLevel: mk.MPVLogLevel.error,
        ),
      );
      try {
        final native = player.platform as mk.NativePlayer;
        await native.setProperty('ao', 'null');
        await native.setProperty('vid', 'auto');
        // media_kit uses a temporary playlist; allow the local lavfi fixture in it.
        await native.setProperty('load-unsafe-playlists', 'yes');
        await native.setProperty('hls-bitrate', '2000000');
        expect(await native.getProperty('hls-bitrate'), '2000000');
        final widthReady = player.stream.width
            .firstWhere((v) => v == 320)
            .timeout(const Duration(seconds: 10));
        await player.open(
          mk.Media('av://lavfi:testsrc=size=320x180:rate=10:duration=2'),
        );
        final width = await widthReady;
        expect(width, 320);
        expect(await native.getProperty('height'), '180');
        await native.setProperty('hls-bitrate', 'max');
        expect(await native.getProperty('hls-bitrate'), 'max');
      } finally {
        await player.dispose();
      }
    },
    skip:
        !Platform.isLinux || Platform.environment['BRENTV_NATIVE_TESTS'] != '1',
  );
}
