// This is a generated file - do not edit.
//
// Generated from generated_proto.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use mediaTypeDescriptor instead')
const MediaType$json = {
  '1': 'MediaType',
  '2': [
    {'1': 'MEDIA_TYPE_LIVESTREAM', '2': 0},
    {'1': 'MEDIA_TYPE_MOVIE', '2': 1},
    {'1': 'MEDIA_TYPE_SERIE', '2': 2},
    {'1': 'MEDIA_TYPE_GROUP', '2': 3},
    {'1': 'MEDIA_TYPE_SEASON', '2': 4},
  ],
};

/// Descriptor for `MediaType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List mediaTypeDescriptor = $convert.base64Decode(
    'CglNZWRpYVR5cGUSGQoVTUVESUFfVFlQRV9MSVZFU1RSRUFNEAASFAoQTUVESUFfVFlQRV9NT1'
    'ZJRRABEhQKEE1FRElBX1RZUEVfU0VSSUUQAhIUChBNRURJQV9UWVBFX0dST1VQEAMSFQoRTUVE'
    'SUFfVFlQRV9TRUFTT04QBA==');

@$core.Deprecated('Use viewTypeDescriptor instead')
const ViewType$json = {
  '1': 'ViewType',
  '2': [
    {'1': 'VIEW_TYPE_ALL', '2': 0},
    {'1': 'VIEW_TYPE_CATEGORIES', '2': 1},
    {'1': 'VIEW_TYPE_FAVORITES', '2': 2},
    {'1': 'VIEW_TYPE_HISTORY', '2': 3},
    {'1': 'VIEW_TYPE_SETTINGS', '2': 4},
    {'1': 'VIEW_TYPE_LOCAL_MEDIA', '2': 5},
    {'1': 'VIEW_TYPE_RECORDINGS', '2': 6},
    {'1': 'VIEW_TYPE_DOWNLOADS', '2': 7},
  ],
};

/// Descriptor for `ViewType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List viewTypeDescriptor = $convert.base64Decode(
    'CghWaWV3VHlwZRIRCg1WSUVXX1RZUEVfQUxMEAASGAoUVklFV19UWVBFX0NBVEVHT1JJRVMQAR'
    'IXChNWSUVXX1RZUEVfRkFWT1JJVEVTEAISFQoRVklFV19UWVBFX0hJU1RPUlkQAxIWChJWSUVX'
    'X1RZUEVfU0VUVElOR1MQBBIZChVWSUVXX1RZUEVfTE9DQUxfTUVESUEQBRIYChRWSUVXX1RZUE'
    'VfUkVDT1JESU5HUxAGEhcKE1ZJRVdfVFlQRV9ET1dOTE9BRFMQBw==');

@$core.Deprecated('Use categoryModeDescriptor instead')
const CategoryMode$json = {
  '1': 'CategoryMode',
  '2': [
    {'1': 'CATEGORY_MODE_EXCLUDE', '2': 0},
    {'1': 'CATEGORY_MODE_INCLUDE', '2': 1},
  ],
};

/// Descriptor for `CategoryMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List categoryModeDescriptor = $convert.base64Decode(
    'CgxDYXRlZ29yeU1vZGUSGQoVQ0FURUdPUllfTU9ERV9FWENMVURFEAASGQoVQ0FURUdPUllfTU'
    '9ERV9JTkNMVURFEAE=');

@$core.Deprecated('Use altOverrideKindDescriptor instead')
const AltOverrideKind$json = {
  '1': 'AltOverrideKind',
  '2': [
    {'1': 'ALT_OVERRIDE_UNLINK', '2': 0},
    {'1': 'ALT_OVERRIDE_LINK', '2': 1},
    {'1': 'ALT_OVERRIDE_PREFERRED', '2': 2},
  ],
};

/// Descriptor for `AltOverrideKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List altOverrideKindDescriptor = $convert.base64Decode(
    'Cg9BbHRPdmVycmlkZUtpbmQSFwoTQUxUX09WRVJSSURFX1VOTElOSxAAEhUKEUFMVF9PVkVSUk'
    'lERV9MSU5LEAESGgoWQUxUX09WRVJSSURFX1BSRUZFUlJFRBAC');

@$core.Deprecated('Use channelDescriptor instead')
const Channel$json = {
  '1': 'Channel',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '9': 0, '10': 'id', '17': true},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'url', '3': 3, '4': 1, '5': 9, '9': 1, '10': 'url', '17': true},
    {'1': 'group', '3': 4, '4': 1, '5': 9, '9': 2, '10': 'group', '17': true},
    {'1': 'image', '3': 5, '4': 1, '5': 9, '9': 3, '10': 'image', '17': true},
    {'1': 'media_type', '3': 6, '4': 1, '5': 13, '10': 'mediaType'},
    {
      '1': 'source_id',
      '3': 7,
      '4': 1,
      '5': 3,
      '9': 4,
      '10': 'sourceId',
      '17': true
    },
    {
      '1': 'series_id',
      '3': 8,
      '4': 1,
      '5': 4,
      '9': 5,
      '10': 'seriesId',
      '17': true
    },
    {
      '1': 'group_id',
      '3': 9,
      '4': 1,
      '5': 3,
      '9': 6,
      '10': 'groupId',
      '17': true
    },
    {'1': 'favorite', '3': 10, '4': 1, '5': 8, '10': 'favorite'},
    {
      '1': 'stream_id',
      '3': 11,
      '4': 1,
      '5': 4,
      '9': 7,
      '10': 'streamId',
      '17': true
    },
    {
      '1': 'tv_archive',
      '3': 12,
      '4': 1,
      '5': 8,
      '9': 8,
      '10': 'tvArchive',
      '17': true
    },
    {
      '1': 'season_id',
      '3': 13,
      '4': 1,
      '5': 3,
      '9': 9,
      '10': 'seasonId',
      '17': true
    },
    {
      '1': 'episode_num',
      '3': 14,
      '4': 1,
      '5': 3,
      '9': 10,
      '10': 'episodeNum',
      '17': true
    },
    {'1': 'quality', '3': 15, '4': 1, '5': 13, '10': 'quality'},
    {
      '1': 'playback_headers',
      '3': 20,
      '4': 1,
      '5': 11,
      '6': '.generated_proto.ChannelHttpHeaders',
      '9': 11,
      '10': 'playbackHeaders',
      '17': true
    },
    {'1': 'hidden', '3': 17, '4': 1, '5': 8, '10': 'hidden'},
    {
      '1': 'archive_days',
      '3': 18,
      '4': 1,
      '5': 13,
      '9': 12,
      '10': 'archiveDays',
      '17': true
    },
    {
      '1': 'epg_id',
      '3': 19,
      '4': 1,
      '5': 9,
      '9': 13,
      '10': 'epgId',
      '17': true
    },
    {
      '1': 'alt_key',
      '3': 16,
      '4': 1,
      '5': 9,
      '9': 14,
      '10': 'altKey',
      '17': true
    },
  ],
  '8': [
    {'1': '_id'},
    {'1': '_url'},
    {'1': '_group'},
    {'1': '_image'},
    {'1': '_source_id'},
    {'1': '_series_id'},
    {'1': '_group_id'},
    {'1': '_stream_id'},
    {'1': '_tv_archive'},
    {'1': '_season_id'},
    {'1': '_episode_num'},
    {'1': '_playback_headers'},
    {'1': '_archive_days'},
    {'1': '_epg_id'},
    {'1': '_alt_key'},
  ],
};

/// Descriptor for `Channel`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List channelDescriptor = $convert.base64Decode(
    'CgdDaGFubmVsEhMKAmlkGAEgASgDSABSAmlkiAEBEhIKBG5hbWUYAiABKAlSBG5hbWUSFQoDdX'
    'JsGAMgASgJSAFSA3VybIgBARIZCgVncm91cBgEIAEoCUgCUgVncm91cIgBARIZCgVpbWFnZRgF'
    'IAEoCUgDUgVpbWFnZYgBARIdCgptZWRpYV90eXBlGAYgASgNUgltZWRpYVR5cGUSIAoJc291cm'
    'NlX2lkGAcgASgDSARSCHNvdXJjZUlkiAEBEiAKCXNlcmllc19pZBgIIAEoBEgFUghzZXJpZXNJ'
    'ZIgBARIeCghncm91cF9pZBgJIAEoA0gGUgdncm91cElkiAEBEhoKCGZhdm9yaXRlGAogASgIUg'
    'hmYXZvcml0ZRIgCglzdHJlYW1faWQYCyABKARIB1IIc3RyZWFtSWSIAQESIgoKdHZfYXJjaGl2'
    'ZRgMIAEoCEgIUgl0dkFyY2hpdmWIAQESIAoJc2Vhc29uX2lkGA0gASgDSAlSCHNlYXNvbklkiA'
    'EBEiQKC2VwaXNvZGVfbnVtGA4gASgDSApSCmVwaXNvZGVOdW2IAQESGAoHcXVhbGl0eRgPIAEo'
    'DVIHcXVhbGl0eRJTChBwbGF5YmFja19oZWFkZXJzGBQgASgLMiMuZ2VuZXJhdGVkX3Byb3RvLk'
    'NoYW5uZWxIdHRwSGVhZGVyc0gLUg9wbGF5YmFja0hlYWRlcnOIAQESFgoGaGlkZGVuGBEgASgI'
    'UgZoaWRkZW4SJgoMYXJjaGl2ZV9kYXlzGBIgASgNSAxSC2FyY2hpdmVEYXlziAEBEhoKBmVwZ1'
    '9pZBgTIAEoCUgNUgVlcGdJZIgBARIcCgdhbHRfa2V5GBAgASgJSA5SBmFsdEtleYgBAUIFCgNf'
    'aWRCBgoEX3VybEIICgZfZ3JvdXBCCAoGX2ltYWdlQgwKCl9zb3VyY2VfaWRCDAoKX3Nlcmllc1'
    '9pZEILCglfZ3JvdXBfaWRCDAoKX3N0cmVhbV9pZEINCgtfdHZfYXJjaGl2ZUIMCgpfc2Vhc29u'
    'X2lkQg4KDF9lcGlzb2RlX251bUITChFfcGxheWJhY2tfaGVhZGVyc0IPCg1fYXJjaGl2ZV9kYX'
    'lzQgkKB19lcGdfaWRCCgoIX2FsdF9rZXk=');

