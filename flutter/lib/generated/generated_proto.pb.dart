// This is a generated file - do not edit.
//
// Generated from generated_proto.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'generated_proto.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'generated_proto.pbenum.dart';

class Channel extends $pb.GeneratedMessage {
  factory Channel({
    $fixnum.Int64? id,
    $core.String? name,
    $core.String? url,
    $core.String? group,
    $core.String? image,
    $core.int? mediaType,
    $fixnum.Int64? sourceId,
    $fixnum.Int64? seriesId,
    $fixnum.Int64? groupId,
    $core.bool? favorite,
    $fixnum.Int64? streamId,
    $core.bool? tvArchive,
    $fixnum.Int64? seasonId,
    $fixnum.Int64? episodeNum,
    $core.int? quality,
    $core.String? altKey,
    $core.bool? hidden,
    $core.int? archiveDays,
    $core.String? epgId,
    ChannelHttpHeaders? playbackHeaders,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (url != null) result.url = url;
    if (group != null) result.group = group;
    if (image != null) result.image = image;
    if (mediaType != null) result.mediaType = mediaType;
    if (sourceId != null) result.sourceId = sourceId;
    if (seriesId != null) result.seriesId = seriesId;
    if (groupId != null) result.groupId = groupId;
    if (favorite != null) result.favorite = favorite;
    if (streamId != null) result.streamId = streamId;
    if (tvArchive != null) result.tvArchive = tvArchive;
    if (seasonId != null) result.seasonId = seasonId;
    if (episodeNum != null) result.episodeNum = episodeNum;
    if (quality != null) result.quality = quality;
    if (altKey != null) result.altKey = altKey;
    if (hidden != null) result.hidden = hidden;
    if (archiveDays != null) result.archiveDays = archiveDays;
    if (epgId != null) result.epgId = epgId;
    if (playbackHeaders != null) result.playbackHeaders = playbackHeaders;
    return result;
  }

  Channel._();

  factory Channel.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Channel.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Channel',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'url')
    ..aOS(4, _omitFieldNames ? '' : 'group')
    ..aOS(5, _omitFieldNames ? '' : 'image')
    ..aI(6, _omitFieldNames ? '' : 'mediaType', fieldType: $pb.PbFieldType.OU3)
    ..aInt64(7, _omitFieldNames ? '' : 'sourceId')
    ..a<$fixnum.Int64>(
        8, _omitFieldNames ? '' : 'seriesId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aInt64(9, _omitFieldNames ? '' : 'groupId')
    ..aOB(10, _omitFieldNames ? '' : 'favorite')
    ..a<$fixnum.Int64>(
        11, _omitFieldNames ? '' : 'streamId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOB(12, _omitFieldNames ? '' : 'tvArchive')
    ..aInt64(13, _omitFieldNames ? '' : 'seasonId')
    ..aInt64(14, _omitFieldNames ? '' : 'episodeNum')
    ..aI(15, _omitFieldNames ? '' : 'quality', fieldType: $pb.PbFieldType.OU3)
    ..aOS(16, _omitFieldNames ? '' : 'altKey')
    ..aOB(17, _omitFieldNames ? '' : 'hidden')
    ..aI(18, _omitFieldNames ? '' : 'archiveDays',
        fieldType: $pb.PbFieldType.OU3)
    ..aOS(19, _omitFieldNames ? '' : 'epgId')
    ..aOM<ChannelHttpHeaders>(20, _omitFieldNames ? '' : 'playbackHeaders',
        subBuilder: ChannelHttpHeaders.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Channel clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Channel copyWith(void Function(Channel) updates) =>
      super.copyWith((message) => updates(message as Channel)) as Channel;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Channel create() => Channel._();
  @$core.override
  Channel createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Channel getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Channel>(create);
  static Channel? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get url => $_getSZ(2);
  @$pb.TagNumber(3)
  set url($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUrl() => $_has(2);
  @$pb.TagNumber(3)
  void clearUrl() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get group => $_getSZ(3);
  @$pb.TagNumber(4)
  set group($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasGroup() => $_has(3);
  @$pb.TagNumber(4)
  void clearGroup() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get image => $_getSZ(4);
  @$pb.TagNumber(5)
  set image($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasImage() => $_has(4);
  @$pb.TagNumber(5)
  void clearImage() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get mediaType => $_getIZ(5);
  @$pb.TagNumber(6)
  set mediaType($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMediaType() => $_has(5);
  @$pb.TagNumber(6)
  void clearMediaType() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get sourceId => $_getI64(6);
  @$pb.TagNumber(7)
  set sourceId($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSourceId() => $_has(6);
  @$pb.TagNumber(7)
  void clearSourceId() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get seriesId => $_getI64(7);
  @$pb.TagNumber(8)
  set seriesId($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSeriesId() => $_has(7);
  @$pb.TagNumber(8)
  void clearSeriesId() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get groupId => $_getI64(8);
  @$pb.TagNumber(9)
  set groupId($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasGroupId() => $_has(8);
  @$pb.TagNumber(9)
  void clearGroupId() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get favorite => $_getBF(9);
  @$pb.TagNumber(10)
  set favorite($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasFavorite() => $_has(9);
  @$pb.TagNumber(10)
  void clearFavorite() => $_clearField(10);

  @$pb.TagNumber(11)
  $fixnum.Int64 get streamId => $_getI64(10);
  @$pb.TagNumber(11)
  set streamId($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(11)
  $core.bool hasStreamId() => $_has(10);
  @$pb.TagNumber(11)
  void clearStreamId() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.bool get tvArchive => $_getBF(11);
  @$pb.TagNumber(12)
  set tvArchive($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasTvArchive() => $_has(11);
  @$pb.TagNumber(12)
  void clearTvArchive() => $_clearField(12);

  @$pb.TagNumber(13)
  $fixnum.Int64 get seasonId => $_getI64(12);
  @$pb.TagNumber(13)
  set seasonId($fixnum.Int64 value) => $_setInt64(12, value);
  @$pb.TagNumber(13)
  $core.bool hasSeasonId() => $_has(12);
  @$pb.TagNumber(13)
  void clearSeasonId() => $_clearField(13);

  @$pb.TagNumber(14)
  $fixnum.Int64 get episodeNum => $_getI64(13);
  @$pb.TagNumber(14)
  set episodeNum($fixnum.Int64 value) => $_setInt64(13, value);
  @$pb.TagNumber(14)
  $core.bool hasEpisodeNum() => $_has(13);
  @$pb.TagNumber(14)
  void clearEpisodeNum() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.int get quality => $_getIZ(14);
  @$pb.TagNumber(15)
  set quality($core.int value) => $_setUnsignedInt32(14, value);
  @$pb.TagNumber(15)
  $core.bool hasQuality() => $_has(14);
  @$pb.TagNumber(15)
  void clearQuality() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.String get altKey => $_getSZ(15);
  @$pb.TagNumber(16)
  set altKey($core.String value) => $_setString(15, value);
  @$pb.TagNumber(16)
  $core.bool hasAltKey() => $_has(15);
  @$pb.TagNumber(16)
  void clearAltKey() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.bool get hidden => $_getBF(16);
  @$pb.TagNumber(17)
  set hidden($core.bool value) => $_setBool(16, value);
  @$pb.TagNumber(17)
  $core.bool hasHidden() => $_has(16);
  @$pb.TagNumber(17)
  void clearHidden() => $_clearField(17);

  @$pb.TagNumber(18)
  $core.int get archiveDays => $_getIZ(17);
  @$pb.TagNumber(18)
  set archiveDays($core.int value) => $_setUnsignedInt32(17, value);
  @$pb.TagNumber(18)
  $core.bool hasArchiveDays() => $_has(17);
  @$pb.TagNumber(18)
  void clearArchiveDays() => $_clearField(18);

  @$pb.TagNumber(19)
  $core.String get epgId => $_getSZ(18);
  @$pb.TagNumber(19)
  set epgId($core.String value) => $_setString(18, value);
  @$pb.TagNumber(19)
  $core.bool hasEpgId() => $_has(18);
  @$pb.TagNumber(19)
  void clearEpgId() => $_clearField(19);

  @$pb.TagNumber(20)
  ChannelHttpHeaders get playbackHeaders => $_getN(19);
  @$pb.TagNumber(20)
  set playbackHeaders(ChannelHttpHeaders value) => $_setField(20, value);
  @$pb.TagNumber(20)
  $core.bool hasPlaybackHeaders() => $_has(19);
  @$pb.TagNumber(20)
  void clearPlaybackHeaders() => $_clearField(20);
  @$pb.TagNumber(20)
  ChannelHttpHeaders ensurePlaybackHeaders() => $_ensure(19);
}

class SetHidden extends $pb.GeneratedMessage {
  factory SetHidden({
    $fixnum.Int64? id,
    $core.bool? hidden,
    $core.bool? group,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (hidden != null) result.hidden = hidden;
    if (group != null) result.group = group;
    return result;
  }

  SetHidden._();

  factory SetHidden.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetHidden.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetHidden',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aOB(2, _omitFieldNames ? '' : 'hidden')
    ..aOB(3, _omitFieldNames ? '' : 'group')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetHidden clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetHidden copyWith(void Function(SetHidden) updates) =>
      super.copyWith((message) => updates(message as SetHidden)) as SetHidden;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetHidden create() => SetHidden._();
  @$core.override
  SetHidden createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetHidden getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetHidden>(create);
  static SetHidden? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get hidden => $_getBF(1);
  @$pb.TagNumber(2)
  set hidden($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHidden() => $_has(1);
  @$pb.TagNumber(2)
  void clearHidden() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get group => $_getBF(2);
  @$pb.TagNumber(3)
  set group($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasGroup() => $_has(2);
  @$pb.TagNumber(3)
  void clearGroup() => $_clearField(3);
}

class SwapFavorites extends $pb.GeneratedMessage {
  factory SwapFavorites({
    $fixnum.Int64? id,
    $fixnum.Int64? other,
    $core.bool? group,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (other != null) result.other = other;
    if (group != null) result.group = group;
    return result;
  }

  SwapFavorites._();

  factory SwapFavorites.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SwapFavorites.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SwapFavorites',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aInt64(2, _omitFieldNames ? '' : 'other')
    ..aOB(3, _omitFieldNames ? '' : 'group')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SwapFavorites clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SwapFavorites copyWith(void Function(SwapFavorites) updates) =>
      super.copyWith((message) => updates(message as SwapFavorites))
          as SwapFavorites;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SwapFavorites create() => SwapFavorites._();
  @$core.override
  SwapFavorites createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SwapFavorites getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SwapFavorites>(create);
  static SwapFavorites? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get other => $_getI64(1);
  @$pb.TagNumber(2)
  set other($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOther() => $_has(1);
  @$pb.TagNumber(2)
  void clearOther() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get group => $_getBF(2);
  @$pb.TagNumber(3)
  set group($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasGroup() => $_has(2);
  @$pb.TagNumber(3)
  void clearGroup() => $_clearField(3);
}

class GuideRequest extends $pb.GeneratedMessage {
  factory GuideRequest({
    $fixnum.Int64? channelId,
    $fixnum.Int64? from,
    $fixnum.Int64? to,
  }) {
    final result = create();
    if (channelId != null) result.channelId = channelId;
    if (from != null) result.from = from;
    if (to != null) result.to = to;
    return result;
  }

  GuideRequest._();

  factory GuideRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GuideRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GuideRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'channelId')
    ..aInt64(2, _omitFieldNames ? '' : 'from')
    ..aInt64(3, _omitFieldNames ? '' : 'to')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GuideRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GuideRequest copyWith(void Function(GuideRequest) updates) =>
      super.copyWith((message) => updates(message as GuideRequest))
          as GuideRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GuideRequest create() => GuideRequest._();
  @$core.override
  GuideRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GuideRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GuideRequest>(create);
  static GuideRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get channelId => $_getI64(0);
  @$pb.TagNumber(1)
  set channelId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChannelId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChannelId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get from => $_getI64(1);
  @$pb.TagNumber(2)
  set from($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFrom() => $_has(1);
  @$pb.TagNumber(2)
  void clearFrom() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get to => $_getI64(2);
  @$pb.TagNumber(3)
  set to($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTo() => $_has(2);
  @$pb.TagNumber(3)
  void clearTo() => $_clearField(3);
}

class ProgrammeList extends $pb.GeneratedMessage {
  factory ProgrammeList({
    $core.bool? supported,
    $core.Iterable<Programme>? programmes,
    $core.bool? catchupSupported,
    $core.int? archiveDays,
  }) {
    final result = create();
    if (supported != null) result.supported = supported;
    if (programmes != null) result.programmes.addAll(programmes);
    if (catchupSupported != null) result.catchupSupported = catchupSupported;
    if (archiveDays != null) result.archiveDays = archiveDays;
    return result;
  }

  ProgrammeList._();

  factory ProgrammeList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProgrammeList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProgrammeList',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'supported')
    ..pPM<Programme>(2, _omitFieldNames ? '' : 'programmes',
        subBuilder: Programme.create)
    ..aOB(3, _omitFieldNames ? '' : 'catchupSupported')
    ..aI(4, _omitFieldNames ? '' : 'archiveDays',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProgrammeList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProgrammeList copyWith(void Function(ProgrammeList) updates) =>
      super.copyWith((message) => updates(message as ProgrammeList))
          as ProgrammeList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProgrammeList create() => ProgrammeList._();
  @$core.override
  ProgrammeList createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ProgrammeList getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProgrammeList>(create);
  static ProgrammeList? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get supported => $_getBF(0);
  @$pb.TagNumber(1)
  set supported($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSupported() => $_has(0);
  @$pb.TagNumber(1)
  void clearSupported() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<Programme> get programmes => $_getList(1);

  @$pb.TagNumber(3)
  $core.bool get catchupSupported => $_getBF(2);
  @$pb.TagNumber(3)
  set catchupSupported($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCatchupSupported() => $_has(2);
  @$pb.TagNumber(3)
  void clearCatchupSupported() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get archiveDays => $_getIZ(3);
  @$pb.TagNumber(4)
  set archiveDays($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasArchiveDays() => $_has(3);
  @$pb.TagNumber(4)
  void clearArchiveDays() => $_clearField(4);
}

class ChannelList extends $pb.GeneratedMessage {
  factory ChannelList({
    $core.Iterable<Channel>? channels,
    $fixnum.Int64? preferredChannelId,
  }) {
    final result = create();
    if (channels != null) result.channels.addAll(channels);
    if (preferredChannelId != null)
      result.preferredChannelId = preferredChannelId;
    return result;
  }

  ChannelList._();

  factory ChannelList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ChannelList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChannelList',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..pPM<Channel>(1, _omitFieldNames ? '' : 'channels',
        subBuilder: Channel.create)
    ..aInt64(2, _omitFieldNames ? '' : 'preferredChannelId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChannelList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChannelList copyWith(void Function(ChannelList) updates) =>
      super.copyWith((message) => updates(message as ChannelList))
          as ChannelList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ChannelList create() => ChannelList._();
  @$core.override
  ChannelList createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ChannelList getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ChannelList>(create);
  static ChannelList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Channel> get channels => $_getList(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get preferredChannelId => $_getI64(1);
  @$pb.TagNumber(2)
  set preferredChannelId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPreferredChannelId() => $_has(1);
  @$pb.TagNumber(2)
  void clearPreferredChannelId() => $_clearField(2);
}

class Source extends $pb.GeneratedMessage {
  factory Source({
    $fixnum.Int64? id,
    $core.String? name,
    $core.String? url,
    $core.String? urlOrigin,
    $core.String? username,
    $core.String? password,
    $core.int? sourceType,
    $core.bool? enabled,
    $core.String? userAgent,
    $core.String? streamUserAgent,
    $fixnum.Int64? lastUpdated,
    $core.bool? importLive,
    $core.bool? importMovies,
    $core.bool? importSeries,
    RefreshStats? lastRefreshStats,
    $core.String? epgUrl,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (url != null) result.url = url;
    if (urlOrigin != null) result.urlOrigin = urlOrigin;
    if (username != null) result.username = username;
    if (password != null) result.password = password;
    if (sourceType != null) result.sourceType = sourceType;
    if (enabled != null) result.enabled = enabled;
    if (userAgent != null) result.userAgent = userAgent;
    if (streamUserAgent != null) result.streamUserAgent = streamUserAgent;
    if (lastUpdated != null) result.lastUpdated = lastUpdated;
    if (importLive != null) result.importLive = importLive;
    if (importMovies != null) result.importMovies = importMovies;
    if (importSeries != null) result.importSeries = importSeries;
    if (lastRefreshStats != null) result.lastRefreshStats = lastRefreshStats;
    if (epgUrl != null) result.epgUrl = epgUrl;
    return result;
  }

  Source._();

  factory Source.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Source.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Source',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'url')
    ..aOS(4, _omitFieldNames ? '' : 'urlOrigin')
    ..aOS(5, _omitFieldNames ? '' : 'username')
    ..aOS(6, _omitFieldNames ? '' : 'password')
    ..aI(7, _omitFieldNames ? '' : 'sourceType', fieldType: $pb.PbFieldType.OU3)
    ..aOB(9, _omitFieldNames ? '' : 'enabled')
    ..aOS(10, _omitFieldNames ? '' : 'userAgent')
    ..aOS(12, _omitFieldNames ? '' : 'streamUserAgent')
    ..aInt64(13, _omitFieldNames ? '' : 'lastUpdated')
    ..aOB(14, _omitFieldNames ? '' : 'importLive')
    ..aOB(15, _omitFieldNames ? '' : 'importMovies')
    ..aOB(16, _omitFieldNames ? '' : 'importSeries')
    ..aOM<RefreshStats>(17, _omitFieldNames ? '' : 'lastRefreshStats',
        subBuilder: RefreshStats.create)
    ..aOS(18, _omitFieldNames ? '' : 'epgUrl')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Source clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Source copyWith(void Function(Source) updates) =>
      super.copyWith((message) => updates(message as Source)) as Source;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Source create() => Source._();
  @$core.override
  Source createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Source getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Source>(create);
  static Source? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get url => $_getSZ(2);
  @$pb.TagNumber(3)
  set url($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUrl() => $_has(2);
  @$pb.TagNumber(3)
  void clearUrl() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get urlOrigin => $_getSZ(3);
  @$pb.TagNumber(4)
  set urlOrigin($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUrlOrigin() => $_has(3);
  @$pb.TagNumber(4)
  void clearUrlOrigin() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get username => $_getSZ(4);
  @$pb.TagNumber(5)
  set username($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasUsername() => $_has(4);
  @$pb.TagNumber(5)
  void clearUsername() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get password => $_getSZ(5);
  @$pb.TagNumber(6)
  set password($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPassword() => $_has(5);
  @$pb.TagNumber(6)
  void clearPassword() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get sourceType => $_getIZ(6);
  @$pb.TagNumber(7)
  set sourceType($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSourceType() => $_has(6);
  @$pb.TagNumber(7)
  void clearSourceType() => $_clearField(7);

  @$pb.TagNumber(9)
  $core.bool get enabled => $_getBF(7);
  @$pb.TagNumber(9)
  set enabled($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(9)
  $core.bool hasEnabled() => $_has(7);
  @$pb.TagNumber(9)
  void clearEnabled() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get userAgent => $_getSZ(8);
  @$pb.TagNumber(10)
  set userAgent($core.String value) => $_setString(8, value);
  @$pb.TagNumber(10)
  $core.bool hasUserAgent() => $_has(8);
  @$pb.TagNumber(10)
  void clearUserAgent() => $_clearField(10);

  @$pb.TagNumber(12)
  $core.String get streamUserAgent => $_getSZ(9);
  @$pb.TagNumber(12)
  set streamUserAgent($core.String value) => $_setString(9, value);
  @$pb.TagNumber(12)
  $core.bool hasStreamUserAgent() => $_has(9);
  @$pb.TagNumber(12)
  void clearStreamUserAgent() => $_clearField(12);

  @$pb.TagNumber(13)
  $fixnum.Int64 get lastUpdated => $_getI64(10);
  @$pb.TagNumber(13)
  set lastUpdated($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(13)
  $core.bool hasLastUpdated() => $_has(10);
  @$pb.TagNumber(13)
  void clearLastUpdated() => $_clearField(13);

  /// Selective import; unset means true.
  @$pb.TagNumber(14)
  $core.bool get importLive => $_getBF(11);
  @$pb.TagNumber(14)
  set importLive($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(14)
  $core.bool hasImportLive() => $_has(11);
  @$pb.TagNumber(14)
  void clearImportLive() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.bool get importMovies => $_getBF(12);
  @$pb.TagNumber(15)
  set importMovies($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(15)
  $core.bool hasImportMovies() => $_has(12);
  @$pb.TagNumber(15)
  void clearImportMovies() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.bool get importSeries => $_getBF(13);
  @$pb.TagNumber(16)
  set importSeries($core.bool value) => $_setBool(13, value);
  @$pb.TagNumber(16)
  $core.bool hasImportSeries() => $_has(13);
  @$pb.TagNumber(16)
  void clearImportSeries() => $_clearField(16);

  @$pb.TagNumber(17)
  RefreshStats get lastRefreshStats => $_getN(14);
  @$pb.TagNumber(17)
  set lastRefreshStats(RefreshStats value) => $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasLastRefreshStats() => $_has(14);
  @$pb.TagNumber(17)
  void clearLastRefreshStats() => $_clearField(17);
  @$pb.TagNumber(17)
  RefreshStats ensureLastRefreshStats() => $_ensure(14);

  @$pb.TagNumber(18)
  $core.String get epgUrl => $_getSZ(15);
  @$pb.TagNumber(18)
  set epgUrl($core.String value) => $_setString(15, value);
  @$pb.TagNumber(18)
  $core.bool hasEpgUrl() => $_has(15);
  @$pb.TagNumber(18)
  void clearEpgUrl() => $_clearField(18);
}

class Settings extends $pb.GeneratedMessage {
  factory Settings({
    $core.bool? useStreamCaching,
    $core.int? defaultView,
    $core.bool? refreshOnStart,
    $core.int? defaultSort,
    $core.bool? forceTvMode,
    $core.bool? showLivestreams,
    $core.bool? showMovies,
    $core.bool? showSeries,
    $core.int? linuxPlayer,
    $core.String? mpvPath,
    $core.String? hwdec,
    $core.int? cacheSecs,
    $core.int? demuxerMaxMb,
    $core.String? mpvExtraArgs,
    $core.bool? mpvReuseWindow,
    $core.bool? iosNativePlayer,
    $core.bool? iosPreferHls,
    $core.bool? backgroundAudio,
    $core.bool? autoPip,
    $fixnum.Int64? startGroupId,
    $core.String? startGroupName,
    $core.bool? showProgrammes,
    $core.bool? enableCatchup,
    $core.bool? enableFullGuide,
    $core.bool? enableXmltv,
    $core.bool? keyboardShortcuts,
    $core.bool? guidePlayerTitles,
    $core.bool? guideTileText,
    $core.bool? autoQualityDiscovery,
    $core.int? searchDelayMs,
    $core.bool? numberKeySwitching,
    $core.int? uiScalePercent,
    $core.bool? squareCorners,
    $core.String? bottomBar,
    $core.String? mediaPreferences,
    $core.String? recordingJobs,
    $core.String? downloadJobs,
  }) {
    final result = create();
    if (useStreamCaching != null) result.useStreamCaching = useStreamCaching;
    if (defaultView != null) result.defaultView = defaultView;
    if (refreshOnStart != null) result.refreshOnStart = refreshOnStart;
    if (defaultSort != null) result.defaultSort = defaultSort;
    if (forceTvMode != null) result.forceTvMode = forceTvMode;
    if (showLivestreams != null) result.showLivestreams = showLivestreams;
    if (showMovies != null) result.showMovies = showMovies;
    if (showSeries != null) result.showSeries = showSeries;
    if (linuxPlayer != null) result.linuxPlayer = linuxPlayer;
    if (mpvPath != null) result.mpvPath = mpvPath;
    if (hwdec != null) result.hwdec = hwdec;
    if (cacheSecs != null) result.cacheSecs = cacheSecs;
    if (demuxerMaxMb != null) result.demuxerMaxMb = demuxerMaxMb;
    if (mpvExtraArgs != null) result.mpvExtraArgs = mpvExtraArgs;
    if (mpvReuseWindow != null) result.mpvReuseWindow = mpvReuseWindow;
    if (iosNativePlayer != null) result.iosNativePlayer = iosNativePlayer;
    if (iosPreferHls != null) result.iosPreferHls = iosPreferHls;
    if (backgroundAudio != null) result.backgroundAudio = backgroundAudio;
    if (autoPip != null) result.autoPip = autoPip;
    if (startGroupId != null) result.startGroupId = startGroupId;
    if (startGroupName != null) result.startGroupName = startGroupName;
    if (showProgrammes != null) result.showProgrammes = showProgrammes;
    if (enableCatchup != null) result.enableCatchup = enableCatchup;
    if (enableFullGuide != null) result.enableFullGuide = enableFullGuide;
    if (enableXmltv != null) result.enableXmltv = enableXmltv;
    if (keyboardShortcuts != null) result.keyboardShortcuts = keyboardShortcuts;
    if (guidePlayerTitles != null) result.guidePlayerTitles = guidePlayerTitles;
    if (guideTileText != null) result.guideTileText = guideTileText;
    if (autoQualityDiscovery != null)
      result.autoQualityDiscovery = autoQualityDiscovery;
    if (searchDelayMs != null) result.searchDelayMs = searchDelayMs;
    if (numberKeySwitching != null)
      result.numberKeySwitching = numberKeySwitching;
    if (uiScalePercent != null) result.uiScalePercent = uiScalePercent;
    if (squareCorners != null) result.squareCorners = squareCorners;
    if (bottomBar != null) result.bottomBar = bottomBar;
    if (mediaPreferences != null) result.mediaPreferences = mediaPreferences;
    if (recordingJobs != null) result.recordingJobs = recordingJobs;
    if (downloadJobs != null) result.downloadJobs = downloadJobs;
    return result;
  }

  Settings._();

  factory Settings.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Settings.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Settings',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'useStreamCaching')
    ..aI(2, _omitFieldNames ? '' : 'defaultView',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(3, _omitFieldNames ? '' : 'refreshOnStart')
    ..aI(4, _omitFieldNames ? '' : 'defaultSort',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(5, _omitFieldNames ? '' : 'forceTvMode')
    ..aOB(6, _omitFieldNames ? '' : 'showLivestreams')
    ..aOB(7, _omitFieldNames ? '' : 'showMovies')
    ..aOB(8, _omitFieldNames ? '' : 'showSeries')
    ..aI(10, _omitFieldNames ? '' : 'linuxPlayer',
        fieldType: $pb.PbFieldType.OU3)
    ..aOS(11, _omitFieldNames ? '' : 'mpvPath')
    ..aOS(12, _omitFieldNames ? '' : 'hwdec')
    ..aI(13, _omitFieldNames ? '' : 'cacheSecs', fieldType: $pb.PbFieldType.OU3)
    ..aI(14, _omitFieldNames ? '' : 'demuxerMaxMb',
        fieldType: $pb.PbFieldType.OU3)
    ..aOS(15, _omitFieldNames ? '' : 'mpvExtraArgs')
    ..aOB(16, _omitFieldNames ? '' : 'mpvReuseWindow')
    ..aOB(17, _omitFieldNames ? '' : 'iosNativePlayer')
    ..aOB(18, _omitFieldNames ? '' : 'iosPreferHls')
    ..aOB(19, _omitFieldNames ? '' : 'backgroundAudio')
    ..aOB(20, _omitFieldNames ? '' : 'autoPip')
    ..aInt64(21, _omitFieldNames ? '' : 'startGroupId')
    ..aOS(22, _omitFieldNames ? '' : 'startGroupName')
    ..aOB(23, _omitFieldNames ? '' : 'showProgrammes')
    ..aOB(24, _omitFieldNames ? '' : 'enableCatchup')
    ..aOB(25, _omitFieldNames ? '' : 'enableFullGuide')
    ..aOB(26, _omitFieldNames ? '' : 'enableXmltv')
    ..aOB(27, _omitFieldNames ? '' : 'keyboardShortcuts')
    ..aOB(28, _omitFieldNames ? '' : 'guidePlayerTitles')
    ..aOB(29, _omitFieldNames ? '' : 'guideTileText')
    ..aOB(30, _omitFieldNames ? '' : 'autoQualityDiscovery')
    ..aI(31, _omitFieldNames ? '' : 'searchDelayMs',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(32, _omitFieldNames ? '' : 'numberKeySwitching')
    ..aI(33, _omitFieldNames ? '' : 'uiScalePercent',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(34, _omitFieldNames ? '' : 'squareCorners')
    ..aOS(35, _omitFieldNames ? '' : 'bottomBar')
    ..aOS(36, _omitFieldNames ? '' : 'mediaPreferences')
    ..aOS(37, _omitFieldNames ? '' : 'recordingJobs')
    ..aOS(38, _omitFieldNames ? '' : 'downloadJobs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Settings clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Settings copyWith(void Function(Settings) updates) =>
      super.copyWith((message) => updates(message as Settings)) as Settings;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Settings create() => Settings._();
  @$core.override
  Settings createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Settings getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Settings>(create);
  static Settings? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get useStreamCaching => $_getBF(0);
  @$pb.TagNumber(1)
  set useStreamCaching($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUseStreamCaching() => $_has(0);
  @$pb.TagNumber(1)
  void clearUseStreamCaching() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get defaultView => $_getIZ(1);
  @$pb.TagNumber(2)
  set defaultView($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDefaultView() => $_has(1);
  @$pb.TagNumber(2)
  void clearDefaultView() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get refreshOnStart => $_getBF(2);
  @$pb.TagNumber(3)
  set refreshOnStart($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRefreshOnStart() => $_has(2);
  @$pb.TagNumber(3)
  void clearRefreshOnStart() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get defaultSort => $_getIZ(3);
  @$pb.TagNumber(4)
  set defaultSort($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDefaultSort() => $_has(3);
  @$pb.TagNumber(4)
  void clearDefaultSort() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get forceTvMode => $_getBF(4);
  @$pb.TagNumber(5)
  set forceTvMode($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasForceTvMode() => $_has(4);
  @$pb.TagNumber(5)
  void clearForceTvMode() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get showLivestreams => $_getBF(5);
  @$pb.TagNumber(6)
  set showLivestreams($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasShowLivestreams() => $_has(5);
  @$pb.TagNumber(6)
  void clearShowLivestreams() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get showMovies => $_getBF(6);
  @$pb.TagNumber(7)
  set showMovies($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasShowMovies() => $_has(6);
  @$pb.TagNumber(7)
  void clearShowMovies() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get showSeries => $_getBF(7);
  @$pb.TagNumber(8)
  set showSeries($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasShowSeries() => $_has(7);
  @$pb.TagNumber(8)
  void clearShowSeries() => $_clearField(8);

  @$pb.TagNumber(10)
  $core.int get linuxPlayer => $_getIZ(8);
  @$pb.TagNumber(10)
  set linuxPlayer($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(10)
  $core.bool hasLinuxPlayer() => $_has(8);
  @$pb.TagNumber(10)
  void clearLinuxPlayer() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get mpvPath => $_getSZ(9);
  @$pb.TagNumber(11)
  set mpvPath($core.String value) => $_setString(9, value);
  @$pb.TagNumber(11)
  $core.bool hasMpvPath() => $_has(9);
  @$pb.TagNumber(11)
  void clearMpvPath() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get hwdec => $_getSZ(10);
  @$pb.TagNumber(12)
  set hwdec($core.String value) => $_setString(10, value);
  @$pb.TagNumber(12)
  $core.bool hasHwdec() => $_has(10);
  @$pb.TagNumber(12)
  void clearHwdec() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.int get cacheSecs => $_getIZ(11);
  @$pb.TagNumber(13)
  set cacheSecs($core.int value) => $_setUnsignedInt32(11, value);
  @$pb.TagNumber(13)
  $core.bool hasCacheSecs() => $_has(11);
  @$pb.TagNumber(13)
  void clearCacheSecs() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.int get demuxerMaxMb => $_getIZ(12);
  @$pb.TagNumber(14)
  set demuxerMaxMb($core.int value) => $_setUnsignedInt32(12, value);
  @$pb.TagNumber(14)
  $core.bool hasDemuxerMaxMb() => $_has(12);
  @$pb.TagNumber(14)
  void clearDemuxerMaxMb() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.String get mpvExtraArgs => $_getSZ(13);
  @$pb.TagNumber(15)
  set mpvExtraArgs($core.String value) => $_setString(13, value);
  @$pb.TagNumber(15)
  $core.bool hasMpvExtraArgs() => $_has(13);
  @$pb.TagNumber(15)
  void clearMpvExtraArgs() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.bool get mpvReuseWindow => $_getBF(14);
  @$pb.TagNumber(16)
  set mpvReuseWindow($core.bool value) => $_setBool(14, value);
  @$pb.TagNumber(16)
  $core.bool hasMpvReuseWindow() => $_has(14);
  @$pb.TagNumber(16)
  void clearMpvReuseWindow() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.bool get iosNativePlayer => $_getBF(15);
  @$pb.TagNumber(17)
  set iosNativePlayer($core.bool value) => $_setBool(15, value);
  @$pb.TagNumber(17)
  $core.bool hasIosNativePlayer() => $_has(15);
  @$pb.TagNumber(17)
  void clearIosNativePlayer() => $_clearField(17);

  @$pb.TagNumber(18)
  $core.bool get iosPreferHls => $_getBF(16);
  @$pb.TagNumber(18)
  set iosPreferHls($core.bool value) => $_setBool(16, value);
  @$pb.TagNumber(18)
  $core.bool hasIosPreferHls() => $_has(16);
  @$pb.TagNumber(18)
  void clearIosPreferHls() => $_clearField(18);

  @$pb.TagNumber(19)
  $core.bool get backgroundAudio => $_getBF(17);
  @$pb.TagNumber(19)
  set backgroundAudio($core.bool value) => $_setBool(17, value);
  @$pb.TagNumber(19)
  $core.bool hasBackgroundAudio() => $_has(17);
  @$pb.TagNumber(19)
  void clearBackgroundAudio() => $_clearField(19);

  @$pb.TagNumber(20)
  $core.bool get autoPip => $_getBF(18);
  @$pb.TagNumber(20)
  set autoPip($core.bool value) => $_setBool(18, value);
  @$pb.TagNumber(20)
  $core.bool hasAutoPip() => $_has(18);
  @$pb.TagNumber(20)
  void clearAutoPip() => $_clearField(20);

  @$pb.TagNumber(21)
  $fixnum.Int64 get startGroupId => $_getI64(19);
  @$pb.TagNumber(21)
  set startGroupId($fixnum.Int64 value) => $_setInt64(19, value);
  @$pb.TagNumber(21)
  $core.bool hasStartGroupId() => $_has(19);
  @$pb.TagNumber(21)
  void clearStartGroupId() => $_clearField(21);

  @$pb.TagNumber(22)
  $core.String get startGroupName => $_getSZ(20);
  @$pb.TagNumber(22)
  set startGroupName($core.String value) => $_setString(20, value);
  @$pb.TagNumber(22)
  $core.bool hasStartGroupName() => $_has(20);
  @$pb.TagNumber(22)
  void clearStartGroupName() => $_clearField(22);

  @$pb.TagNumber(23)
  $core.bool get showProgrammes => $_getBF(21);
  @$pb.TagNumber(23)
  set showProgrammes($core.bool value) => $_setBool(21, value);
  @$pb.TagNumber(23)
  $core.bool hasShowProgrammes() => $_has(21);
  @$pb.TagNumber(23)
  void clearShowProgrammes() => $_clearField(23);

  @$pb.TagNumber(24)
  $core.bool get enableCatchup => $_getBF(22);
  @$pb.TagNumber(24)
  set enableCatchup($core.bool value) => $_setBool(22, value);
  @$pb.TagNumber(24)
  $core.bool hasEnableCatchup() => $_has(22);
  @$pb.TagNumber(24)
  void clearEnableCatchup() => $_clearField(24);

  @$pb.TagNumber(25)
  $core.bool get enableFullGuide => $_getBF(23);
  @$pb.TagNumber(25)
  set enableFullGuide($core.bool value) => $_setBool(23, value);
  @$pb.TagNumber(25)
  $core.bool hasEnableFullGuide() => $_has(23);
  @$pb.TagNumber(25)
  void clearEnableFullGuide() => $_clearField(25);

  @$pb.TagNumber(26)
  $core.bool get enableXmltv => $_getBF(24);
  @$pb.TagNumber(26)
  set enableXmltv($core.bool value) => $_setBool(24, value);
  @$pb.TagNumber(26)
  $core.bool hasEnableXmltv() => $_has(24);
  @$pb.TagNumber(26)
  void clearEnableXmltv() => $_clearField(26);

  @$pb.TagNumber(27)
  $core.bool get keyboardShortcuts => $_getBF(25);
  @$pb.TagNumber(27)
  set keyboardShortcuts($core.bool value) => $_setBool(25, value);
  @$pb.TagNumber(27)
  $core.bool hasKeyboardShortcuts() => $_has(25);
  @$pb.TagNumber(27)
  void clearKeyboardShortcuts() => $_clearField(27);

  @$pb.TagNumber(28)
  $core.bool get guidePlayerTitles => $_getBF(26);
  @$pb.TagNumber(28)
  set guidePlayerTitles($core.bool value) => $_setBool(26, value);
  @$pb.TagNumber(28)
  $core.bool hasGuidePlayerTitles() => $_has(26);
  @$pb.TagNumber(28)
  void clearGuidePlayerTitles() => $_clearField(28);

  @$pb.TagNumber(29)
  $core.bool get guideTileText => $_getBF(27);
  @$pb.TagNumber(29)
  set guideTileText($core.bool value) => $_setBool(27, value);
  @$pb.TagNumber(29)
  $core.bool hasGuideTileText() => $_has(27);
  @$pb.TagNumber(29)
  void clearGuideTileText() => $_clearField(29);

  @$pb.TagNumber(30)
  $core.bool get autoQualityDiscovery => $_getBF(28);
  @$pb.TagNumber(30)
  set autoQualityDiscovery($core.bool value) => $_setBool(28, value);
  @$pb.TagNumber(30)
  $core.bool hasAutoQualityDiscovery() => $_has(28);
  @$pb.TagNumber(30)
  void clearAutoQualityDiscovery() => $_clearField(30);

  @$pb.TagNumber(31)
  $core.int get searchDelayMs => $_getIZ(29);
  @$pb.TagNumber(31)
  set searchDelayMs($core.int value) => $_setUnsignedInt32(29, value);
  @$pb.TagNumber(31)
  $core.bool hasSearchDelayMs() => $_has(29);
  @$pb.TagNumber(31)
  void clearSearchDelayMs() => $_clearField(31);

  @$pb.TagNumber(32)
  $core.bool get numberKeySwitching => $_getBF(30);
  @$pb.TagNumber(32)
  set numberKeySwitching($core.bool value) => $_setBool(30, value);
  @$pb.TagNumber(32)
  $core.bool hasNumberKeySwitching() => $_has(30);
  @$pb.TagNumber(32)
  void clearNumberKeySwitching() => $_clearField(32);

  @$pb.TagNumber(33)
  $core.int get uiScalePercent => $_getIZ(31);
  @$pb.TagNumber(33)
  set uiScalePercent($core.int value) => $_setUnsignedInt32(31, value);
  @$pb.TagNumber(33)
  $core.bool hasUiScalePercent() => $_has(31);
  @$pb.TagNumber(33)
  void clearUiScalePercent() => $_clearField(33);

  @$pb.TagNumber(34)
  $core.bool get squareCorners => $_getBF(32);
  @$pb.TagNumber(34)
  set squareCorners($core.bool value) => $_setBool(32, value);
  @$pb.TagNumber(34)
  $core.bool hasSquareCorners() => $_has(32);
  @$pb.TagNumber(34)
  void clearSquareCorners() => $_clearField(34);

  @$pb.TagNumber(35)
  $core.String get bottomBar => $_getSZ(33);
  @$pb.TagNumber(35)
  set bottomBar($core.String value) => $_setString(33, value);
  @$pb.TagNumber(35)
  $core.bool hasBottomBar() => $_has(33);
  @$pb.TagNumber(35)
  void clearBottomBar() => $_clearField(35);

  @$pb.TagNumber(36)
  $core.String get mediaPreferences => $_getSZ(34);
  @$pb.TagNumber(36)
  set mediaPreferences($core.String value) => $_setString(34, value);
  @$pb.TagNumber(36)
  $core.bool hasMediaPreferences() => $_has(34);
  @$pb.TagNumber(36)
  void clearMediaPreferences() => $_clearField(36);

  @$pb.TagNumber(37)
  $core.String get recordingJobs => $_getSZ(35);
  @$pb.TagNumber(37)
  set recordingJobs($core.String value) => $_setString(35, value);
  @$pb.TagNumber(37)
  $core.bool hasRecordingJobs() => $_has(35);
  @$pb.TagNumber(37)
  void clearRecordingJobs() => $_clearField(37);

  @$pb.TagNumber(38)
  $core.String get downloadJobs => $_getSZ(36);
  @$pb.TagNumber(38)
  set downloadJobs($core.String value) => $_setString(36, value);
  @$pb.TagNumber(38)
  $core.bool hasDownloadJobs() => $_has(36);
  @$pb.TagNumber(38)
  void clearDownloadJobs() => $_clearField(38);
}

class Filters extends $pb.GeneratedMessage {
  factory Filters({
    $core.String? query,
    $core.Iterable<$fixnum.Int64>? sourceIds,
    $core.Iterable<MediaType>? mediaTypes,
    ViewType? viewType,
    $core.int? page,
    $fixnum.Int64? seriesId,
    $fixnum.Int64? groupId,
    $core.bool? useKeywords,
    $core.int? sort,
    $fixnum.Int64? season,
    $core.bool? favoriteGroups,
    $core.bool? hiddenOnly,
    $core.bool? includeHidden,
  }) {
    final result = create();
    if (query != null) result.query = query;
    if (sourceIds != null) result.sourceIds.addAll(sourceIds);
    if (mediaTypes != null) result.mediaTypes.addAll(mediaTypes);
    if (viewType != null) result.viewType = viewType;
    if (page != null) result.page = page;
    if (seriesId != null) result.seriesId = seriesId;
    if (groupId != null) result.groupId = groupId;
    if (useKeywords != null) result.useKeywords = useKeywords;
    if (sort != null) result.sort = sort;
    if (season != null) result.season = season;
    if (favoriteGroups != null) result.favoriteGroups = favoriteGroups;
    if (hiddenOnly != null) result.hiddenOnly = hiddenOnly;
    if (includeHidden != null) result.includeHidden = includeHidden;
    return result;
  }

  Filters._();

  factory Filters.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Filters.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Filters',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'query')
    ..p<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'sourceIds', $pb.PbFieldType.K6)
    ..pc<MediaType>(3, _omitFieldNames ? '' : 'mediaTypes', $pb.PbFieldType.KE,
        valueOf: MediaType.valueOf,
        enumValues: MediaType.values,
        defaultEnumValue: MediaType.MEDIA_TYPE_LIVESTREAM)
    ..aE<ViewType>(4, _omitFieldNames ? '' : 'viewType',
        enumValues: ViewType.values)
    ..aI(5, _omitFieldNames ? '' : 'page', fieldType: $pb.PbFieldType.OU3)
    ..aInt64(6, _omitFieldNames ? '' : 'seriesId')
    ..aInt64(7, _omitFieldNames ? '' : 'groupId')
    ..aOB(8, _omitFieldNames ? '' : 'useKeywords')
    ..aI(9, _omitFieldNames ? '' : 'sort', fieldType: $pb.PbFieldType.OU3)
    ..aInt64(10, _omitFieldNames ? '' : 'season')
    ..aOB(11, _omitFieldNames ? '' : 'favoriteGroups')
    ..aOB(12, _omitFieldNames ? '' : 'hiddenOnly')
    ..aOB(13, _omitFieldNames ? '' : 'includeHidden')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Filters clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Filters copyWith(void Function(Filters) updates) =>
      super.copyWith((message) => updates(message as Filters)) as Filters;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Filters create() => Filters._();
  @$core.override
  Filters createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Filters getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Filters>(create);
  static Filters? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get query => $_getSZ(0);
  @$pb.TagNumber(1)
  set query($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasQuery() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuery() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$fixnum.Int64> get sourceIds => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<MediaType> get mediaTypes => $_getList(2);

  @$pb.TagNumber(4)
  ViewType get viewType => $_getN(3);
  @$pb.TagNumber(4)
  set viewType(ViewType value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasViewType() => $_has(3);
  @$pb.TagNumber(4)
  void clearViewType() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get page => $_getIZ(4);
  @$pb.TagNumber(5)
  set page($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPage() => $_has(4);
  @$pb.TagNumber(5)
  void clearPage() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get seriesId => $_getI64(5);
  @$pb.TagNumber(6)
  set seriesId($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSeriesId() => $_has(5);
  @$pb.TagNumber(6)
  void clearSeriesId() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get groupId => $_getI64(6);
  @$pb.TagNumber(7)
  set groupId($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasGroupId() => $_has(6);
  @$pb.TagNumber(7)
  void clearGroupId() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get useKeywords => $_getBF(7);
  @$pb.TagNumber(8)
  set useKeywords($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasUseKeywords() => $_has(7);
  @$pb.TagNumber(8)
  void clearUseKeywords() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get sort => $_getIZ(8);
  @$pb.TagNumber(9)
  set sort($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasSort() => $_has(8);
  @$pb.TagNumber(9)
  void clearSort() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get season => $_getI64(9);
  @$pb.TagNumber(10)
  set season($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasSeason() => $_has(9);
  @$pb.TagNumber(10)
  void clearSeason() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.bool get favoriteGroups => $_getBF(10);
  @$pb.TagNumber(11)
  set favoriteGroups($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasFavoriteGroups() => $_has(10);
  @$pb.TagNumber(11)
  void clearFavoriteGroups() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.bool get hiddenOnly => $_getBF(11);
  @$pb.TagNumber(12)
  set hiddenOnly($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasHiddenOnly() => $_has(11);
  @$pb.TagNumber(12)
  void clearHiddenOnly() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.bool get includeHidden => $_getBF(12);
  @$pb.TagNumber(13)
  set includeHidden($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(13)
  $core.bool hasIncludeHidden() => $_has(12);
  @$pb.TagNumber(13)
  void clearIncludeHidden() => $_clearField(13);
}

class ToggleFavorite extends $pb.GeneratedMessage {
  factory ToggleFavorite({
    $fixnum.Int64? channelId,
    $core.bool? favorite,
  }) {
    final result = create();
    if (channelId != null) result.channelId = channelId;
    if (favorite != null) result.favorite = favorite;
    return result;
  }

  ToggleFavorite._();

  factory ToggleFavorite.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ToggleFavorite.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ToggleFavorite',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'channelId')
    ..aOB(2, _omitFieldNames ? '' : 'favorite')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ToggleFavorite clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ToggleFavorite copyWith(void Function(ToggleFavorite) updates) =>
      super.copyWith((message) => updates(message as ToggleFavorite))
          as ToggleFavorite;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ToggleFavorite create() => ToggleFavorite._();
  @$core.override
  ToggleFavorite createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ToggleFavorite getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ToggleFavorite>(create);
  static ToggleFavorite? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get channelId => $_getI64(0);
  @$pb.TagNumber(1)
  set channelId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChannelId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChannelId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get favorite => $_getBF(1);
  @$pb.TagNumber(2)
  set favorite($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFavorite() => $_has(1);
  @$pb.TagNumber(2)
  void clearFavorite() => $_clearField(2);
}

class IdMessage extends $pb.GeneratedMessage {
  factory IdMessage({
    $fixnum.Int64? value,
  }) {
    final result = create();
    if (value != null) result.value = value;
    return result;
  }

  IdMessage._();

  factory IdMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory IdMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IdMessage',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IdMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IdMessage copyWith(void Function(IdMessage) updates) =>
      super.copyWith((message) => updates(message as IdMessage)) as IdMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IdMessage create() => IdMessage._();
  @$core.override
  IdMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static IdMessage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<IdMessage>(create);
  static IdMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get value => $_getI64(0);
  @$pb.TagNumber(1)
  set value($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class MoviePosition extends $pb.GeneratedMessage {
  factory MoviePosition({
    $fixnum.Int64? channelId,
    $fixnum.Int64? position,
  }) {
    final result = create();
    if (channelId != null) result.channelId = channelId;
    if (position != null) result.position = position;
    return result;
  }

  MoviePosition._();

  factory MoviePosition.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MoviePosition.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MoviePosition',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'channelId')
    ..aInt64(2, _omitFieldNames ? '' : 'position')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MoviePosition clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MoviePosition copyWith(void Function(MoviePosition) updates) =>
      super.copyWith((message) => updates(message as MoviePosition))
          as MoviePosition;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MoviePosition create() => MoviePosition._();
  @$core.override
  MoviePosition createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MoviePosition getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MoviePosition>(create);
  static MoviePosition? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get channelId => $_getI64(0);
  @$pb.TagNumber(1)
  set channelId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChannelId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChannelId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get position => $_getI64(1);
  @$pb.TagNumber(2)
  set position($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPosition() => $_has(1);
  @$pb.TagNumber(2)
  void clearPosition() => $_clearField(2);
}

class StrMessage extends $pb.GeneratedMessage {
  factory StrMessage({
    $core.String? value,
  }) {
    final result = create();
    if (value != null) result.value = value;
    return result;
  }

  StrMessage._();

  factory StrMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StrMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StrMessage',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StrMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StrMessage copyWith(void Function(StrMessage) updates) =>
      super.copyWith((message) => updates(message as StrMessage)) as StrMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StrMessage create() => StrMessage._();
  @$core.override
  StrMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StrMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StrMessage>(create);
  static StrMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get value => $_getSZ(0);
  @$pb.TagNumber(1)
  set value($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class OptStrMessage extends $pb.GeneratedMessage {
  factory OptStrMessage({
    $core.String? value,
  }) {
    final result = create();
    if (value != null) result.value = value;
    return result;
  }

  OptStrMessage._();

  factory OptStrMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OptStrMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OptStrMessage',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OptStrMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OptStrMessage copyWith(void Function(OptStrMessage) updates) =>
      super.copyWith((message) => updates(message as OptStrMessage))
          as OptStrMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OptStrMessage create() => OptStrMessage._();
  @$core.override
  OptStrMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static OptStrMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OptStrMessage>(create);
  static OptStrMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get value => $_getSZ(0);
  @$pb.TagNumber(1)
  set value($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class BoolMessage extends $pb.GeneratedMessage {
  factory BoolMessage({
    $core.bool? value,
  }) {
    final result = create();
    if (value != null) result.value = value;
    return result;
  }

  BoolMessage._();

  factory BoolMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BoolMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BoolMessage',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BoolMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BoolMessage copyWith(void Function(BoolMessage) updates) =>
      super.copyWith((message) => updates(message as BoolMessage))
          as BoolMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BoolMessage create() => BoolMessage._();
  @$core.override
  BoolMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BoolMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BoolMessage>(create);
  static BoolMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get value => $_getBF(0);
  @$pb.TagNumber(1)
  set value($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class GetMoviePosition extends $pb.GeneratedMessage {
  factory GetMoviePosition({
    $fixnum.Int64? position,
  }) {
    final result = create();
    if (position != null) result.position = position;
    return result;
  }

  GetMoviePosition._();

  factory GetMoviePosition.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetMoviePosition.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetMoviePosition',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'position')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetMoviePosition clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetMoviePosition copyWith(void Function(GetMoviePosition) updates) =>
      super.copyWith((message) => updates(message as GetMoviePosition))
          as GetMoviePosition;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetMoviePosition create() => GetMoviePosition._();
  @$core.override
  GetMoviePosition createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetMoviePosition getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetMoviePosition>(create);
  static GetMoviePosition? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get position => $_getI64(0);
  @$pb.TagNumber(1)
  set position($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPosition() => $_has(0);
  @$pb.TagNumber(1)
  void clearPosition() => $_clearField(1);
}

class InitMessage extends $pb.GeneratedMessage {
  factory InitMessage({
    $core.String? dbPath,
    $core.String? tempPath,
  }) {
    final result = create();
    if (dbPath != null) result.dbPath = dbPath;
    if (tempPath != null) result.tempPath = tempPath;
    return result;
  }

  InitMessage._();

  factory InitMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory InitMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'InitMessage',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'dbPath')
    ..aOS(2, _omitFieldNames ? '' : 'tempPath')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InitMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InitMessage copyWith(void Function(InitMessage) updates) =>
      super.copyWith((message) => updates(message as InitMessage))
          as InitMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static InitMessage create() => InitMessage._();
  @$core.override
  InitMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static InitMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<InitMessage>(create);
  static InitMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get dbPath => $_getSZ(0);
  @$pb.TagNumber(1)
  set dbPath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDbPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearDbPath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get tempPath => $_getSZ(1);
  @$pb.TagNumber(2)
  set tempPath($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTempPath() => $_has(1);
  @$pb.TagNumber(2)
  void clearTempPath() => $_clearField(2);
}

class GetEpisodes extends $pb.GeneratedMessage {
  factory GetEpisodes({
    $fixnum.Int64? seriesId,
    $fixnum.Int64? sourceId,
    $core.String? fallbackImage,
  }) {
    final result = create();
    if (seriesId != null) result.seriesId = seriesId;
    if (sourceId != null) result.sourceId = sourceId;
    if (fallbackImage != null) result.fallbackImage = fallbackImage;
    return result;
  }

  GetEpisodes._();

  factory GetEpisodes.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetEpisodes.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetEpisodes',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'seriesId')
    ..aInt64(2, _omitFieldNames ? '' : 'sourceId')
    ..aOS(3, _omitFieldNames ? '' : 'fallbackImage')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetEpisodes clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetEpisodes copyWith(void Function(GetEpisodes) updates) =>
      super.copyWith((message) => updates(message as GetEpisodes))
          as GetEpisodes;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetEpisodes create() => GetEpisodes._();
  @$core.override
  GetEpisodes createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetEpisodes getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetEpisodes>(create);
  static GetEpisodes? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get seriesId => $_getI64(0);
  @$pb.TagNumber(1)
  set seriesId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSeriesId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSeriesId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get sourceId => $_getI64(1);
  @$pb.TagNumber(2)
  set sourceId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSourceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSourceId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get fallbackImage => $_getSZ(2);
  @$pb.TagNumber(3)
  set fallbackImage($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFallbackImage() => $_has(2);
  @$pb.TagNumber(3)
  void clearFallbackImage() => $_clearField(3);
}

class ChannelHttpHeaders extends $pb.GeneratedMessage {
  factory ChannelHttpHeaders({
    $fixnum.Int64? id,
    $fixnum.Int64? channelId,
    $core.String? referrer,
    $core.String? userAgent,
    $core.String? httpOrigin,
    $core.bool? ignoreSsl,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (channelId != null) result.channelId = channelId;
    if (referrer != null) result.referrer = referrer;
    if (userAgent != null) result.userAgent = userAgent;
    if (httpOrigin != null) result.httpOrigin = httpOrigin;
    if (ignoreSsl != null) result.ignoreSsl = ignoreSsl;
    return result;
  }

  ChannelHttpHeaders._();

  factory ChannelHttpHeaders.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ChannelHttpHeaders.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChannelHttpHeaders',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aInt64(2, _omitFieldNames ? '' : 'channelId')
    ..aOS(3, _omitFieldNames ? '' : 'referrer')
    ..aOS(4, _omitFieldNames ? '' : 'userAgent')
    ..aOS(5, _omitFieldNames ? '' : 'httpOrigin')
    ..aOB(6, _omitFieldNames ? '' : 'ignoreSsl')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChannelHttpHeaders clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChannelHttpHeaders copyWith(void Function(ChannelHttpHeaders) updates) =>
      super.copyWith((message) => updates(message as ChannelHttpHeaders))
          as ChannelHttpHeaders;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ChannelHttpHeaders create() => ChannelHttpHeaders._();
  @$core.override
  ChannelHttpHeaders createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ChannelHttpHeaders getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ChannelHttpHeaders>(create);
  static ChannelHttpHeaders? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get channelId => $_getI64(1);
  @$pb.TagNumber(2)
  set channelId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasChannelId() => $_has(1);
  @$pb.TagNumber(2)
  void clearChannelId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get referrer => $_getSZ(2);
  @$pb.TagNumber(3)
  set referrer($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasReferrer() => $_has(2);
  @$pb.TagNumber(3)
  void clearReferrer() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get userAgent => $_getSZ(3);
  @$pb.TagNumber(4)
  set userAgent($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUserAgent() => $_has(3);
  @$pb.TagNumber(4)
  void clearUserAgent() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get httpOrigin => $_getSZ(4);
  @$pb.TagNumber(5)
  set httpOrigin($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasHttpOrigin() => $_has(4);
  @$pb.TagNumber(5)
  void clearHttpOrigin() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get ignoreSsl => $_getBF(5);
  @$pb.TagNumber(6)
  set ignoreSsl($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIgnoreSsl() => $_has(5);
  @$pb.TagNumber(6)
  void clearIgnoreSsl() => $_clearField(6);
}

class GetEnabledSourcesMinimal extends $pb.GeneratedMessage {
  factory GetEnabledSourcesMinimal({
    $core.Iterable<$fixnum.Int64>? listId,
  }) {
    final result = create();
    if (listId != null) result.listId.addAll(listId);
    return result;
  }

  GetEnabledSourcesMinimal._();

  factory GetEnabledSourcesMinimal.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetEnabledSourcesMinimal.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetEnabledSourcesMinimal',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..p<$fixnum.Int64>(1, _omitFieldNames ? '' : 'listId', $pb.PbFieldType.K6)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetEnabledSourcesMinimal clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetEnabledSourcesMinimal copyWith(
          void Function(GetEnabledSourcesMinimal) updates) =>
      super.copyWith((message) => updates(message as GetEnabledSourcesMinimal))
          as GetEnabledSourcesMinimal;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetEnabledSourcesMinimal create() => GetEnabledSourcesMinimal._();
  @$core.override
  GetEnabledSourcesMinimal createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetEnabledSourcesMinimal getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetEnabledSourcesMinimal>(create);
  static GetEnabledSourcesMinimal? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$fixnum.Int64> get listId => $_getList(0);
}

class SourceList extends $pb.GeneratedMessage {
  factory SourceList({
    $core.Iterable<Source>? sources,
  }) {
    final result = create();
    if (sources != null) result.sources.addAll(sources);
    return result;
  }

  SourceList._();

  factory SourceList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SourceList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SourceList',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..pPM<Source>(1, _omitFieldNames ? '' : 'sources',
        subBuilder: Source.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SourceList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SourceList copyWith(void Function(SourceList) updates) =>
      super.copyWith((message) => updates(message as SourceList)) as SourceList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SourceList create() => SourceList._();
  @$core.override
  SourceList createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SourceList getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SourceList>(create);
  static SourceList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Source> get sources => $_getList(0);
}

class SetSourceEnabled extends $pb.GeneratedMessage {
  factory SetSourceEnabled({
    $fixnum.Int64? sourceId,
    $core.bool? enabled,
  }) {
    final result = create();
    if (sourceId != null) result.sourceId = sourceId;
    if (enabled != null) result.enabled = enabled;
    return result;
  }

  SetSourceEnabled._();

  factory SetSourceEnabled.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetSourceEnabled.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetSourceEnabled',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'sourceId')
    ..aOB(2, _omitFieldNames ? '' : 'enabled')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetSourceEnabled clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetSourceEnabled copyWith(void Function(SetSourceEnabled) updates) =>
      super.copyWith((message) => updates(message as SetSourceEnabled))
          as SetSourceEnabled;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetSourceEnabled create() => SetSourceEnabled._();
  @$core.override
  SetSourceEnabled createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetSourceEnabled getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetSourceEnabled>(create);
  static SetSourceEnabled? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get sourceId => $_getI64(0);
  @$pb.TagNumber(1)
  set sourceId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSourceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSourceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get enabled => $_getBF(1);
  @$pb.TagNumber(2)
  set enabled($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEnabled() => $_has(1);
  @$pb.TagNumber(2)
  void clearEnabled() => $_clearField(2);
}

class Category extends $pb.GeneratedMessage {
  factory Category({
    $fixnum.Int64? id,
    $core.int? mediaType,
    $core.String? name,
    $core.bool? listed,
    $core.int? streamCount,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (mediaType != null) result.mediaType = mediaType;
    if (name != null) result.name = name;
    if (listed != null) result.listed = listed;
    if (streamCount != null) result.streamCount = streamCount;
    return result;
  }

  Category._();

  factory Category.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Category.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Category',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aI(2, _omitFieldNames ? '' : 'mediaType', fieldType: $pb.PbFieldType.OU3)
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aOB(4, _omitFieldNames ? '' : 'listed')
    ..aI(5, _omitFieldNames ? '' : 'streamCount',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Category clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Category copyWith(void Function(Category) updates) =>
      super.copyWith((message) => updates(message as Category)) as Category;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Category create() => Category._();
  @$core.override
  Category createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Category getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Category>(create);
  static Category? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get mediaType => $_getIZ(1);
  @$pb.TagNumber(2)
  set mediaType($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMediaType() => $_has(1);
  @$pb.TagNumber(2)
  void clearMediaType() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get listed => $_getBF(3);
  @$pb.TagNumber(4)
  set listed($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasListed() => $_has(3);
  @$pb.TagNumber(4)
  void clearListed() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get streamCount => $_getIZ(4);
  @$pb.TagNumber(5)
  set streamCount($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasStreamCount() => $_has(4);
  @$pb.TagNumber(5)
  void clearStreamCount() => $_clearField(5);
}

class CategoryList extends $pb.GeneratedMessage {
  factory CategoryList({
    $core.Iterable<Category>? categories,
    CategoryMode? liveMode,
    CategoryMode? moviesMode,
    CategoryMode? seriesMode,
  }) {
    final result = create();
    if (categories != null) result.categories.addAll(categories);
    if (liveMode != null) result.liveMode = liveMode;
    if (moviesMode != null) result.moviesMode = moviesMode;
    if (seriesMode != null) result.seriesMode = seriesMode;
    return result;
  }

  CategoryList._();

  factory CategoryList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CategoryList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CategoryList',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..pPM<Category>(1, _omitFieldNames ? '' : 'categories',
        subBuilder: Category.create)
    ..aE<CategoryMode>(2, _omitFieldNames ? '' : 'liveMode',
        enumValues: CategoryMode.values)
    ..aE<CategoryMode>(3, _omitFieldNames ? '' : 'moviesMode',
        enumValues: CategoryMode.values)
    ..aE<CategoryMode>(4, _omitFieldNames ? '' : 'seriesMode',
        enumValues: CategoryMode.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CategoryList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CategoryList copyWith(void Function(CategoryList) updates) =>
      super.copyWith((message) => updates(message as CategoryList))
          as CategoryList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CategoryList create() => CategoryList._();
  @$core.override
  CategoryList createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CategoryList getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CategoryList>(create);
  static CategoryList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Category> get categories => $_getList(0);

  @$pb.TagNumber(2)
  CategoryMode get liveMode => $_getN(1);
  @$pb.TagNumber(2)
  set liveMode(CategoryMode value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasLiveMode() => $_has(1);
  @$pb.TagNumber(2)
  void clearLiveMode() => $_clearField(2);

  @$pb.TagNumber(3)
  CategoryMode get moviesMode => $_getN(2);
  @$pb.TagNumber(3)
  set moviesMode(CategoryMode value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasMoviesMode() => $_has(2);
  @$pb.TagNumber(3)
  void clearMoviesMode() => $_clearField(3);

  @$pb.TagNumber(4)
  CategoryMode get seriesMode => $_getN(3);
  @$pb.TagNumber(4)
  set seriesMode(CategoryMode value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasSeriesMode() => $_has(3);
  @$pb.TagNumber(4)
  void clearSeriesMode() => $_clearField(4);
}

class SetCategories extends $pb.GeneratedMessage {
  factory SetCategories({
    $fixnum.Int64? sourceId,
    $core.int? mediaType,
    CategoryMode? mode,
    $core.Iterable<$core.String>? listed,
  }) {
    final result = create();
    if (sourceId != null) result.sourceId = sourceId;
    if (mediaType != null) result.mediaType = mediaType;
    if (mode != null) result.mode = mode;
    if (listed != null) result.listed.addAll(listed);
    return result;
  }

  SetCategories._();

  factory SetCategories.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetCategories.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetCategories',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'sourceId')
    ..aI(2, _omitFieldNames ? '' : 'mediaType', fieldType: $pb.PbFieldType.OU3)
    ..aE<CategoryMode>(3, _omitFieldNames ? '' : 'mode',
        enumValues: CategoryMode.values)
    ..pPS(4, _omitFieldNames ? '' : 'listed')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetCategories clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetCategories copyWith(void Function(SetCategories) updates) =>
      super.copyWith((message) => updates(message as SetCategories))
          as SetCategories;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetCategories create() => SetCategories._();
  @$core.override
  SetCategories createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetCategories getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetCategories>(create);
  static SetCategories? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get sourceId => $_getI64(0);
  @$pb.TagNumber(1)
  set sourceId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSourceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSourceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get mediaType => $_getIZ(1);
  @$pb.TagNumber(2)
  set mediaType($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMediaType() => $_has(1);
  @$pb.TagNumber(2)
  void clearMediaType() => $_clearField(2);

  @$pb.TagNumber(3)
  CategoryMode get mode => $_getN(2);
  @$pb.TagNumber(3)
  set mode(CategoryMode value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasMode() => $_has(2);
  @$pb.TagNumber(3)
  void clearMode() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get listed => $_getList(3);
}

/// Refresh statistics
class MediaTypeStats extends $pb.GeneratedMessage {
  factory MediaTypeStats({
    $core.int? mediaType,
    $core.bool? enabled,
    $core.bool? failed,
    $core.String? error,
    $core.int? fetched,
    $core.int? imported,
    $core.int? excluded,
    $core.int? categories,
    $core.int? categoriesExcluded,
  }) {
    final result = create();
    if (mediaType != null) result.mediaType = mediaType;
    if (enabled != null) result.enabled = enabled;
    if (failed != null) result.failed = failed;
    if (error != null) result.error = error;
    if (fetched != null) result.fetched = fetched;
    if (imported != null) result.imported = imported;
    if (excluded != null) result.excluded = excluded;
    if (categories != null) result.categories = categories;
    if (categoriesExcluded != null)
      result.categoriesExcluded = categoriesExcluded;
    return result;
  }

  MediaTypeStats._();

  factory MediaTypeStats.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MediaTypeStats.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaTypeStats',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'mediaType', fieldType: $pb.PbFieldType.OU3)
    ..aOB(2, _omitFieldNames ? '' : 'enabled')
    ..aOB(3, _omitFieldNames ? '' : 'failed')
    ..aOS(4, _omitFieldNames ? '' : 'error')
    ..aI(5, _omitFieldNames ? '' : 'fetched', fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'imported', fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'excluded', fieldType: $pb.PbFieldType.OU3)
    ..aI(8, _omitFieldNames ? '' : 'categories', fieldType: $pb.PbFieldType.OU3)
    ..aI(9, _omitFieldNames ? '' : 'categoriesExcluded',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaTypeStats clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaTypeStats copyWith(void Function(MediaTypeStats) updates) =>
      super.copyWith((message) => updates(message as MediaTypeStats))
          as MediaTypeStats;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MediaTypeStats create() => MediaTypeStats._();
  @$core.override
  MediaTypeStats createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MediaTypeStats getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaTypeStats>(create);
  static MediaTypeStats? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get mediaType => $_getIZ(0);
  @$pb.TagNumber(1)
  set mediaType($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMediaType() => $_has(0);
  @$pb.TagNumber(1)
  void clearMediaType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get enabled => $_getBF(1);
  @$pb.TagNumber(2)
  set enabled($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEnabled() => $_has(1);
  @$pb.TagNumber(2)
  void clearEnabled() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get failed => $_getBF(2);
  @$pb.TagNumber(3)
  set failed($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFailed() => $_has(2);
  @$pb.TagNumber(3)
  void clearFailed() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get error => $_getSZ(3);
  @$pb.TagNumber(4)
  set error($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasError() => $_has(3);
  @$pb.TagNumber(4)
  void clearError() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get fetched => $_getIZ(4);
  @$pb.TagNumber(5)
  set fetched($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFetched() => $_has(4);
  @$pb.TagNumber(5)
  void clearFetched() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get imported => $_getIZ(5);
  @$pb.TagNumber(6)
  set imported($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasImported() => $_has(5);
  @$pb.TagNumber(6)
  void clearImported() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get excluded => $_getIZ(6);
  @$pb.TagNumber(7)
  set excluded($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasExcluded() => $_has(6);
  @$pb.TagNumber(7)
  void clearExcluded() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get categories => $_getIZ(7);
  @$pb.TagNumber(8)
  set categories($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCategories() => $_has(7);
  @$pb.TagNumber(8)
  void clearCategories() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get categoriesExcluded => $_getIZ(8);
  @$pb.TagNumber(9)
  set categoriesExcluded($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasCategoriesExcluded() => $_has(8);
  @$pb.TagNumber(9)
  void clearCategoriesExcluded() => $_clearField(9);
}

class RefreshStats extends $pb.GeneratedMessage {
  factory RefreshStats({
    $fixnum.Int64? sourceId,
    $core.String? sourceName,
    $core.Iterable<MediaTypeStats>? types,
    $fixnum.Int64? durationMs,
    $fixnum.Int64? finishedAt,
    $core.bool? success,
    $core.String? error,
  }) {
    final result = create();
    if (sourceId != null) result.sourceId = sourceId;
    if (sourceName != null) result.sourceName = sourceName;
    if (types != null) result.types.addAll(types);
    if (durationMs != null) result.durationMs = durationMs;
    if (finishedAt != null) result.finishedAt = finishedAt;
    if (success != null) result.success = success;
    if (error != null) result.error = error;
    return result;
  }

  RefreshStats._();

  factory RefreshStats.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RefreshStats.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RefreshStats',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'sourceId')
    ..aOS(2, _omitFieldNames ? '' : 'sourceName')
    ..pPM<MediaTypeStats>(3, _omitFieldNames ? '' : 'types',
        subBuilder: MediaTypeStats.create)
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'durationMs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aInt64(5, _omitFieldNames ? '' : 'finishedAt')
    ..aOB(6, _omitFieldNames ? '' : 'success')
    ..aOS(7, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefreshStats clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefreshStats copyWith(void Function(RefreshStats) updates) =>
      super.copyWith((message) => updates(message as RefreshStats))
          as RefreshStats;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RefreshStats create() => RefreshStats._();
  @$core.override
  RefreshStats createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RefreshStats getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RefreshStats>(create);
  static RefreshStats? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get sourceId => $_getI64(0);
  @$pb.TagNumber(1)
  set sourceId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSourceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSourceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sourceName => $_getSZ(1);
  @$pb.TagNumber(2)
  set sourceName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSourceName() => $_has(1);
  @$pb.TagNumber(2)
  void clearSourceName() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<MediaTypeStats> get types => $_getList(2);

  @$pb.TagNumber(4)
  $fixnum.Int64 get durationMs => $_getI64(3);
  @$pb.TagNumber(4)
  set durationMs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDurationMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearDurationMs() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get finishedAt => $_getI64(4);
  @$pb.TagNumber(5)
  set finishedAt($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFinishedAt() => $_has(4);
  @$pb.TagNumber(5)
  void clearFinishedAt() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get success => $_getBF(5);
  @$pb.TagNumber(6)
  set success($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSuccess() => $_has(5);
  @$pb.TagNumber(6)
  void clearSuccess() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get error => $_getSZ(6);
  @$pb.TagNumber(7)
  set error($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasError() => $_has(6);
  @$pb.TagNumber(7)
  void clearError() => $_clearField(7);
}

class RefreshStatsList extends $pb.GeneratedMessage {
  factory RefreshStatsList({
    $core.Iterable<RefreshStats>? stats,
  }) {
    final result = create();
    if (stats != null) result.stats.addAll(stats);
    return result;
  }

  RefreshStatsList._();

  factory RefreshStatsList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RefreshStatsList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RefreshStatsList',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..pPM<RefreshStats>(1, _omitFieldNames ? '' : 'stats',
        subBuilder: RefreshStats.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefreshStatsList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefreshStatsList copyWith(void Function(RefreshStatsList) updates) =>
      super.copyWith((message) => updates(message as RefreshStatsList))
          as RefreshStatsList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RefreshStatsList create() => RefreshStatsList._();
  @$core.override
  RefreshStatsList createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RefreshStatsList getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RefreshStatsList>(create);
  static RefreshStatsList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<RefreshStats> get stats => $_getList(0);
}

class AltOverride extends $pb.GeneratedMessage {
  factory AltOverride({
    $fixnum.Int64? channelId,
    AltOverrideKind? kind,
    $fixnum.Int64? targetChannelId,
  }) {
    final result = create();
    if (channelId != null) result.channelId = channelId;
    if (kind != null) result.kind = kind;
    if (targetChannelId != null) result.targetChannelId = targetChannelId;
    return result;
  }

  AltOverride._();

  factory AltOverride.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AltOverride.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AltOverride',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'channelId')
    ..aE<AltOverrideKind>(2, _omitFieldNames ? '' : 'kind',
        enumValues: AltOverrideKind.values)
    ..aInt64(3, _omitFieldNames ? '' : 'targetChannelId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AltOverride clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AltOverride copyWith(void Function(AltOverride) updates) =>
      super.copyWith((message) => updates(message as AltOverride))
          as AltOverride;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AltOverride create() => AltOverride._();
  @$core.override
  AltOverride createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AltOverride getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AltOverride>(create);
  static AltOverride? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get channelId => $_getI64(0);
  @$pb.TagNumber(1)
  set channelId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChannelId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChannelId() => $_clearField(1);

  @$pb.TagNumber(2)
  AltOverrideKind get kind => $_getN(1);
  @$pb.TagNumber(2)
  set kind(AltOverrideKind value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasKind() => $_has(1);
  @$pb.TagNumber(2)
  void clearKind() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get targetChannelId => $_getI64(2);
  @$pb.TagNumber(3)
  set targetChannelId($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTargetChannelId() => $_has(2);
  @$pb.TagNumber(3)
  void clearTargetChannelId() => $_clearField(3);
}

/// HLS variants
class StreamVariant extends $pb.GeneratedMessage {
  factory StreamVariant({
    $core.String? url,
    $fixnum.Int64? bandwidth,
    $fixnum.Int64? averageBandwidth,
    $core.int? width,
    $core.int? height,
    $core.double? frameRate,
    $core.String? codecs,
    $core.String? name,
  }) {
    final result = create();
    if (url != null) result.url = url;
    if (bandwidth != null) result.bandwidth = bandwidth;
    if (averageBandwidth != null) result.averageBandwidth = averageBandwidth;
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    if (frameRate != null) result.frameRate = frameRate;
    if (codecs != null) result.codecs = codecs;
    if (name != null) result.name = name;
    return result;
  }

  StreamVariant._();

  factory StreamVariant.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StreamVariant.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamVariant',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'url')
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'bandwidth', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'averageBandwidth', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(4, _omitFieldNames ? '' : 'width', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'height', fieldType: $pb.PbFieldType.OU3)
    ..aD(6, _omitFieldNames ? '' : 'frameRate')
    ..aOS(7, _omitFieldNames ? '' : 'codecs')
    ..aOS(8, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamVariant clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamVariant copyWith(void Function(StreamVariant) updates) =>
      super.copyWith((message) => updates(message as StreamVariant))
          as StreamVariant;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StreamVariant create() => StreamVariant._();
  @$core.override
  StreamVariant createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StreamVariant getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StreamVariant>(create);
  static StreamVariant? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get url => $_getSZ(0);
  @$pb.TagNumber(1)
  set url($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearUrl() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get bandwidth => $_getI64(1);
  @$pb.TagNumber(2)
  set bandwidth($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBandwidth() => $_has(1);
  @$pb.TagNumber(2)
  void clearBandwidth() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get averageBandwidth => $_getI64(2);
  @$pb.TagNumber(3)
  set averageBandwidth($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAverageBandwidth() => $_has(2);
  @$pb.TagNumber(3)
  void clearAverageBandwidth() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get width => $_getIZ(3);
  @$pb.TagNumber(4)
  set width($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasWidth() => $_has(3);
  @$pb.TagNumber(4)
  void clearWidth() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get height => $_getIZ(4);
  @$pb.TagNumber(5)
  set height($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasHeight() => $_has(4);
  @$pb.TagNumber(5)
  void clearHeight() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get frameRate => $_getN(5);
  @$pb.TagNumber(6)
  set frameRate($core.double value) => $_setDouble(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFrameRate() => $_has(5);
  @$pb.TagNumber(6)
  void clearFrameRate() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get codecs => $_getSZ(6);
  @$pb.TagNumber(7)
  set codecs($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCodecs() => $_has(6);
  @$pb.TagNumber(7)
  void clearCodecs() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get name => $_getSZ(7);
  @$pb.TagNumber(8)
  set name($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasName() => $_has(7);
  @$pb.TagNumber(8)
  void clearName() => $_clearField(8);
}

class StreamVariantsRequest extends $pb.GeneratedMessage {
  factory StreamVariantsRequest({
    $fixnum.Int64? channelId,
    $core.String? url,
  }) {
    final result = create();
    if (channelId != null) result.channelId = channelId;
    if (url != null) result.url = url;
    return result;
  }

  StreamVariantsRequest._();

  factory StreamVariantsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StreamVariantsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamVariantsRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'channelId')
    ..aOS(2, _omitFieldNames ? '' : 'url')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamVariantsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamVariantsRequest copyWith(
          void Function(StreamVariantsRequest) updates) =>
      super.copyWith((message) => updates(message as StreamVariantsRequest))
          as StreamVariantsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StreamVariantsRequest create() => StreamVariantsRequest._();
  @$core.override
  StreamVariantsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StreamVariantsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StreamVariantsRequest>(create);
  static StreamVariantsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get channelId => $_getI64(0);
  @$pb.TagNumber(1)
  set channelId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChannelId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChannelId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get url => $_getSZ(1);
  @$pb.TagNumber(2)
  set url($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUrl() => $_has(1);
  @$pb.TagNumber(2)
  void clearUrl() => $_clearField(2);
}

class StreamVariantList extends $pb.GeneratedMessage {
  factory StreamVariantList({
    $core.Iterable<StreamVariant>? variants,
    $core.String? masterUrl,
  }) {
    final result = create();
    if (variants != null) result.variants.addAll(variants);
    if (masterUrl != null) result.masterUrl = masterUrl;
    return result;
  }

  StreamVariantList._();

  factory StreamVariantList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StreamVariantList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamVariantList',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..pPM<StreamVariant>(1, _omitFieldNames ? '' : 'variants',
        subBuilder: StreamVariant.create)
    ..aOS(2, _omitFieldNames ? '' : 'masterUrl')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamVariantList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamVariantList copyWith(void Function(StreamVariantList) updates) =>
      super.copyWith((message) => updates(message as StreamVariantList))
          as StreamVariantList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StreamVariantList create() => StreamVariantList._();
  @$core.override
  StreamVariantList createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StreamVariantList getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StreamVariantList>(create);
  static StreamVariantList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<StreamVariant> get variants => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get masterUrl => $_getSZ(1);
  @$pb.TagNumber(2)
  set masterUrl($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMasterUrl() => $_has(1);
  @$pb.TagNumber(2)
  void clearMasterUrl() => $_clearField(2);
}

class Programme extends $pb.GeneratedMessage {
  factory Programme({
    $core.String? title,
    $fixnum.Int64? start,
    $fixnum.Int64? stop,
    $core.bool? catchupAvailable,
  }) {
    final result = create();
    if (title != null) result.title = title;
    if (start != null) result.start = start;
    if (stop != null) result.stop = stop;
    if (catchupAvailable != null) result.catchupAvailable = catchupAvailable;
    return result;
  }

  Programme._();

  factory Programme.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Programme.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Programme',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'title')
    ..aInt64(2, _omitFieldNames ? '' : 'start')
    ..aInt64(3, _omitFieldNames ? '' : 'stop')
    ..aOB(4, _omitFieldNames ? '' : 'catchupAvailable')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Programme clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Programme copyWith(void Function(Programme) updates) =>
      super.copyWith((message) => updates(message as Programme)) as Programme;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Programme create() => Programme._();
  @$core.override
  Programme createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Programme getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Programme>(create);
  static Programme? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get title => $_getSZ(0);
  @$pb.TagNumber(1)
  set title($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearTitle() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get start => $_getI64(1);
  @$pb.TagNumber(2)
  set start($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStart() => $_has(1);
  @$pb.TagNumber(2)
  void clearStart() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get stop => $_getI64(2);
  @$pb.TagNumber(3)
  set stop($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStop() => $_has(2);
  @$pb.TagNumber(3)
  void clearStop() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get catchupAvailable => $_getBF(3);
  @$pb.TagNumber(4)
  set catchupAvailable($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCatchupAvailable() => $_has(3);
  @$pb.TagNumber(4)
  void clearCatchupAvailable() => $_clearField(4);
}

class NowNext extends $pb.GeneratedMessage {
  factory NowNext({
    $core.bool? supported,
    Programme? now,
    Programme? next,
  }) {
    final result = create();
    if (supported != null) result.supported = supported;
    if (now != null) result.now = now;
    if (next != null) result.next = next;
    return result;
  }

  NowNext._();

  factory NowNext.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NowNext.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NowNext',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'supported')
    ..aOM<Programme>(2, _omitFieldNames ? '' : 'now',
        subBuilder: Programme.create)
    ..aOM<Programme>(3, _omitFieldNames ? '' : 'next',
        subBuilder: Programme.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NowNext clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NowNext copyWith(void Function(NowNext) updates) =>
      super.copyWith((message) => updates(message as NowNext)) as NowNext;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NowNext create() => NowNext._();
  @$core.override
  NowNext createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NowNext getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<NowNext>(create);
  static NowNext? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get supported => $_getBF(0);
  @$pb.TagNumber(1)
  set supported($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSupported() => $_has(0);
  @$pb.TagNumber(1)
  void clearSupported() => $_clearField(1);

  @$pb.TagNumber(2)
  Programme get now => $_getN(1);
  @$pb.TagNumber(2)
  set now(Programme value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasNow() => $_has(1);
  @$pb.TagNumber(2)
  void clearNow() => $_clearField(2);
  @$pb.TagNumber(2)
  Programme ensureNow() => $_ensure(1);

  @$pb.TagNumber(3)
  Programme get next => $_getN(2);
  @$pb.TagNumber(3)
  set next(Programme value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasNext() => $_has(2);
  @$pb.TagNumber(3)
  void clearNext() => $_clearField(3);
  @$pb.TagNumber(3)
  Programme ensureNext() => $_ensure(2);
}

class TransferInfo extends $pb.GeneratedMessage {
  factory TransferInfo({
    Channel? channel,
    $core.int? maxConnections,
    $core.String? identity,
    $core.String? showName,
    $core.int? season,
    $core.int? episode,
  }) {
    final result = create();
    if (channel != null) result.channel = channel;
    if (maxConnections != null) result.maxConnections = maxConnections;
    if (identity != null) result.identity = identity;
    if (showName != null) result.showName = showName;
    if (season != null) result.season = season;
    if (episode != null) result.episode = episode;
    return result;
  }

  TransferInfo._();

  factory TransferInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TransferInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransferInfo',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aOM<Channel>(1, _omitFieldNames ? '' : 'channel',
        subBuilder: Channel.create)
    ..aI(2, _omitFieldNames ? '' : 'maxConnections',
        fieldType: $pb.PbFieldType.OU3)
    ..aOS(3, _omitFieldNames ? '' : 'identity')
    ..aOS(4, _omitFieldNames ? '' : 'showName')
    ..aI(5, _omitFieldNames ? '' : 'season', fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'episode', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferInfo copyWith(void Function(TransferInfo) updates) =>
      super.copyWith((message) => updates(message as TransferInfo))
          as TransferInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TransferInfo create() => TransferInfo._();
  @$core.override
  TransferInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TransferInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TransferInfo>(create);
  static TransferInfo? _defaultInstance;

  @$pb.TagNumber(1)
  Channel get channel => $_getN(0);
  @$pb.TagNumber(1)
  set channel(Channel value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasChannel() => $_has(0);
  @$pb.TagNumber(1)
  void clearChannel() => $_clearField(1);
  @$pb.TagNumber(1)
  Channel ensureChannel() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.int get maxConnections => $_getIZ(1);
  @$pb.TagNumber(2)
  set maxConnections($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMaxConnections() => $_has(1);
  @$pb.TagNumber(2)
  void clearMaxConnections() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get identity => $_getSZ(2);
  @$pb.TagNumber(3)
  set identity($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIdentity() => $_has(2);
  @$pb.TagNumber(3)
  void clearIdentity() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get showName => $_getSZ(3);
  @$pb.TagNumber(4)
  set showName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasShowName() => $_has(3);
  @$pb.TagNumber(4)
  void clearShowName() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get season => $_getIZ(4);
  @$pb.TagNumber(5)
  set season($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSeason() => $_has(4);
  @$pb.TagNumber(5)
  void clearSeason() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get episode => $_getIZ(5);
  @$pb.TagNumber(6)
  set episode($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasEpisode() => $_has(5);
  @$pb.TagNumber(6)
  void clearEpisode() => $_clearField(6);
}

/// A ranged transfer into `part_path`; `total`, `etag` and `last_modified` are
/// what an earlier attempt saved, and validate the partial file on resume.
class DownloadRequest extends $pb.GeneratedMessage {
  factory DownloadRequest({
    $core.String? id,
    $core.String? url,
    $core.String? partPath,
    $core.String? userAgent,
    $core.String? referrer,
    $core.String? httpOrigin,
    $core.bool? ignoreSsl,
    $core.String? etag,
    $core.String? lastModified,
    $fixnum.Int64? total,
    $fixnum.Int64? reservedBytes,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (url != null) result.url = url;
    if (partPath != null) result.partPath = partPath;
    if (userAgent != null) result.userAgent = userAgent;
    if (referrer != null) result.referrer = referrer;
    if (httpOrigin != null) result.httpOrigin = httpOrigin;
    if (ignoreSsl != null) result.ignoreSsl = ignoreSsl;
    if (etag != null) result.etag = etag;
    if (lastModified != null) result.lastModified = lastModified;
    if (total != null) result.total = total;
    if (reservedBytes != null) result.reservedBytes = reservedBytes;
    return result;
  }

  DownloadRequest._();

  factory DownloadRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DownloadRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DownloadRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'url')
    ..aOS(3, _omitFieldNames ? '' : 'partPath')
    ..aOS(4, _omitFieldNames ? '' : 'userAgent')
    ..aOS(5, _omitFieldNames ? '' : 'referrer')
    ..aOS(6, _omitFieldNames ? '' : 'httpOrigin')
    ..aOB(7, _omitFieldNames ? '' : 'ignoreSsl')
    ..aOS(8, _omitFieldNames ? '' : 'etag')
    ..aOS(9, _omitFieldNames ? '' : 'lastModified')
    ..aInt64(10, _omitFieldNames ? '' : 'total')
    ..aInt64(11, _omitFieldNames ? '' : 'reservedBytes')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownloadRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownloadRequest copyWith(void Function(DownloadRequest) updates) =>
      super.copyWith((message) => updates(message as DownloadRequest))
          as DownloadRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DownloadRequest create() => DownloadRequest._();
  @$core.override
  DownloadRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DownloadRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DownloadRequest>(create);
  static DownloadRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get url => $_getSZ(1);
  @$pb.TagNumber(2)
  set url($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUrl() => $_has(1);
  @$pb.TagNumber(2)
  void clearUrl() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get partPath => $_getSZ(2);
  @$pb.TagNumber(3)
  set partPath($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPartPath() => $_has(2);
  @$pb.TagNumber(3)
  void clearPartPath() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get userAgent => $_getSZ(3);
  @$pb.TagNumber(4)
  set userAgent($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUserAgent() => $_has(3);
  @$pb.TagNumber(4)
  void clearUserAgent() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get referrer => $_getSZ(4);
  @$pb.TagNumber(5)
  set referrer($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasReferrer() => $_has(4);
  @$pb.TagNumber(5)
  void clearReferrer() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get httpOrigin => $_getSZ(5);
  @$pb.TagNumber(6)
  set httpOrigin($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHttpOrigin() => $_has(5);
  @$pb.TagNumber(6)
  void clearHttpOrigin() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get ignoreSsl => $_getBF(6);
  @$pb.TagNumber(7)
  set ignoreSsl($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasIgnoreSsl() => $_has(6);
  @$pb.TagNumber(7)
  void clearIgnoreSsl() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get etag => $_getSZ(7);
  @$pb.TagNumber(8)
  set etag($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasEtag() => $_has(7);
  @$pb.TagNumber(8)
  void clearEtag() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get lastModified => $_getSZ(8);
  @$pb.TagNumber(9)
  set lastModified($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasLastModified() => $_has(8);
  @$pb.TagNumber(9)
  void clearLastModified() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get total => $_getI64(9);
  @$pb.TagNumber(10)
  set total($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasTotal() => $_has(9);
  @$pb.TagNumber(10)
  void clearTotal() => $_clearField(10);

  @$pb.TagNumber(11)
  $fixnum.Int64 get reservedBytes => $_getI64(10);
  @$pb.TagNumber(11)
  set reservedBytes($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(11)
  $core.bool hasReservedBytes() => $_has(10);
  @$pb.TagNumber(11)
  void clearReservedBytes() => $_clearField(11);
}

class DownloadStatus extends $pb.GeneratedMessage {
  factory DownloadStatus({
    $fixnum.Int64? bytes,
    $fixnum.Int64? total,
    $core.String? etag,
    $core.String? lastModified,
    $core.bool? finished,
    $core.bool? stopped,
    $core.String? failure,
    $core.bool? active,
  }) {
    final result = create();
    if (bytes != null) result.bytes = bytes;
    if (total != null) result.total = total;
    if (etag != null) result.etag = etag;
    if (lastModified != null) result.lastModified = lastModified;
    if (finished != null) result.finished = finished;
    if (stopped != null) result.stopped = stopped;
    if (failure != null) result.failure = failure;
    if (active != null) result.active = active;
    return result;
  }

  DownloadStatus._();

  factory DownloadStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DownloadStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DownloadStatus',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'bytes')
    ..aInt64(2, _omitFieldNames ? '' : 'total')
    ..aOS(3, _omitFieldNames ? '' : 'etag')
    ..aOS(4, _omitFieldNames ? '' : 'lastModified')
    ..aOB(5, _omitFieldNames ? '' : 'finished')
    ..aOB(6, _omitFieldNames ? '' : 'stopped')
    ..aOS(7, _omitFieldNames ? '' : 'failure')
    ..aOB(8, _omitFieldNames ? '' : 'active')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownloadStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownloadStatus copyWith(void Function(DownloadStatus) updates) =>
      super.copyWith((message) => updates(message as DownloadStatus))
          as DownloadStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DownloadStatus create() => DownloadStatus._();
  @$core.override
  DownloadStatus createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DownloadStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DownloadStatus>(create);
  static DownloadStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get bytes => $_getI64(0);
  @$pb.TagNumber(1)
  set bytes($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBytes() => $_has(0);
  @$pb.TagNumber(1)
  void clearBytes() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get total => $_getI64(1);
  @$pb.TagNumber(2)
  set total($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTotal() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotal() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get etag => $_getSZ(2);
  @$pb.TagNumber(3)
  set etag($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEtag() => $_has(2);
  @$pb.TagNumber(3)
  void clearEtag() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get lastModified => $_getSZ(3);
  @$pb.TagNumber(4)
  set lastModified($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLastModified() => $_has(3);
  @$pb.TagNumber(4)
  void clearLastModified() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get finished => $_getBF(4);
  @$pb.TagNumber(5)
  set finished($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFinished() => $_has(4);
  @$pb.TagNumber(5)
  void clearFinished() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get stopped => $_getBF(5);
  @$pb.TagNumber(6)
  set stopped($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStopped() => $_has(5);
  @$pb.TagNumber(6)
  void clearStopped() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get failure => $_getSZ(6);
  @$pb.TagNumber(7)
  set failure($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasFailure() => $_has(6);
  @$pb.TagNumber(7)
  void clearFailure() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get active => $_getBF(7);
  @$pb.TagNumber(8)
  set active($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasActive() => $_has(7);
  @$pb.TagNumber(8)
  void clearActive() => $_clearField(8);
}

/// A live stream to inspect and, if needed, relay to a local repackager.
class RelayRequest extends $pb.GeneratedMessage {
  factory RelayRequest({
    $core.String? url,
    $core.String? userAgent,
    $core.String? referrer,
    $core.String? httpOrigin,
    $core.bool? ignoreSsl,
    $core.String? directory,
    $core.bool? seekable,
  }) {
    final result = create();
    if (url != null) result.url = url;
    if (userAgent != null) result.userAgent = userAgent;
    if (referrer != null) result.referrer = referrer;
    if (httpOrigin != null) result.httpOrigin = httpOrigin;
    if (ignoreSsl != null) result.ignoreSsl = ignoreSsl;
    if (directory != null) result.directory = directory;
    if (seekable != null) result.seekable = seekable;
    return result;
  }

  RelayRequest._();

  factory RelayRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RelayRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RelayRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'url')
    ..aOS(2, _omitFieldNames ? '' : 'userAgent')
    ..aOS(3, _omitFieldNames ? '' : 'referrer')
    ..aOS(4, _omitFieldNames ? '' : 'httpOrigin')
    ..aOB(5, _omitFieldNames ? '' : 'ignoreSsl')
    ..aOS(6, _omitFieldNames ? '' : 'directory')
    ..aOB(7, _omitFieldNames ? '' : 'seekable')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelayRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelayRequest copyWith(void Function(RelayRequest) updates) =>
      super.copyWith((message) => updates(message as RelayRequest))
          as RelayRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RelayRequest create() => RelayRequest._();
  @$core.override
  RelayRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RelayRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RelayRequest>(create);
  static RelayRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get url => $_getSZ(0);
  @$pb.TagNumber(1)
  set url($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearUrl() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get userAgent => $_getSZ(1);
  @$pb.TagNumber(2)
  set userAgent($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUserAgent() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserAgent() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get referrer => $_getSZ(2);
  @$pb.TagNumber(3)
  set referrer($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasReferrer() => $_has(2);
  @$pb.TagNumber(3)
  void clearReferrer() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get httpOrigin => $_getSZ(3);
  @$pb.TagNumber(4)
  set httpOrigin($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasHttpOrigin() => $_has(3);
  @$pb.TagNumber(4)
  void clearHttpOrigin() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get ignoreSsl => $_getBF(4);
  @$pb.TagNumber(5)
  set ignoreSsl($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIgnoreSsl() => $_has(4);
  @$pb.TagNumber(5)
  void clearIgnoreSsl() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get directory => $_getSZ(5);
  @$pb.TagNumber(6)
  set directory($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDirectory() => $_has(5);
  @$pb.TagNumber(6)
  void clearDirectory() => $_clearField(6);

  /// A file rather than a live stream: nothing is fetched until a reader
  /// asks, and each request's Range goes to the provider (input.<anything>).
  @$pb.TagNumber(7)
  $core.bool get seekable => $_getBF(6);
  @$pb.TagNumber(7)
  set seekable($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSeekable() => $_has(6);
  @$pb.TagNumber(7)
  void clearSeekable() => $_clearField(7);
}

/// `video`/`audio` are FFmpeg codec names from the stream's program map,
/// empty when absent or when the stream is not MPEG-TS. Files in the request's
/// folder are served at http://127.0.0.1:<port>/<token>/<name>; the provider's
/// bytes at .../input.ts.
class RelayInfo extends $pb.GeneratedMessage {
  factory RelayInfo({
    $core.String? token,
    $core.int? port,
    $core.String? video,
    $core.String? audio,
  }) {
    final result = create();
    if (token != null) result.token = token;
    if (port != null) result.port = port;
    if (video != null) result.video = video;
    if (audio != null) result.audio = audio;
    return result;
  }

  RelayInfo._();

  factory RelayInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RelayInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RelayInfo',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'token')
    ..aI(2, _omitFieldNames ? '' : 'port', fieldType: $pb.PbFieldType.OU3)
    ..aOS(3, _omitFieldNames ? '' : 'video')
    ..aOS(4, _omitFieldNames ? '' : 'audio')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelayInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelayInfo copyWith(void Function(RelayInfo) updates) =>
      super.copyWith((message) => updates(message as RelayInfo)) as RelayInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RelayInfo create() => RelayInfo._();
  @$core.override
  RelayInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RelayInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RelayInfo>(create);
  static RelayInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get token => $_getSZ(0);
  @$pb.TagNumber(1)
  set token($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get port => $_getIZ(1);
  @$pb.TagNumber(2)
  set port($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPort() => $_has(1);
  @$pb.TagNumber(2)
  void clearPort() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get video => $_getSZ(2);
  @$pb.TagNumber(3)
  set video($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasVideo() => $_has(2);
  @$pb.TagNumber(3)
  void clearVideo() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get audio => $_getSZ(3);
  @$pb.TagNumber(4)
  set audio($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAudio() => $_has(3);
  @$pb.TagNumber(4)
  void clearAudio() => $_clearField(4);
}

enum FFIResult_Data {
  settings,
  source,
  channelList,
  boolMessage,
  moviePosition,
  headers,
  enabledSourcesMinimal,
  sourceList,
  categoryList,
  refreshStats,
  refreshStatsList,
  streamVariants,
  nowNext,
  programmeList,
  transferInfo,
  diskSpace,
  downloadStatus,
  relayInfo,
  notSet
}

class FFIResult extends $pb.GeneratedMessage {
  factory FFIResult({
    $core.bool? success,
    $core.String? errorMessage,
    Settings? settings,
    Source? source,
    ChannelList? channelList,
    BoolMessage? boolMessage,
    GetMoviePosition? moviePosition,
    ChannelHttpHeaders? headers,
    GetEnabledSourcesMinimal? enabledSourcesMinimal,
    SourceList? sourceList,
    CategoryList? categoryList,
    RefreshStats? refreshStats,
    RefreshStatsList? refreshStatsList,
    StreamVariantList? streamVariants,
    NowNext? nowNext,
    ProgrammeList? programmeList,
    TransferInfo? transferInfo,
    IdMessage? diskSpace,
    DownloadStatus? downloadStatus,
    RelayInfo? relayInfo,
  }) {
    final result = create();
    if (success != null) result.success = success;
    if (errorMessage != null) result.errorMessage = errorMessage;
    if (settings != null) result.settings = settings;
    if (source != null) result.source = source;
    if (channelList != null) result.channelList = channelList;
    if (boolMessage != null) result.boolMessage = boolMessage;
    if (moviePosition != null) result.moviePosition = moviePosition;
    if (headers != null) result.headers = headers;
    if (enabledSourcesMinimal != null)
      result.enabledSourcesMinimal = enabledSourcesMinimal;
    if (sourceList != null) result.sourceList = sourceList;
    if (categoryList != null) result.categoryList = categoryList;
    if (refreshStats != null) result.refreshStats = refreshStats;
    if (refreshStatsList != null) result.refreshStatsList = refreshStatsList;
    if (streamVariants != null) result.streamVariants = streamVariants;
    if (nowNext != null) result.nowNext = nowNext;
    if (programmeList != null) result.programmeList = programmeList;
    if (transferInfo != null) result.transferInfo = transferInfo;
    if (diskSpace != null) result.diskSpace = diskSpace;
    if (downloadStatus != null) result.downloadStatus = downloadStatus;
    if (relayInfo != null) result.relayInfo = relayInfo;
    return result;
  }

  FFIResult._();

  factory FFIResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FFIResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, FFIResult_Data> _FFIResult_DataByTag = {
    3: FFIResult_Data.settings,
    4: FFIResult_Data.source,
    6: FFIResult_Data.channelList,
    7: FFIResult_Data.boolMessage,
    8: FFIResult_Data.moviePosition,
    9: FFIResult_Data.headers,
    10: FFIResult_Data.enabledSourcesMinimal,
    11: FFIResult_Data.sourceList,
    12: FFIResult_Data.categoryList,
    13: FFIResult_Data.refreshStats,
    14: FFIResult_Data.refreshStatsList,
    15: FFIResult_Data.streamVariants,
    16: FFIResult_Data.nowNext,
    17: FFIResult_Data.programmeList,
    18: FFIResult_Data.transferInfo,
    19: FFIResult_Data.diskSpace,
    20: FFIResult_Data.downloadStatus,
    21: FFIResult_Data.relayInfo,
    0: FFIResult_Data.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FFIResult',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'generated_proto'),
      createEmptyInstance: create)
    ..oo(0, [3, 4, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21])
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'errorMessage')
    ..aOM<Settings>(3, _omitFieldNames ? '' : 'settings',
        subBuilder: Settings.create)
    ..aOM<Source>(4, _omitFieldNames ? '' : 'source', subBuilder: Source.create)
    ..aOM<ChannelList>(6, _omitFieldNames ? '' : 'channelList',
        subBuilder: ChannelList.create)
    ..aOM<BoolMessage>(7, _omitFieldNames ? '' : 'boolMessage',
        subBuilder: BoolMessage.create)
    ..aOM<GetMoviePosition>(8, _omitFieldNames ? '' : 'moviePosition',
        subBuilder: GetMoviePosition.create)
    ..aOM<ChannelHttpHeaders>(9, _omitFieldNames ? '' : 'headers',
        subBuilder: ChannelHttpHeaders.create)
    ..aOM<GetEnabledSourcesMinimal>(
        10, _omitFieldNames ? '' : 'enabledSourcesMinimal',
        subBuilder: GetEnabledSourcesMinimal.create)
    ..aOM<SourceList>(11, _omitFieldNames ? '' : 'sourceList',
        subBuilder: SourceList.create)
    ..aOM<CategoryList>(12, _omitFieldNames ? '' : 'categoryList',
        subBuilder: CategoryList.create)
    ..aOM<RefreshStats>(13, _omitFieldNames ? '' : 'refreshStats',
        subBuilder: RefreshStats.create)
    ..aOM<RefreshStatsList>(14, _omitFieldNames ? '' : 'refreshStatsList',
        subBuilder: RefreshStatsList.create)
    ..aOM<StreamVariantList>(15, _omitFieldNames ? '' : 'streamVariants',
        subBuilder: StreamVariantList.create)
    ..aOM<NowNext>(16, _omitFieldNames ? '' : 'nowNext',
        subBuilder: NowNext.create)
    ..aOM<ProgrammeList>(17, _omitFieldNames ? '' : 'programmeList',
        subBuilder: ProgrammeList.create)
    ..aOM<TransferInfo>(18, _omitFieldNames ? '' : 'transferInfo',
        subBuilder: TransferInfo.create)
    ..aOM<IdMessage>(19, _omitFieldNames ? '' : 'diskSpace',
        subBuilder: IdMessage.create)
    ..aOM<DownloadStatus>(20, _omitFieldNames ? '' : 'downloadStatus',
        subBuilder: DownloadStatus.create)
    ..aOM<RelayInfo>(21, _omitFieldNames ? '' : 'relayInfo',
        subBuilder: RelayInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FFIResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FFIResult copyWith(void Function(FFIResult) updates) =>
      super.copyWith((message) => updates(message as FFIResult)) as FFIResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FFIResult create() => FFIResult._();
  @$core.override
  FFIResult createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FFIResult getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FFIResult>(create);
  static FFIResult? _defaultInstance;

  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  @$pb.TagNumber(18)
  @$pb.TagNumber(19)
  @$pb.TagNumber(20)
  @$pb.TagNumber(21)
  FFIResult_Data whichData() => _FFIResult_DataByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  @$pb.TagNumber(18)
  @$pb.TagNumber(19)
  @$pb.TagNumber(20)
  @$pb.TagNumber(21)
  void clearData() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get errorMessage => $_getSZ(1);
  @$pb.TagNumber(2)
  set errorMessage($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasErrorMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearErrorMessage() => $_clearField(2);

  @$pb.TagNumber(3)
  Settings get settings => $_getN(2);
  @$pb.TagNumber(3)
  set settings(Settings value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasSettings() => $_has(2);
  @$pb.TagNumber(3)
  void clearSettings() => $_clearField(3);
  @$pb.TagNumber(3)
  Settings ensureSettings() => $_ensure(2);

  @$pb.TagNumber(4)
  Source get source => $_getN(3);
  @$pb.TagNumber(4)
  set source(Source value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasSource() => $_has(3);
  @$pb.TagNumber(4)
  void clearSource() => $_clearField(4);
  @$pb.TagNumber(4)
  Source ensureSource() => $_ensure(3);

  @$pb.TagNumber(6)
  ChannelList get channelList => $_getN(4);
  @$pb.TagNumber(6)
  set channelList(ChannelList value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasChannelList() => $_has(4);
  @$pb.TagNumber(6)
  void clearChannelList() => $_clearField(6);
  @$pb.TagNumber(6)
  ChannelList ensureChannelList() => $_ensure(4);

  @$pb.TagNumber(7)
  BoolMessage get boolMessage => $_getN(5);
  @$pb.TagNumber(7)
  set boolMessage(BoolMessage value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasBoolMessage() => $_has(5);
  @$pb.TagNumber(7)
  void clearBoolMessage() => $_clearField(7);
  @$pb.TagNumber(7)
  BoolMessage ensureBoolMessage() => $_ensure(5);

  @$pb.TagNumber(8)
  GetMoviePosition get moviePosition => $_getN(6);
  @$pb.TagNumber(8)
  set moviePosition(GetMoviePosition value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasMoviePosition() => $_has(6);
  @$pb.TagNumber(8)
  void clearMoviePosition() => $_clearField(8);
  @$pb.TagNumber(8)
  GetMoviePosition ensureMoviePosition() => $_ensure(6);

  @$pb.TagNumber(9)
  ChannelHttpHeaders get headers => $_getN(7);
  @$pb.TagNumber(9)
  set headers(ChannelHttpHeaders value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasHeaders() => $_has(7);
  @$pb.TagNumber(9)
  void clearHeaders() => $_clearField(9);
  @$pb.TagNumber(9)
  ChannelHttpHeaders ensureHeaders() => $_ensure(7);

  @$pb.TagNumber(10)
  GetEnabledSourcesMinimal get enabledSourcesMinimal => $_getN(8);
  @$pb.TagNumber(10)
  set enabledSourcesMinimal(GetEnabledSourcesMinimal value) =>
      $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasEnabledSourcesMinimal() => $_has(8);
  @$pb.TagNumber(10)
  void clearEnabledSourcesMinimal() => $_clearField(10);
  @$pb.TagNumber(10)
  GetEnabledSourcesMinimal ensureEnabledSourcesMinimal() => $_ensure(8);

  @$pb.TagNumber(11)
  SourceList get sourceList => $_getN(9);
  @$pb.TagNumber(11)
  set sourceList(SourceList value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasSourceList() => $_has(9);
  @$pb.TagNumber(11)
  void clearSourceList() => $_clearField(11);
  @$pb.TagNumber(11)
  SourceList ensureSourceList() => $_ensure(9);

  @$pb.TagNumber(12)
  CategoryList get categoryList => $_getN(10);
  @$pb.TagNumber(12)
  set categoryList(CategoryList value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasCategoryList() => $_has(10);
  @$pb.TagNumber(12)
  void clearCategoryList() => $_clearField(12);
  @$pb.TagNumber(12)
  CategoryList ensureCategoryList() => $_ensure(10);

  @$pb.TagNumber(13)
  RefreshStats get refreshStats => $_getN(11);
  @$pb.TagNumber(13)
  set refreshStats(RefreshStats value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasRefreshStats() => $_has(11);
  @$pb.TagNumber(13)
  void clearRefreshStats() => $_clearField(13);
  @$pb.TagNumber(13)
  RefreshStats ensureRefreshStats() => $_ensure(11);

  @$pb.TagNumber(14)
  RefreshStatsList get refreshStatsList => $_getN(12);
  @$pb.TagNumber(14)
  set refreshStatsList(RefreshStatsList value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasRefreshStatsList() => $_has(12);
  @$pb.TagNumber(14)
  void clearRefreshStatsList() => $_clearField(14);
  @$pb.TagNumber(14)
  RefreshStatsList ensureRefreshStatsList() => $_ensure(12);

  @$pb.TagNumber(15)
  StreamVariantList get streamVariants => $_getN(13);
  @$pb.TagNumber(15)
  set streamVariants(StreamVariantList value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasStreamVariants() => $_has(13);
  @$pb.TagNumber(15)
  void clearStreamVariants() => $_clearField(15);
  @$pb.TagNumber(15)
  StreamVariantList ensureStreamVariants() => $_ensure(13);

  @$pb.TagNumber(16)
  NowNext get nowNext => $_getN(14);
  @$pb.TagNumber(16)
  set nowNext(NowNext value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasNowNext() => $_has(14);
  @$pb.TagNumber(16)
  void clearNowNext() => $_clearField(16);
  @$pb.TagNumber(16)
  NowNext ensureNowNext() => $_ensure(14);

  @$pb.TagNumber(17)
  ProgrammeList get programmeList => $_getN(15);
  @$pb.TagNumber(17)
  set programmeList(ProgrammeList value) => $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasProgrammeList() => $_has(15);
  @$pb.TagNumber(17)
  void clearProgrammeList() => $_clearField(17);
  @$pb.TagNumber(17)
  ProgrammeList ensureProgrammeList() => $_ensure(15);

  @$pb.TagNumber(18)
  TransferInfo get transferInfo => $_getN(16);
  @$pb.TagNumber(18)
  set transferInfo(TransferInfo value) => $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasTransferInfo() => $_has(16);
  @$pb.TagNumber(18)
  void clearTransferInfo() => $_clearField(18);
  @$pb.TagNumber(18)
  TransferInfo ensureTransferInfo() => $_ensure(16);

  @$pb.TagNumber(19)
  IdMessage get diskSpace => $_getN(17);
  @$pb.TagNumber(19)
  set diskSpace(IdMessage value) => $_setField(19, value);
  @$pb.TagNumber(19)
  $core.bool hasDiskSpace() => $_has(17);
  @$pb.TagNumber(19)
  void clearDiskSpace() => $_clearField(19);
  @$pb.TagNumber(19)
  IdMessage ensureDiskSpace() => $_ensure(17);

  @$pb.TagNumber(20)
  DownloadStatus get downloadStatus => $_getN(18);
  @$pb.TagNumber(20)
  set downloadStatus(DownloadStatus value) => $_setField(20, value);
  @$pb.TagNumber(20)
  $core.bool hasDownloadStatus() => $_has(18);
  @$pb.TagNumber(20)
  void clearDownloadStatus() => $_clearField(20);
  @$pb.TagNumber(20)
  DownloadStatus ensureDownloadStatus() => $_ensure(18);

  @$pb.TagNumber(21)
  RelayInfo get relayInfo => $_getN(19);
  @$pb.TagNumber(21)
  set relayInfo(RelayInfo value) => $_setField(21, value);
  @$pb.TagNumber(21)
  $core.bool hasRelayInfo() => $_has(19);
  @$pb.TagNumber(21)
  void clearRelayInfo() => $_clearField(21);
  @$pb.TagNumber(21)
  RelayInfo ensureRelayInfo() => $_ensure(19);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
