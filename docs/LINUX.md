# Linux

brenTV targets x86_64 Artix on Wayland. It needs GTK 3 and mpv at runtime
(libmpv is also used by the built-in player). The local file chooser uses
xdg-desktop-portal with its GTK backend. It starts no system services;
runit needs no configuration.

## Build

Install the Artix build dependencies:

```sh
doas pacman -S rustup clang cmake ninja lld pkgconf gtk3 mpv
rustup default stable
```

Install Flutter **3.44.4** from its Linux SDK archive and put `flutter/bin`
on PATH. Rust is pinned to **1.99.1** in `rust-toolchain.toml` and uses edition 2024. The development
machine uses clang/lld 23 and mpv 0.41; CMake and Ninja build the GTK runner.
Protobuf regeneration is not needed for a normal build; see ARCHITECTURE.md
if changing the protocol (protoc, protoc-gen-prost, protoc_plugin 24).

From the repository root:

```sh
cd flutter
flutter pub get --enforce-lockfile
flutter analyze
flutter test
cd ..
cargo fmt --check
cargo clippy --locked --all-targets -- -D warnings
cargo test --locked
scripts/package-linux.sh
```

The script calls `scripts/build-linux.sh` (release Rust core, then Flutter
Linux release). Output: `dist/brentv-1.0.0-linux-x86_64.tar.gz`, using the
version in `flutter/pubspec.yaml`. The bundle is also available at
`flutter/build/linux/x64/release/bundle/`. For an offline build, first cache
Cargo and pub dependencies; `flutter pub get --offline` resolves cached pub
packages and `CARGO_NET_OFFLINE=true scripts/package-linux.sh` builds offline.

## Native regression tests

Plain `flutter test` skips tests that need the Rust library and real players.
After building the release bundle, run the complete Linux suite (including
ffmpeg recordings) from the repository root:

```sh
runtime_dir=$(mktemp -d)
(cd flutter && XDG_RUNTIME_DIR="$runtime_dir" BRENTV_NATIVE_TESTS=1 \
  BRENTV_RECORDING_TESTS=1 \
  LD_LIBRARY_PATH="$PWD/build/linux/x64/release/bundle/lib" \
  flutter test --no-pub --concurrency=1)
rm -rf "$runtime_dir"
```

These tests use temporary databases and loopback streams. They need `mpv`,
`ffmpeg`, and `sqlite3` on PATH and do not use your provider or live database.
Linux CI runs this same suite after packaging.

## Install

```sh
tar xf dist/brentv-1.0.0-linux-x86_64.tar.gz
cd brentv-1.0.0-linux-x86_64
./install.sh
```

The default prefix is `~/.local`: the bundle goes into `lib/brentv`, a
`bin/brentv` symlink launches it, and the desktop entry and SVG icon go into
`share/applications` and `share/icons/hicolor/scalable/apps`. Put
`~/.local/bin` on PATH. Quit brenTV before updating an installed bundle.
For a system installation, use `doas env PREFIX=/usr/local ./install.sh`.
Uninstall using `./install.sh --uninstall` with the same PREFIX if set.
The installer requires an absolute PREFIX.

## Catalog controls and optional features

Outside text fields, `/` focuses search, `1`–`8` select pages in the visible bottom-bar order, and Home/End move to the top or bottom of the
currently loaded items. Infinite scrolling continues to load more. These
shortcuts can be disabled. Search has no fixed wait by default; Settings →
Search update delay offers optional delays for reducing queries while typing.

Favorites has separate Channels, Movies, Series, and Categories tabs.
Favorited episodes appear under Series. Star a category from the
Categories page to add it to Favorites → Categories. Search, sorting and
infinite scrolling apply to the selected tab. Opening a favorite category
shows its channels; removing its star removes it from the favorites tab.
New favorites go last. With the default provider sort, the tile menu's Move
earlier/later (also Ctrl+↑/↓, or Ctrl+←/→) changes their order; F1–F9 in mpv
follow the Favorites → Channels order.

