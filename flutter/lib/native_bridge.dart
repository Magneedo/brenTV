import 'dart:async';
import 'models/bottom_bar.dart';
import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:fixnum/fixnum.dart';
import 'package:protobuf/protobuf.dart' as $pb;

import 'generated/generated_proto.pb.dart' as pb;
import 'generated/bindings.dart' as ffi;
import 'package:brentv/models/channel.dart';
import 'package:brentv/models/source.dart';
import 'package:brentv/models/filters.dart';
import 'package:brentv/models/settings.dart';
import 'package:brentv/models/proto_extensions.dart';
import 'package:brentv/models/channel_http_headers.dart';
import 'package:brentv/models/media_type.dart';

class NativeBridge {
  static NativeBridge? _instance;

  final ffi.RustLibBindings _bindings;
  int _nextTaskId = 0;
  bool _disposed = false;
  final Map<int, Completer<pb.FFIResult>> _pendingRequests = {};
  Future<void>? _settingsWrites;
  final _catalogChanges = StreamController<void>.broadcast();
  Stream<void> get catalogChanges => _catalogChanges.stream;
  void _catalogChanged() {
    if (!_catalogChanges.isClosed) _catalogChanges.add(null);
  }

  late final NativeCallable<Void Function(Uint64, Pointer<Uint8>, Size)>
  _globalCallback;

  static NativeBridge get instance => _instance ??= NativeBridge._internal(
    ffi.RustLibBindings(_openDynamicLibrary()),
  );

  static DynamicLibrary _openDynamicLibrary() {
    if (Platform.isIOS) {
      return DynamicLibrary.process();
    }
    return DynamicLibrary.open("libbrentv_core.so");
  }

  NativeBridge._internal(this._bindings) {
    _globalCallback =
        NativeCallable<Void Function(Uint64, Pointer<Uint8>, Size)>.listener((
          int taskId,
          Pointer<Uint8> ptr,
          int len,
        ) {
          final completer = _pendingRequests.remove(taskId);
          try {
            if (completer == null || completer.isCompleted) return;
            final copiedBytes = Uint8List.fromList(ptr.asTypedList(len));
            final result = pb.FFIResult.fromBuffer(copiedBytes);
            completer.complete(result);
          } catch (e, stackTrace) {
            if (completer != null && !completer.isCompleted) {
              completer.completeError(e, stackTrace);
            }
          } finally {
            _bindings.free_message(ptr, len);
            if (_disposed && _pendingRequests.isEmpty) _globalCallback.close();
          }
        });
  }

  Future<pb.FFIResult> _executeAsync(
    void Function(int taskId, ffi.FfiCallback callback) ffiAction,
  ) async {
    if (_disposed) throw StateError("NativeBridge was disposed.");
    final taskId = _nextTaskId++;
    final completer = Completer<pb.FFIResult>();
    _pendingRequests[taskId] = completer;
    try {
      ffiAction(taskId, _globalCallback.nativeFunction);
    } catch (_) {
      _pendingRequests.remove(taskId);
      rethrow;
    }
    final result = await completer.future;
    if (!result.success) {
      throw Exception(
        result.hasErrorMessage() ? result.errorMessage : "Unknown FFI error",
      );
    }
    return result;
  }

  Future<pb.FFIResult> _executeWithMsg<T extends $pb.GeneratedMessage>(
    T request,
    void Function(
      int taskId,
      Pointer<Uint8> ptr,
      int len,
      ffi.FfiCallback callback,
    )
    ffiAction,
  ) async {
    final pbBytes = request.writeToBuffer();
    // At least 1 byte: an all-default message encodes to 0 bytes.
    final nativeBuffer = malloc.allocate<Uint8>(
      pbBytes.isEmpty ? 1 : pbBytes.length,
    );

    try {
      final pointerList = nativeBuffer.asTypedList(pbBytes.length);
      pointerList.setAll(0, pbBytes);

      return await _executeAsync((id, cb) {
        ffiAction(id, nativeBuffer, pbBytes.length, cb);
      });
    } finally {
      malloc.free(nativeBuffer);
    }
  }

