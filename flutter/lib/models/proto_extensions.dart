import 'package:fixnum/fixnum.dart';
import 'bottom_bar.dart';
import 'package:brentv/generated/generated_proto.pb.dart' as pb;
import 'package:brentv/models/channel.dart';
import 'package:brentv/models/source.dart';
import 'package:brentv/models/filters.dart';
import 'package:brentv/models/settings.dart';
import 'package:brentv/models/sort_type.dart';
import 'package:brentv/models/media_type.dart';
import 'package:brentv/models/view_type.dart';
import 'package:brentv/models/channel_http_headers.dart';
import 'package:brentv/models/source_type.dart';

extension ChannelProtoExtension on pb.Channel {
  Channel toDomain() => Channel(
    id: hasId() ? id.toInt() : null,
    name: name,
    group: hasGroup() ? group : null,
    groupId: hasGroupId() ? groupId.toInt() : null,
    image: hasImage() ? image : null,
    url: hasUrl() ? url : null,
    mediaType: MediaType.values[mediaType],
    sourceId: sourceId.toInt(),
    favorite: favorite,
    playbackHeaders: hasPlaybackHeaders() ? playbackHeaders.toDomain() : null,
    hidden: hidden,
    archiveDays: hasArchiveDays() ? archiveDays : null,
    epgId: hasEpgId() ? epgId : null,
    seriesId: hasSeriesId() ? seriesId.toInt() : null,
    streamId: hasStreamId() ? streamId.toInt() : null,
    quality: quality,
    altKey: hasAltKey() ? altKey : null,
  );
}

extension SourceProtoExtension on pb.Source {
  Source toDomain() => Source(
    id: hasId() ? id.toInt() : null,
    name: name,
    url: hasUrl() ? url : null,
    urlOrigin: hasUrlOrigin() ? urlOrigin : null,
    epgUrl: hasEpgUrl() ? epgUrl : null,
    username: hasUsername() ? username : null,
    password: hasPassword() ? password : null,
    sourceType: SourceType.values[sourceType],
    enabled: enabled,
    userAgent: hasUserAgent() ? userAgent : null,
    streamUserAgent: hasStreamUserAgent() ? streamUserAgent : null,
    importLive: hasImportLive() ? importLive : true,
    importMovies: hasImportMovies() ? importMovies : true,
    importSeries: hasImportSeries() ? importSeries : true,
    lastRefreshStats: hasLastRefreshStats() ? lastRefreshStats : null,
  );
}

extension SourceDomainExtension on Source {
  pb.Source toProto() => pb.Source(
    id: id != null ? Int64(id!) : null,
    name: name,
    url: url,
    urlOrigin: urlOrigin,
    epgUrl: epgUrl,
    username: username,
    password: password,
    sourceType: sourceType.index,
    enabled: enabled,
    userAgent: userAgent,
    streamUserAgent: streamUserAgent,
    importLive: importLive,
    importMovies: importMovies,
    importSeries: importSeries,
    lastRefreshStats: lastRefreshStats,
  );
}

extension FiltersDomainExtension on Filters {
  pb.Filters toProto() => pb.Filters(
    query: query,
    sourceIds: sourceIds?.map(Int64.new) ?? [],
    mediaTypes: mediaTypes?.map((m) => pb.MediaType.valueOf(m.index)!) ?? [],
    viewType: pb.ViewType.valueOf(viewType.index),
    page: page,
    seriesId: seriesId != null ? Int64(seriesId!) : null,
    season: seasonId != null ? Int64(seasonId!) : null,
    groupId: groupId != null ? Int64(groupId!) : null,
    useKeywords: useKeywords,
    sort: sort.index,
    favoriteGroups: favoriteGroups,
    hiddenOnly: hiddenOnly,
    includeHidden: includeHidden,
  );
}