@$core.Deprecated('Use setHiddenDescriptor instead')
const SetHidden$json = {
  '1': 'SetHidden',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'hidden', '3': 2, '4': 1, '5': 8, '10': 'hidden'},
    {'1': 'group', '3': 3, '4': 1, '5': 8, '10': 'group'},
  ],
};

/// Descriptor for `SetHidden`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setHiddenDescriptor = $convert.base64Decode(
    'CglTZXRIaWRkZW4SDgoCaWQYASABKANSAmlkEhYKBmhpZGRlbhgCIAEoCFIGaGlkZGVuEhQKBW'
    'dyb3VwGAMgASgIUgVncm91cA==');

@$core.Deprecated('Use swapFavoritesDescriptor instead')
const SwapFavorites$json = {
  '1': 'SwapFavorites',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'other', '3': 2, '4': 1, '5': 3, '10': 'other'},
    {'1': 'group', '3': 3, '4': 1, '5': 8, '10': 'group'},
  ],
};

/// Descriptor for `SwapFavorites`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List swapFavoritesDescriptor = $convert.base64Decode(
    'Cg1Td2FwRmF2b3JpdGVzEg4KAmlkGAEgASgDUgJpZBIUCgVvdGhlchgCIAEoA1IFb3RoZXISFA'
    'oFZ3JvdXAYAyABKAhSBWdyb3Vw');

@$core.Deprecated('Use guideRequestDescriptor instead')
const GuideRequest$json = {
  '1': 'GuideRequest',
  '2': [
    {'1': 'channel_id', '3': 1, '4': 1, '5': 3, '10': 'channelId'},
    {'1': 'from', '3': 2, '4': 1, '5': 3, '10': 'from'},
    {'1': 'to', '3': 3, '4': 1, '5': 3, '10': 'to'},
  ],
};

/// Descriptor for `GuideRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List guideRequestDescriptor = $convert.base64Decode(
    'CgxHdWlkZVJlcXVlc3QSHQoKY2hhbm5lbF9pZBgBIAEoA1IJY2hhbm5lbElkEhIKBGZyb20YAi'
    'ABKANSBGZyb20SDgoCdG8YAyABKANSAnRv');

@$core.Deprecated('Use programmeListDescriptor instead')
const ProgrammeList$json = {
  '1': 'ProgrammeList',
  '2': [
    {'1': 'supported', '3': 1, '4': 1, '5': 8, '10': 'supported'},
    {
      '1': 'programmes',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.generated_proto.Programme',
      '10': 'programmes'
    },
    {
      '1': 'catchup_supported',
      '3': 3,
      '4': 1,
      '5': 8,
      '10': 'catchupSupported'
    },
    {'1': 'archive_days', '3': 4, '4': 1, '5': 13, '10': 'archiveDays'},
  ],
};

/// Descriptor for `ProgrammeList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List programmeListDescriptor = $convert.base64Decode(
    'Cg1Qcm9ncmFtbWVMaXN0EhwKCXN1cHBvcnRlZBgBIAEoCFIJc3VwcG9ydGVkEjoKCnByb2dyYW'
    '1tZXMYAiADKAsyGi5nZW5lcmF0ZWRfcHJvdG8uUHJvZ3JhbW1lUgpwcm9ncmFtbWVzEisKEWNh'
    'dGNodXBfc3VwcG9ydGVkGAMgASgIUhBjYXRjaHVwU3VwcG9ydGVkEiEKDGFyY2hpdmVfZGF5cx'
    'gEIAEoDVILYXJjaGl2ZURheXM=');

@$core.Deprecated('Use channelListDescriptor instead')
const ChannelList$json = {
  '1': 'ChannelList',
  '2': [
    {
      '1': 'channels',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.generated_proto.Channel',
      '10': 'channels'
    },
    {
      '1': 'preferred_channel_id',
      '3': 2,
      '4': 1,
      '5': 3,
      '9': 0,
      '10': 'preferredChannelId',
      '17': true
    },
  ],
  '8': [
    {'1': '_preferred_channel_id'},
  ],
};

/// Descriptor for `ChannelList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List channelListDescriptor = $convert.base64Decode(
    'CgtDaGFubmVsTGlzdBI0CghjaGFubmVscxgBIAMoCzIYLmdlbmVyYXRlZF9wcm90by5DaGFubm'
    'VsUghjaGFubmVscxI1ChRwcmVmZXJyZWRfY2hhbm5lbF9pZBgCIAEoA0gAUhJwcmVmZXJyZWRD'
    'aGFubmVsSWSIAQFCFwoVX3ByZWZlcnJlZF9jaGFubmVsX2lk');

@$core.Deprecated('Use sourceDescriptor instead')
const Source$json = {
  '1': 'Source',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '9': 0, '10': 'id', '17': true},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'url', '3': 3, '4': 1, '5': 9, '9': 1, '10': 'url', '17': true},
    {
      '1': 'url_origin',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'urlOrigin',
      '17': true
    },
    {
      '1': 'username',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'username',
      '17': true
    },
    {
      '1': 'password',
      '3': 6,
      '4': 1,
      '5': 9,
      '9': 4,
      '10': 'password',
      '17': true
    },
    {'1': 'source_type', '3': 7, '4': 1, '5': 13, '10': 'sourceType'},
    {'1': 'enabled', '3': 9, '4': 1, '5': 8, '10': 'enabled'},
    {
      '1': 'user_agent',
      '3': 10,
      '4': 1,
      '5': 9,
      '9': 5,
      '10': 'userAgent',
      '17': true
    },
    {
      '1': 'stream_user_agent',
      '3': 12,
      '4': 1,
      '5': 9,
      '9': 6,
      '10': 'streamUserAgent',
      '17': true
    },
    {
      '1': 'last_updated',
      '3': 13,
      '4': 1,
      '5': 3,
      '9': 7,
      '10': 'lastUpdated',
      '17': true
    },
    {
      '1': 'import_live',
      '3': 14,
      '4': 1,
      '5': 8,
      '9': 8,
      '10': 'importLive',
      '17': true
    },
    {
      '1': 'import_movies',
      '3': 15,
      '4': 1,
      '5': 8,
      '9': 9,
      '10': 'importMovies',
      '17': true
    },
    {
      '1': 'import_series',
      '3': 16,
      '4': 1,
      '5': 8,
      '9': 10,
      '10': 'importSeries',
      '17': true
    },
    {
      '1': 'epg_url',
      '3': 18,
      '4': 1,
      '5': 9,
      '9': 11,
      '10': 'epgUrl',
      '17': true
    },
    {
      '1': 'last_refresh_stats',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.generated_proto.RefreshStats',
      '9': 12,
      '10': 'lastRefreshStats',
      '17': true
    },
  ],
  '8': [
    {'1': '_id'},
    {'1': '_url'},
    {'1': '_url_origin'},
    {'1': '_username'},
    {'1': '_password'},
    {'1': '_user_agent'},
    {'1': '_stream_user_agent'},
    {'1': '_last_updated'},
    {'1': '_import_live'},
    {'1': '_import_movies'},
    {'1': '_import_series'},
    {'1': '_epg_url'},
    {'1': '_last_refresh_stats'},
  ],
};

/// Descriptor for `Source`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sourceDescriptor = $convert.base64Decode(
    'CgZTb3VyY2USEwoCaWQYASABKANIAFICaWSIAQESEgoEbmFtZRgCIAEoCVIEbmFtZRIVCgN1cm'
    'wYAyABKAlIAVIDdXJsiAEBEiIKCnVybF9vcmlnaW4YBCABKAlIAlIJdXJsT3JpZ2luiAEBEh8K'
    'CHVzZXJuYW1lGAUgASgJSANSCHVzZXJuYW1liAEBEh8KCHBhc3N3b3JkGAYgASgJSARSCHBhc3'
    'N3b3JkiAEBEh8KC3NvdXJjZV90eXBlGAcgASgNUgpzb3VyY2VUeXBlEhgKB2VuYWJsZWQYCSAB'
    'KAhSB2VuYWJsZWQSIgoKdXNlcl9hZ2VudBgKIAEoCUgFUgl1c2VyQWdlbnSIAQESLwoRc3RyZW'
    'FtX3VzZXJfYWdlbnQYDCABKAlIBlIPc3RyZWFtVXNlckFnZW50iAEBEiYKDGxhc3RfdXBkYXRl'
    'ZBgNIAEoA0gHUgtsYXN0VXBkYXRlZIgBARIkCgtpbXBvcnRfbGl2ZRgOIAEoCEgIUgppbXBvcn'
    'RMaXZliAEBEigKDWltcG9ydF9tb3ZpZXMYDyABKAhICVIMaW1wb3J0TW92aWVziAEBEigKDWlt'
    'cG9ydF9zZXJpZXMYECABKAhIClIMaW1wb3J0U2VyaWVziAEBEhwKB2VwZ191cmwYEiABKAlIC1'
    'IGZXBnVXJsiAEBElAKEmxhc3RfcmVmcmVzaF9zdGF0cxgRIAEoCzIdLmdlbmVyYXRlZF9wcm90'
    'by5SZWZyZXNoU3RhdHNIDFIQbGFzdFJlZnJlc2hTdGF0c4gBAUIFCgNfaWRCBgoEX3VybEINCg'
    'tfdXJsX29yaWdpbkILCglfdXNlcm5hbWVCCwoJX3Bhc3N3b3JkQg0KC191c2VyX2FnZW50QhQK'
    'El9zdHJlYW1fdXNlcl9hZ2VudEIPCg1fbGFzdF91cGRhdGVkQg4KDF9pbXBvcnRfbGl2ZUIQCg'
    '5faW1wb3J0X21vdmllc0IQCg5faW1wb3J0X3Nlcmllc0IKCghfZXBnX3VybEIVChNfbGFzdF9y'
    'ZWZyZXNoX3N0YXRz');

