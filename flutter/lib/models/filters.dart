import 'package:brentv/models/media_type.dart';
import 'package:brentv/models/sort_type.dart';
import 'package:brentv/models/view_type.dart';

class Filters {
  bool hiddenOnly;
  bool includeHidden;

  String? query;
  List<int>? sourceIds;
  List<MediaType>? mediaTypes;
  ViewType viewType;
  int page;
  int? seriesId;
  int? seasonId;
  int? groupId;
  bool useKeywords;
  SortType sort;

  /// List the favourite categories instead of channels.
  bool favoriteGroups;

  Filters({
    this.hiddenOnly = false,
    this.includeHidden = false,

    this.query,
    this.sourceIds,
    this.mediaTypes,
    required this.viewType,
    this.page = 1,
    this.seriesId,
    this.seasonId,
    this.groupId,
    this.useKeywords = false,
    this.sort = SortType.provider,
    this.favoriteGroups = false,
  });
}
