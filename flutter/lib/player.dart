import 'library/download_ui.dart';
import 'library/recording_ui.dart';
import 'library/media_library.dart';
import 'package:brentv/playback/feeds.dart';
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:brentv/models/channel.dart';
import 'package:brentv/models/id_data.dart';
import 'package:brentv/models/media_type.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkvideo;
import 'package:brentv/models/settings.dart';
import 'package:brentv/native_bridge.dart';
import 'package:brentv/select_dialog.dart';
import 'package:brentv/error.dart';
import 'package:brentv/programme_guide.dart';

/// Reopen attempts are bounded until playback makes forward progress.
class ReconnectBudget {
  int attempts = 0;
  Duration? nextDelay() =>
      attempts < 3 ? Duration(seconds: 1 << attempts++) : null;
  void reset() => attempts = 0;
}

class Player extends StatefulWidget {
  final Channel channel;
  final Settings settings;
  final int? navigationId;

  /// The list the channel was picked from, for next/previous channel.
  final List<Channel> siblings;
  const Player({
    super.key,
    required this.channel,
    required this.settings,
    this.siblings = const [],
    this.navigationId,
  });
  @override
  State<StatefulWidget> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  late mk.Player player = mk.Player();
  late mkvideo.VideoController videoController = mkvideo.VideoController(
    player,
  );
  late final GlobalKey<VideoState> key = GlobalKey<VideoState>();
  late Channel channel = widget.channel;
  late Feed feed = Feed(channel, channel.url!);
  bool switching = false;
  int playbackGeneration = 0;
  bool reconnecting = false;
  bool reconnectPending = false;
  final reconnectBudget = ReconnectBudget();
  Duration? lastPosition;
  Duration recoveryProgress = Duration.zero;
  Timer? idleCheck;
  bool checkingIdle = false;
  bool exhausted = false;
  bool opening = true;
  late int? navigationId = widget.navigationId ?? widget.channel.id;
  bool exiting = false;
  bool fill = false;
  List<StreamSubscription> subscriptions = [];
  late final _guide = ProgrammeGuide(
    (id) => NativeBridge.instance.getNowNext(id),
  );
  String? _programmeTitle;

  Future<void> _reloadGuide() async {
    _guide.setActive(false);
    _guide.invalidate();
    try {
      final settings = await NativeBridge.instance.getSettings();
      if (!mounted || exiting) return;
      widget.settings.showProgrammes = settings.showProgrammes;
      widget.settings.guidePlayerTitles = settings.guidePlayerTitles;
      widget.settings.enableXmltv = settings.enableXmltv;
      _guide.setVisible([channel]);
      _guide.setActive(guideEnabled(channel, widget.settings, player: true));
      _programmeChanged();
    } catch (_) {
      /* Keep guide requests stopped when settings cannot be read. */
    }
  }

  void _programmeChanged() {
    if (!mounted || exiting) return;
    final title =
        widget.settings.showProgrammes && widget.settings.guidePlayerTitles
        ? _guide.playbackTitle(channel)
        : channel.name;
    if (title == _programmeTitle) return;
    setState(() => _programmeTitle = title);
    if (player.platform is mk.NativePlayer) {
      unawaited(
        (player.platform as mk.NativePlayer)
            .setProperty('force-media-title', title)
            .catchError((_) {}),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _guide.addListener(_programmeChanged);
    subscriptions.add(
      NativeBridge.instance.catalogChanges.listen((_) => _reloadGuide()),
    );
    mk.MediaKit.ensureInitialized();
    initAsync();
  }

  Future<void> initAsync() async {
    player.setPlaylistMode(mk.PlaylistMode.none);
    await setMpvOptions();
    if (!mounted) return;
    subscriptions.add(
      player.stream.width.listen((_) {
        if (mounted) setState(() {});
      }),
    );
    subscriptions.add(
      player.stream.height.listen((_) {
        if (mounted) setState(() {});
      }),
    );
    // media_kit can report playing=true after libmpv has failed an open.
    // Native idle is authoritative; error-level logs can be recoverable.
    idleCheck = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (checkingIdle ||
          opening ||
          switching ||
          reconnecting ||
          exiting ||
          !mounted ||
          player.platform is! mk.NativePlayer) {
        return;
      }
      checkingIdle = true;
      final generation = playbackGeneration;
      try {
        final idle = await (player.platform as mk.NativePlayer).getProperty(
          'idle-active',
        );
        if (mounted &&
            !exiting &&
            !opening &&
            !switching &&
            generation == playbackGeneration &&
            idle == 'yes') {
          onDisconnect();
        }
      } catch (_) {
        // Disposal can race an outstanding property request.
      } finally {
        checkingIdle = false;
      }
    });
    subscriptions.add(
      player.stream.position.listen((position) {
        if (opening || switching) return;
        final previous = lastPosition;
        if (previous == null) {
          lastPosition = position;
          return;
        }
        if (position > previous) {
          recoveryProgress += position - previous;
          lastPosition = position;
          if (recoveryProgress >= const Duration(seconds: 3)) {
            reconnectBudget.reset();
            exhausted = false;
          }
        }
      }),
    );
    subscriptions.add(
      player.stream.completed.listen((completed) {
        if (completed) onDisconnect();
      }),
    );
    final generation = playbackGeneration;
    final initialChannel = channel.id;
    final seconds = channel.mediaType == MediaType.movie && !channel.transient
        ? (await Error.tryAsyncNoLoading(() async {
            return await NativeBridge.instance.getMoviePosition(channel.id!);
          }, context)).data
        : null;
    if (!mounted ||
        generation != playbackGeneration ||
        initialChannel != channel.id) {
      return;
    }
    final started = await _startPlayback(
      seconds != null ? Duration(seconds: seconds) : null,
    );
    if (!started) onDisconnect();
    if (!mounted) return;
  }