  Future<void> setHidden(int id, bool hidden, {bool group = false}) async {
    await _executeWithMsg(
      pb.SetHidden(id: Int64(id), hidden: hidden, group: group),
      (id, ptr, len, cb) {
        _bindings.set_hidden(id, cb, ptr, len);
      },
    );
    _catalogChanged();
  }

  Future<void> restoreAllHidden() async {
    await _executeAsync((id, cb) {
      _bindings.restore_all_hidden(id, cb);
    });
    _catalogChanged();
  }

  Future<int> getDiskSpace(String folder) async {
    final result = await _executeWithMsg(
      pb.StrMessage(value: folder),
      (id, ptr, len, cb) => _bindings.get_disk_space(id, cb, ptr, len),
    );
    return result.diskSpace.value.toInt();
  }

  /// Runs until the transfer ends; a thrown error means it can be retried.
  Future<pb.DownloadStatus> downloadFile(pb.DownloadRequest request) async {
    final result = await _executeWithMsg(
      request,
      (id, ptr, len, cb) => _bindings.download_file(id, cb, ptr, len),
    );
    return result.downloadStatus;
  }

  Future<pb.DownloadStatus> downloadProgress(String id) async {
    final result = await _executeWithMsg(
      pb.StrMessage(value: id),
      (id, ptr, len, cb) => _bindings.download_progress(id, cb, ptr, len),
    );
    return result.downloadStatus;
  }

  Future<void> stopDownload(String id) => _executeWithMsg(
    pb.StrMessage(value: id),
    (id, ptr, len, cb) => _bindings.stop_download(id, cb, ptr, len),
  );

  /// Connects to a live stream and reports its codecs; see `src/relay.rs`.
  Future<pb.RelayInfo> relayOpen(pb.RelayRequest request) async {
    final result = await _executeWithMsg(
      request,
      (id, ptr, len, cb) => _bindings.relay_open(id, cb, ptr, len),
    );
    return result.relayInfo;
  }

  Future<void> relayClose(String token) => _executeWithMsg(
    pb.StrMessage(value: token),
    (id, ptr, len, cb) => _bindings.relay_close(id, cb, ptr, len),
  );

  Future<pb.TransferInfo> getTransferInfo(int channelId) async {
    final result = await _executeWithMsg(
      pb.IdMessage(value: Int64(channelId)),
      (id, ptr, len, cb) {
        _bindings.get_transfer_info(id, cb, ptr, len);
      },
    );
    return result.transferInfo;
  }

  Future<pb.Settings> getMediaState() async {
    final result = await _executeAsync(
      (id, cb) => _bindings.get_settings(id, cb),
    );
    return result.settings;
  }

  Future<void> saveMediaState(pb.Settings patch) =>
      _updateSettings(patch, notifyCatalog: false);

  Future<pb.ProgrammeList> getSchedule(int channelId, int from, int to) async {
    final result = await _executeWithMsg(
      pb.GuideRequest(
        channelId: Int64(channelId),
        from: Int64(from),
        to: Int64(to),
      ),
      (id, ptr, len, cb) {
        _bindings.get_schedule(id, cb, ptr, len);
      },
    );
    return result.programmeList;
  }

  Future<Channel> getCatchup(int channelId, int start, int stop) async {
    final result = await _executeWithMsg(
      pb.GuideRequest(
        channelId: Int64(channelId),
        from: Int64(start),
        to: Int64(stop),
      ),
      (id, ptr, len, cb) {
        _bindings.get_catchup(id, cb, ptr, len);
      },
    );
    return result.channelList.channels.single.toDomain();
  }

  Future<void> initialize(pb.InitMessage init) async {
    await _executeWithMsg(init, (id, ptr, len, cb) {
      _bindings.initialize(id, cb, ptr, len);
    });
  }

  Future<pb.RefreshStats> processSource(Source source) async {
    final result = await _executeWithMsg(source.toProto(), (id, ptr, len, cb) {
      _bindings.process_source(id, cb, ptr, len);
    });
    _catalogChanged();
    return result.refreshStats;
  }

  Future<pb.RefreshStats> refreshSource(Source source) async {
    final result = await _executeWithMsg(source.toProto(), (id, ptr, len, cb) {
      _bindings.refresh_source(id, cb, ptr, len);
    });
    _catalogChanged();
    return result.refreshStats;
  }