extension SettingsProtoExtension on pb.Settings {
  Settings toDomain() => Settings(
    bottomBar: BottomBarConfig.decode(hasBottomBar() ? bottomBar : null),
    defaultView: hasDefaultView() && defaultView < ViewType.values.length
        ? ViewType.values[defaultView]
        : ViewType.all,
    defaultSort: hasDefaultSort()
        ? SortType.values[defaultSort]
        : SortType.provider,
    refreshOnStart: hasRefreshOnStart() ? refreshOnStart : false,
    lowLatency: hasUseStreamCaching() ? !useStreamCaching : false,
    forceTVMode: hasForceTvMode() ? forceTvMode : false,
    showLivestreams: hasShowLivestreams() ? showLivestreams : true,
    showMovies: hasShowMovies() ? showMovies : true,
    showSeries: hasShowSeries() ? showSeries : true,
    showProgrammes: hasShowProgrammes() ? showProgrammes : true,
    numberKeySwitching: hasNumberKeySwitching() ? numberKeySwitching : false,
    enableCatchup: hasEnableCatchup() ? enableCatchup : true,
    enableFullGuide: hasEnableFullGuide() ? enableFullGuide : true,
    enableXmltv: hasEnableXmltv() ? enableXmltv : false,
    keyboardShortcuts: hasKeyboardShortcuts() ? keyboardShortcuts : true,
    guidePlayerTitles: hasGuidePlayerTitles() ? guidePlayerTitles : true,
    guideTileText: hasGuideTileText() ? guideTileText : true,
    autoQualityDiscovery: hasAutoQualityDiscovery()
        ? autoQualityDiscovery
        : true,
    searchDelayMs: hasSearchDelayMs() ? searchDelayMs : 0,
    uiScalePercent: hasUiScalePercent() ? uiScalePercent.clamp(50, 300) : 100,
    squareCorners: squareCorners,

    linuxPlayer: hasLinuxPlayer() && linuxPlayer < LinuxPlayer.values.length
        ? LinuxPlayer.values[linuxPlayer]
        : LinuxPlayer.mpv,
    mpvPath: hasMpvPath() && mpvPath.trim().isNotEmpty ? mpvPath : "mpv",
    hwdec: hasHwdec() ? hwdec : "auto-safe",
    cacheSecs: hasCacheSecs() ? cacheSecs : 10,
    demuxerMaxMb: hasDemuxerMaxMb() ? demuxerMaxMb : 150,
    mpvExtraArgs: hasMpvExtraArgs() ? mpvExtraArgs : "",
    mpvReuseWindow: hasMpvReuseWindow() ? mpvReuseWindow : true,
    iosNativePlayer: hasIosNativePlayer() ? iosNativePlayer : true,
    iosPreferHls: hasIosPreferHls() ? iosPreferHls : true,
    backgroundAudio: hasBackgroundAudio() ? backgroundAudio : true,
    autoPip: hasAutoPip() ? autoPip : true,
    startGroupId: hasStartGroupId() && startGroupId.toInt() > 0
        ? startGroupId.toInt()
        : null,
    startGroupName: hasStartGroupName() ? startGroupName : null,
  );
}

extension SettingsDomainExtension on Settings {
  pb.Settings toProto() => pb.Settings(
    defaultView: defaultView.index,
    defaultSort: defaultSort.index,
    refreshOnStart: refreshOnStart,
    useStreamCaching: !lowLatency,
    forceTvMode: forceTVMode,
    showLivestreams: showLivestreams,
    showMovies: showMovies,
    showSeries: showSeries,
    showProgrammes: showProgrammes,
    numberKeySwitching: numberKeySwitching,
    enableCatchup: enableCatchup,
    enableFullGuide: enableFullGuide,
    enableXmltv: enableXmltv,
    keyboardShortcuts: keyboardShortcuts,
    guidePlayerTitles: guidePlayerTitles,
    guideTileText: guideTileText,
    autoQualityDiscovery: autoQualityDiscovery,
    searchDelayMs: searchDelayMs,

    linuxPlayer: linuxPlayer.index,
    mpvPath: mpvPath,
    hwdec: hwdec,
    cacheSecs: cacheSecs,
    demuxerMaxMb: demuxerMaxMb,
    mpvExtraArgs: mpvExtraArgs,
    mpvReuseWindow: mpvReuseWindow,
    iosNativePlayer: iosNativePlayer,
    iosPreferHls: iosPreferHls,
    backgroundAudio: backgroundAudio,
    autoPip: autoPip,
    startGroupId: Int64(startGroupId ?? 0),
    startGroupName: startGroupName ?? "",
  );
}

extension ChannelHttpHeadersProtoExtension on pb.ChannelHttpHeaders {
  ChannelHttpHeaders toDomain() => ChannelHttpHeaders(
    id: hasId() ? id.toInt() : null,
    channelId: hasChannelId() ? channelId.toInt() : null,
    referrer: hasReferrer() ? referrer : null,
    userAgent: hasUserAgent() ? userAgent : null,
    httpOrigin: hasHttpOrigin() ? httpOrigin : null,
    ignoreSSL: hasIgnoreSsl() ? ignoreSsl.toString() : null,
  );
}