@$core.Deprecated('Use settingsDescriptor instead')
const Settings$json = {
  '1': 'Settings',
  '2': [
    {
      '1': 'use_stream_caching',
      '3': 1,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'useStreamCaching',
      '17': true
    },
    {
      '1': 'default_view',
      '3': 2,
      '4': 1,
      '5': 13,
      '9': 1,
      '10': 'defaultView',
      '17': true
    },
    {
      '1': 'refresh_on_start',
      '3': 3,
      '4': 1,
      '5': 8,
      '9': 2,
      '10': 'refreshOnStart',
      '17': true
    },
    {
      '1': 'default_sort',
      '3': 4,
      '4': 1,
      '5': 13,
      '9': 3,
      '10': 'defaultSort',
      '17': true
    },
    {
      '1': 'force_tv_mode',
      '3': 5,
      '4': 1,
      '5': 8,
      '9': 4,
      '10': 'forceTvMode',
      '17': true
    },
    {
      '1': 'show_livestreams',
      '3': 6,
      '4': 1,
      '5': 8,
      '9': 5,
      '10': 'showLivestreams',
      '17': true
    },
    {
      '1': 'show_movies',
      '3': 7,
      '4': 1,
      '5': 8,
      '9': 6,
      '10': 'showMovies',
      '17': true
    },
    {
      '1': 'show_series',
      '3': 8,
      '4': 1,
      '5': 8,
      '9': 7,
      '10': 'showSeries',
      '17': true
    },
    {
      '1': 'enable_catchup',
      '3': 24,
      '4': 1,
      '5': 8,
      '9': 8,
      '10': 'enableCatchup',
      '17': true
    },
    {
      '1': 'enable_full_guide',
      '3': 25,
      '4': 1,
      '5': 8,
      '9': 9,
      '10': 'enableFullGuide',
      '17': true
    },
    {
      '1': 'enable_xmltv',
      '3': 26,
      '4': 1,
      '5': 8,
      '9': 10,
      '10': 'enableXmltv',
      '17': true
    },
    {
      '1': 'keyboard_shortcuts',
      '3': 27,
      '4': 1,
      '5': 8,
      '9': 11,
      '10': 'keyboardShortcuts',
      '17': true
    },
    {
      '1': 'guide_player_titles',
      '3': 28,
      '4': 1,
      '5': 8,
      '9': 12,
      '10': 'guidePlayerTitles',
      '17': true
    },
    {
      '1': 'guide_tile_text',
      '3': 29,
      '4': 1,
      '5': 8,
      '9': 13,
      '10': 'guideTileText',
      '17': true
    },
    {
      '1': 'auto_quality_discovery',
      '3': 30,
      '4': 1,
      '5': 8,
      '9': 14,
      '10': 'autoQualityDiscovery',
      '17': true
    },
    {
      '1': 'search_delay_ms',
      '3': 31,
      '4': 1,
      '5': 13,
      '9': 15,
      '10': 'searchDelayMs',
      '17': true
    },
    {
      '1': 'linux_player',
      '3': 10,
      '4': 1,
      '5': 13,
      '9': 16,
      '10': 'linuxPlayer',
      '17': true
    },
    {
      '1': 'mpv_path',
      '3': 11,
      '4': 1,
      '5': 9,
      '9': 17,
      '10': 'mpvPath',
      '17': true
    },
    {'1': 'hwdec', '3': 12, '4': 1, '5': 9, '9': 18, '10': 'hwdec', '17': true},
    {
      '1': 'cache_secs',
      '3': 13,
      '4': 1,
      '5': 13,
      '9': 19,
      '10': 'cacheSecs',
      '17': true
    },
    {
      '1': 'demuxer_max_mb',
      '3': 14,
      '4': 1,
      '5': 13,
      '9': 20,
      '10': 'demuxerMaxMb',
      '17': true
    },
    {
      '1': 'mpv_extra_args',
      '3': 15,
      '4': 1,
      '5': 9,
      '9': 21,
      '10': 'mpvExtraArgs',
      '17': true
    },
    {
      '1': 'mpv_reuse_window',
      '3': 16,
      '4': 1,
      '5': 8,
      '9': 22,
      '10': 'mpvReuseWindow',
      '17': true
    },
    {
      '1': 'ios_native_player',
      '3': 17,
      '4': 1,
      '5': 8,
      '9': 23,
      '10': 'iosNativePlayer',
      '17': true
    },
    {
      '1': 'ios_prefer_hls',
      '3': 18,
      '4': 1,
      '5': 8,
      '9': 24,
      '10': 'iosPreferHls',
      '17': true
    },
    {
      '1': 'background_audio',
      '3': 19,
      '4': 1,
      '5': 8,
      '9': 25,
      '10': 'backgroundAudio',
      '17': true
    },
    {
      '1': 'auto_pip',
      '3': 20,
      '4': 1,
      '5': 8,
      '9': 26,
      '10': 'autoPip',
      '17': true
    },
    {
      '1': 'start_group_id',
      '3': 21,
      '4': 1,
      '5': 3,
      '9': 27,
      '10': 'startGroupId',
      '17': true
    },
    {
      '1': 'start_group_name',
      '3': 22,
      '4': 1,
      '5': 9,
      '9': 28,
      '10': 'startGroupName',
      '17': true
    },
    {
      '1': 'show_programmes',
      '3': 23,
      '4': 1,
      '5': 8,
      '9': 29,
      '10': 'showProgrammes',
      '17': true
    },
    {
      '1': 'number_key_switching',
      '3': 32,
      '4': 1,
      '5': 8,
      '9': 30,
      '10': 'numberKeySwitching',
      '17': true
    },
    {
      '1': 'ui_scale_percent',
      '3': 33,
      '4': 1,
      '5': 13,
      '9': 31,
      '10': 'uiScalePercent',
      '17': true
    },
    {
      '1': 'media_preferences',
      '3': 36,
      '4': 1,
      '5': 9,
      '9': 32,
      '10': 'mediaPreferences',
      '17': true
    },
    {
      '1': 'download_jobs',
      '3': 38,
      '4': 1,
      '5': 9,
      '9': 33,
      '10': 'downloadJobs',
      '17': true
    },
    {
      '1': 'recording_jobs',
      '3': 37,
      '4': 1,
      '5': 9,
      '9': 34,
      '10': 'recordingJobs',
      '17': true
    },
    {
      '1': 'bottom_bar',
      '3': 35,
      '4': 1,
      '5': 9,
      '9': 35,
      '10': 'bottomBar',
      '17': true
    },
    {
      '1': 'square_corners',
      '3': 34,
      '4': 1,
      '5': 8,
      '9': 36,
      '10': 'squareCorners',
      '17': true
    },
  ],
  '8': [
    {'1': '_use_stream_caching'},
    {'1': '_default_view'},
    {'1': '_refresh_on_start'},
    {'1': '_default_sort'},
    {'1': '_force_tv_mode'},
    {'1': '_show_livestreams'},
    {'1': '_show_movies'},
    {'1': '_show_series'},
    {'1': '_enable_catchup'},
    {'1': '_enable_full_guide'},
    {'1': '_enable_xmltv'},
    {'1': '_keyboard_shortcuts'},
    {'1': '_guide_player_titles'},
    {'1': '_guide_tile_text'},
    {'1': '_auto_quality_discovery'},
    {'1': '_search_delay_ms'},
    {'1': '_linux_player'},
    {'1': '_mpv_path'},
    {'1': '_hwdec'},
    {'1': '_cache_secs'},
    {'1': '_demuxer_max_mb'},
    {'1': '_mpv_extra_args'},
    {'1': '_mpv_reuse_window'},
    {'1': '_ios_native_player'},
    {'1': '_ios_prefer_hls'},
    {'1': '_background_audio'},
    {'1': '_auto_pip'},
    {'1': '_start_group_id'},
    {'1': '_start_group_name'},
    {'1': '_show_programmes'},
    {'1': '_number_key_switching'},
    {'1': '_ui_scale_percent'},
    {'1': '_media_preferences'},
    {'1': '_download_jobs'},
    {'1': '_recording_jobs'},
    {'1': '_bottom_bar'},
    {'1': '_square_corners'},
  ],
  '9': [
    {'1': 9, '2': 10},
  ],
};

