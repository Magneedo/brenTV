import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:brentv/playback/mpv/ipc.dart';
import 'package:brentv/playback/mpv/options.dart';
import 'package:brentv/models/settings.dart';

void main() {
  for (final reuse in [true, false]) {
    test(
      'real mpv loads, observes, replaces, messages and disconnects (reuse=$reuse)',
      () async {
        try {
          await Process.run('mpv', ['--version']);
        } on ProcessException {
          markTestSkipped('mpv missing');
          return;
        }
        final dir = await Directory.systemTemp.createTemp('brentv-test-');
        final process = await Process.start('mpv', [
          '--no-config',
          '--vo=null',
          '--ao=null',
          ...mpvArguments(
            Settings(mpvReuseWindow: reuse, hwdec: 'no'),
            '${dir.path}/ipc',
            live: true,
          ),
        ]);
        unawaited(process.stdout.drain<void>());
        unawaited(process.stderr.drain<void>());
        MpvIpc? ipc;
        addTearDown(() async {
          ipc?.close();
          process.kill();
          await process.exitCode;
          await dir.delete(recursive: true);
        });
        for (var i = 0; i < 100; i++) {
          try {
            ipc = await MpvIpc.connect('${dir.path}/ipc');
            break;
          } on SocketException {
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
        }
        expect(ipc, isNotNull);
        final client = ipc!;
        for (final option in recordingOscOptions(live: true)) {
          await client.command([
            'change-list',
            'script-opts',
            'append',
            option,
          ]);
        }
        final oscOptions =
            await client.command(['get_property', 'script-opts']) as Map;
        expect(
          oscOptions['osc-custom_button_1_mbtn_left_command'],
          'script-message brentv-record-button',
        );
        expect(oscOptions['osc-custom_button_1_content'], contains('●'));
        for (final option in recordingOscOptions(live: false)) {
          await client.command([
            'change-list',
            'script-opts',
            'append',
            option,
          ]);
        }
        expect(
          (await client.command(['get_property', 'script-opts'])
              as Map)['osc-custom_button_1_content'],
          '',
        );
        await client.command(['keybind', 'x', 'script-message user-binding']);
        for (final binding in mpvKeyBindings.entries) {
          await client.command([
            'keybind',
            binding.key,
            'script-message ${binding.value}',
          ]);
        }
        final bindings =
            await client.command(['get_property', 'input-bindings']) as List;
        expect(
          bindings.any(
            (b) => b['key'] == 'x' && b['cmd'] == 'script-message user-binding',
          ),
          isTrue,
        );
        expect(
          bindings.any(
            (b) =>
                b['key'] == 'A' &&
                b['cmd'] == 'script-message brentv-feed-prev',
          ),
          isTrue,
        );
        for (final pair in <String, dynamic>{
          'user-agent': '',
          'referrer': '',
          'http-header-fields': <String>[],
          'force-media-title': 'Local fixture',
          'hls-bitrate': 'max',
        }.entries) {
          await client.command(['set_property', pair.key, pair.value]);
        }
        await client.command([
          'osd-overlay',
          73,
          'ass-events',
          r'{\an7\pos(16,16)}REC 00:01',
          0,
          0,
        ]);
        await client.command(['osd-overlay', 73, 'ass-events', '', 0, 0]);
        await client.command(['set_property', 'hls-bitrate', '2500000']);
        expect(await client.command(['get_property', 'hls-bitrate']), 2500000);
        await client.command(['set_property', 'hls-bitrate', 'max']);
        final events = <Map<String, dynamic>>[];
        client.events.listen(events.add);
        await client.observe([
          'time-pos',
          'duration',
          'video-params',
          'estimated-vf-fps',
          'container-fps',
          'video-bitrate',
          'idle-active',
        ]);
        for (final size in ['320x240', '640x360']) {
          final loaded = client.events.firstWhere(
            (e) => e['event'] == 'file-loaded',
          );
          await client.command([
            'loadfile',
            'av://lavfi:testsrc=size=$size:rate=25',
            'replace',
            -1,
            {'start': '0'},
          ]);
          await loaded.timeout(const Duration(seconds: 10));
          await Future<void>.delayed(const Duration(milliseconds: 200));
          final params =
              await client.command(['get_property', 'video-params']) as Map;
          expect(params['w'], size == '320x240' ? 320 : 640);
        }
        expect(
          events.any(
            (e) =>
                e['event'] == 'property-change' &&
                e['name'] == 'time-pos' &&
                e['data'] is num,
          ),
          true,
        );
        final message = client.events.firstWhere(
          (e) => e['event'] == 'client-message',
        );
        await client.command(['script-message', 'brentv-info']);
        expect((await message.timeout(const Duration(seconds: 5)))['args'], [
          'brentv-info',
        ]);
        final disconnected = Completer<void>();
        client.events.listen((_) {}, onDone: disconnected.complete);
        await client.command(['quit']);
        await disconnected.future.timeout(const Duration(seconds: 5));
        expect(await process.exitCode, 0);
        await expectLater(
          client.command(['get_property', 'time-pos']),
          throwsStateError,
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  }
}
