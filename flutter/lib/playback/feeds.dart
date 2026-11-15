import 'package:brentv/generated/generated_proto.pb.dart' as pb;
import 'package:brentv/models/channel.dart';
import 'package:brentv/native_bridge.dart';

/// One entry of the quality selector: the channel's stream (Auto), one of its
/// HLS variants, or an alternate feed of the same channel.
///
/// For a variant, [url] is the master playlist and players cap the bitrate at
/// `variant.bandwidth` (mpv `hls-bitrate`, AVPlayer `preferredPeakBitRate`),
/// so audio and subtitle renditions of the master stay attached.
class Feed {
  final Channel channel;
  final String url;
  final pb.StreamVariant? variant;
  final bool alternate;

  const Feed(this.channel, this.url, {this.variant, this.alternate = false});

  bool get isAuto => variant == null && !alternate;

  /// Bitrate cap for this feed in bits per second, or null for no cap.
  int? get maxBitrate => variant?.bandwidth.toInt();

  String get label {
    final v = variant;
    if (v != null) return variantLabel(v);
    if (alternate) {
      final q = qualityLabel(channel.quality);
      return q.isEmpty ? channel.name : "$q · ${channel.name}";
    }
    return "Auto";
  }

  bool sameAs(Feed other) =>
      url == other.url &&
      maxBitrate == other.maxBitrate &&
      channel.sameAs(other.channel);
}

String qualityLabel(int quality) =>
    const ["", "SD", "HD", "FHD", "UHD"][quality.clamp(0, 4)];

/// "1080p60 · 6.2 Mb/s", leaving out what the playlist doesn't state.
String variantLabel(pb.StreamVariant v) {
  final parts = <String>[];
  if (v.hasHeight()) {
    final fps = v.hasFrameRate() && v.frameRate > 30
        ? v.frameRate.round().toString()
        : "";
    parts.add("${v.height}p$fps");
  } else if (v.hasName()) {
    parts.add(v.name);
  }
  final bps = (v.hasAverageBandwidth() ? v.averageBandwidth : v.bandwidth)
      .toInt();
  if (bps > 0) parts.add("${(bps / 1e6).toStringAsFixed(1)} Mb/s");
  return parts.isEmpty ? "Variant" : parts.join(" · ");
}

/// The `.m3u8` twin of an Xtream live `.ts` URL, or null.
String? xtreamHlsUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null ||
      !uri.path.contains("/live/") ||
      !uri.path.endsWith(".ts")) {
    return null;
  }
  return uri
      .replace(path: "${uri.path.substring(0, uri.path.length - 3)}.m3u8")
      .toString();
}

/// Selector entries for [channel]: Auto, the HLS variants its stream really
/// has, then its alternate feeds. A failed probe leaves its part out rather
/// than guessing, so unavailable qualities are never listed. When the probe
/// found a multi-variant master (possibly the `.m3u8` twin of a `.ts` URL),
/// Auto plays that master, adaptively.
Future<List<Feed>> loadFeeds(Channel channel) async {
  if (channel.transient) return [Feed(channel, channel.url!)];
  final url = channel.url!;
  final probe = xtreamHlsUrl(url) ?? url;
  final results = await Future.wait([
    NativeBridge.instance
        .getStreamVariants(channel.id!, probe)
        .catchError((_) => pb.StreamVariantList()),
    NativeBridge.instance
        .getAlternates(channel.id!)
        .catchError((_) => <Channel>[]),
  ]);
  return buildFeeds(
    channel,
    results[0] as pb.StreamVariantList,
    results[1] as List<Channel>,
  );
}

List<Feed> buildFeeds(
  Channel channel,
  pb.StreamVariantList list,
  List<Channel> alternates,
) {
  final url = channel.url!;
  final variants = List<pb.StreamVariant>.of(list.variants)
    ..sort((a, b) {
      final h = b.height.compareTo(a.height);
      return h != 0 ? h : b.bandwidth.compareTo(a.bandwidth);
    });
  final master = variants.length > 1 && list.masterUrl.isNotEmpty
      ? list.masterUrl
      : null;
  final feeds = <Feed>[Feed(channel, master ?? url)];
  if (master != null) {
    feeds.addAll(variants.map((v) => Feed(channel, master, variant: v)));
  }
  for (final alt in alternates) {
    if (alt.id != channel.id && alt.url?.isNotEmpty == true) {
      feeds.add(Feed(alt, alt.url!, alternate: true));
    }
  }
  return feeds;
}

/// Preferences are a local SQLite lookup; no network probe delays playback.
Future<Channel> preferredChannel(Channel channel) async {
  if (channel.mediaType.index != 0 || channel.id == null) return channel;
  try {
    final alternates = await NativeBridge.instance.getAlternates(channel.id!);
    return alternates.where((c) => c.preferred).firstOrNull ?? channel;
  } catch (_) {
    return channel;
  }
}
