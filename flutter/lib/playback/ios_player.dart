import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:brentv/library/media_library.dart';
import 'package:brentv/library/recording_ui.dart';
import 'package:brentv/models/channel.dart';
import 'package:brentv/models/media_type.dart';
import 'package:brentv/models/settings.dart';
import 'package:brentv/native_bridge.dart';
import 'package:brentv/playback/feeds.dart';
import 'package:brentv/playback/ios/live_relay.dart';
import 'package:brentv/playback/ios/native_player.dart';
import 'package:brentv/programme_guide.dart';

/// Presents Apple's own full-screen UI; there is no Flutter player route.
class IosPlayer {
  /// Inspects a live stream and starts the repackager if it is needed.
  static Future<LivePreparation> Function(
    String url,
    Map<String, String> headers, {
    required bool ignoreSsl,
    required bool force,
  })
  prepareLive = LivePreparation.run;

  /// Starts converting a movie or episode Apple's player cannot open.
  static Future<LivePreparation> Function(
    String url,
    Map<String, String> headers, {
    required bool ignoreSsl,
    required double start,
  })
  prepareMovie = LivePreparation.movie;
  static Completer<void>? _session;
  static bool _replacing = false, _preparing = false;

  static Future<void> open(
    BuildContext context,
    Channel channel,
    Settings settings,
  ) async {
    if (_replacing || _preparing) {
      libraryMessage(context, 'Switching videos. Try again in a moment.');
      return;
    }
    final previous = _session;
    if (previous != null) {
      _replacing = true;
      try {
        await IosNativePlayer.command('stop');
        await previous.future;
      } finally {
        _replacing = false;
      }
      if (!context.mounted) return;
    }
    final session = Completer<void>();
    _session = session;
    _preparing = true;
    var finished = Completer<void>();
    var failedEarly = false;
    // [offset] is where a converted movie's own timeline starts in the film.
    double position = 0, offset = 0;
    StreamSubscription<Map<String, dynamic>>? subscription;
    StreamSubscription<void>? invalidation;
    final guide = ProgrammeGuide((id) => NativeBridge.instance.getNowNext(id));
    String? title;
    LiveRelay? relay;
    void updateTitle() {
      final next = guide.playbackTitle(channel);
      if (next == title || finished.isCompleted) return;
      title = next;
      unawaited(
        IosNativePlayer.command('setTitle', {'title': next}).catchError((_) {}),
      );
    }

    void finish() {
      if (!finished.isCompleted) finished.complete();
    }

    final library = MediaLibrary.instance;
    try {
      final headers =
          channel.playbackHeaders ??
          (channel.id == null
              ? null
              : await NativeBridge.instance.getChannelHeaders(channel.id!));
      final saved =
          channel.mediaType == MediaType.movie &&
              !channel.transient &&
              channel.id != null
          ? await NativeBridge.instance.getMoviePosition(channel.id!)
          : null;
      if (!context.mounted) return;
      final sent = {
        if (headers?.userAgent != null) 'User-Agent': headers!.userAgent!,
        if (headers?.referrer != null) 'Referer': headers!.referrer!,
        if (headers?.httpOrigin != null) 'Origin': headers!.httpOrigin!,
      };
      // Live transport streams are inspected first: some need repackaging
      // before Apple's player can show them.
      final live =
          channel.mediaType == MediaType.livestream &&
          !channel.isLocal &&
          (channel.url!.startsWith('http://') ||
              channel.url!.startsWith('https://'));
      Future<LivePreparation> prepare({required bool force}) => prepareLive(
        channel.url!,
        sent,
        ignoreSsl: headers?.ignoreSSL == 'true',
        force: force,
      );
      // Movies and episodes in a container Apple cannot open (MKV, AVI…) are
      // converted as they play; others get the same treatment if rejected.
      final file =
          channel.mediaType != MediaType.livestream &&
          !channel.isLocal &&
          (channel.url!.startsWith('http://') ||
              channel.url!.startsWith('https://'));
      Future<LivePreparation> convert() => prepareMovie(
        channel.url!,
        sent,
        ignoreSsl: headers?.ignoreSSL == 'true',
        start: saved?.toDouble() ?? 0,
      );
      var canFallBack = false;
      if (live) {
        final known = library.preferences;
        final prepared = await _busy(
          context,
          'Opening channel…',
          prepare(
            force:
                known.relayAlways || known.relayChannels.contains(channel.id),
          ),
        );
        if (prepared == null || !context.mounted) return;
        if (prepared.failed) {
          libraryMessage(context, _unplayable);
          return;
        }
        relay = prepared.relay;
        canFallBack = prepared.canFallBack;
      } else if (file && !appleContainer(channel.url!)) {
        final prepared = await _busy(context, 'Preparing video…', convert());
        if (prepared == null || !context.mounted) return;
        if (prepared.relay == null) {
          libraryMessage(context, prepared.message ?? _unconvertible);
          return;
        }
        relay = prepared.relay;
        offset = prepared.offset;
      } else {
        canFallBack = file;
      }
      subscription = IosNativePlayer.events.listen(
        (event) {
          if (event['position'] is num) {
            position = (event['position'] as num).toDouble();
          }
          if (event['type'] == 'closed') {
            failedEarly = event['failed'] == true;
            finish();
          }
        },
        onError: (_) => finish(),
        onDone: finish,
      );
      library.playing = channel.isLocal ? null : channel;
      library.closePlayer = () async {
        await IosNativePlayer.command('stop');
        await session.future;
      };
      while (true) {
        final current = relay;
        await IosNativePlayer.open(
          Feed(channel, current?.playlistUrl ?? channel.url!),
          settings,
          // The loopback playlist needs none of the provider's headers.
          headers: current == null ? sent : const {},
          // A converted movie already starts where it was left.
          startSeconds: current != null && file ? 0 : saved?.toDouble() ?? 0,
          fromStart: current != null && file,
          isLive: channel.mediaType == MediaType.livestream,
          quietFailure: current == null && canFallBack,
        );
        _preparing = false;
        if (current != null && live) {
          // Without FFmpeg the playlist stops growing; do not leave a
          // frozen picture on screen.
          unawaited(
            current.ended.then((_) {
              if (identical(relay, current) && !finished.isCompleted) {
                IosNativePlayer.command('stop').catchError((_) {});
              }
            }),
          );
        }
        if (title == null) {
          guide.addListener(updateTitle);
          guide.setVisible([channel]);
          guide.setActive(guideEnabled(channel, settings, player: true));
          if (!channel.transient) {
            invalidation = NativeBridge.instance.catalogChanges.listen((_) {
              guide.invalidate();
            });
          }
        }
        await finished.future;
        if (current != null || !canFallBack || !failedEarly) break;
        if (!context.mounted) break;
        // Apple's player rejected the provider's own stream: repackage it,
        // and go straight there for this channel from now on.
        _preparing = true;
        final prepared = await _busy(
          context,
          live ? 'Opening channel…' : 'Preparing video…',
          live ? prepare(force: true) : convert(),
        );
        if (prepared == null || !context.mounted) break;
        if (prepared.relay == null) {
          libraryMessage(
            context,
            prepared.message ?? (live ? _unplayable : _unconvertible),
          );
          break;
        }
        relay = prepared.relay;
        offset = prepared.offset;
        position = 0;
        final id = channel.id;
        final known = library.preferences.relayChannels;
        if (live && id != null && !known.contains(id)) {
          known.add(id);
          if (known.length > 300) known.removeAt(0);
          unawaited(library.savePreferences().catchError((_) {}));
        }
        finished = Completer<void>();
        failedEarly = false;
        title = null;
        guide.removeListener(updateTitle);
        await invalidation?.cancel();
        invalidation = null;
      }
    } catch (error) {
      if (context.mounted) {
        libraryMessage(
          context,
          error is PlatformException && error.code == 'headers'
              ? 'Apple’s player cannot play sources that require these custom headers.'
              : 'Apple’s player could not open this video. The format may not be supported.',
        );
      }
    } finally {
      finish();
      await invalidation?.cancel();
      guide.dispose();
      try {
        await IosNativePlayer.command('stop');
      } catch (_) {
        /* Keep the library available if the native channel fails. */
      }
      await subscription?.cancel();
      await relay?.close();
      if (channel.mediaType == MediaType.movie &&
          !channel.transient &&
          channel.id != null &&
          position.isFinite &&
          position > 0) {
        try {
          await NativeBridge.instance.setMoviePosition(
            channel.id!,
            (offset + position).toInt(),
          );
        } catch (_) {
          /* Closing playback must not depend on a database write. */
        }
      }
      library.playing = null;
      library.closePlayer = null;
      _preparing = false;
      _session = null;
      session.complete();
    }
  }

