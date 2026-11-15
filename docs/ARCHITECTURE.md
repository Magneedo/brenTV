# brenTV architecture

brenTV is a fork of [Fred TV Mobile](https://github.com/Fredolx/fred-tv-mobile)
(AGPL-3.0) for Linux and iOS. One repository, one Flutter UI, one Rust core.

```
src/                 Rust core (crate brentv-core): SQLite, M3U/Xtream import, HLS probing
protocol/            generated_proto.proto: every message crossing the FFI
flutter/lib/         Flutter UI
flutter/lib/playback Playback dispatcher, quality/alternate feeds, mpv (Linux), AVPlayer (iOS)
flutter/linux/       GTK runner (Wayland, no X11 code), links libbrentv_core.so
flutter/ios/         Xcode project, statically links ios/rust/libbrentv_core.a
scripts/             build-linux.sh, build-ios-rust.sh
```

## FFI

Dart calls `extern "C"` functions with a protobuf-encoded request; Rust runs
the work on a tokio runtime and answers through one callback with an encoded
`FFIResult` (`src/c.rs`, `flutter/lib/native_bridge.dart`). Linux loads
`libbrentv_core.so`; iOS links the static library into the app binary and
uses `DynamicLibrary.process()` (strip style "non-global" keeps the symbols).

After editing `protocol/generated_proto.proto`, regenerate both sides:

```
protoc --prost_opt=flat_output_dir=true --prost_out=src -I protocol generated_proto.proto
protoc --dart_out=flutter/lib/generated -I protocol generated_proto.proto   # protoc_plugin 24.x
```

Disposal rejects new bridge calls and fails waiting callers, but keeps the
native callback alive until every issued Rust reply has arrived and been freed.

New FFI functions are added by hand to `flutter/lib/generated/bindings.dart`
in the existing style (ffigen needs libclang and regenerates the whole libc).

| Function | Request | Result |
|---|---|---|
| `save_source` | `Source` | `Source` with id, nothing imported |
| `process_source` | `Source` | `RefreshStats`; failure is an FFI error (nothing to keep) |
| `refresh_source` | `Source` | `RefreshStats`; a failed refresh is `success: false` + `error`, stored, old data kept |
| `refresh_all` | – | `RefreshStatsList` of enabled sources (one failing source doesn't stop the rest) |
| `get_source_categories` | `IdMessage` (source) | `CategoryList` |
| `fetch_source_categories` | `IdMessage` (source) | `CategoryList` after asking the provider (Xtream) |
| `set_source_categories` | `SetCategories` | – |
| `get_alternates` | `IdMessage` (channel) | `ChannelList`, best first |
| `set_alt_override`, `clear_alt_overrides` | `AltOverride`, `IdMessage` | – |
| `get_transfer_info` | `IdMessage` (channel) | Current channel/headers, stable identity, provider connection limit and episode metadata |
| `get_disk_space` | `StrMessage` (existing folder) | `IdMessage` available bytes on that filesystem |
| `download_file` | `DownloadRequest` | `DownloadStatus` when the transfer ends: finished, stopped, or a `failure` to show; an FFI error means retry later |
| `download_progress` | `StrMessage` (job id) | `DownloadStatus` of a running transfer (`active` false if none) |
| `stop_download` | `StrMessage` (job id) | — (the `download_file` call then returns `stopped`) |
| `relay_open` | `RelayRequest` | `RelayInfo`: the live stream's codecs plus the loopback port and token serving its bytes (`input.ts`) and the repackager's output folder |
| `relay_close` | `StrMessage` (token) | — (provider connection closed, files refused) |
| `get_stream_variants` | `StreamVariantsRequest` | `StreamVariantList` |

All upstream functions are unchanged apart from `Filters.page` (no longer
truncated to 255 pages; offsets in i64) and the extra fields on `Source`,
`Channel` and `Settings`.

**Adding a source** (UI): validate the form → `save_source` → optionally
`fetch_source_categories` (Xtream) and `set_source_categories` → then
`process_source`, which imports into the saved row (matched by name). Cancel
after saving deletes the source again.

**Credentials** (Xtream puts them in query strings and stream paths, M3U
links often too): reqwest errors are stripped of their URL (`without_url`)
at every HTTP call; every error that reaches a log, an FFI error message or
stored stats goes through `redact::redact` / `redact::error`, which masks
`username=`/`password=`-style query values, `/live|movie|series/<u>/<p>/`
paths, URL userinfo and the source's own username/password. Stream URLs are
never logged. Dart and player code must not log or display full stream URLs
either.

## Data model (migration 2, `src/sql.rs`)

- `sources.import_live|import_movies|import_series`: selective import.
  A disabled type is neither fetched (Xtream) nor written (M3U).
- `sources.category_mode_*` + `source_categories`: per source and media
  type, a list of category names and a mode. Exclude mode skips listed
  categories (new categories are imported); include mode imports only listed
  ones (new categories are not). Every category seen at a refresh is stored
  with its stream count, so the UI can offer categories that are currently
  not imported. Names are the key (M3U has no category ids; Xtream ids can
  change).
- `sources.last_refresh_stats`: the last `RefreshStats`, protobuf-encoded.
- `channels.episodes_loaded`: catalog refresh invalidates the lazy episode cache; refreshing episodes upserts by provider ID and preserves saved state.
- `channels.ext_key` + `channels.position`: the provider's identity for a row
  and its order in the provider's list. Exact formats: Xtream live/movie
  `"<media_type>:<stream_id>"`, Xtream series `"2:<series_id>"`, M3U
  `"<url>\t<name>"`; episodes use `episode:<series_id>:<episode_id>`. Refresh upserts with
  `ON CONFLICT (source_id, ext_key) WHERE ext_key IS NOT NULL` (the partial
  index needs the predicate) and deletes rows of refreshed types that
  disappeared, so channel ids, favorites, history and movie positions
  survive refreshes without name matching. Migration 2 backfills these keys
  for upstream rows (duplicates stay NULL); on the first refresh, NULL-key
  catalog rows that weren't adopted hand their favorite/history/position to the new
  row with the same (name, media type) and are deleted. "Provider" sort uses
  `position` (backfilled from id).
- `channels.alt_key` + `channels.quality` + `alt_overrides`: alternate feeds
  (below). Overrides are keyed by the feed's `(source_id, ext_key)`; a link
  stores the target feed's `(source_id, ext_key)`.

## Features

1. **Selective import.** Per source (`Source.import_*`), edited in the source
   dialog. Xtream skips the stream and category requests of disabled types.
2. **Category filters.** Xtream: categories are always fetched for enabled
   types (small). When the categories to import are few (≤ 20) and fewer than
   half of all, streams are fetched per category (`&category_id=`); otherwise
   everything is fetched once. Either way streams are filtered before they
   are written, so a provider that ignores `category_id` still gets filtered.
   M3U: filtered while parsing.
3. **Names-only tiles.** Artwork rendering and downloads are removed, including iOS lock-screen artwork. Former protobuf settings field 9 is reserved. Migration 5 stores category favorites; Favorites has separate, centered Channels/Movies/Series/Categories choices using the same bounded pagination, search and sort filters. Start-page settings select a main page or favorite category, opened after any startup refresh.
4. **Adaptive playback.** HLS masters are played adaptively; custom quality
   selector controls are removed. The existing variant-probe/bitrate-cap FFI
   remains compatible. External mpv feed cycling lists alternate feeds without
   bitrate variants. iOS presents Apple's full-screen AVPlayerViewController with standard
   transport, subtitle/audio, AirPlay and PiP controls. Explicit frame readiness
   validates video startup; advancing audio only validates known audio-only
   assets. Unsupported native playback shows an error without a fallback.
5. **Alternate feeds.** `alt::alt_key(name)` normalizes a live channel name:
   lowercase, separators unified, quality tags (SD/HD/FHD/UHD/4K/1080p/HEVC/
   fps…) and backup tags removed; numbers, `+1` and country prefixes stay, so
   "ESPN 2" ≠ "ESPN" and "UK: Sky News" ≠ "US: Sky News". Channels with equal
   keys (any enabled source) are alternates. Overrides (unlink, link,
   preferred) are stored by the feed's `(source_id, ext_key)` and re-applied
   after every refresh; unlink and link exclude each other; one preferred
   feed per group.
6. **Linux playback.** External mpv, one instance reused across channel
   switches (`loadfile … replace` over `--input-ipc-server`), hardware
   decoding, cache and readahead from settings, live reconnect. mpv keys send
   `script-message`s back for next/previous channel, alternate feed and
   quality. brendwl swallows mpv into the brenTV window through its
   `isterm` rule for the brenTV app_id; quitting mpv shows brenTV again.
7. **iOS playback.** Apple’s full-screen `AVPlayerViewController` exclusively,
   with standard controls and dismissal, AVKit PiP restoration, background
   audio, lock-screen controls, interruption and route-change handling.
   Method/event channels preserve movie resume state without a Flutter player
   route. Unsupported sources show a generic error. Xtream live prefers HLS;
   the iOS mpv binary dependency and native-player switch are removed.
8. **Performance.** WAL, prepared statements, batched writes, bounded idle connection pooling, indexes for the
   real query shapes; measured by `cargo run --release --example bench`
   before and after (docs/BENCHMARKS.md). Unchanged upserts skip secondary-index rewrites; ordered source indexes cover pagination without sorting the full catalog.
9. **Refresh.** One transaction per source. Cached episodes retain IDs, favorites, history and positions; catalog refresh marks them stale, and opening the series refreshes its metadata transactionally by provider identity. A media type whose fetch fails
   keeps its previous rows; the refresh fails only when every enabled type
   fails (rollback). Importers return `RefreshStats` either way (a total
   failure: `error` set, per-type `failed`); stats per media type (fetched,
   imported, excluded, categories) are returned, stored (failed attempts
   too) and shown.
10. **Settings.** All of the above in Settings and the source dialog.

## Playback dispatch

Migration 6 adds channel/category hidden flags, provider archive days, exact
EPG IDs and per-source XMLTV URLs. Catalog queries mask both directly hidden
channels and descendants of hidden categories; the management query explicitly
includes hidden items. Import upserts preserve hidden flags. No state is deleted
when hiding or restoring an item.

Migration 7 makes `favorite` an order (1, 2, …; 0 = not a favorite) for
channels and categories and reindexes `favorite > 0`. Existing stars (all 1)
keep provider order until the first move; a move renumbers the favorites and
swaps two places in one transaction.

`get_schedule` returns a bounded program list for one channel and a window
of at most seven days. Xtream uses `get_simple_data_table`, an eight-second
deadline, a 2 MiB body cap and at most 2,048 entries. Full-grid requests run
serially for visible rows and retain at most 32 rows or the visible row count,
whichever is larger. Schedule-window changes do not invalidate pending catalog
pages. `get_catchup` validates
retention and feature switches, rechecks the current provider program and
source identity, and builds the archive URL from its paired local date. An
explicitly unavailable archive or invalid date is never offered as catch-up.
The returned channel has no catalog ID and carries its playback headers, so
players skip catalog history and saved-position writes for that playback.

The optional XMLTV adapter uses a bounded gzip/XML parser, exact source/EPG IDs,
up to four expiring source-document caches and source identity checks. Document
loads are serialized and recheck the cache to coalesce concurrent misses. It
starts no service or background importer. Disabled guide/XMLTV settings block requests in Rust as
well as in the UI. `ProgrammeGuide` uses a single scheduled deadline for each
active controller, not a polling interval; pending loads, source backoff,
program boundaries and cache expiry determine the next wakeup.

The Xtream now/next adapter (`src/epg.rs`, `get_now_next`) resolves the source
from a local channel ID, checks enabled/import-live/global-guide settings, and
rechecks source/channel identity after the request. Its reusable client has a
five-second deadline, three-redirect limit and 256 KiB streamed-body cap; at most
two requests can be in flight. Errors omit URLs, credentials and response bodies.
Program timestamps are UTC Unix seconds. Invalid mixed responses fail as a
whole, leaving the UI's still-valid cached programs available for up to ten
minutes. Source edits, enable/delete actions, refresh and settings changes
invalidate guide caches. No schema migration or persistent EPG database.

`programme_guide.dart` schedules visible live channels and separately the actual
playing feed. Catalog visibility follows measured grid geometry, route coverage
and app lifecycle. A channel's text rebuilds only when its displayed program
changes. Player metadata updates do not open media or seek. Full schedules
and optional XMLTV use the separate, lazily requested adapters described above.

`Playback.play(context, channel, siblings:)` (`playback/playback.dart`):
Linux + `LinuxPlayer.mpv` → `ExternalMpv`; iOS always → `IosPlayer` (Apple’s
full-screen system player); other desktop playback → built-in `Player`.
The legacy iOS native-player preference is ignored. Desktop `siblings` is
the list the channel came from, for next/previous.

## Build and test

```
cargo test && cargo clippy
cd flutter && flutter analyze && flutter test
scripts/build-linux.sh          # Linux bundle
scripts/build-ios-rust.sh       # macOS: Rust static lib, then flutter build ipa
```


## DVR and downloads

`flutter/lib/library/` owns app-lifetime recording and download queues,
independently of player routes. Schedules and jobs are JSON in SQLite settings
through partial `Settings` protobuf patches (`src/settings.rs`); they retain
catalog IDs and opaque identities, not provider URLs or credentials. Folder,
padding, concurrency, first-use destinations and dismissed tips share the
media preferences setting. Bottom-bar order uses stable page names separately
from persisted `ViewType` IDs; Settings is normalized to the final position.
Media uses the existing downloads ID; legacy localMedia entries map to Media,
merge visibility and preserve the earliest saved position. Files and completed
downloads share one browser. A global floating indicator opens unfinished
transfers and disappears once none remain. Only completion changes trigger a
media-folder rescan; transfer progress does not repeatedly scan the filesystem.

`get_transfer_info` resolves a currently visible/import-enabled catalog item,
its playback headers and exact episode metadata, fetches bounded Xtream
`user_info.max_connections` when available (otherwise 1), and rechecks source
and channel identity after HTTP. Connection metadata is cached for five
minutes. The Dart queues resolve again when work starts; disabled, replaced
or hidden items fail safely. HTTP/process diagnostics never reach saved jobs.

Linux DVR records from the active player's existing connection when provider
slots are full and that player is showing the requested channel. Other
recordings spawn ffmpeg with stream copy to TS. Both remux to MKV on a normal
finish. Reconnecting player recordings start their continuation while the previous
segment remuxes; finishing player segments do not reserve provider capacity. It preserves partial TS files on failure. Restart marks interrupted
recordings failed and past scheduled starts missed. The download queue shares
provider slots with DVR and playback, reserves slots before awaiting work,
runs production HTTP transfers in `src/download.rs`, streams bytes to `.part`,
validates ranges and object validators (or the saved total size when validators
are unavailable), checks free space through statvfs, and renames only after the
declared size matches. Duplicate transfer IDs cannot replace running transfers;
concurrent queue additions cannot reserve the same video or destination twice.
DVR and Downloads build visible cards lazily as their libraries grow.
Playback resolves completed jobs to transient local channels before stream
selection, also during next/previous navigation. There is no background
service; mobile suspension and device behavior need platform verification.
