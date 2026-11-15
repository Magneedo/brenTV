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

import 'package:protobuf/protobuf.dart' as $pb;

class MediaType extends $pb.ProtobufEnum {
  static const MediaType MEDIA_TYPE_LIVESTREAM =
      MediaType._(0, _omitEnumNames ? '' : 'MEDIA_TYPE_LIVESTREAM');
  static const MediaType MEDIA_TYPE_MOVIE =
      MediaType._(1, _omitEnumNames ? '' : 'MEDIA_TYPE_MOVIE');
  static const MediaType MEDIA_TYPE_SERIE =
      MediaType._(2, _omitEnumNames ? '' : 'MEDIA_TYPE_SERIE');
  static const MediaType MEDIA_TYPE_GROUP =
      MediaType._(3, _omitEnumNames ? '' : 'MEDIA_TYPE_GROUP');
  static const MediaType MEDIA_TYPE_SEASON =
      MediaType._(4, _omitEnumNames ? '' : 'MEDIA_TYPE_SEASON');

  static const $core.List<MediaType> values = <MediaType>[
    MEDIA_TYPE_LIVESTREAM,
    MEDIA_TYPE_MOVIE,
    MEDIA_TYPE_SERIE,
    MEDIA_TYPE_GROUP,
    MEDIA_TYPE_SEASON,
  ];

  static final $core.List<MediaType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static MediaType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const MediaType._(super.value, super.name);
}

class ViewType extends $pb.ProtobufEnum {
  static const ViewType VIEW_TYPE_ALL =
      ViewType._(0, _omitEnumNames ? '' : 'VIEW_TYPE_ALL');
  static const ViewType VIEW_TYPE_CATEGORIES =
      ViewType._(1, _omitEnumNames ? '' : 'VIEW_TYPE_CATEGORIES');
  static const ViewType VIEW_TYPE_FAVORITES =
      ViewType._(2, _omitEnumNames ? '' : 'VIEW_TYPE_FAVORITES');
  static const ViewType VIEW_TYPE_HISTORY =
      ViewType._(3, _omitEnumNames ? '' : 'VIEW_TYPE_HISTORY');
  static const ViewType VIEW_TYPE_SETTINGS =
      ViewType._(4, _omitEnumNames ? '' : 'VIEW_TYPE_SETTINGS');
  static const ViewType VIEW_TYPE_LOCAL_MEDIA =
      ViewType._(5, _omitEnumNames ? '' : 'VIEW_TYPE_LOCAL_MEDIA');
  static const ViewType VIEW_TYPE_RECORDINGS =
      ViewType._(6, _omitEnumNames ? '' : 'VIEW_TYPE_RECORDINGS');
  static const ViewType VIEW_TYPE_DOWNLOADS =
      ViewType._(7, _omitEnumNames ? '' : 'VIEW_TYPE_DOWNLOADS');

  static const $core.List<ViewType> values = <ViewType>[
    VIEW_TYPE_ALL,
    VIEW_TYPE_CATEGORIES,
    VIEW_TYPE_FAVORITES,
    VIEW_TYPE_HISTORY,
    VIEW_TYPE_SETTINGS,
    VIEW_TYPE_LOCAL_MEDIA,
    VIEW_TYPE_RECORDINGS,
    VIEW_TYPE_DOWNLOADS,
  ];

  static final $core.List<ViewType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 7);
  static ViewType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ViewType._(super.value, super.name);
}

/// Category filters (per source and media type)
class CategoryMode extends $pb.ProtobufEnum {
  static const CategoryMode CATEGORY_MODE_EXCLUDE =
      CategoryMode._(0, _omitEnumNames ? '' : 'CATEGORY_MODE_EXCLUDE');
  static const CategoryMode CATEGORY_MODE_INCLUDE =
      CategoryMode._(1, _omitEnumNames ? '' : 'CATEGORY_MODE_INCLUDE');

  static const $core.List<CategoryMode> values = <CategoryMode>[
    CATEGORY_MODE_EXCLUDE,
    CATEGORY_MODE_INCLUDE,
  ];

  static final $core.List<CategoryMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static CategoryMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CategoryMode._(super.value, super.name);
}

/// Alternate feeds
class AltOverrideKind extends $pb.ProtobufEnum {
  static const AltOverrideKind ALT_OVERRIDE_UNLINK =
      AltOverrideKind._(0, _omitEnumNames ? '' : 'ALT_OVERRIDE_UNLINK');
  static const AltOverrideKind ALT_OVERRIDE_LINK =
      AltOverrideKind._(1, _omitEnumNames ? '' : 'ALT_OVERRIDE_LINK');
  static const AltOverrideKind ALT_OVERRIDE_PREFERRED =
      AltOverrideKind._(2, _omitEnumNames ? '' : 'ALT_OVERRIDE_PREFERRED');

  static const $core.List<AltOverrideKind> values = <AltOverrideKind>[
    ALT_OVERRIDE_UNLINK,
    ALT_OVERRIDE_LINK,
    ALT_OVERRIDE_PREFERRED,
  ];

  static final $core.List<AltOverrideKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static AltOverrideKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const AltOverrideKind._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
