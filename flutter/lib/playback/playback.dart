import '../library/download_ui.dart';
import '../library/recording_ui.dart';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:brentv/models/channel.dart';
import 'package:brentv/models/media_type.dart';
import 'package:brentv/models/settings.dart';
import 'package:brentv/native_bridge.dart';
import 'package:brentv/player.dart';
import 'package:brentv/playback/external_mpv.dart';
import 'package:brentv/playback/ios_player.dart';
import 'package:brentv/playback/feeds.dart';

/// Opens a channel in the player that fits the platform and settings:
/// Linux uses external mpv unless the built-in player is chosen; iOS uses
/// Apple's full-screen system player exclusively. The built-in media_kit
/// player is available only on desktop.
///
/// [siblings] is the list the channel was picked from, for next/previous.
class Playback {
  static Future<void> play(
    BuildContext context,
    Channel channel, {
    List<Channel> siblings = const [],
    Settings? settings,
  }) async {
    final listedChannel = channel;
    channel = await offlineChannel(channel);
    if (!context.mounted) return;
    if (!await prepareLibraryPlayback(context, channel)) {
      return;
    }
    if (!context.mounted) return;
    if (channel.mediaType == MediaType.livestream) {
      await showMediaTip(context, 'recording');
    }
    if (!context.mounted) return;
    settings ??= await NativeBridge.instance.getSettings();
    if (!channel.transient) NativeBridge.instance.addLastWatched(channel.id!);
    if (!context.mounted) return;
    if (Platform.isLinux && settings.linuxPlayer == LinuxPlayer.mpv) {
      await ExternalMpv.instance.play(
        context,
        listedChannel,
        settings,
        siblings: siblings,
      );
      return;
    }
    channel = await preferredChannel(channel);
    if (!context.mounted) return;
    if (Platform.isIOS) {
      await IosPlayer.open(context, channel, settings);
      return;
    }
    await openBuiltIn(
      context,
      channel,
      settings,
      siblings: siblings,
      navigationId: listedChannel.id,
    );
  }

  static Future<void> openBuiltIn(
    BuildContext context,
    Channel channel,
    Settings settings, {
    List<Channel> siblings = const [],
    int? navigationId,
  }) {
    if (Platform.isIOS) return IosPlayer.open(context, channel, settings);
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Player(
          channel: channel,
          settings: settings,
          siblings: siblings,
          navigationId: navigationId,
        ),
      ),
    );
  }
}
