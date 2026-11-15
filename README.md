# brenTV

IPTV player for Linux (Wayland) and iOS: M3U files, M3U links and Xtream
Codes accounts, with live TV, movies and series.

brenTV is a fork of [Fred TV Mobile](https://github.com/Fredolx/fred-tv-mobile)
by Frédéric Lachapelle (Fredolx), under the same license (AGPL-3.0). It
branched from upstream commit `6ed07a9` (2026-07-18), one commit after v2.0.2.

## What it adds to Fred TV

- Per source: import only live TV, movies and/or series; disabled types are not downloaded.
- Per source and media type: include or exclude categories (Xtream fetches only what's needed when it can).
- Names-only channel and category tiles, with no artwork requests or decoding. The grid fills the window and loads more as you scroll.
- Favorite channels and categories with the tile menu, right-click, F or long-press; Favorites has separate Channels, Movies, Series, and Categories tabs, in your own order (tile menu or Ctrl+↑/↓); F1–F9 in mpv follow it. `/` jumps to the search box. Settings → Start page opens a main page or a starred category.
- Live program guide: compact now/next text for Xtream channels, plus program titles in the player. Settings can disable all guide requests.
- Full program grid with six-hour windows, visible-row loading, and catch-up buttons only for eligible archived programs. Provider wall-clock dates are used for catch-up URLs.
- Hide individual channels or whole categories with the tile menu or H; restore them in Settings without deleting favorites, history or positions.
- Optional XMLTV for M3U sources: exact `tvg-id` matching, bounded XML/gzip loading, disabled by default.
- Dark theme in dwl's colors (#222222, #444444, #005577).
- UI scale (Settings, or Ctrl+= / Ctrl+- / Ctrl+0) zooms the whole app. `?` or Settings → Keyboard shortcut list shows every key.
- Media: browse and play local files from `~/Videos` on Linux or Files → On My iPhone → brenTV on iOS. Download progress opens from a small floating indicator.
- Linux DVR: record the current channel or schedule a program from the guide; recordings are saved locally. Keep the app open for schedules.
- Download movies and episodes for offline playback, with pause/resume, season queues, and shared provider connection limits.
- Reorder and show or hide bottom-bar destinations in Settings → Appearance.
- Settings in collapsible sections; no hover labels.
- Search updates immediately by default; an optional typing delay and separate guide, player-title, XMLTV, quality-discovery and shortcut switches are in Settings.
- Adaptive HLS playback with automatic quality; Apple’s standard playback controls on iOS.
- Alternate feeds (FHD/HD/SD/backup) grouped automatically, switchable instantly, with manual overrides.
- Linux: external mpv over IPC (hardware decoding, buffering settings, one reused window for fast switching, keys for next/previous channel and feeds), swallowed by dwl.
- iOS: native player with Picture-in-Picture, background audio and lock-screen controls. Live channels Apple can't play as provided are repackaged on the phone, MKV movies stream while they convert, and downloads finish as MP4.
- Faster, incremental and transactional refresh that keeps favorites, history and positions and reports what it imported.

## Install

The [releases page](https://github.com/Magneedo/brenTV/releases) has a Linux
x86_64 archive and an unsigned iPhone IPA that you sign with your own Apple
account.

- Linux: [docs/LINUX.md](docs/LINUX.md)
- iOS: [docs/IOS.md](docs/IOS.md)

## Develop

[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) explains the layout, the Rust↔Dart
contract and the design of each feature. Benchmarks: [docs/BENCHMARKS.md](docs/BENCHMARKS.md).

Upstream's Android, Windows, macOS, web and Flatpak files were removed here;
account for those platform differences when porting upstream fixes.

## License

AGPL-3.0, see [LICENSE](LICENSE).
