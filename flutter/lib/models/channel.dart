import 'channel_http_headers.dart';
import 'package:brentv/models/media_type.dart';

class Channel {
  /// Playback without a catalog ID must not change saved channel state.
  bool get transient => id == null;

  bool get isLocal => transient && Uri.tryParse(url ?? '')?.scheme == 'file';

  /// Catalog rows keep their identity across URL changes. Transient playback
  /// (local files and catch-up) uses its URL instead of a shared null ID.
  bool sameAs(Channel? other) {
    if (other == null) return false;
    if (id != null || other.id != null) return id != null && id == other.id;
    return url?.isNotEmpty == true &&
        url == other.url &&
        sourceId == other.sourceId &&
        mediaType == other.mediaType;
  }

  ChannelHttpHeaders? playbackHeaders;
  bool hidden;
  int? archiveDays;
  String? epgId;

  int? id;
  String name;
  int? groupId;
  String? group;
  String? image;
  String? url;
  MediaType mediaType;
  int sourceId;
  bool favorite;
  int? seriesId;
  int? streamId;

  /// Parsed from the name: 0 unknown, 1 SD, 2 HD, 3 FHD, 4 UHD.
  int quality;
  bool preferred;

  /// Alternate-feed group; channels sharing it are the same channel.
  String? altKey;

  bool get isSeriesContainer =>
      mediaType == MediaType.serie && int.tryParse(url ?? '') != null;
  bool get isPlayable =>
      url?.isNotEmpty == true &&
      !isSeriesContainer &&
      (mediaType == MediaType.livestream ||
          mediaType == MediaType.movie ||
          mediaType == MediaType.serie);

  Channel({
    this.playbackHeaders,
    this.hidden = false,
    this.archiveDays,
    this.epgId,

    this.id,
    required this.name,
    this.group,
    this.groupId,
    this.image,
    this.url,
    required this.mediaType,
    required this.sourceId,
    required this.favorite,
    this.seriesId,
    this.streamId,
    this.quality = 0,
    this.preferred = false,
    this.altKey,
  });
}