  static const _unconvertible =
      'This video could not be prepared for Apple’s player. Try Download instead.';

  /// Prefer Apple's player first for known containers and opaque addresses.
  static bool appleContainer(String url) {
    final extension = _extension(url);
    return extension.isEmpty ||
        const {'mp4', 'm4v', 'mov', 'm3u8'}.contains(extension);
  }

  static String _extension(String url) {
    final name = Uri.tryParse(url)?.pathSegments.lastOrNull ?? '';
    return name.contains('.') ? name.split('.').last.toLowerCase() : '';
  }

  static const _unplayable =
      'This channel could not be prepared for Apple’s player. It may be offline; try another feed.';

  /// Shows "Opening channel…" if [work] takes a moment. Null when the user
  /// cancels; the abandoned result is then cleaned up when it arrives.
  static Future<LivePreparation?> _busy(
    BuildContext context,
    String label,
    Future<LivePreparation> work,
  ) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final canceled = Completer<LivePreparation?>();
    var shown = false, done = false;
    final timer = Timer(const Duration(milliseconds: 400), () {
      if (done || !navigator.mounted) return;
      shown = true;
      showDialog<void>(
        context: navigator.context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: 20),
              Expanded(child: Text(label)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (!canceled.isCompleted) canceled.complete(null);
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    });
    try {
      final result = await Future.any([work, canceled.future]);
      if (result == null) {
        unawaited(work.then((late) => late.relay?.close()).catchError((_) {}));
      }
      return result;
    } finally {
      done = true;
      timer.cancel();
      if (shown && navigator.mounted) navigator.pop();
    }
  }
}