`?` (or Settings → Keyboard shortcut list) shows every shortcut. Settings → UI
scale zooms the whole app from 75% to 200%, but never lays it out narrower
than 280 px; Ctrl+= and Ctrl+- step it and Ctrl+0 resets it, also inside text
fields. The app uses dwl's colors: #222222 surfaces, #444444 3 px borders, and
#005577 for focus and selection (snackbars match mako).

Media (the bottom-bar destination, or L) browses
`~/Videos` one folder at a time and plays files in the selected player.
Folders and links you placed there are followed; hidden dot entries are
skipped. Nothing is indexed or written to the catalog, and local files never
enter History or saved positions. PgUp/PgDn move between the files of the
open folder; in external mpv, Backspace returns to the previous file.

Settings groups its options into collapsible sections (Appearance and
navigation, Playback, Program guide, Keyboard and search, Library visibility,
Sources, About). Hover labels are turned off everywhere; screen readers still
get the labels.

The tile menu offers Hide (also H) and Program guide (also G on live channels).
Settings → Hidden channels and categories restores individual items or all
items. A hidden category masks its channels; restore the category to show them.
Hiding retains favorites, history and saved positions through refreshes.

The full guide shows six-hour windows and loads schedules only for visible
rows. Previous/next controls browse up to seven days either side of today;
Now returns to the current window. Program times are displayed locally.
Completed programs show Play catch-up only when the provider reports archive
support, retention and an eligible program. The request is revalidated before
playback. The provider's matching wall-clock date determines the archive URL,
so the device timezone cannot shift the requested program. Catch-up is
transient playback and does not overwrite the live channel's saved state.

Live program guide is the master switch. Separate switches control text on
tiles, player titles, the full grid, catch-up and optional XMLTV. An inactive or
covered catalog schedules no guide requests. A fresh visible cache sleeps until
the next request or program boundary, without a periodic polling timer.
Automatic quality discovery can also be disabled; manual feed selection can
request discovery explicitly.

MPV channel number entry is an independent opt-in switch and applies on the
next player launch. With it enabled, type digits then Enter to select a live
channel by its one-based position in enabled, visible provider order. These are
list positions, not invented provider channel numbers. Backspace edits the
pending number; Escape cancels it. With no pending number, Backspace retains
its last-channel action. Number entry overrides mpv's usual digit/Enter/Escape
bindings while enabled; default mpv digit keys are preserved when it is off.

XMLTV is off by default. For M3U sources, set an XMLTV URL in Edit source or use
the playlist's `url-tvg`/`x-tvg-url` header, then enable XMLTV in Settings.
Matching uses the exact `tvg-id`, never guessed names. HTTP, HTTPS and local
file URLs are supported. XML/gzip wire and decoded data are each limited to
16 MiB per document, with at most 50,000 entries. Up to four source documents
are cached for 15 minutes; the least recently used source is evicted at the cap.
Concurrent document loads are serialized and cache hits are reused; waiting
for a load and fetching each have an eight-second deadline. DTDs are never
loaded, internal subsets are rejected, and missing timestamp offsets mean UTC.
Only the first program title is used. Turning XMLTV or the master guide off
clears those native caches. The adapter stays inactive while XMLTV is disabled.
The DVR scheduler runs only while brenTV is open; it starts no system service.

## External mpv

Settings → Live program guide enables now/next text for eligible Xtream
live channels. Catalog requests are limited to visible tiles; covered routes
and an inactive catalog stop scheduling. The in-memory cache holds 128 channels,
requests run one at a time at no more than two starts per second, and failures
back off for 30 seconds per source. A channel is asked again when its
program changes (at least 1 and at most 9 minutes apart), every 5 minutes
when it has no listings, and every 10 minutes when its source has no guide.
Current/future timestamps decide what is
displayed; unavailable programs add no placeholder. Hover the text for now
and next times. Artwork is never fetched; optional XMLTV matches exact IDs. Turning the setting
off stops new guide HTTP requests, including from an already-open player.