  Future<void> updateSource(Source source) async {
    await _executeWithMsg(source.toProto(), (id, ptr, len, cb) {
      _bindings.update_source(id, cb, ptr, len);
    });
    _catalogChanged();
  }

  Future<void> setSourceEnabled(int sourceId, bool enabled) async {
    await _executeWithMsg(
      pb.SetSourceEnabled(sourceId: Int64(sourceId), enabled: enabled),
      (id, ptr, len, cb) {
        _bindings.set_source_enabled(id, cb, ptr, len);
      },
    );
    _catalogChanged();
  }

  Future<void> deleteSource(int id) async {
    await _executeWithMsg(pb.IdMessage(value: Int64(id)), (id, ptr, len, cb) {
      _bindings.delete_source(id, cb, ptr, len);
    });
    _catalogChanged();
  }

  Future<List<Source>> getSources() async {
    final result = await _executeAsync((id, cb) {
      _bindings.get_sources(id, cb);
    });
    return result.sourceList.sources.map((s) => s.toDomain()).toList();
  }

  Future<List<int>> getEnabledSourcesMinimal() async {
    final result = await _executeAsync((id, cb) {
      _bindings.get_enabled_sources_minimal(id, cb);
    });
    return result.enabledSourcesMinimal.listId.map((e) => e.toInt()).toList();
  }

  Future<bool> hasSources() async {
    final result = await _executeAsync((id, cb) {
      _bindings.has_sources(id, cb);
    });
    return result.boolMessage.value;
  }

  Future<List<Channel>> getChannels(Filters filters) async {
    final result = await _executeWithMsg(filters.toProto(), (id, ptr, len, cb) {
      _bindings.get_channels(id, cb, ptr, len);
    });
    return result.channelList.channels.map((c) => c.toDomain()).toList();
  }

  /// Collects every page without changing the caller's filters.
  Future<List<Channel>> getAllChannels(Filters filters) async {
    final request = filters.toProto()..page = 1;
    final channels = <Channel>[];
    while (true) {
      final result = await _executeWithMsg(request, (id, ptr, len, cb) {
        _bindings.get_channels(id, cb, ptr, len);
      });
      final page = result.channelList.channels;
      if (page.isEmpty) return channels;
      channels.addAll(page.map((c) => c.toDomain()));
      request.page++;
    }
  }

  Future<void> favorite(int channelId, bool isFavorite) async {
    await _executeWithMsg(
      pb.ToggleFavorite(channelId: Int64(channelId), favorite: isFavorite),
      (id, ptr, len, cb) {
        _bindings.favorite(id, cb, ptr, len);
      },
    );
  }

  /// Marks a category as favourite (shown first and on the Favorites page).
  Future<void> favoriteGroup(int groupId, bool isFavorite) async {
    await _executeWithMsg(
      pb.ToggleFavorite(channelId: Int64(groupId), favorite: isFavorite),
      (id, ptr, len, cb) {
        _bindings.favorite_group(id, cb, ptr, len);
      },
    );
  }

  /// Swaps two favorites' places in Favorites (and F1–F9) order.
  Future<void> swapFavorites(int id, int other, {bool group = false}) async {
    await _executeWithMsg(
      pb.SwapFavorites(id: Int64(id), other: Int64(other), group: group),
      (id, ptr, len, cb) {
        _bindings.swap_favorites(id, cb, ptr, len);
      },
    );
  }

  /// Saves only the UI scale; every other setting keeps its stored value.
  Future<void> setUiScale(int percent) async {
    await _executeWithMsg(pb.Settings(uiScalePercent: percent), (
      id,
      ptr,
      len,
      cb,
    ) {
      _bindings.update_settings(id, cb, ptr, len);
    });
  }

  Future<Settings> getSettings() async {
    final pendingWrite = _settingsWrites;
    if (pendingWrite != null) await pendingWrite.catchError((_) {});
    final result = await _executeAsync((id, cb) {
      _bindings.get_settings(id, cb);
    });
    return result.settings.toDomain();
  }

  Future<void> setBottomBar(BottomBarConfig value) =>
      _updateSettings(pb.Settings(bottomBar: value.encode()));