/// The outcome of inspecting a live stream before it is opened.
class LivePreparation {
  /// Running repackager to play from, or null to play the provider's stream.
  final LiveRelay? relay;

  /// The provider's stream is a transport stream, so the repackager can take
  /// over if Apple's player rejects it.
  final bool canFallBack;

  /// The stream needs repackaging and that could not be started.
  final bool failed;

  /// Seconds into the film at which a converted movie begins.
  final double offset;

  /// Why a movie could not be converted, when there is something to say.
  final String? message;
  const LivePreparation({
    this.relay,
    this.canFallBack = false,
    this.failed = false,
    this.offset = 0,
    this.message,
  });

  /// Converts the file at [url] from [start] seconds in, through the relay.
  static Future<LivePreparation> movie(
    String url,
    Map<String, String> headers, {
    required bool ignoreSsl,
    required double start,
    Future<LiveRelay> Function()? open,
    Future<int> Function(String folder)? freeSpace,
  }) async {
    final LiveRelay relay;
    try {
      relay =
          await (open ??
              () => LiveRelay.open(
                url,
                headers: headers,
                ignoreSsl: ignoreSsl,
                seekable: true,
              ))();
    } catch (_) {
      return const LivePreparation(failed: true);
    }
    final name = IosPlayer._extension(url);
    final extension = RegExp(r'^[a-z0-9]{1,5}$').hasMatch(name) ? name : 'mkv';
    final info = await relay.probe(extension);
    final plan = info == null ? null : MoviePlan(info);
    if (plan?.video == null) {
      await relay.close();
      return const LivePreparation(failed: true);
    }
    // The converted film is kept on the phone while it plays.
    try {
      final free = await (freeSpace ?? NativeBridge.instance.getDiskSpace)(
        relay.directory.path,
      );
      if (plan!.size > 0 && free < plan.size + 256 * 1024 * 1024) {
        await relay.close();
        return LivePreparation(
          failed: true,
          message:
              'Not enough free space to play this video: it needs about ${(plan.size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB while it plays.',
        );
      }
    } catch (_) {
      /* Unknown space: FFmpeg stops if the phone fills up. */
    }
    final resume = plan!.resumePosition(start);
    if (await relay.startMovie(plan, extension, start: resume)) {
      return LivePreparation(relay: relay, offset: resume);
    }
    await relay.close();
    return const LivePreparation(failed: true);
  }

  static Future<LivePreparation> run(
    String url,
    Map<String, String> headers, {
    required bool ignoreSsl,
    required bool force,
    Future<LiveRelay> Function()? open,
  }) async {
    final LiveRelay relay;
    try {
      relay =
          await (open ??
              () => LiveRelay.open(
                url,
                headers: headers,
                ignoreSsl: ignoreSsl,
              ))();
    } catch (_) {
      // Unreachable as a plain stream. Its HLS address may still work, and
      // Apple's player reports the failure if not.
      return const LivePreparation();
    }
    final plan = relay.plan;
    if (plan.known && (force || plan.required)) {
      if (await relay.start()) return LivePreparation(relay: relay);
      await relay.close();
      return LivePreparation(failed: plan.required);
    }
    await relay.close();
    return LivePreparation(canFallBack: plan.known);
  }
}