/// Descriptor for `Settings`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List settingsDescriptor = $convert.base64Decode(
    'CghTZXR0aW5ncxIxChJ1c2Vfc3RyZWFtX2NhY2hpbmcYASABKAhIAFIQdXNlU3RyZWFtQ2FjaG'
    'luZ4gBARImCgxkZWZhdWx0X3ZpZXcYAiABKA1IAVILZGVmYXVsdFZpZXeIAQESLQoQcmVmcmVz'
    'aF9vbl9zdGFydBgDIAEoCEgCUg5yZWZyZXNoT25TdGFydIgBARImCgxkZWZhdWx0X3NvcnQYBC'
    'ABKA1IA1ILZGVmYXVsdFNvcnSIAQESJwoNZm9yY2VfdHZfbW9kZRgFIAEoCEgEUgtmb3JjZVR2'
    'TW9kZYgBARIuChBzaG93X2xpdmVzdHJlYW1zGAYgASgISAVSD3Nob3dMaXZlc3RyZWFtc4gBAR'
    'IkCgtzaG93X21vdmllcxgHIAEoCEgGUgpzaG93TW92aWVziAEBEiQKC3Nob3dfc2VyaWVzGAgg'
    'ASgISAdSCnNob3dTZXJpZXOIAQESKgoOZW5hYmxlX2NhdGNodXAYGCABKAhICFINZW5hYmxlQ2'
    'F0Y2h1cIgBARIvChFlbmFibGVfZnVsbF9ndWlkZRgZIAEoCEgJUg9lbmFibGVGdWxsR3VpZGWI'
    'AQESJgoMZW5hYmxlX3htbHR2GBogASgISApSC2VuYWJsZVhtbHR2iAEBEjIKEmtleWJvYXJkX3'
    'Nob3J0Y3V0cxgbIAEoCEgLUhFrZXlib2FyZFNob3J0Y3V0c4gBARIzChNndWlkZV9wbGF5ZXJf'
    'dGl0bGVzGBwgASgISAxSEWd1aWRlUGxheWVyVGl0bGVziAEBEisKD2d1aWRlX3RpbGVfdGV4dB'
    'gdIAEoCEgNUg1ndWlkZVRpbGVUZXh0iAEBEjkKFmF1dG9fcXVhbGl0eV9kaXNjb3ZlcnkYHiAB'
    'KAhIDlIUYXV0b1F1YWxpdHlEaXNjb3ZlcnmIAQESKwoPc2VhcmNoX2RlbGF5X21zGB8gASgNSA'
    '9SDXNlYXJjaERlbGF5TXOIAQESJgoMbGludXhfcGxheWVyGAogASgNSBBSC2xpbnV4UGxheWVy'
    'iAEBEh4KCG1wdl9wYXRoGAsgASgJSBFSB21wdlBhdGiIAQESGQoFaHdkZWMYDCABKAlIElIFaH'
    'dkZWOIAQESIgoKY2FjaGVfc2VjcxgNIAEoDUgTUgljYWNoZVNlY3OIAQESKQoOZGVtdXhlcl9t'
    'YXhfbWIYDiABKA1IFFIMZGVtdXhlck1heE1iiAEBEikKDm1wdl9leHRyYV9hcmdzGA8gASgJSB'
    'VSDG1wdkV4dHJhQXJnc4gBARItChBtcHZfcmV1c2Vfd2luZG93GBAgASgISBZSDm1wdlJldXNl'
    'V2luZG93iAEBEi8KEWlvc19uYXRpdmVfcGxheWVyGBEgASgISBdSD2lvc05hdGl2ZVBsYXllco'
    'gBARIpCg5pb3NfcHJlZmVyX2hscxgSIAEoCEgYUgxpb3NQcmVmZXJIbHOIAQESLgoQYmFja2dy'
    'b3VuZF9hdWRpbxgTIAEoCEgZUg9iYWNrZ3JvdW5kQXVkaW+IAQESHgoIYXV0b19waXAYFCABKA'
    'hIGlIHYXV0b1BpcIgBARIpCg5zdGFydF9ncm91cF9pZBgVIAEoA0gbUgxzdGFydEdyb3VwSWSI'
    'AQESLQoQc3RhcnRfZ3JvdXBfbmFtZRgWIAEoCUgcUg5zdGFydEdyb3VwTmFtZYgBARIsCg9zaG'
    '93X3Byb2dyYW1tZXMYFyABKAhIHVIOc2hvd1Byb2dyYW1tZXOIAQESNQoUbnVtYmVyX2tleV9z'
    'd2l0Y2hpbmcYICABKAhIHlISbnVtYmVyS2V5U3dpdGNoaW5niAEBEi0KEHVpX3NjYWxlX3Blcm'
    'NlbnQYISABKA1IH1IOdWlTY2FsZVBlcmNlbnSIAQESMAoRbWVkaWFfcHJlZmVyZW5jZXMYJCAB'
    'KAlIIFIQbWVkaWFQcmVmZXJlbmNlc4gBARIoCg1kb3dubG9hZF9qb2JzGCYgASgJSCFSDGRvd2'
    '5sb2FkSm9ic4gBARIqCg5yZWNvcmRpbmdfam9icxglIAEoCUgiUg1yZWNvcmRpbmdKb2JziAEB'
    'EiIKCmJvdHRvbV9iYXIYIyABKAlII1IJYm90dG9tQmFyiAEBEioKDnNxdWFyZV9jb3JuZXJzGC'
    'IgASgISCRSDXNxdWFyZUNvcm5lcnOIAQFCFQoTX3VzZV9zdHJlYW1fY2FjaGluZ0IPCg1fZGVm'
    'YXVsdF92aWV3QhMKEV9yZWZyZXNoX29uX3N0YXJ0Qg8KDV9kZWZhdWx0X3NvcnRCEAoOX2Zvcm'
    'NlX3R2X21vZGVCEwoRX3Nob3dfbGl2ZXN0cmVhbXNCDgoMX3Nob3dfbW92aWVzQg4KDF9zaG93'
    'X3Nlcmllc0IRCg9fZW5hYmxlX2NhdGNodXBCFAoSX2VuYWJsZV9mdWxsX2d1aWRlQg8KDV9lbm'
    'FibGVfeG1sdHZCFQoTX2tleWJvYXJkX3Nob3J0Y3V0c0IWChRfZ3VpZGVfcGxheWVyX3RpdGxl'
    'c0ISChBfZ3VpZGVfdGlsZV90ZXh0QhkKF19hdXRvX3F1YWxpdHlfZGlzY292ZXJ5QhIKEF9zZW'
    'FyY2hfZGVsYXlfbXNCDwoNX2xpbnV4X3BsYXllckILCglfbXB2X3BhdGhCCAoGX2h3ZGVjQg0K'
    'C19jYWNoZV9zZWNzQhEKD19kZW11eGVyX21heF9tYkIRCg9fbXB2X2V4dHJhX2FyZ3NCEwoRX2'
    '1wdl9yZXVzZV93aW5kb3dCFAoSX2lvc19uYXRpdmVfcGxheWVyQhEKD19pb3NfcHJlZmVyX2hs'
    'c0ITChFfYmFja2dyb3VuZF9hdWRpb0ILCglfYXV0b19waXBCEQoPX3N0YXJ0X2dyb3VwX2lkQh'
    'MKEV9zdGFydF9ncm91cF9uYW1lQhIKEF9zaG93X3Byb2dyYW1tZXNCFwoVX251bWJlcl9rZXlf'
    'c3dpdGNoaW5nQhMKEV91aV9zY2FsZV9wZXJjZW50QhQKEl9tZWRpYV9wcmVmZXJlbmNlc0IQCg'
    '5fZG93bmxvYWRfam9ic0IRCg9fcmVjb3JkaW5nX2pvYnNCDQoLX2JvdHRvbV9iYXJCEQoPX3Nx'
    'dWFyZV9jb3JuZXJzSgQICRAK');

@$core.Deprecated('Use filtersDescriptor instead')
const Filters$json = {
  '1': 'Filters',
  '2': [
    {'1': 'query', '3': 1, '4': 1, '5': 9, '9': 0, '10': 'query', '17': true},
    {'1': 'source_ids', '3': 2, '4': 3, '5': 3, '10': 'sourceIds'},
    {
      '1': 'media_types',
      '3': 3,
      '4': 3,
      '5': 14,
      '6': '.generated_proto.MediaType',
      '10': 'mediaTypes'
    },
    {
      '1': 'view_type',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.generated_proto.ViewType',
      '10': 'viewType'
    },
    {'1': 'page', '3': 5, '4': 1, '5': 13, '10': 'page'},
    {
      '1': 'series_id',
      '3': 6,
      '4': 1,
      '5': 3,
      '9': 1,
      '10': 'seriesId',
      '17': true
    },
    {
      '1': 'group_id',
      '3': 7,
      '4': 1,
      '5': 3,
      '9': 2,
      '10': 'groupId',
      '17': true
    },
    {'1': 'use_keywords', '3': 8, '4': 1, '5': 8, '10': 'useKeywords'},
    {'1': 'sort', '3': 9, '4': 1, '5': 13, '10': 'sort'},
    {
      '1': 'season',
      '3': 10,
      '4': 1,
      '5': 3,
      '9': 3,
      '10': 'season',
      '17': true
    },
    {'1': 'hidden_only', '3': 12, '4': 1, '5': 8, '10': 'hiddenOnly'},
    {'1': 'include_hidden', '3': 13, '4': 1, '5': 8, '10': 'includeHidden'},
    {'1': 'favorite_groups', '3': 11, '4': 1, '5': 8, '10': 'favoriteGroups'},
  ],
  '8': [
    {'1': '_query'},
    {'1': '_series_id'},
    {'1': '_group_id'},
    {'1': '_season'},
  ],
};

/// Descriptor for `Filters`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List filtersDescriptor = $convert.base64Decode(
    'CgdGaWx0ZXJzEhkKBXF1ZXJ5GAEgASgJSABSBXF1ZXJ5iAEBEh0KCnNvdXJjZV9pZHMYAiADKA'
    'NSCXNvdXJjZUlkcxI7CgttZWRpYV90eXBlcxgDIAMoDjIaLmdlbmVyYXRlZF9wcm90by5NZWRp'
    'YVR5cGVSCm1lZGlhVHlwZXMSNgoJdmlld190eXBlGAQgASgOMhkuZ2VuZXJhdGVkX3Byb3RvLl'
    'ZpZXdUeXBlUgh2aWV3VHlwZRISCgRwYWdlGAUgASgNUgRwYWdlEiAKCXNlcmllc19pZBgGIAEo'
    'A0gBUghzZXJpZXNJZIgBARIeCghncm91cF9pZBgHIAEoA0gCUgdncm91cElkiAEBEiEKDHVzZV'
    '9rZXl3b3JkcxgIIAEoCFILdXNlS2V5d29yZHMSEgoEc29ydBgJIAEoDVIEc29ydBIbCgZzZWFz'
    'b24YCiABKANIA1IGc2Vhc29uiAEBEh8KC2hpZGRlbl9vbmx5GAwgASgIUgpoaWRkZW5Pbmx5Ei'
    'UKDmluY2x1ZGVfaGlkZGVuGA0gASgIUg1pbmNsdWRlSGlkZGVuEicKD2Zhdm9yaXRlX2dyb3Vw'
    'cxgLIAEoCFIOZmF2b3JpdGVHcm91cHNCCAoGX3F1ZXJ5QgwKCl9zZXJpZXNfaWRCCwoJX2dyb3'
    'VwX2lkQgkKB19zZWFzb24=');

@$core.Deprecated('Use toggleFavoriteDescriptor instead')
const ToggleFavorite$json = {
  '1': 'ToggleFavorite',
  '2': [
    {'1': 'channel_id', '3': 1, '4': 1, '5': 3, '10': 'channelId'},
    {'1': 'favorite', '3': 2, '4': 1, '5': 8, '10': 'favorite'},
  ],
};

/// Descriptor for `ToggleFavorite`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List toggleFavoriteDescriptor = $convert.base64Decode(
    'Cg5Ub2dnbGVGYXZvcml0ZRIdCgpjaGFubmVsX2lkGAEgASgDUgljaGFubmVsSWQSGgoIZmF2b3'
    'JpdGUYAiABKAhSCGZhdm9yaXRl');

@$core.Deprecated('Use idMessageDescriptor instead')
const IdMessage$json = {
  '1': 'IdMessage',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 3, '10': 'value'},
  ],
};

/// Descriptor for `IdMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List idMessageDescriptor =
    $convert.base64Decode('CglJZE1lc3NhZ2USFAoFdmFsdWUYASABKANSBXZhbHVl');

@$core.Deprecated('Use moviePositionDescriptor instead')
const MoviePosition$json = {
  '1': 'MoviePosition',
  '2': [
    {'1': 'channel_id', '3': 1, '4': 1, '5': 3, '10': 'channelId'},
    {'1': 'position', '3': 2, '4': 1, '5': 3, '10': 'position'},
  ],
};