  /// Saves only corner style; stale settings pages cannot overwrite it.
  Future<void> setSquareCorners(bool value) =>
      _updateSettings(pb.Settings(squareCorners: value), notifyCatalog: false);

  Future<void> updateSettings(Settings settings) {
    // Snapshot before queuing: rapid UI changes must be saved in their order,
    // even when native workers would otherwise finish writes out of order.
    return _updateSettings(settings.toProto());
  }

  Future<void> _updateSettings(
    pb.Settings message, {
    bool notifyCatalog = true,
  }) {
    final previous = _settingsWrites ?? Future<void>.value();
    final write = previous.catchError((_) {}).then((_) async {
      await _executeWithMsg(message, (id, ptr, len, cb) {
        _bindings.update_settings(id, cb, ptr, len);
      });
      if (notifyCatalog) _catalogChanged();
    });
    _settingsWrites = write;
    void clear() {
      if (identical(_settingsWrites, write)) _settingsWrites = null;
    }

    unawaited(
      write.then((_) => clear(), onError: (Object _, StackTrace _) => clear()),
    );
    return write;
  }

  Future<void> addLastWatched(int id) async {
    await _executeWithMsg(pb.IdMessage(value: Int64(id)), (id, ptr, len, cb) {
      _bindings.add_last_watched(id, cb, ptr, len);
    });
  }

  Future<void> setMoviePosition(int channelId, int position) async {
    await _executeWithMsg(
      pb.MoviePosition(channelId: Int64(channelId), position: Int64(position)),
      (id, ptr, len, cb) {
        _bindings.set_movie_position(id, cb, ptr, len);
      },
    );
  }

  Future<int?> getMoviePosition(int id) async {
    final result = await _executeWithMsg(pb.IdMessage(value: Int64(id)), (
      id,
      ptr,
      len,
      cb,
    ) {
      _bindings.get_movie_position(id, cb, ptr, len);
    });
    return result.hasMoviePosition() && result.moviePosition.hasPosition()
        ? result.moviePosition.position.toInt()
        : null;
  }

  Future<ChannelHttpHeaders?> getChannelHeaders(int id) async {
    final result = await _executeWithMsg(pb.IdMessage(value: Int64(id)), (
      id,
      ptr,
      len,
      cb,
    ) {
      _bindings.get_channel_headers(id, cb, ptr, len);
    });
    return result.hasHeaders() ? result.headers.toDomain() : null;
  }

  Future<void> getEpisodes(
    int seriesId,
    int sourceId,
    String? fallbackImage,
  ) async {
    final msg = pb.GetEpisodes(
      seriesId: Int64(seriesId),
      sourceId: Int64(sourceId),
      fallbackImage: fallbackImage,
    );
    await _executeWithMsg(msg, (id, ptr, len, cb) {
      _bindings.get_episodes(id, cb, ptr, len);
    });
  }

  Future<void> removeLastWatched(int id) async {
    await _executeWithMsg(pb.IdMessage(value: Int64(id)), (id, ptr, len, cb) {
      _bindings.remove_last_watched(id, cb, ptr, len);
    });
  }

  Future<void> clearHistory() async {
    await _executeAsync((id, cb) {
      _bindings.clear_history(id, cb);
    });
  }

  /// Refreshes every enabled source; failed sources carry `error`.
  Future<List<pb.RefreshStats>> refreshAll() async {
    final result = await _executeAsync((id, cb) {
      _bindings.refresh_all(id, cb);
    });
    _catalogChanged();
    return result.refreshStatsList.stats;
  }

  /// Creates the source without importing and returns it with its id, so
  /// categories can be chosen before the first import. `processSource` then
  /// imports into it (matched by name).
  Future<Source> saveSource(Source source) async {
    final result = await _executeWithMsg(source.toProto(), (id, ptr, len, cb) {
      _bindings.save_source(id, cb, ptr, len);
    });
    _catalogChanged();
    return result.source.toDomain();
  }

  Future<pb.CategoryList> getSourceCategories(int sourceId) async {
    final result = await _executeWithMsg(pb.IdMessage(value: Int64(sourceId)), (
      id,
      ptr,
      len,
      cb,
    ) {
      _bindings.get_source_categories(id, cb, ptr, len);
    });
    return result.categoryList;
  }

