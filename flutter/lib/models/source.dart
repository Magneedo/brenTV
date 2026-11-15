import 'package:brentv/generated/generated_proto.pb.dart' as pb;
import 'package:brentv/models/source_type.dart';

class Source {
  String? epgUrl;

  int? id;
  String name;
  String? url;
  String? urlOrigin;
  String? username;
  String? password;
  SourceType sourceType;
  bool enabled;
  String? userAgent;
  String? streamUserAgent;
  bool importLive;
  bool importMovies;
  bool importSeries;
  pb.RefreshStats? lastRefreshStats;

  Source({
    this.epgUrl,

    this.id,
    required this.name,
    this.url,
    this.urlOrigin,
    this.username,
    this.password,
    required this.sourceType,
    this.enabled = true,
    this.userAgent,
    this.streamUserAgent,
    this.importLive = true,
    this.importMovies = true,
    this.importSeries = true,
    this.lastRefreshStats,
  });
}