/// Descriptor for `MoviePosition`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List moviePositionDescriptor = $convert.base64Decode(
    'Cg1Nb3ZpZVBvc2l0aW9uEh0KCmNoYW5uZWxfaWQYASABKANSCWNoYW5uZWxJZBIaCghwb3NpdG'
    'lvbhgCIAEoA1IIcG9zaXRpb24=');

@$core.Deprecated('Use strMessageDescriptor instead')
const StrMessage$json = {
  '1': 'StrMessage',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 9, '10': 'value'},
  ],
};

/// Descriptor for `StrMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List strMessageDescriptor =
    $convert.base64Decode('CgpTdHJNZXNzYWdlEhQKBXZhbHVlGAEgASgJUgV2YWx1ZQ==');

@$core.Deprecated('Use optStrMessageDescriptor instead')
const OptStrMessage$json = {
  '1': 'OptStrMessage',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 9, '9': 0, '10': 'value', '17': true},
  ],
  '8': [
    {'1': '_value'},
  ],
};

/// Descriptor for `OptStrMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List optStrMessageDescriptor = $convert.base64Decode(
    'Cg1PcHRTdHJNZXNzYWdlEhkKBXZhbHVlGAEgASgJSABSBXZhbHVliAEBQggKBl92YWx1ZQ==');

@$core.Deprecated('Use boolMessageDescriptor instead')
const BoolMessage$json = {
  '1': 'BoolMessage',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 8, '10': 'value'},
  ],
};

/// Descriptor for `BoolMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List boolMessageDescriptor =
    $convert.base64Decode('CgtCb29sTWVzc2FnZRIUCgV2YWx1ZRgBIAEoCFIFdmFsdWU=');

@$core.Deprecated('Use getMoviePositionDescriptor instead')
const GetMoviePosition$json = {
  '1': 'GetMoviePosition',
  '2': [
    {
      '1': 'position',
      '3': 1,
      '4': 1,
      '5': 3,
      '9': 0,
      '10': 'position',
      '17': true
    },
  ],
  '8': [
    {'1': '_position'},
  ],
};

/// Descriptor for `GetMoviePosition`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getMoviePositionDescriptor = $convert.base64Decode(
    'ChBHZXRNb3ZpZVBvc2l0aW9uEh8KCHBvc2l0aW9uGAEgASgDSABSCHBvc2l0aW9uiAEBQgsKCV'
    '9wb3NpdGlvbg==');

@$core.Deprecated('Use initMessageDescriptor instead')
const InitMessage$json = {
  '1': 'InitMessage',
  '2': [
    {'1': 'db_path', '3': 1, '4': 1, '5': 9, '10': 'dbPath'},
    {'1': 'temp_path', '3': 2, '4': 1, '5': 9, '10': 'tempPath'},
  ],
};

/// Descriptor for `InitMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List initMessageDescriptor = $convert.base64Decode(
    'CgtJbml0TWVzc2FnZRIXCgdkYl9wYXRoGAEgASgJUgZkYlBhdGgSGwoJdGVtcF9wYXRoGAIgAS'
    'gJUgh0ZW1wUGF0aA==');

@$core.Deprecated('Use getEpisodesDescriptor instead')
const GetEpisodes$json = {
  '1': 'GetEpisodes',
  '2': [
    {'1': 'series_id', '3': 1, '4': 1, '5': 3, '10': 'seriesId'},
    {'1': 'source_id', '3': 2, '4': 1, '5': 3, '10': 'sourceId'},
    {
      '1': 'fallback_image',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'fallbackImage',
      '17': true
    },
  ],
  '8': [
    {'1': '_fallback_image'},
  ],
};

/// Descriptor for `GetEpisodes`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getEpisodesDescriptor = $convert.base64Decode(
    'CgtHZXRFcGlzb2RlcxIbCglzZXJpZXNfaWQYASABKANSCHNlcmllc0lkEhsKCXNvdXJjZV9pZB'
    'gCIAEoA1IIc291cmNlSWQSKgoOZmFsbGJhY2tfaW1hZ2UYAyABKAlIAFINZmFsbGJhY2tJbWFn'
    'ZYgBAUIRCg9fZmFsbGJhY2tfaW1hZ2U=');

@$core.Deprecated('Use channelHttpHeadersDescriptor instead')
const ChannelHttpHeaders$json = {
  '1': 'ChannelHttpHeaders',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '9': 0, '10': 'id', '17': true},
    {
      '1': 'channel_id',
      '3': 2,
      '4': 1,
      '5': 3,
      '9': 1,
      '10': 'channelId',
      '17': true
    },
    {
      '1': 'referrer',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'referrer',
      '17': true
    },
    {
      '1': 'user_agent',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'userAgent',
      '17': true
    },
    {
      '1': 'http_origin',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 4,
      '10': 'httpOrigin',
      '17': true
    },
    {
      '1': 'ignore_ssl',
      '3': 6,
      '4': 1,
      '5': 8,
      '9': 5,
      '10': 'ignoreSsl',
      '17': true
    },
  ],
  '8': [
    {'1': '_id'},
    {'1': '_channel_id'},
    {'1': '_referrer'},
    {'1': '_user_agent'},
    {'1': '_http_origin'},
    {'1': '_ignore_ssl'},
  ],
};

/// Descriptor for `ChannelHttpHeaders`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List channelHttpHeadersDescriptor = $convert.base64Decode(
    'ChJDaGFubmVsSHR0cEhlYWRlcnMSEwoCaWQYASABKANIAFICaWSIAQESIgoKY2hhbm5lbF9pZB'
    'gCIAEoA0gBUgljaGFubmVsSWSIAQESHwoIcmVmZXJyZXIYAyABKAlIAlIIcmVmZXJyZXKIAQES'
    'IgoKdXNlcl9hZ2VudBgEIAEoCUgDUgl1c2VyQWdlbnSIAQESJAoLaHR0cF9vcmlnaW4YBSABKA'
    'lIBFIKaHR0cE9yaWdpbogBARIiCgppZ25vcmVfc3NsGAYgASgISAVSCWlnbm9yZVNzbIgBAUIF'
    'CgNfaWRCDQoLX2NoYW5uZWxfaWRCCwoJX3JlZmVycmVyQg0KC191c2VyX2FnZW50Qg4KDF9odH'
    'RwX29yaWdpbkINCgtfaWdub3JlX3NzbA==');

@$core.Deprecated('Use getEnabledSourcesMinimalDescriptor instead')
const GetEnabledSourcesMinimal$json = {
  '1': 'GetEnabledSourcesMinimal',
  '2': [
    {'1': 'list_id', '3': 1, '4': 3, '5': 3, '10': 'listId'},
  ],
};

/// Descriptor for `GetEnabledSourcesMinimal`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getEnabledSourcesMinimalDescriptor =
    $convert.base64Decode(
        'ChhHZXRFbmFibGVkU291cmNlc01pbmltYWwSFwoHbGlzdF9pZBgBIAMoA1IGbGlzdElk');

@$core.Deprecated('Use sourceListDescriptor instead')
const SourceList$json = {
  '1': 'SourceList',
  '2': [
    {
      '1': 'sources',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.generated_proto.Source',
      '10': 'sources'
    },
  ],
};

/// Descriptor for `SourceList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sourceListDescriptor = $convert.base64Decode(
    'CgpTb3VyY2VMaXN0EjEKB3NvdXJjZXMYASADKAsyFy5nZW5lcmF0ZWRfcHJvdG8uU291cmNlUg'
    'dzb3VyY2Vz');

@$core.Deprecated('Use setSourceEnabledDescriptor instead')
const SetSourceEnabled$json = {
  '1': 'SetSourceEnabled',
  '2': [
    {'1': 'source_id', '3': 1, '4': 1, '5': 3, '10': 'sourceId'},
    {'1': 'enabled', '3': 2, '4': 1, '5': 8, '10': 'enabled'},
  ],
};

/// Descriptor for `SetSourceEnabled`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setSourceEnabledDescriptor = $convert.base64Decode(
    'ChBTZXRTb3VyY2VFbmFibGVkEhsKCXNvdXJjZV9pZBgBIAEoA1IIc291cmNlSWQSGAoHZW5hYm'
    'xlZBgCIAEoCFIHZW5hYmxlZA==');

@$core.Deprecated('Use categoryDescriptor instead')
const Category$json = {
  '1': 'Category',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'media_type', '3': 2, '4': 1, '5': 13, '10': 'mediaType'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'listed', '3': 4, '4': 1, '5': 8, '10': 'listed'},
    {
      '1': 'stream_count',
      '3': 5,
      '4': 1,
      '5': 13,
      '9': 0,
      '10': 'streamCount',
      '17': true
    },
  ],
  '8': [
    {'1': '_stream_count'},
  ],
};

/// Descriptor for `Category`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List categoryDescriptor = $convert.base64Decode(
    'CghDYXRlZ29yeRIOCgJpZBgBIAEoA1ICaWQSHQoKbWVkaWFfdHlwZRgCIAEoDVIJbWVkaWFUeX'
    'BlEhIKBG5hbWUYAyABKAlSBG5hbWUSFgoGbGlzdGVkGAQgASgIUgZsaXN0ZWQSJgoMc3RyZWFt'
    'X2NvdW50GAUgASgNSABSC3N0cmVhbUNvdW50iAEBQg8KDV9zdHJlYW1fY291bnQ=');

@$core.Deprecated('Use categoryListDescriptor instead')
const CategoryList$json = {
  '1': 'CategoryList',
  '2': [
    {
      '1': 'categories',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.generated_proto.Category',
      '10': 'categories'
    },
    {
      '1': 'live_mode',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.generated_proto.CategoryMode',
      '10': 'liveMode'
    },
    {
      '1': 'movies_mode',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.generated_proto.CategoryMode',
      '10': 'moviesMode'
    },
    {
      '1': 'series_mode',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.generated_proto.CategoryMode',
      '10': 'seriesMode'
    },
  ],
};

