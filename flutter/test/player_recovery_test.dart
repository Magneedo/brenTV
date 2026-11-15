import 'dart:io';
import 'package:flutter/services.dart';
import 'package:brentv/generated/generated_proto.pb.dart' as pb;
import 'package:brentv/models/channel.dart';
import 'package:brentv/models/media_type.dart';
import 'package:brentv/models/settings.dart';
import 'package:brentv/native_bridge.dart';
import 'package:brentv/playback/feeds.dart';
import 'package:brentv/player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' as mk;

void main() {
  testWidgets(
    'native initial failure and failing switch exhaust retries',
    (tester) async {
      const videoChannel = MethodChannel('com.alexmercerind/media_kit_video');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        videoChannel,
        (call) async {
          if (call.method == 'VideoOutputManager.Create') {
            await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
              videoChannel.name,
              const StandardMethodCodec().encodeMethodCall(
                MethodCall('VideoOutput.Resize', {
                  'handle': int.parse(call.arguments['handle']),
                  'id': 1,
                  'rect': const {
                    'left': 0,
                    'top': 0,
                    'width': 32,
                    'height': 32,
                  },
                }),
              ),
              (_) {},
            );
          }
          return null;
        },
      );
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('brentv-recovery-'),
      ))!;
      await tester.runAsync(() async {
        mk.MediaKit.ensureInitialized();
        await NativeBridge.instance.initialize(
          pb.InitMessage(dbPath: dir.path, tempPath: dir.path),
        );
      });
      final url = await tester.runAsync(() async {
        final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final url = 'http://127.0.0.1:${socket.port}/missing';
        await socket.close();
        return url;
      });
      final channel = Channel(
        id: 999,
        name: 'Fixture',
        url: url,
        mediaType: MediaType.livestream,
        sourceId: 1,
        favorite: false,
      );
      await tester.runAsync(
        () => tester.pumpWidget(
          MaterialApp(
            home: Player(
              channel: channel,
              settings: Settings(),
              siblings: [
                channel,
                Channel(
                  id: 1001,
                  name: 'Container',
                  url: '42',
                  mediaType: MediaType.serie,
                  sourceId: 1,
                  favorite: false,
                ),
                Channel(
                  name: 'No id',
                  url: url,
                  mediaType: MediaType.serie,
                  sourceId: 1,
                  favorite: false,
                ),
                Channel(
                  id: 1000,
                  name: 'Direct M3U series',
                  url: url,
                  mediaType: MediaType.serie,
                  sourceId: 1,
                  favorite: false,
                ),
              ],
            ),
          ),
        ),
      );
      final dynamic state = tester.state(find.byType(Player));
      Future<void> waitUntil(bool Function() check) async {
        for (var n = 0; n < 300; n++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (check()) return;
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
        }
        fail('Native recovery timed out');
      }

      await waitUntil(() => state.idleCheck != null);
      await tester.runAsync(() async {
        await (state.player.platform as mk.NativePlayer).setProperty(
          'vo',
          'null',
        );
        await (state.player.platform as mk.NativePlayer).setProperty(
          'ao',
          'null',
        );
        await (state.player.platform as mk.NativePlayer).setProperty(
          'load-unsafe-playlists',
          'yes',
        );
      });
      await waitUntil(() => state.exhausted as bool);
      debugPrint('Native failed open exhausted three retries');
      expect(state.reconnectBudget.attempts, 3);
      expect(
        find.text('Stream unavailable. Try another channel.'),
        findsOneWidget,
      );
      final native = state.player.platform as mk.NativePlayer;
      expect(
        await tester.runAsync(() => native.getProperty('idle-active')),
        'yes',
      );
      await tester.runAsync(
        () =>
            state.switchFeed(
                  Feed(channel, 'av://lavfi:sine=frequency=440:duration=60'),
                )
                as Future<void>,
      );
      await waitUntil(
        () => state.recoveryProgress >= const Duration(seconds: 3),
      );
      expect(state.reconnectBudget.attempts, 0);
      debugPrint('Native playback advanced three seconds');
      final errors = <String>[];
      final errorSubscription = state.player.stream.error.listen(
        (String error) => errors.add(error),
      );
      final before = state.player.state.position as Duration;
      await tester.runAsync(() => native.command(['sub-add', url!]));
      debugPrint('Native subtitle failure requested');
      await waitUntil(
        () =>
            errors.isNotEmpty &&
            state.player.state.position > before + const Duration(seconds: 1),
      );
      expect(state.reconnectBudget.attempts, 0);
      debugPrint('Recoverable error received while native playback advanced');
      await tester.runAsync(() => errorSubscription.cancel() as Future<void>);
      debugPrint('Recoverable error subscription cancelled');
      await tester.runAsync(
        () => state.switchFeed(Feed(channel, url!)) as Future<void>,
      );
      debugPrint('Failing feed switch returned');
      await waitUntil(() => state.exhausted as bool);
      debugPrint('Failing feed exhausted retries');
      expect(state.reconnectBudget.attempts, 3);
      for (var n = 0; n < 30; n++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(state.reconnectBudget.attempts, 3);
      await tester.runAsync(() => state.adjacent(1) as Future<void>);
      expect(state.channel.id, 1000);
      expect(state.navigationId, 1000);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => dir.delete(recursive: true));
    },
    skip:
        !Platform.isLinux || Platform.environment['BRENTV_NATIVE_TESTS'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