During playback, the actual selected feed's current program updates the
media title without loading the stream again. The player continues its guide
updates while it is playing, independently of the hidden catalog.

Choose external mpv in Settings. The executable defaults to `mpv`; a custom
path is supported. Reuse window keeps mpv idle between streams and uses IPC
`loadfile replace` for fast switches. With reuse disabled, each channel
launches its own mpv, which exits when playback ends. Quit with mpv's usual
`q` key or close its window; the next play starts a fresh process.

Hardware decoding defaults to `auto-safe`. An empty hwdec setting leaves
mpv.conf in charge. Cache seconds sets both cache and demuxer readahead;
maximum demuxer MB bounds the demuxer buffer. Low latency applies mpv's
`low-latency` profile to live channels. Extra arguments accept whitespace,
single/double quotes and backslash escapes; they are arguments, never shell
commands. brenTV retains mpv.conf and mpv's default keys. Its managed IPC,
input, cache and window options take precedence over extra arguments.
Settings affecting process options take effect at the next channel launch.

Stream headers and the media title are reset before every load. Variants
play the HLS master with a bitrate cap; Auto and alternates remove the cap.
Movies resume at their saved seconds and save progress on switch/end/quit.
Live errors retry three times with 1, 2 and 4 second backoff, then advance
through available alternate feeds. No provider URLs are written to logs or
OSD; mpv's terminal output is discarded. Startup failures offer the built-in
player.

| Key | Action |
| --- | --- |
| PGUP / CHANNEL_UP | Next playable sibling channel |
| PGDWN / CHANNEL_DOWN | Previous playable sibling channel |
| a / A | Next / previous feed (Auto, HLS variants, alternate feeds) |
| i | Feed label, resolution, frame rate, bitrate; now and next program when the guide is on |
| Backspace | Toggle the current and previous logical channel |
| F1–F9 | Play the first nine enabled live favorites in Favorites order |

Groups, series and seasons are skipped by channel navigation. The channel
list used is the list playback was opened from. Feed changes and channel
changes show an OSD note; channel changes update last watched.
Last-channel toggling restores that channel's navigation list, including when
its preferred alternate is playing. Favorite shortcuts use the live-favorites
list for PGUP/PGDWN. Missing favorites and selecting the current favorite leave
playback running. Favorites are read when the key is pressed. The built-in
player also uses PgUp for the next channel.
Reconnects check mpv's playlist-entry ID when available, so a delayed EOF from
the old file cannot reconnect a different, healthy file.

## dwl swallowing

In `~/Projects/brendwl/config.h`, in `rules[]`, use:

```c
/* app_id  title  tags  isfloat  isterm  noswallow  monitor  width%  height% */
{ "brentv", NULL, 0, 0, 1, 0, -1, 0, 0 },
```

The GTK app_id is `xyz.brendynmarroquin.brentv`; brendwl uses `strstr`, so
`brentv` matches. This rule is already present on the development machine.
No compositor code change is needed. Verified against `applyrules()` and
`termforwin()` in brendwl's `dwl.c`: automatic swallowing must be enabled,
mpv must be a mapped, nonfloating window with `noswallow=0`, and its PID
ancestry must include the mapped brenTV window marked `isterm`. brenTV
launches mpv directly with `Process.start`, without a shell or detached
launcher. Do not mark mpv `isterm` or force it floating in a later rule.
Closing mpv restores the parent; reusing it preserves the swallowed window.
Rebuild/restart dwl after changing its rules.

## Troubleshooting

- For a decoder problem, try `hwdec=no` or empty hwdec to use mpv.conf. Test
  a local video directly in mpv before changing brenTV cache settings.
- Run in a Wayland session with a valid `WAYLAND_DISPLAY` and
  `XDG_RUNTIME_DIR`. If mpv chooses an unsuitable backend, add
  `--gpu-context=wayland` to extra arguments. No X11 backend is required.
- IPC uses `$XDG_RUNTIME_DIR/brentv/mpv-*/ipc`, with private directories
  (0700). If unavailable, it uses a private `brentv-*` temp directory.
  Normal process exit removes the instance directory. After a crash, stale
  directories can be removed once no brenTV/mpv instance is using them.