/// Descriptor for `CategoryList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List categoryListDescriptor = $convert.base64Decode(
    'CgxDYXRlZ29yeUxpc3QSOQoKY2F0ZWdvcmllcxgBIAMoCzIZLmdlbmVyYXRlZF9wcm90by5DYX'
    'RlZ29yeVIKY2F0ZWdvcmllcxI6CglsaXZlX21vZGUYAiABKA4yHS5nZW5lcmF0ZWRfcHJvdG8u'
    'Q2F0ZWdvcnlNb2RlUghsaXZlTW9kZRI+Cgttb3ZpZXNfbW9kZRgDIAEoDjIdLmdlbmVyYXRlZF'
    '9wcm90by5DYXRlZ29yeU1vZGVSCm1vdmllc01vZGUSPgoLc2VyaWVzX21vZGUYBCABKA4yHS5n'
    'ZW5lcmF0ZWRfcHJvdG8uQ2F0ZWdvcnlNb2RlUgpzZXJpZXNNb2Rl');

@$core.Deprecated('Use setCategoriesDescriptor instead')
const SetCategories$json = {
  '1': 'SetCategories',
  '2': [
    {'1': 'source_id', '3': 1, '4': 1, '5': 3, '10': 'sourceId'},
    {'1': 'media_type', '3': 2, '4': 1, '5': 13, '10': 'mediaType'},
    {
      '1': 'mode',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.generated_proto.CategoryMode',
      '10': 'mode'
    },
    {'1': 'listed', '3': 4, '4': 3, '5': 9, '10': 'listed'},
  ],
};

/// Descriptor for `SetCategories`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setCategoriesDescriptor = $convert.base64Decode(
    'Cg1TZXRDYXRlZ29yaWVzEhsKCXNvdXJjZV9pZBgBIAEoA1IIc291cmNlSWQSHQoKbWVkaWFfdH'
    'lwZRgCIAEoDVIJbWVkaWFUeXBlEjEKBG1vZGUYAyABKA4yHS5nZW5lcmF0ZWRfcHJvdG8uQ2F0'
    'ZWdvcnlNb2RlUgRtb2RlEhYKBmxpc3RlZBgEIAMoCVIGbGlzdGVk');

@$core.Deprecated('Use mediaTypeStatsDescriptor instead')
const MediaTypeStats$json = {
  '1': 'MediaTypeStats',
  '2': [
    {'1': 'media_type', '3': 1, '4': 1, '5': 13, '10': 'mediaType'},
    {'1': 'enabled', '3': 2, '4': 1, '5': 8, '10': 'enabled'},
    {'1': 'failed', '3': 3, '4': 1, '5': 8, '10': 'failed'},
    {'1': 'error', '3': 4, '4': 1, '5': 9, '9': 0, '10': 'error', '17': true},
    {'1': 'fetched', '3': 5, '4': 1, '5': 13, '10': 'fetched'},
    {'1': 'imported', '3': 6, '4': 1, '5': 13, '10': 'imported'},
    {'1': 'excluded', '3': 7, '4': 1, '5': 13, '10': 'excluded'},
    {'1': 'categories', '3': 8, '4': 1, '5': 13, '10': 'categories'},
    {
      '1': 'categories_excluded',
      '3': 9,
      '4': 1,
      '5': 13,
      '10': 'categoriesExcluded'
    },
  ],
  '8': [
    {'1': '_error'},
  ],
};

/// Descriptor for `MediaTypeStats`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mediaTypeStatsDescriptor = $convert.base64Decode(
    'Cg5NZWRpYVR5cGVTdGF0cxIdCgptZWRpYV90eXBlGAEgASgNUgltZWRpYVR5cGUSGAoHZW5hYm'
    'xlZBgCIAEoCFIHZW5hYmxlZBIWCgZmYWlsZWQYAyABKAhSBmZhaWxlZBIZCgVlcnJvchgEIAEo'
    'CUgAUgVlcnJvcogBARIYCgdmZXRjaGVkGAUgASgNUgdmZXRjaGVkEhoKCGltcG9ydGVkGAYgAS'
    'gNUghpbXBvcnRlZBIaCghleGNsdWRlZBgHIAEoDVIIZXhjbHVkZWQSHgoKY2F0ZWdvcmllcxgI'
    'IAEoDVIKY2F0ZWdvcmllcxIvChNjYXRlZ29yaWVzX2V4Y2x1ZGVkGAkgASgNUhJjYXRlZ29yaW'
    'VzRXhjbHVkZWRCCAoGX2Vycm9y');

@$core.Deprecated('Use refreshStatsDescriptor instead')
const RefreshStats$json = {
  '1': 'RefreshStats',
  '2': [
    {'1': 'source_id', '3': 1, '4': 1, '5': 3, '10': 'sourceId'},
    {'1': 'source_name', '3': 2, '4': 1, '5': 9, '10': 'sourceName'},
    {
      '1': 'types',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.generated_proto.MediaTypeStats',
      '10': 'types'
    },
    {'1': 'duration_ms', '3': 4, '4': 1, '5': 4, '10': 'durationMs'},
    {'1': 'finished_at', '3': 5, '4': 1, '5': 3, '10': 'finishedAt'},
    {'1': 'success', '3': 6, '4': 1, '5': 8, '10': 'success'},
    {'1': 'error', '3': 7, '4': 1, '5': 9, '9': 0, '10': 'error', '17': true},
  ],
  '8': [
    {'1': '_error'},
  ],
};

/// Descriptor for `RefreshStats`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refreshStatsDescriptor = $convert.base64Decode(
    'CgxSZWZyZXNoU3RhdHMSGwoJc291cmNlX2lkGAEgASgDUghzb3VyY2VJZBIfCgtzb3VyY2Vfbm'
    'FtZRgCIAEoCVIKc291cmNlTmFtZRI1CgV0eXBlcxgDIAMoCzIfLmdlbmVyYXRlZF9wcm90by5N'
    'ZWRpYVR5cGVTdGF0c1IFdHlwZXMSHwoLZHVyYXRpb25fbXMYBCABKARSCmR1cmF0aW9uTXMSHw'
    'oLZmluaXNoZWRfYXQYBSABKANSCmZpbmlzaGVkQXQSGAoHc3VjY2VzcxgGIAEoCFIHc3VjY2Vz'
    'cxIZCgVlcnJvchgHIAEoCUgAUgVlcnJvcogBAUIICgZfZXJyb3I=');

@$core.Deprecated('Use refreshStatsListDescriptor instead')
const RefreshStatsList$json = {
  '1': 'RefreshStatsList',
  '2': [
    {
      '1': 'stats',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.generated_proto.RefreshStats',
      '10': 'stats'
    },
  ],
};

/// Descriptor for `RefreshStatsList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refreshStatsListDescriptor = $convert.base64Decode(
    'ChBSZWZyZXNoU3RhdHNMaXN0EjMKBXN0YXRzGAEgAygLMh0uZ2VuZXJhdGVkX3Byb3RvLlJlZn'
    'Jlc2hTdGF0c1IFc3RhdHM=');

@$core.Deprecated('Use altOverrideDescriptor instead')
const AltOverride$json = {
  '1': 'AltOverride',
  '2': [
    {'1': 'channel_id', '3': 1, '4': 1, '5': 3, '10': 'channelId'},
    {
      '1': 'kind',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.generated_proto.AltOverrideKind',
      '10': 'kind'
    },
    {
      '1': 'target_channel_id',
      '3': 3,
      '4': 1,
      '5': 3,
      '9': 0,
      '10': 'targetChannelId',
      '17': true
    },
  ],
  '8': [
    {'1': '_target_channel_id'},
  ],
};

/// Descriptor for `AltOverride`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List altOverrideDescriptor = $convert.base64Decode(
    'CgtBbHRPdmVycmlkZRIdCgpjaGFubmVsX2lkGAEgASgDUgljaGFubmVsSWQSNAoEa2luZBgCIA'
    'EoDjIgLmdlbmVyYXRlZF9wcm90by5BbHRPdmVycmlkZUtpbmRSBGtpbmQSLwoRdGFyZ2V0X2No'
    'YW5uZWxfaWQYAyABKANIAFIPdGFyZ2V0Q2hhbm5lbElkiAEBQhQKEl90YXJnZXRfY2hhbm5lbF'
    '9pZA==');

@$core.Deprecated('Use streamVariantDescriptor instead')
const StreamVariant$json = {
  '1': 'StreamVariant',
  '2': [
    {'1': 'url', '3': 1, '4': 1, '5': 9, '10': 'url'},
    {'1': 'bandwidth', '3': 2, '4': 1, '5': 4, '10': 'bandwidth'},
    {
      '1': 'average_bandwidth',
      '3': 3,
      '4': 1,
      '5': 4,
      '9': 0,
      '10': 'averageBandwidth',
      '17': true
    },
    {'1': 'width', '3': 4, '4': 1, '5': 13, '9': 1, '10': 'width', '17': true},
    {
      '1': 'height',
      '3': 5,
      '4': 1,
      '5': 13,
      '9': 2,
      '10': 'height',
      '17': true
    },
    {
      '1': 'frame_rate',
      '3': 6,
      '4': 1,
      '5': 1,
      '9': 3,
      '10': 'frameRate',
      '17': true
    },
    {'1': 'codecs', '3': 7, '4': 1, '5': 9, '9': 4, '10': 'codecs', '17': true},
    {'1': 'name', '3': 8, '4': 1, '5': 9, '9': 5, '10': 'name', '17': true},
  ],
  '8': [
    {'1': '_average_bandwidth'},
    {'1': '_width'},
    {'1': '_height'},
    {'1': '_frame_rate'},
    {'1': '_codecs'},
    {'1': '_name'},
  ],
};

/// Descriptor for `StreamVariant`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List streamVariantDescriptor = $convert.base64Decode(
    'Cg1TdHJlYW1WYXJpYW50EhAKA3VybBgBIAEoCVIDdXJsEhwKCWJhbmR3aWR0aBgCIAEoBFIJYm'
    'FuZHdpZHRoEjAKEWF2ZXJhZ2VfYmFuZHdpZHRoGAMgASgESABSEGF2ZXJhZ2VCYW5kd2lkdGiI'
    'AQESGQoFd2lkdGgYBCABKA1IAVIFd2lkdGiIAQESGwoGaGVpZ2h0GAUgASgNSAJSBmhlaWdodI'
    'gBARIiCgpmcmFtZV9yYXRlGAYgASgBSANSCWZyYW1lUmF0ZYgBARIbCgZjb2RlY3MYByABKAlI'
    'BFIGY29kZWNziAEBEhcKBG5hbWUYCCABKAlIBVIEbmFtZYgBAUIUChJfYXZlcmFnZV9iYW5kd2'
    'lkdGhCCAoGX3dpZHRoQgkKB19oZWlnaHRCDQoLX2ZyYW1lX3JhdGVCCQoHX2NvZGVjc0IHCgVf'
    'bmFtZQ==');