  Future<void> setMpvOptions() async {
    if (player.platform is mk.NativePlayer) {
      final nativePlayer = player.platform as mk.NativePlayer;
      if (channel.mediaType == MediaType.livestream) {
        if (widget.settings.lowLatency) {
          await nativePlayer.setProperty('profile', 'low-latency');
        }
      }
    }
  }

  void onDisconnect() async {
    if (reconnecting) {
      reconnectPending = true;
      return;
    }
    if (!mounted ||
        exiting ||
        switching ||
        channel.mediaType != MediaType.livestream) {
      return;
    }
    if (reconnectBudget.attempts >= 3) {
      if (!exhausted) {
        exhausted = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stream unavailable. Try another channel.'),
          ),
        );
      }
      return;
    }
    reconnecting = true;
    reconnectPending = false;
    final generation = playbackGeneration;
    try {
      while (reconnectBudget.attempts < 3 &&
          mounted &&
          !exiting &&
          generation == playbackGeneration &&
          channel.mediaType == MediaType.livestream) {
        await Future<void>.delayed(reconnectBudget.nextDelay()!);
        if (!mounted || exiting || generation != playbackGeneration) return;
        if (await _startPlayback(null)) return;
      }
      if (mounted &&
          !exiting &&
          generation == playbackGeneration &&
          reconnectBudget.attempts >= 3) {
        exhausted = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stream unavailable. Try another channel.'),
          ),
        );
      }
    } finally {
      reconnecting = false;
      if (mounted &&
          !exiting &&
          (reconnectPending ||
              (generation != playbackGeneration && player.state.completed))) {
        onDisconnect();
      }
    }
  }

  int? _recordedChannel;

  bool _armingRecord = false, _recordProbe = false;

  /// Saves the stream the player is showing to [file], or stops when null.
  Future<bool> _record(String? file) async {
    if (player.platform is! mk.NativePlayer) return false;
    final native = player.platform as mk.NativePlayer;
    try {
      if (file == null) {
        await native.setProperty('stream-record', '');
        if (_recordProbe) {
          // Back to the low-latency profile's fast open for the next channel.
          _recordProbe = false;
          await native.setProperty('demuxer-lavf-probe-info', 'nostreams');
          await native.setProperty('demuxer-lavf-analyzeduration', '0.1');
        }
        return true;
      }
      if (!widget.settings.lowLatency ||
          channel.mediaType != MediaType.livestream) {
        await native.setProperty('stream-record', file);
        return true;
      }
      // The low-latency profile opens a stream without reading its codec
      // details, which mpv's recorder needs: open it again with them.
      await native.setProperty('demuxer-lavf-probe-info', 'auto');
      await native.setProperty('demuxer-lavf-analyzeduration', '0.5');
      _recordProbe = true;
      await native.setProperty('stream-record', file);
      _armingRecord = true;
      try {
        return await _startPlayback(null);
      } finally {
        _armingRecord = false;
      }
    } catch (_) {
      return false;
    }
  }

  Future<bool> _startPlayback(Duration? startPosition) async {
    final generation = playbackGeneration;
    if (!mounted || exiting) return false;
    opening = true;
    try {
      if (!await prepareLibraryPlayback(context, channel)) {
        return false;
      }
      MediaLibrary.instance.closePlayer = () async {
        if (mounted) onExit();
      };
      if (!_armingRecord) {
        // Opening again would overwrite the file the player is recording into.
        await _record(null);
        unawaited(
          MediaLibrary.instance.playerStreamEnded(
            reloading: _recordedChannel == channel.id,
          ),
        );
      }
      _recordedChannel = channel.id;
      MediaLibrary.instance.playerRecord = _record;
      final headers =
          channel.playbackHeaders ??
          (channel.id == null
              ? null
              : await NativeBridge.instance.getChannelHeaders(channel.id!));
      if (!mounted || exiting || generation != playbackGeneration) return false;
      if (player.platform is mk.NativePlayer) {
        await (player.platform as mk.NativePlayer).setProperty(
          'hls-bitrate',
          feed.maxBitrate?.toString() ?? 'max',
        );
      }
      if (!mounted || exiting || generation != playbackGeneration) return false;
      lastPosition = null;
      recoveryProgress = Duration.zero;
      await player.open(
        mk.Media(
          feed.url,
          start: startPosition,
          httpHeaders: headers == null
              ? null
              : {
                  if (headers.referrer != null) 'Referer': headers.referrer!,
                  if (headers.httpOrigin != null) 'Origin': headers.httpOrigin!,
                  if (headers.userAgent != null)
                    'User-Agent': headers.userAgent!,
                },
        ),
      );
      if (!mounted || exiting || generation != playbackGeneration) return false;
      unawaited(MediaLibrary.instance.resumePlayerRecordings());
      _programmeTitle = null;
      _guide.setVisible([channel]);
      _guide.setActive(guideEnabled(channel, widget.settings, player: true));
      _programmeChanged();
      if (Platform.isAndroid) {
        await key.currentState?.enterFullscreen();
      }
      return true;
    } catch (_) {
      if (channel.mediaType != MediaType.livestream && mounted) {
        await Error.handleError(context, 'Unable to open this stream.');
      }
      return false;
    } finally {
      if (generation == playbackGeneration) opening = false;
    }
  }

  Future<void> switchFeed(Feed chosen) async {
    if (switching || exiting) return;
    if (!await prepareLibraryPlayback(context, chosen.channel)) {
      return;
    }
    if (!mounted) return;
    switching = true;
    playbackGeneration++;
    reconnectBudget.reset();
    exhausted = false;
    lastPosition = null;
    final sameChannel = chosen.channel.sameAs(channel);
    final position = sameChannel && channel.mediaType == MediaType.movie
        ? player.state.position
        : null;
    var started = false;
    try {
      if (!sameChannel) {
        if (channel.mediaType == MediaType.movie && !channel.transient) {
          await NativeBridge.instance.setMoviePosition(
            channel.id!,
            player.state.position.inSeconds,
          );
        }
        if (!chosen.channel.transient) {
          await NativeBridge.instance.addLastWatched(chosen.channel.id!);
        }
      }
      if (!mounted) return;
      setState(() {
        channel = chosen.channel;
        feed = chosen;
      });
      started = await _startPlayback(position);
    } catch (_) {
      if (mounted) await Error.handleError(context, 'Unable to switch feeds.');
    } finally {
      switching = false;
      if (!started) onDisconnect();
    }
  }

  Future<void> adjacent(int delta) async {
    if (switching || exiting) return;
    final generation = playbackGeneration;
    final playable = widget.siblings
        .where((c) => c.isPlayable && (!c.transient || c.isLocal))
        .toList();
    final index = playable.indexWhere(
      (c) => navigationId != null ? c.id == navigationId : c.sameAs(channel),
    );
    if (index < 0 || index + delta < 0 || index + delta >= playable.length) {
      return;
    }
    final next = playable[index + delta];
    final resolved = await preferredChannel(await offlineChannel(next));
    if (!mounted || exiting || switching || generation != playbackGeneration) {
      return;
    }
    navigationId = next.id;
    await switchFeed(Feed(resolved, resolved.url!));
  }

  List<Widget> get channelControls => [
    IconButton(
      tooltip: 'Previous channel',
      onPressed: () => adjacent(-1),
      icon: const Icon(Icons.skip_previous, color: Colors.white),
    ),
    IconButton(
      tooltip: 'Next channel',
      onPressed: () => adjacent(1),
      icon: const Icon(Icons.skip_next, color: Colors.white),
    ),
  ];

  String get resolution =>
      player.state.width != null && player.state.height != null
      ? '${player.state.width} × ${player.state.height}'
      : '';

  @override
  void dispose() {
    MediaLibrary.instance.playing = null;
    MediaLibrary.instance.closePlayer = null;
    MediaLibrary.instance.playerRecord = null;
    _guide.dispose();
    idleCheck?.cancel();
    for (final s in subscriptions) {
      s.cancel();
    }
    // Once the player is gone it has closed the file it was recording into.
    player.dispose().whenComplete(MediaLibrary.instance.playerStreamEnded);
    super.dispose();
  }

  Future<void> openSubtitlesModal() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => SelectDialog(
        title: "Select subtitles",
        action: (id) async {
          player.setSubtitleTrack(player.state.tracks.subtitle[id]);
          Navigator.of(context).pop();
        },
        data: player.state.tracks.subtitle
            .asMap()
            .entries
            .map(
              (entry) => IdData(
                id: entry.key,
                data: entry.value.language != null
                    ? "${entry.value.language} - ${entry.value.id}"
                    : entry.value.id,
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> openAudioModal() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => SelectDialog(
        title: "Select audio",
        action: (id) async {
          player.setAudioTrack(player.state.tracks.audio[id]);
          Navigator.of(context).pop();
        },
        data: player.state.tracks.audio
            .asMap()
            .entries
            .map(
              (entry) => IdData(
                id: entry.key,
                data:
                    entry.value.title ?? entry.value.language ?? entry.value.id,
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        if (Platform.isLinux &&
            widget.settings.keyboardShortcuts &&
            channel.mediaType == MediaType.livestream)
          const SingleActivator(LogicalKeyboardKey.keyR): () =>
              toggleRecording(context, channel),
        const SingleActivator(LogicalKeyboardKey.pageUp): () => adjacent(1),
        const SingleActivator(LogicalKeyboardKey.pageDown): () => adjacent(-1),
        const SingleActivator(LogicalKeyboardKey.channelUp): () => adjacent(1),
        const SingleActivator(LogicalKeyboardKey.channelDown): () =>
            adjacent(-1),
        const SingleActivator(LogicalKeyboardKey.mediaTrackNext): () =>
            adjacent(1),
        const SingleActivator(LogicalKeyboardKey.mediaTrackPrevious): () =>
            adjacent(-1),
      },
      child: Focus(
        autofocus: true,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            onExit();
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            body: MaterialVideoControlsTheme(
              normal: getThemeData(context),
              fullscreen: getThemeData(context),
              child: MaterialDesktopVideoControlsTheme(
                normal: getDesktopThemeData(context),
                fullscreen: getDesktopThemeData(context),
                child: Video(
                  key: key,
                  controller: videoController,
                  onExitFullscreen: (Platform.isAndroid || Platform.isIOS)
                      ? () async => onExit()
                      : defaultExitNativeFullscreen,
                  controls: AdaptiveVideoControls,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void onExit() async {
    if (exiting) return;
    exiting = true;
    if (channel.mediaType == MediaType.movie && !channel.transient) {
      NativeBridge.instance.setMoviePosition(
        channel.id!,
        player.state.position.inSeconds,
      );
    }
    if (key.currentState?.isFullscreen() == true) {
      await key.currentState!.exitFullscreen();
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void toggleZoom() {
    if (player.state.width == null ||
        player.state.height == null ||
        player.state.height == 0) {
      return;
    }
    final videoAspectRatio = player.state.width! / player.state.height!;
    final deviceAspectRatio = MediaQuery.of(context).size.aspectRatio;
    key.currentState!.update(
      aspectRatio: fill ? videoAspectRatio : deviceAspectRatio,
    );
    setState(() {
      fill = !fill;
    });
  }

  MaterialVideoControlsThemeData getThemeData(BuildContext context) {
    return MaterialVideoControlsThemeData(
      speedUpOnLongPress: false,
      seekOnDoubleTap: channel.mediaType != MediaType.livestream,
      displaySeekBar: channel.mediaType != MediaType.livestream,
      seekBarMargin: const EdgeInsets.only(bottom: 60),
      seekBarThumbSize: 20,
      seekBarHeight: 10,
      seekGesture: channel.mediaType != MediaType.livestream,
      topButtonBar: [
        IconButton(
          onPressed: onExit,
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            _programmeTitle ?? channel.name,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (resolution.isNotEmpty) Text(resolution),
      ],
      bottomButtonBar: [
        ...channelControls,
        if (Platform.isLinux && channel.mediaType == MediaType.livestream)
          RecordControl(channel: channel),
        if (Platform.isLinux && channel.mediaType == MediaType.livestream)
          const SizedBox(width: 20),
        IconButton(
          onPressed: openSubtitlesModal,
          icon: const Icon(Icons.subtitles, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 20),
        IconButton(
          onPressed: openAudioModal,
          icon: const Icon(Icons.music_note, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 20),
        IconButton(
          icon: const Icon(
            Icons.aspect_ratio_outlined,
            color: Colors.white,
            size: 32,
          ),
          onPressed: toggleZoom,
        ),
        if (!(Platform.isAndroid || Platform.isIOS)) ...[
          const Spacer(),
          const MaterialFullscreenButton(iconSize: 32, iconColor: Colors.white),
        ],
      ],
    );
  }

  MaterialDesktopVideoControlsThemeData getDesktopThemeData(
    BuildContext context,
  ) {
    return MaterialDesktopVideoControlsThemeData(
      keyboardShortcuts: {
        if (Platform.isLinux &&
            widget.settings.keyboardShortcuts &&
            channel.mediaType == MediaType.livestream)
          const SingleActivator(LogicalKeyboardKey.keyR): () =>
              toggleRecording(context, channel),
        const SingleActivator(LogicalKeyboardKey.pageUp): () => adjacent(1),
        const SingleActivator(LogicalKeyboardKey.pageDown): () => adjacent(-1),
        const SingleActivator(LogicalKeyboardKey.channelUp): () => adjacent(1),
        const SingleActivator(LogicalKeyboardKey.channelDown): () =>
            adjacent(-1),
        const SingleActivator(LogicalKeyboardKey.mediaTrackNext): () =>
            adjacent(1),
        const SingleActivator(LogicalKeyboardKey.mediaTrackPrevious): () =>
            adjacent(-1),
        const SingleActivator(LogicalKeyboardKey.mediaPlay): player.play,
        const SingleActivator(LogicalKeyboardKey.mediaPause): player.pause,
        const SingleActivator(LogicalKeyboardKey.mediaPlayPause):
            player.playOrPause,
        const SingleActivator(LogicalKeyboardKey.space): player.playOrPause,
        const SingleActivator(LogicalKeyboardKey.keyJ): () =>
            player.seek(player.state.position - const Duration(seconds: 10)),
        const SingleActivator(LogicalKeyboardKey.keyI): () =>
            player.seek(player.state.position + const Duration(seconds: 10)),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            player.seek(player.state.position - const Duration(seconds: 2)),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            player.seek(player.state.position + const Duration(seconds: 2)),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            player.setVolume((player.state.volume + 5).clamp(0, 100)),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            player.setVolume((player.state.volume - 5).clamp(0, 100)),
        const SingleActivator(LogicalKeyboardKey.keyF): () =>
            key.currentState?.toggleFullscreen(),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            key.currentState?.exitFullscreen(),
      },
      seekBarMargin: const EdgeInsets.only(bottom: 60),
      seekBarThumbSize: 20,
      seekBarHeight: 10,
      displaySeekBar: channel.mediaType != MediaType.livestream,
      hideMouseOnControlsRemoval: true,
      controlsHoverDuration: const Duration(seconds: 3),
      topButtonBar: [
        IconButton(
          onPressed: onExit,
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            _programmeTitle ?? channel.name,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (resolution.isNotEmpty) Text(resolution),
      ],
      bottomButtonBar: [
        ...channelControls,
        if (Platform.isLinux && channel.mediaType == MediaType.livestream)
          RecordControl(channel: channel),
        if (Platform.isLinux && channel.mediaType == MediaType.livestream)
          const SizedBox(width: 20),
        IconButton(
          onPressed: openSubtitlesModal,
          icon: const Icon(Icons.subtitles, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 20),
        IconButton(
          onPressed: openAudioModal,
          icon: const Icon(Icons.music_note, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 20),
        IconButton(
          icon: const Icon(
            Icons.aspect_ratio_outlined,
            color: Colors.white,
            size: 32,
          ),
          onPressed: toggleZoom,
        ),
        const Spacer(),
        const MaterialDesktopFullscreenButton(
          iconSize: 32,
          iconColor: Colors.white,
        ),
      ],
    );
  }
}