- A missing executable, IPC failure or rejected arguments offers the
  built-in player. Check the configured executable with `mpv --version`.
- The tested mpv version is 0.41. Resume resets the `start` property before
  the version-independent `loadfile … replace` command. Tests use lavfi locally, with null
  audio/video output and no provider access.

## Verified on the development machine

On 2026-11-10 the release ran in an isolated Wayland/dwl session using
synthetic local media and disposable application data. The native portal
chooser selected an M3U file; setup saved Movies-only import and an include
rule before importing. The source imported one movie and displayed its
statistics. External playback reported `gpu-next`, `waylandvk`, and `vaapi`
over IPC. Only mpv was visible while the parent was swallowed; closing mpv
restored brenTV. A favorite, history and a 33-second resume position survived
refresh, and the thumbnail-off setting persisted. The compositor was built
with the new rule for this isolated test; the live desktop still needs that
binary installed and a normal session restart.

The native-enabled tests also exercise process reuse/restart, HTTP header
reset, reconnect limits, resume/history, real HLS low/high/Auto selection and
separate audio, plus media_kit property handling. Fixtures use no provider
credentials or public IPTV endpoints. These checks do not establish behavior
against every provider or codec.


## DVR and offline video

Settings → Appearance and navigation → Bottom bar reorders or hides pages;
Settings stays last and at least one content page stays visible. Local media
is Linux-only. DVR and Downloads are separate pages, hidden until first use.
A hidden start page falls back to the first visible page. TV home follows the
same order. On compact windows the bar scrolls horizontally.

DVR needs ffmpeg (`pacman -S ffmpeg`). Use Record in the built-in player, R on
a focused live channel, Record now in a channel menu, or Record this program
in the guide. External mpv also has a red Record control (right-click it for
its hint). Its Record control or R records until the current program ends, or
one hour without EPG, and R stops the recording. The shell and mpv show a
recording indicator and elapsed time.
Quit brenTV normally to finish active recordings before the app exits.

A recording normally runs in ffmpeg on its own provider connection and
continues when the player changes channel or closes; ffmpeg reconnects if
the stream drops. When no connection is free and the player is showing the
channel, the player saves its own stream instead (mpv `stream-record`): that
recording ends when the player changes channel or closes, and continues in
a new file after a reconnect. With low-latency playback the stream reopens
once when such a recording starts. A scheduled recording of another channel
closes the player to take the connection and says so. Starting playback while
a recording holds the last connection asks which one to stop.

Some providers report more connections than they allow: a second stream cuts
the first. Settings → Downloads → Provider streams at once overrides the
reported number; set it to 1 if recordings, downloads and playback interrupt
each other.

Recordings default to `~/Videos/DVR/`, initially as TS and then remuxed to MKV.
Settings → Recordings changes the folder and padding (2 minutes before,
5 minutes after). Keep brenTV open for scheduled starts. After a restart,
missed starts and interrupted recordings are labeled; retained partial TS
files can be played from Local media.

Movies and episodes have a Download button; a series' season tile offers
Download season. Downloads saves movies in `~/Videos/Movies/` and episodes
in `~/Videos/Series/<Show>/Season NN/`. Settings → Downloads changes both
folders and concurrency (default 1). Existing jobs keep their destination.
Provider connection limits include playback, DVR and downloads. Playback and
DVR pause downloads when they need the connection; queued work resumes later.

Downloads retains partial `.part` files, validators and queue state across
restarts, resumes with HTTP Range/If-Range, checks free space and verifies the
final byte count before renaming. A server that sends neither ETag nor
Last-Modified is resumed by its reported total size. The transfer runs in the
Rust core (dart:io was several times slower). Completed videos play locally from their
catalog tiles. Downloads requires a direct HTTP video file and a declared
size; HLS playlists and webpages produce a clear explanation. iOS uses the
app's document folders; recording remains hidden there. Settings → Reset tips
shows the introductory recording/download tips again.
