import 'package:brentv/models/media_type.dart';
import 'bottom_bar.dart';
import 'package:brentv/models/sort_type.dart';
import 'package:brentv/models/view_type.dart';

class Settings {
  BottomBarConfig bottomBar;
  ViewType get effectiveStartPage => bottomBar.startPage(defaultView);
  bool numberKeySwitching;
  bool enableCatchup;
  bool enableFullGuide;
  bool enableXmltv;
  bool keyboardShortcuts;
  bool guidePlayerTitles;
  bool guideTileText;
  bool autoQualityDiscovery;
  int searchDelayMs;

  /// Read-only here: saved by setUiScale alone, so pages holding an older
  /// copy of the settings can't undo a zoom.
  int uiScalePercent;

  /// Saved by setSquareCorners alone, so older settings copies cannot undo it.
  final bool squareCorners;

  ViewType defaultView;
  SortType defaultSort;
  bool refreshOnStart;
  bool showLivestreams;
  bool lowLatency;
  bool showMovies;
  bool showSeries;
  bool showProgrammes;
  bool forceTVMode;
  LinuxPlayer linuxPlayer;
  String mpvPath;

  /// mpv --hwdec value; empty leaves it to mpv.conf.
  String hwdec;
  int cacheSecs;
  int demuxerMaxMb;
  String mpvExtraArgs;
  bool mpvReuseWindow;
  bool iosNativePlayer;
  bool iosPreferHls;
  bool backgroundAudio;
  bool autoPip;

  /// Start page category (with defaultView categories); null: the page itself.
  int? startGroupId;
  String? startGroupName;
  Settings({
    BottomBarConfig? bottomBar,
    this.numberKeySwitching = false,
    this.enableCatchup = true,
    this.enableFullGuide = true,
    this.enableXmltv = false,
    this.keyboardShortcuts = true,
    this.guidePlayerTitles = true,
    this.guideTileText = true,
    this.autoQualityDiscovery = true,
    this.searchDelayMs = 0,
    this.uiScalePercent = 100,
    this.squareCorners = false,

    this.defaultView = ViewType.all,
    this.defaultSort = SortType.provider,
    this.refreshOnStart = false,
    this.showLivestreams = true,
    this.lowLatency = false,
    this.showMovies = true,
    this.showSeries = true,
    this.showProgrammes = true,
    this.forceTVMode = false,
    this.linuxPlayer = LinuxPlayer.mpv,
    this.mpvPath = "mpv",
    this.hwdec = "auto-safe",
    this.cacheSecs = 10,
    this.demuxerMaxMb = 150,
    this.mpvExtraArgs = "",
    this.mpvReuseWindow = true,
    this.iosNativePlayer = true,
    this.iosPreferHls = true,
    this.backgroundAudio = true,
    this.autoPip = true,
    this.startGroupId,
    this.startGroupName,
  }) : bottomBar = bottomBar ?? BottomBarConfig.defaults();

  List<MediaType> getMediaTypes() {
    return [
      if (showLivestreams) MediaType.livestream,
      if (showMovies) MediaType.movie,
      if (showSeries) MediaType.serie,
    ];
  }
}

/// How Linux plays streams: an external mpv window or the built-in player.
enum LinuxPlayer { mpv, builtIn }