@$core.Deprecated('Use streamVariantsRequestDescriptor instead')
const StreamVariantsRequest$json = {
  '1': 'StreamVariantsRequest',
  '2': [
    {'1': 'channel_id', '3': 1, '4': 1, '5': 3, '10': 'channelId'},
    {'1': 'url', '3': 2, '4': 1, '5': 9, '10': 'url'},
  ],
};

/// Descriptor for `StreamVariantsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List streamVariantsRequestDescriptor = $convert.base64Decode(
    'ChVTdHJlYW1WYXJpYW50c1JlcXVlc3QSHQoKY2hhbm5lbF9pZBgBIAEoA1IJY2hhbm5lbElkEh'
    'AKA3VybBgCIAEoCVIDdXJs');

@$core.Deprecated('Use streamVariantListDescriptor instead')
const StreamVariantList$json = {
  '1': 'StreamVariantList',
  '2': [
    {
      '1': 'variants',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.generated_proto.StreamVariant',
      '10': 'variants'
    },
    {'1': 'master_url', '3': 2, '4': 1, '5': 9, '10': 'masterUrl'},
  ],
};

/// Descriptor for `StreamVariantList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List streamVariantListDescriptor = $convert.base64Decode(
    'ChFTdHJlYW1WYXJpYW50TGlzdBI6Cgh2YXJpYW50cxgBIAMoCzIeLmdlbmVyYXRlZF9wcm90by'
    '5TdHJlYW1WYXJpYW50Ugh2YXJpYW50cxIdCgptYXN0ZXJfdXJsGAIgASgJUgltYXN0ZXJVcmw=');

@$core.Deprecated('Use programmeDescriptor instead')
const Programme$json = {
  '1': 'Programme',
  '2': [
    {'1': 'title', '3': 1, '4': 1, '5': 9, '10': 'title'},
    {'1': 'start', '3': 2, '4': 1, '5': 3, '10': 'start'},
    {'1': 'stop', '3': 3, '4': 1, '5': 3, '10': 'stop'},
    {
      '1': 'catchup_available',
      '3': 4,
      '4': 1,
      '5': 8,
      '10': 'catchupAvailable'
    },
  ],
};

/// Descriptor for `Programme`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List programmeDescriptor = $convert.base64Decode(
    'CglQcm9ncmFtbWUSFAoFdGl0bGUYASABKAlSBXRpdGxlEhQKBXN0YXJ0GAIgASgDUgVzdGFydB'
    'ISCgRzdG9wGAMgASgDUgRzdG9wEisKEWNhdGNodXBfYXZhaWxhYmxlGAQgASgIUhBjYXRjaHVw'
    'QXZhaWxhYmxl');

@$core.Deprecated('Use nowNextDescriptor instead')
const NowNext$json = {
  '1': 'NowNext',
  '2': [
    {'1': 'supported', '3': 1, '4': 1, '5': 8, '10': 'supported'},
    {
      '1': 'now',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.generated_proto.Programme',
      '10': 'now'
    },
    {
      '1': 'next',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.generated_proto.Programme',
      '10': 'next'
    },
  ],
};

/// Descriptor for `NowNext`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nowNextDescriptor = $convert.base64Decode(
    'CgdOb3dOZXh0EhwKCXN1cHBvcnRlZBgBIAEoCFIJc3VwcG9ydGVkEiwKA25vdxgCIAEoCzIaLm'
    'dlbmVyYXRlZF9wcm90by5Qcm9ncmFtbWVSA25vdxIuCgRuZXh0GAMgASgLMhouZ2VuZXJhdGVk'
    'X3Byb3RvLlByb2dyYW1tZVIEbmV4dA==');

@$core.Deprecated('Use transferInfoDescriptor instead')
const TransferInfo$json = {
  '1': 'TransferInfo',
  '2': [
    {
      '1': 'channel',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.generated_proto.Channel',
      '10': 'channel'
    },
    {'1': 'max_connections', '3': 2, '4': 1, '5': 13, '10': 'maxConnections'},
    {'1': 'identity', '3': 3, '4': 1, '5': 9, '10': 'identity'},
    {'1': 'show_name', '3': 4, '4': 1, '5': 9, '10': 'showName'},
    {'1': 'season', '3': 5, '4': 1, '5': 13, '10': 'season'},
    {'1': 'episode', '3': 6, '4': 1, '5': 13, '10': 'episode'},
  ],
};

/// Descriptor for `TransferInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transferInfoDescriptor = $convert.base64Decode(
    'CgxUcmFuc2ZlckluZm8SMgoHY2hhbm5lbBgBIAEoCzIYLmdlbmVyYXRlZF9wcm90by5DaGFubm'
    'VsUgdjaGFubmVsEicKD21heF9jb25uZWN0aW9ucxgCIAEoDVIObWF4Q29ubmVjdGlvbnMSGgoI'
    'aWRlbnRpdHkYAyABKAlSCGlkZW50aXR5EhsKCXNob3dfbmFtZRgEIAEoCVIIc2hvd05hbWUSFg'
    'oGc2Vhc29uGAUgASgNUgZzZWFzb24SGAoHZXBpc29kZRgGIAEoDVIHZXBpc29kZQ==');

@$core.Deprecated('Use downloadRequestDescriptor instead')
const DownloadRequest$json = {
  '1': 'DownloadRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'url', '3': 2, '4': 1, '5': 9, '10': 'url'},
    {'1': 'part_path', '3': 3, '4': 1, '5': 9, '10': 'partPath'},
    {
      '1': 'user_agent',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'userAgent',
      '17': true
    },
    {
      '1': 'referrer',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'referrer',
      '17': true
    },
    {
      '1': 'http_origin',
      '3': 6,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'httpOrigin',
      '17': true
    },
    {'1': 'ignore_ssl', '3': 7, '4': 1, '5': 8, '10': 'ignoreSsl'},
    {'1': 'etag', '3': 8, '4': 1, '5': 9, '9': 3, '10': 'etag', '17': true},
    {
      '1': 'last_modified',
      '3': 9,
      '4': 1,
      '5': 9,
      '9': 4,
      '10': 'lastModified',
      '17': true
    },
    {'1': 'total', '3': 10, '4': 1, '5': 3, '10': 'total'},
    {'1': 'reserved_bytes', '3': 11, '4': 1, '5': 3, '10': 'reservedBytes'},
  ],
  '8': [
    {'1': '_user_agent'},
    {'1': '_referrer'},
    {'1': '_http_origin'},
    {'1': '_etag'},
    {'1': '_last_modified'},
  ],
};

/// Descriptor for `DownloadRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List downloadRequestDescriptor = $convert.base64Decode(
    'Cg9Eb3dubG9hZFJlcXVlc3QSDgoCaWQYASABKAlSAmlkEhAKA3VybBgCIAEoCVIDdXJsEhsKCX'
    'BhcnRfcGF0aBgDIAEoCVIIcGFydFBhdGgSIgoKdXNlcl9hZ2VudBgEIAEoCUgAUgl1c2VyQWdl'
    'bnSIAQESHwoIcmVmZXJyZXIYBSABKAlIAVIIcmVmZXJyZXKIAQESJAoLaHR0cF9vcmlnaW4YBi'
    'ABKAlIAlIKaHR0cE9yaWdpbogBARIdCgppZ25vcmVfc3NsGAcgASgIUglpZ25vcmVTc2wSFwoE'
    'ZXRhZxgIIAEoCUgDUgRldGFniAEBEigKDWxhc3RfbW9kaWZpZWQYCSABKAlIBFIMbGFzdE1vZG'
    'lmaWVkiAEBEhQKBXRvdGFsGAogASgDUgV0b3RhbBIlCg5yZXNlcnZlZF9ieXRlcxgLIAEoA1IN'
    'cmVzZXJ2ZWRCeXRlc0INCgtfdXNlcl9hZ2VudEILCglfcmVmZXJyZXJCDgoMX2h0dHBfb3JpZ2'
    'luQgcKBV9ldGFnQhAKDl9sYXN0X21vZGlmaWVk');

@$core.Deprecated('Use downloadStatusDescriptor instead')
const DownloadStatus$json = {
  '1': 'DownloadStatus',
  '2': [
    {'1': 'bytes', '3': 1, '4': 1, '5': 3, '10': 'bytes'},
    {'1': 'total', '3': 2, '4': 1, '5': 3, '10': 'total'},
    {'1': 'etag', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'etag', '17': true},
    {
      '1': 'last_modified',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'lastModified',
      '17': true
    },
    {'1': 'finished', '3': 5, '4': 1, '5': 8, '10': 'finished'},
    {'1': 'stopped', '3': 6, '4': 1, '5': 8, '10': 'stopped'},
    {
      '1': 'failure',
      '3': 7,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'failure',
      '17': true
    },
    {'1': 'active', '3': 8, '4': 1, '5': 8, '10': 'active'},
  ],
  '8': [
    {'1': '_etag'},
    {'1': '_last_modified'},
    {'1': '_failure'},
  ],
};

/// Descriptor for `DownloadStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List downloadStatusDescriptor = $convert.base64Decode(
    'Cg5Eb3dubG9hZFN0YXR1cxIUCgVieXRlcxgBIAEoA1IFYnl0ZXMSFAoFdG90YWwYAiABKANSBX'
    'RvdGFsEhcKBGV0YWcYAyABKAlIAFIEZXRhZ4gBARIoCg1sYXN0X21vZGlmaWVkGAQgASgJSAFS'
    'DGxhc3RNb2RpZmllZIgBARIaCghmaW5pc2hlZBgFIAEoCFIIZmluaXNoZWQSGAoHc3RvcHBlZB'
    'gGIAEoCFIHc3RvcHBlZBIdCgdmYWlsdXJlGAcgASgJSAJSB2ZhaWx1cmWIAQESFgoGYWN0aXZl'
    'GAggASgIUgZhY3RpdmVCBwoFX2V0YWdCEAoOX2xhc3RfbW9kaWZpZWRCCgoIX2ZhaWx1cmU=');

