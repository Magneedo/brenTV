import 'package:brentv/generated/generated_proto.pb.dart' as pb;
import 'package:brentv/models/channel.dart';
import 'package:brentv/models/media_type.dart';
import 'package:brentv/models/settings.dart';
import 'package:brentv/playback/feeds.dart';
import 'dart:async';
import 'dart:io';

import 'package:brentv/playback/ios/live_relay.dart';
import 'package:brentv/playback/ios/native_player.dart';
import 'package:brentv/playback/ios_player.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Channel fixture(String url) => Channel(
  id: 1,
  name: 'Fixture',
  url: url,
  image: 'http://127.0.0.1/art.png',
  mediaType: MediaType.livestream,
  sourceId: 1,
  favorite: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    // No stream is inspected unless a test asks for it.
    IosPlayer.prepareLive =
        (url, headers, {required ignoreSsl, required force}) async =>
            const LivePreparation();
    IosPlayer.prepareMovie =
        (url, headers, {required ignoreSsl, required start}) async =>
            const LivePreparation(failed: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(IosNativePlayer.channel, (call) async {
          calls.add(call);
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(IosNativePlayer.channel, null),
  );
  testWidgets('every format uses native UI, errors never open a Flutter player', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const events = MethodChannel('brentv/ios_player/events');
    messenger.setMockMethodCallHandler(events, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(events, null));
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              context = c;
              return const Text('Library');
            },
          ),
        ),
      ),
    );
    Future<void> emit(Map<String, dynamic> event) async {
      await messenger.handlePlatformMessage(
        events.name,
        const StandardMethodCodec().encodeSuccessEnvelope(event),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);
    }

    await tester.runAsync(() async {
      for (final url in [
        'http://127.0.0.1/watch',
        'http://127.0.0.1/video.mkv',
        'http://127.0.0.1/video.ts',
        'file:///Movies/local.mp4',
      ]) {
        final item = fixture(url)..id = null;
        var closed = false;
        final opening = IosPlayer.open(
          context,
          item,
          Settings(
            iosNativePlayer: false,
            iosPreferHls: false,
            showProgrammes: false,
          ),
        ).then((_) => closed = true);
        await Future<void>.delayed(Duration.zero);
        expect(
          calls.lastWhere((c) => c.method == 'open').arguments['url'],
          url,
        );
        expect(closed, isFalse);
        await emit({
          'type': 'state',
          'state': 'failed',
          'beforeFirstFrame': true,
        });
        expect(closed, isFalse);
        expect(find.text('Library'), findsOneWidget);
        expect(find.byType(UiKitView), findsNothing);
        await emit({'type': 'closed', 'position': 4.5});
        await opening;
        expect(closed, isTrue);
        expect(calls.last.method, 'stop');
      }
      final first = IosPlayer.open(
        context,
        fixture('file:///first.mp4')..id = null,
        Settings(showProgrammes: false),
      );
      await Future<void>.delayed(Duration.zero);
      var stopCurrent = true;
      messenger.setMockMethodCallHandler(IosNativePlayer.channel, (call) async {
        calls.add(call);
        if (call.method == 'stop' && stopCurrent) {
          stopCurrent = false;
          await emit({'type': 'closed', 'position': 6.0});
        }
        return null;
      });
      final replacement = IosPlayer.open(
        context,
        fixture('file:///second.mp4')..id = null,
        Settings(showProgrammes: false),
      );
      await first;
      await Future<void>.delayed(Duration.zero);
      expect(
        calls.lastWhere((c) => c.method == 'open').arguments['url'],
        'file:///second.mp4',
      );
      await emit({'type': 'closed', 'position': 1.0});
      await replacement;
      messenger.setMockMethodCallHandler(IosNativePlayer.channel, (call) async {
        calls.add(call);
        if (call.method == 'open') throw PlatformException(code: 'headers');
        return null;
      });
      final rejected = IosPlayer.open(
        context,
        fixture('file:///bad.mkv')..id = null,
        Settings(showProgrammes: false),
      );
      await rejected;
    });
    await tester.pump();
    expect(
      find.text(
        'Apple’s player cannot play sources that require these custom headers.',
      ),
      findsOneWidget,
    );
    expect(find.text('Library'), findsOneWidget);
    expect(calls.last.method, 'stop');
  });
  testWidgets('a live stream Apple rejects reopens through the repackager', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const events = MethodChannel('brentv/ios_player/events');
    messenger.setMockMethodCallHandler(events, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(events, null));
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              context = c;
              return const Text('Library');
            },
          ),
        ),
      ),
    );
    Future<void> emit(Map<String, dynamic> event) async {
      await messenger.handlePlatformMessage(
        events.name,
        const StandardMethodCodec().encodeSuccessEnvelope(event),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);
    }

    await tester.runAsync(() async {
      final forced = <bool>[];
      final ffmpeg = Completer<void>();
      var closedRelays = 0;
      Future<LiveRelay> relay(String video) => LiveRelay.open(
        'http://127.0.0.1/live/u/p/1.ts',
        openRelay: (request) async => pb.RelayInfo(
          token: 'token',
          port: 4321,
          video: video,
          audio: 'aac',
        ),
        closeRelay: (_) async => closedRelays++,
        invoke: (method, args) async {
          if (method == 'cancel' && !ffmpeg.isCompleted) ffmpeg.complete();
          if (method != 'stream') return null;
          final arguments = (args['arguments'] as List).cast<String>();
          await File(arguments.last).writeAsString(
            '#EXTM3U\n#EXTINF:2,\nseg00000.m4s\n#EXTINF:2,\nseg00001.m4s\n',
          );
          await ffmpeg.future;
          return {'status': 'canceled'};
        },
      );
      IosPlayer.prepareLive =
          (url, headers, {required ignoreSsl, required force}) {
            forced.add(force);
            return LivePreparation.run(
              url,
              headers,
              ignoreSsl: ignoreSsl,
              force: force,
              open: () => relay('h264'),
            );
          };
      final item = fixture('http://127.0.0.1/live/u/p/1.ts')..id = null;
      var done = false;
      final opening = IosPlayer.open(
        context,
        item,
        Settings(showProgrammes: false),
      ).then((_) => done = true);
      Future<void> settle(bool Function() ready) async {
        for (var i = 0; i < 200 && !ready(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(ready(), isTrue);
      }

      // H.264 with AAC plays from the provider's own HLS first.
      await settle(() => calls.any((c) => c.method == 'open'));
      var open = calls.lastWhere((c) => c.method == 'open').arguments as Map;
      expect(open['url'], 'http://127.0.0.1/live/u/p/1.m3u8');
      expect(open['quietFailure'], isTrue);
      expect(forced, [false]);
      calls.clear();
      await emit({'type': 'closed', 'position': 0.0, 'failed': true});
      await settle(() => calls.any((c) => c.method == 'open'));
      open = calls.lastWhere((c) => c.method == 'open').arguments as Map;
      expect(open['url'], 'http://127.0.0.1:4321/token/live.m3u8');
      expect(open['quietFailure'], isFalse);
      expect(open['headers'], isEmpty);
      expect(forced, [false, true]);
      expect(done, isFalse);
      await emit({'type': 'closed', 'position': 9.0});
      await opening;
      expect(ffmpeg.isCompleted, isTrue);
      expect(closedRelays, 2);

      // HEVC goes straight to the repackager, with no failure in between.
      calls.clear();
      forced.clear();
      IosPlayer.prepareLive =
          (url, headers, {required ignoreSsl, required force}) =>
              LivePreparation.run(
                url,
                headers,
                ignoreSsl: ignoreSsl,
                force: force,
                open: () => relay('hevc'),
              );
      final second = IosPlayer.open(
        context,
        item,
        Settings(showProgrammes: false),
      );
      await settle(() => calls.any((c) => c.method == 'open'));
      open = calls.lastWhere((c) => c.method == 'open').arguments as Map;
      expect(open['url'], 'http://127.0.0.1:4321/token/live.m3u8');
      expect(open['quietFailure'], isFalse);
      await emit({'type': 'closed', 'position': 1.0});
      await second;
    });
    await tester.pump();
    expect(find.text('Library'), findsOneWidget);
  });
  testWidgets('movies use conversion directly or after Apple rejects them', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const events = MethodChannel('brentv/ios_player/events');
    messenger.setMockMethodCallHandler(events, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(events, null));
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              context = c;
              return const Text('Library');
            },
          ),
        ),
      ),
    );
    Future<void> emit(Map<String, dynamic> event) async {
      await messenger.handlePlatformMessage(
        events.name,
        const StandardMethodCodec().encodeSuccessEnvelope(event),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);
    }

    Future<void> opened() async {
      for (var i = 0; i < 200 && !calls.any((c) => c.method == 'open'); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(calls.any((c) => c.method == 'open'), isTrue);
    }

    var conversions = 0, closed = 0;
    IosPlayer.prepareMovie =
        (url, headers, {required ignoreSsl, required start}) async {
          conversions++;
          expect(start, 0);
          return LivePreparation(
            relay: await LiveRelay.open(
              url,
              seekable: true,
              openRelay: (_) async => pb.RelayInfo(token: 'movie', port: 4321),
              closeRelay: (_) async => closed++,
              invoke: (_, _) async => null,
            ),
          );
        };
    await tester.runAsync(() async {
      for (final extension in ['mkv', 'mp4', '']) {
        calls.clear();
        final url =
            'http://127.0.0.1/movie${extension.isEmpty ? '?id=1' : '.$extension'}';
        final item = fixture(url)
          ..id = null
          ..mediaType = MediaType.movie;
        final opening = IosPlayer.open(
          context,
          item,
          Settings(showProgrammes: false),
        );
        await opened();
        if (extension != 'mkv') {
          final direct =
              calls.lastWhere((c) => c.method == 'open').arguments as Map;
          expect(direct['url'], url);
          expect(direct['quietFailure'], isTrue);
          calls.clear();
          await emit({'type': 'closed', 'failed': true, 'position': 0.0});
          await opened();
        }
        final converted =
            calls.lastWhere((c) => c.method == 'open').arguments as Map;
        expect(converted['url'], 'http://127.0.0.1:4321/movie/live.m3u8');
        expect(converted['isLive'], isFalse);
        expect(converted['fromStart'], isTrue);
        expect(converted['startSeconds'], 0.0);
        expect(converted['quietFailure'], isFalse);
        expect(converted['headers'], isEmpty);
        await emit({'type': 'closed', 'position': 8.0});
        await opening;
      }
    });
    expect(conversions, 3);
    expect(closed, 3);
    await tester.pump();
  });
  test('Xtream HLS preference changes URL without choosing another player', () {
    const ts = 'http://127.0.0.1/live/fixture/sample/1.ts?q=1';
    expect(
      IosNativePlayer.playbackUrl(ts, Settings()),
      ts.replaceFirst('.ts', '.m3u8'),
    );
    expect(IosNativePlayer.playbackUrl(ts, Settings(iosPreferHls: false)), ts);
    expect(
      IosNativePlayer.playbackUrl('http://127.0.0.1/a.mp4', Settings()),
      'http://127.0.0.1/a.mp4',
    );
  });
  test(
    'variant sends master, caps, headers, title and resume, no artwork',
    () async {
      final item = fixture('http://127.0.0.1/master.m3u8');
      final feed = Feed(
        item,
        item.url!,
        variant: pb.StreamVariant(
          bandwidth: Int64(4000000),
          width: 1920,
          height: 1080,
        ),
      );
      const headers = {
        'User-Agent': 'fixture',
        'Referer': 'http://127.0.0.1/',
        'Origin': 'http://127.0.0.1',
      };
      await IosNativePlayer.open(
        feed,
        Settings(),
        headers: headers,
        startSeconds: 42,
        isLive: false,
      );
      expect(calls.single.method, 'open');
      expect(calls.single.arguments, {
        'url': item.url,
        'headers': headers,
        'title': 'Fixture',
        'startSeconds': 42.0,
        'isLive': false,
        'backgroundAudio': true,
        'fromStart': false,
        'quietFailure': false,
        'autoPip': true,
        'maxBitrate': 4000000,
        'width': 1920,
        'height': 1080,
      });
    },
  );
  test('Auto and alternates remove caps', () async {
    final item = fixture('http://127.0.0.1/master.m3u8');
    for (final alternate in [false, true]) {
      await IosNativePlayer.open(
        Feed(item, item.url!, alternate: alternate),
        Settings(backgroundAudio: false, autoPip: false),
        isLive: true,
      );
      final args = calls.last.arguments as Map;
      expect(args['maxBitrate'], 0);
      expect(args['width'], 0);
      expect(args['height'], 0);
      expect(args['backgroundAudio'], isFalse);
      expect(args['autoPip'], isFalse);
    }
  });
  test('native route control messages encode correctly', () async {
    await IosNativePlayer.command('seek', {'seconds': 45.0});
    expect(calls.last.method, 'seek');
    expect(calls.last.arguments, {'seconds': 45.0});
    for (final command in ['play', 'pause', 'stop']) {
      await IosNativePlayer.command(command);
      expect(calls.last.method, command);
      expect(calls.last.arguments, isNull);
    }
  });
}
