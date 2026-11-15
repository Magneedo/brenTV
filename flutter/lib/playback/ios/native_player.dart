import 'package:flutter/services.dart';
import 'package:brentv/models/settings.dart';
import 'package:brentv/playback/feeds.dart';

/// Commands and events for the native iOS player route.
class IosNativePlayer {
  static const channel = MethodChannel('brentv/ios_player');
  static final events = const EventChannel('brentv/ios_player/events')
      .receiveBroadcastStream()
      .map((event) => Map<String, dynamic>.from(event as Map));

  static Future<void> command(String method, [Map<String, dynamic>? args]) =>
      channel.invokeMethod<void>(method, args);

  static String playbackUrl(String url, Settings settings) =>
      settings.iosPreferHls ? xtreamHlsUrl(url) ?? url : url;

  static Future<void> open(
    Feed feed,
    Settings settings, {
    Map<String, String> headers = const {},
    double startSeconds = 0,
    required bool isLive,
    bool quietFailure = false,
    bool fromStart = false,
  }) => command('open', {
    // A growing playlist would otherwise open at its newest end.
    'fromStart': fromStart,
    // Close without an alert if nothing could be shown, so the caller can
    // try another route to the same channel.
    'quietFailure': quietFailure,
    'url': playbackUrl(feed.url, settings),
    'headers': headers,
    'title': feed.channel.name,
    'startSeconds': startSeconds,
    'isLive': isLive,
    'backgroundAudio': settings.backgroundAudio,
    'autoPip': settings.autoPip,
    'maxBitrate': feed.maxBitrate ?? 0,
    'width': feed.variant?.width ?? 0,
    'height': feed.variant?.height ?? 0,
  });
}