@$core.Deprecated('Use relayRequestDescriptor instead')
const RelayRequest$json = {
  '1': 'RelayRequest',
  '2': [
    {'1': 'url', '3': 1, '4': 1, '5': 9, '10': 'url'},
    {
      '1': 'user_agent',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'userAgent',
      '17': true
    },
    {
      '1': 'referrer',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'referrer',
      '17': true
    },
    {
      '1': 'http_origin',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'httpOrigin',
      '17': true
    },
    {'1': 'ignore_ssl', '3': 5, '4': 1, '5': 8, '10': 'ignoreSsl'},
    {'1': 'directory', '3': 6, '4': 1, '5': 9, '10': 'directory'},
    {'1': 'seekable', '3': 7, '4': 1, '5': 8, '10': 'seekable'},
  ],
  '8': [
    {'1': '_user_agent'},
    {'1': '_referrer'},
    {'1': '_http_origin'},
  ],
};

/// Descriptor for `RelayRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List relayRequestDescriptor = $convert.base64Decode(
    'CgxSZWxheVJlcXVlc3QSEAoDdXJsGAEgASgJUgN1cmwSIgoKdXNlcl9hZ2VudBgCIAEoCUgAUg'
    'l1c2VyQWdlbnSIAQESHwoIcmVmZXJyZXIYAyABKAlIAVIIcmVmZXJyZXKIAQESJAoLaHR0cF9v'
    'cmlnaW4YBCABKAlIAlIKaHR0cE9yaWdpbogBARIdCgppZ25vcmVfc3NsGAUgASgIUglpZ25vcm'
    'VTc2wSHAoJZGlyZWN0b3J5GAYgASgJUglkaXJlY3RvcnkSGgoIc2Vla2FibGUYByABKAhSCHNl'
    'ZWthYmxlQg0KC191c2VyX2FnZW50QgsKCV9yZWZlcnJlckIOCgxfaHR0cF9vcmlnaW4=');

@$core.Deprecated('Use relayInfoDescriptor instead')
const RelayInfo$json = {
  '1': 'RelayInfo',
  '2': [
    {'1': 'token', '3': 1, '4': 1, '5': 9, '10': 'token'},
    {'1': 'port', '3': 2, '4': 1, '5': 13, '10': 'port'},
    {'1': 'video', '3': 3, '4': 1, '5': 9, '10': 'video'},
    {'1': 'audio', '3': 4, '4': 1, '5': 9, '10': 'audio'},
  ],
};

/// Descriptor for `RelayInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List relayInfoDescriptor = $convert.base64Decode(
    'CglSZWxheUluZm8SFAoFdG9rZW4YASABKAlSBXRva2VuEhIKBHBvcnQYAiABKA1SBHBvcnQSFA'
    'oFdmlkZW8YAyABKAlSBXZpZGVvEhQKBWF1ZGlvGAQgASgJUgVhdWRpbw==');

@$core.Deprecated('Use fFIResultDescriptor instead')
const FFIResult$json = {
  '1': 'FFIResult',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {
      '1': 'error_message',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'errorMessage',
      '17': true
    },
    {
      '1': 'settings',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.generated_proto.Settings',
      '9': 0,
      '10': 'settings'
    },
    {
      '1': 'source',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.generated_proto.Source',
      '9': 0,
      '10': 'source'
    },
    {
      '1': 'channel_list',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.generated_proto.ChannelList',
      '9': 0,
      '10': 'channelList'
    },
    {
      '1': 'bool_message',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.generated_proto.BoolMessage',
      '9': 0,
      '10': 'boolMessage'
    },
    {
      '1': 'movie_position',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.generated_proto.GetMoviePosition',
      '9': 0,
      '10': 'moviePosition'
    },
    {
      '1': 'headers',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.generated_proto.ChannelHttpHeaders',
      '9': 0,
      '10': 'headers'
    },
    {
      '1': 'enabled_sources_minimal',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.generated_proto.GetEnabledSourcesMinimal',
      '9': 0,
      '10': 'enabledSourcesMinimal'
    },
    {
      '1': 'source_list',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.generated_proto.SourceList',
      '9': 0,
      '10': 'sourceList'
    },
    {
      '1': 'category_list',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.generated_proto.CategoryList',
      '9': 0,
      '10': 'categoryList'
    },
    {
      '1': 'refresh_stats',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.generated_proto.RefreshStats',
      '9': 0,
      '10': 'refreshStats'
    },
    {
      '1': 'refresh_stats_list',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.generated_proto.RefreshStatsList',
      '9': 0,
      '10': 'refreshStatsList'
    },
    {
      '1': 'stream_variants',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.generated_proto.StreamVariantList',
      '9': 0,
      '10': 'streamVariants'
    },
    {
      '1': 'now_next',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.generated_proto.NowNext',
      '9': 0,
      '10': 'nowNext'
    },
    {
      '1': 'programme_list',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.generated_proto.ProgrammeList',
      '9': 0,
      '10': 'programmeList'
    },
    {
      '1': 'transfer_info',
      '3': 18,
      '4': 1,
      '5': 11,
      '6': '.generated_proto.TransferInfo',
      '9': 0,
      '10': 'transferInfo'
    },
    {
      '1': 'disk_space',
      '3': 19,
      '4': 1,
      '5': 11,
      '6': '.generated_proto.IdMessage',
      '9': 0,
      '10': 'diskSpace'
    },
    {
      '1': 'download_status',
      '3': 20,
      '4': 1,
      '5': 11,
      '6': '.generated_proto.DownloadStatus',
      '9': 0,
      '10': 'downloadStatus'
    },
    {
      '1': 'relay_info',
      '3': 21,
      '4': 1,
      '5': 11,
      '6': '.generated_proto.RelayInfo',
      '9': 0,
      '10': 'relayInfo'
    },
  ],
  '8': [
    {'1': 'data'},
    {'1': '_error_message'},
  ],
};

/// Descriptor for `FFIResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fFIResultDescriptor = $convert.base64Decode(
    'CglGRklSZXN1bHQSGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxIoCg1lcnJvcl9tZXNzYWdlGA'
    'IgASgJSAFSDGVycm9yTWVzc2FnZYgBARI3CghzZXR0aW5ncxgDIAEoCzIZLmdlbmVyYXRlZF9w'
    'cm90by5TZXR0aW5nc0gAUghzZXR0aW5ncxIxCgZzb3VyY2UYBCABKAsyFy5nZW5lcmF0ZWRfcH'
    'JvdG8uU291cmNlSABSBnNvdXJjZRJBCgxjaGFubmVsX2xpc3QYBiABKAsyHC5nZW5lcmF0ZWRf'
    'cHJvdG8uQ2hhbm5lbExpc3RIAFILY2hhbm5lbExpc3QSQQoMYm9vbF9tZXNzYWdlGAcgASgLMh'
    'wuZ2VuZXJhdGVkX3Byb3RvLkJvb2xNZXNzYWdlSABSC2Jvb2xNZXNzYWdlEkoKDm1vdmllX3Bv'
    'c2l0aW9uGAggASgLMiEuZ2VuZXJhdGVkX3Byb3RvLkdldE1vdmllUG9zaXRpb25IAFINbW92aW'
    'VQb3NpdGlvbhI/CgdoZWFkZXJzGAkgASgLMiMuZ2VuZXJhdGVkX3Byb3RvLkNoYW5uZWxIdHRw'
    'SGVhZGVyc0gAUgdoZWFkZXJzEmMKF2VuYWJsZWRfc291cmNlc19taW5pbWFsGAogASgLMikuZ2'
    'VuZXJhdGVkX3Byb3RvLkdldEVuYWJsZWRTb3VyY2VzTWluaW1hbEgAUhVlbmFibGVkU291cmNl'
    'c01pbmltYWwSPgoLc291cmNlX2xpc3QYCyABKAsyGy5nZW5lcmF0ZWRfcHJvdG8uU291cmNlTG'
    'lzdEgAUgpzb3VyY2VMaXN0EkQKDWNhdGVnb3J5X2xpc3QYDCABKAsyHS5nZW5lcmF0ZWRfcHJv'
    'dG8uQ2F0ZWdvcnlMaXN0SABSDGNhdGVnb3J5TGlzdBJECg1yZWZyZXNoX3N0YXRzGA0gASgLMh'
    '0uZ2VuZXJhdGVkX3Byb3RvLlJlZnJlc2hTdGF0c0gAUgxyZWZyZXNoU3RhdHMSUQoScmVmcmVz'
    'aF9zdGF0c19saXN0GA4gASgLMiEuZ2VuZXJhdGVkX3Byb3RvLlJlZnJlc2hTdGF0c0xpc3RIAF'
    'IQcmVmcmVzaFN0YXRzTGlzdBJNCg9zdHJlYW1fdmFyaWFudHMYDyABKAsyIi5nZW5lcmF0ZWRf'
    'cHJvdG8uU3RyZWFtVmFyaWFudExpc3RIAFIOc3RyZWFtVmFyaWFudHMSNQoIbm93X25leHQYEC'
    'ABKAsyGC5nZW5lcmF0ZWRfcHJvdG8uTm93TmV4dEgAUgdub3dOZXh0EkcKDnByb2dyYW1tZV9s'
    'aXN0GBEgASgLMh4uZ2VuZXJhdGVkX3Byb3RvLlByb2dyYW1tZUxpc3RIAFINcHJvZ3JhbW1lTG'
    'lzdBJECg10cmFuc2Zlcl9pbmZvGBIgASgLMh0uZ2VuZXJhdGVkX3Byb3RvLlRyYW5zZmVySW5m'
    'b0gAUgx0cmFuc2ZlckluZm8SOwoKZGlza19zcGFjZRgTIAEoCzIaLmdlbmVyYXRlZF9wcm90by'
    '5JZE1lc3NhZ2VIAFIJZGlza1NwYWNlEkoKD2Rvd25sb2FkX3N0YXR1cxgUIAEoCzIfLmdlbmVy'
    'YXRlZF9wcm90by5Eb3dubG9hZFN0YXR1c0gAUg5kb3dubG9hZFN0YXR1cxI7CgpyZWxheV9pbm'
    'ZvGBUgASgLMhouZ2VuZXJhdGVkX3Byb3RvLlJlbGF5SW5mb0gAUglyZWxheUluZm9CBgoEZGF0'
    'YUIQCg5fZXJyb3JfbWVzc2FnZQ==');