  /// Asks the provider for its current categories (Xtream) without importing.
  Future<pb.CategoryList> fetchSourceCategories(int sourceId) async {
    final result = await _executeWithMsg(pb.IdMessage(value: Int64(sourceId)), (
      id,
      ptr,
      len,
      cb,
    ) {
      _bindings.fetch_source_categories(id, cb, ptr, len);
    });
    return result.categoryList;
  }

  Future<void> setSourceCategories(
    int sourceId,
    MediaType mediaType,
    pb.CategoryMode mode,
    Iterable<String> listed,
  ) async {
    final msg = pb.SetCategories(
      sourceId: Int64(sourceId),
      mediaType: mediaType.index,
      mode: mode,
      listed: listed,
    );
    await _executeWithMsg(msg, (id, ptr, len, cb) {
      _bindings.set_source_categories(id, cb, ptr, len);
    });
    _catalogChanged();
  }

  /// Other feeds of the same channel, best first.
  Future<List<Channel>> getAlternates(int channelId) async {
    final result = await _executeWithMsg(
      pb.IdMessage(value: Int64(channelId)),
      (id, ptr, len, cb) {
        _bindings.get_alternates(id, cb, ptr, len);
      },
    );
    return result.channelList.channels
        .map(
          (c) => c.toDomain()
            ..preferred =
                result.channelList.hasPreferredChannelId() &&
                c.id == result.channelList.preferredChannelId,
        )
        .toList();
  }

  Future<void> setAltOverride(
    int channelId,
    pb.AltOverrideKind kind, [
    int? targetChannelId,
  ]) async {
    final msg = pb.AltOverride(
      channelId: Int64(channelId),
      kind: kind,
      targetChannelId: targetChannelId != null ? Int64(targetChannelId) : null,
    );
    await _executeWithMsg(msg, (id, ptr, len, cb) {
      _bindings.set_alt_override(id, cb, ptr, len);
    });
  }

  Future<void> clearAltOverrides(int channelId) async {
    await _executeWithMsg(pb.IdMessage(value: Int64(channelId)), (
      id,
      ptr,
      len,
      cb,
    ) {
      _bindings.clear_alt_overrides(id, cb, ptr, len);
    });
  }

  /// HLS variants the stream really offers; empty when it has only one.
  Future<pb.StreamVariantList> getStreamVariants(
    int channelId,
    String url,
  ) async {
    final msg = pb.StreamVariantsRequest(channelId: Int64(channelId), url: url);
    final result = await _executeWithMsg(msg, (id, ptr, len, cb) {
      _bindings.get_stream_variants(id, cb, ptr, len);
    });
    return result.streamVariants;
  }

  Future<pb.NowNext> getNowNext(int channelId) async {
    final result = await _executeWithMsg(
      pb.IdMessage(value: Int64(channelId)),
      (id, ptr, len, cb) {
        _bindings.get_now_next(id, cb, ptr, len);
      },
    );
    return result.nowNext;
  }

  Future<bool> sourceNameExists(String name) async {
    final result = await _executeWithMsg(pb.StrMessage(value: name), (
      id,
      ptr,
      len,
      cb,
    ) {
      _bindings.source_name_exists(id, cb, ptr, len);
    });
    return result.boolMessage.value;
  }

  Future<bool> shouldShowWhatsNew(String? currentVersion) async {
    final result = await _executeWithMsg(
      pb.OptStrMessage(value: currentVersion),
      (id, ptr, len, cb) {
        _bindings.should_show_whats_new(id, cb, ptr, len);
      },
    );
    return result.boolMessage.value;
  }

  Future<void> updateLastSeenVersion(String version) async {
    await _executeWithMsg(pb.StrMessage(value: version), (id, ptr, len, cb) {
      _bindings.update_last_seen_version(id, cb, ptr, len);
    });
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_catalogChanges.close());
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError("NativeBridge was disposed."));
      }
    }
    // Rust cannot cancel issued callbacks. Keep the listener and task IDs until
    // the final reply arrives, freeing its message even after callers fail.
    if (_pendingRequests.isEmpty) _globalCallback.close();
    if (identical(_instance, this)) _instance = null;
  }
}
