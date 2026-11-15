# iOS builds and installation

## CI artifacts

`.github/workflows/ios.yml` runs on tags and manual dispatch,
using macOS, Flutter 3.44.4, pinned Rust 1.99.1 and the aarch64-apple-ios target. It builds the
Rust static library with `scripts/build-ios-rust.sh`, using a Rust build cache.
Dart analysis and tests run in Linux CI. Without signing secrets it compiles the
release device app without signing. With all four secrets it builds one signed archive instead.
It checks each of `initialize`, `get_channels`, `save_source` and
`get_stream_variants`, `get_now_next`, `get_schedule`, `get_catchup`, `set_hidden`
`restore_all_hidden`, the download functions, `relay_open` and `relay_close`
in the final Runner binary with `nm -gU`; a missing symbol
fails the job. `brentv-unsigned` contains `brentv-unsigned.ipa`, a ZIP with
`Payload/Runner.app`. It must be signed before installation.

The converter makes iOS 14 the minimum target. Picture-in-Picture depends on device support and
stream readiness. The app’s Picture-in-Picture switch enables or disables it;
automatic full-screen PiP also follows the iPhone’s system PiP setting. The static Rust
library is force-loaded, `-export_dynamic` preserves globals through link-time
optimization, global symbols survive stripping (`non-global`), and
Security, CoreFoundation and SystemConfiguration are linked. Swift imports
AVFoundation, AVKit and MediaPlayer. CI is the authoritative compile/link check.

The Xtream guide updates the player's program title and lock-screen title
without reopening the item. It preserves playback time, rate and remote-command
state. Disable it with Settings → Live program guide. Physical lock-screen
and background behavior still require device verification.

The shared Flutter UI also provides hiding/restoring, the full schedule grid,
provider-supported catch-up and optional XMLTV. Guide controls have independent
switches in Settings; XMLTV defaults off. Catch-up keeps its own playback
position in memory and preserves the original live channel's saved state.
iOS uses Apple’s system player for every stream and local video; there is no
alternate player. Live streams it cannot show as provided are repackaged on
the phone first (see Live repackaging).

## Current iPhone behavior

The app follows device orientation. Playback presents Apple's full-screen
`AVPlayerViewController` with its standard dismissal, play/pause, seeking,
audio/subtitle, AirPlay and Picture-in-Picture controls. There is no custom
Flutter player screen or channel toolbar. AVKit owns PiP transitions; background audio,
lock-screen commands, interruption recovery and headphone removal stay native.
There is no custom quality selector: the player adapts the HLS master.

Native video startup requires a rendered frame. Advancing playback counts as
success without video only when the loaded asset reports no video tracks.
Otherwise a bounded startup timeout shows a generic native playback error. Actual codec compatibility and background/PiP behavior must
be checked on the device; neither Linux tests nor compilation prove them.

Media combines the previous Local media and Downloads destinations. It browses
`Documents` on iOS, exposed by Files as **On My iPhone → brenTV**, with Movies
and Series subfolders. These folders and saved download paths are resolved
against the current container on every launch, including after an update. Internal `/var/mobile/...` paths remain required by iOS
sandboxing; those paths are not shown as folder settings. A bottom-right
indicator opens unfinished-download details and disappears after completion.
Media refreshes the current folder when a download finishes.

Search supports drag/tap-away dismissal and an explicit Hide keyboard button.
The History list options include confirmed Clear history, preserving favorites
and saved positions. Catalog and guide lists use primary scroll controllers for
iOS status-bar scroll-to-top. Bottom destinations do not animate replacement
routes; tapping the current destination does not reload it. Favorites choices
wrap and center on narrow displays. Desktop shortcut/mpv settings are hidden.

## Optional signing in GitHub Actions

Create repository Actions secrets (Settings → Secrets and variables → Actions):

| Secret | Value |
| --- | --- |
| `IOS_P12_BASE64` | Base64 of an exported Apple signing certificate **and private key** (`.p12`) |
| `IOS_P12_PASSWORD` | Nonempty password protecting that P12 |
| `IOS_PROFILE_BASE64` | Base64 of the matching `.mobileprovision` |
| `IOS_TEAM_ID` | Apple developer team ID |

The profile must cover `xyz.brendynmarroquin.brentv`, the certificate, and the
installation device UDIDs. Choose `development` for an Apple Development
certificate/development profile or `ad-hoc` for an Apple Distribution
certificate/ad hoc profile. Manual dispatch accepts this choice; tag builds
default to development. Export your P12 using Keychain Access on a Mac, and
obtain profiles from Xcode or Apple's developer portal. Encode locally (for
example `base64 -w0 certificate.p12` on Linux) and paste into GitHub's secret
form; keep signing material out of git and logs.

When all four secrets exist, CI imports them into a temporary keychain,
configures manual archive signing, generates ExportOptions.plist and runs
`flutter build ipa --export-options-plist=...`. `brentv-signed` contains
`brentv-signed.ipa`. The cleanup step runs even on failure and removes the
keychain and profile. Partial secrets skip signing. Provisioning/signing
failures fail the job. Signing secrets are scoped to the signing setup step;
the signed archive Runner receives the same FFI symbol check.

## Sideloading from Artix Linux

Connect and unlock the iPhone, accept “Trust This Computer”, and enable
Developer Mode on iOS 16+ when requested. Keep the bundle identifier stable
when refreshing an installation to preserve its data.

Package availability checked with `pacman -Si` on 2026-11-10: `libimobiledevice`
and `usbmuxd` exist in world; `ideviceinstaller` and `usbmuxd-runit` were not
found in this machine's configured sync databases. Check your own repositories:

```sh
pacman -Si libimobiledevice usbmuxd ideviceinstaller
doas pacman -S libimobiledevice usbmuxd
idevice_id -l
idevicepair pair
```

usbmuxd must run. It is commonly launched by the package's udev rules on USB
connection. Check `pgrep -a usbmuxd` before starting another instance. For
manual troubleshooting, run `doas usbmuxd -f -v` in a terminal and reconnect.
If persistent supervision is needed on runit, use an available distro service
package, or create `/etc/runit/sv/usbmuxd/run` containing:

```sh
#!/bin/sh
exec 2>&1
exec /usr/bin/usbmuxd -f -U usbmux
```

Make it executable, link `/etc/runit/sv/usbmuxd` into `/run/runit/service/`, and
use `doas sv up usbmuxd`. Check that the package-created `usbmux` user exists.
Avoid running both a supervised instance and a udev-started instance. See
[upstream usbmuxd](https://github.com/libimobiledevice/usbmuxd) for daemon flags
and [Artix runit](https://wiki.artixlinux.org/Main/Runit) for service management.

Choose one installation route:

1. **Free Apple account:** [Dadoum Sideloader](https://github.com/Dadoum/Sideloader)
   supports Linux and can sign/install the unsigned IPA with your own Apple
   account. Use its upstream release and instructions; authentication and
   two-factor prompts belong in the sideloader, never in project files.
2. **SideStore / iloader:** use the official [iloader repository](https://github.com/nab138/iloader)
   or [iloader.app](https://iloader.app/) to obtain a Linux release. Install
   usbmuxd, connect and trust the device, then follow the official
   [SideStore prerequisites](https://docs.sidestore.io/docs/installation/prerequisites)
   and [installation instructions](https://docs.sidestore.io/docs/installation/install).
   iloader supports installing SideStore and importing its pairing file. Follow
   SideStore's current VPN setup too; pairing alone does not sign an IPA.
   Protect pairing files as device access material. The older
   [AltServer-Linux](https://github.com/NyaMisty/AltServer-Linux) is unmaintained
   (latest release v0.0.5 from 2022); prefer the current SideStore instructions.
3. **Your own certificate/profile:** use [zsign](https://github.com/zhlynn/zsign)
   to sign the unsigned IPA locally, then install it with
   [ideviceinstaller](https://github.com/libimobiledevice/ideviceinstaller).
   Build/install ideviceinstaller from upstream if absent from your repos.
   A CI-signed IPA can go directly to installation if its profile covers the
   connected device. zsign does not obtain certificates or register devices.

```sh
# Read the password without placing it in shell history (bash).
read -r -s -p "P12 password: " signing_password
zsign -k certificate.p12 -p "$signing_password" -m profile.mobileprovision \
  -o brentv-signed.ipa brentv-unsigned.ipa
unset signing_password
# Current ideviceinstaller uses subcommands; older releases use -i.
ideviceinstaller install brentv-signed.ipa
# For an older release only: ideviceinstaller -i brentv-signed.ipa
```

Check your installed `zsign --help` and `ideviceinstaller --help`. The zsign
password argument is briefly visible to local process inspection; use a trusted
local machine and avoid shell tracing and shared logs. Never commit
certificates, private keys or profiles.

Apple's [Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account)
are seven-day provisioning, three installed apps per device, ten App IDs and
three registered test devices (IDs/devices also expire after seven days).
A sideloading companion itself uses an app slot; extensions can consume extra
App IDs. Refresh before expiration. A paid Developer Program membership permits
development/ad hoc provisioning and longer validity (commonly up to a year,
subject to the actual certificate/profile expiration); ad hoc devices must be
registered. Neither account type bypasses the profile's device or expiry rules.

## Playback and integration

The method channel is `brentv/ios_player`, and the event channel is
`brentv/ios_player/events`. There is no Flutter platform view.
`open` accepts URL, allowed HTTP headers, title, startSeconds, isLive,
backgroundAudio, autoPip, maxBitrate, width and height.
Variant URLs remain the HLS master with bitrate/resolution caps; Auto and
alternates clear both caps. No stream URL or native error text is logged.
Failures before a rendered video frame or verified audio-only progress (including a 20-second timeout)
show a generic error with a Close action in the native player.

`IosNativePlayer` in `lib/playback/ios/native_player.dart` owns the native
method/event channels. Native lock-screen commands operate AVPlayer directly;
Dart receives position and dismissal updates to preserve movie resume state.
AVKit owns presentation, dismissal and PiP restoration. Only Apple’s player
owns iOS playback. The iOS mpv binary dependency is removed; desktop players
remain available on Linux.

`UIBackgroundModes = audio` and a playback/moviePlayback audio session support
background audio. PiP uses the same background mode; neither needs an
additional signing entitlement. See Apple's [PiP setup](https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-in-a-standard-player).
HTTP media is permitted through the media-specific ATS exception, without
relaxing ordinary URLSession networking. The player makes no artwork requests.

## Verification still needed on Apple hardware

This implementation was developed on Linux without Xcode or a device. Swift
compilation, static Rust linking, signed export and installation have **not**
been exercised locally. The workflow must pass on macOS before release. Test
on a physical device: local HLS and MP4, invalid/unsupported input errors,
resume/save, variant caps and reset, authenticated header delivery, PiP entry,
automatic PiP, restore UI, background audio on/off, headphone removal,
interruption/resume and lock-screen controls without artwork. Test both iOS 14
manual PiP and newer automatic PiP where hardware is available. No sideloading
route or account signing flow has been tested here.

## Native player limits and device checks

Native playback uses Apple's documented `AVURLAssetHTTPUserAgentKey` on iOS
16 and later. A source requiring Referer/Origin headers, or a custom user
agent on older iOS, receives an unsupported-source error. No other player
is opened.
No undocumented HTTP-header initialization option is used.

Nothing is drawn as focused on iPhone (`showsFocus` in `theme.dart`): tiles
and rows only flash when tapped.

Lock-screen play, pause, toggle, seek and skip run directly in Swift, even
when Flutter is suspended. Return to the channel list to choose another channel.
Audio-only HLS counts advancing audio as successful playback. On a device,
verify foreground playback, lock/unlock, pause then resume from the lock
screen, interruption begin/end, headphone removal, PiP enter/exit, and closing
the player during an interruption. Linux tests cover channel messages and
arguments only; they cannot establish these native behaviors.

Lock-screen metadata contains the title and playback state; artwork is omitted.
The media-only ATS exception permits HTTP streams.

## Live repackaging

Apple’s player shows H.264 with AAC, AC-3 or E-AC-3 from a provider’s HLS.
Tests against a real Xtream source on 2026-11-15 found three kinds of live
channel that Apple could not play as provided: HEVC in MPEG-TS (audio only,
because Apple requires fragmented MP4 for HEVC), MP2 audio, and channels whose
HLS address fails while the plain transport stream works.

Before a live channel opens, the Rust core (`src/relay.rs`) connects to its
`.ts` address and reads the codecs from the program map. H.264 with a
supported audio codec opens in Apple’s player as before, from the provider’s
HLS. Anything else goes through the repackager: the core serves the
provider’s bytes on a loopback address, the bundled FFmpeg (which has no TLS
of its own) turns them into fragmented-MP4 HLS in a temporary folder, and
Apple’s player opens that playlist from the same loopback server. HEVC and
H.264 are copied, other video is encoded as H.264 with VideoToolbox, AAC,
AC-3 and E-AC-3 audio are copied and other audio becomes AAC. One provider
connection is used, the one that was probed.

If Apple’s player rejects a stream that was opened directly, the channel
reopens through the repackager without an error in between, and that channel
goes straight to the repackager from then on. Settings → Playback → Convert
every live channel sends all live channels through it. The temporary folder
holds about twenty segments and is removed when the player closes; leftovers
are cleared at launch. Repackaging runs for as long as the player is open,
including in the background and Picture in Picture.

Movies and episodes get the same treatment. A file in a container Apple
cannot open (MKV, AVI and so on) is converted as it plays: FFmpeg reads it
through the relay, which passes range requests to the provider so it can seek
in the file, and writes a growing HLS playlist. H.264/HEVC video and
AAC/AC-3/E-AC-3 audio are copied, so conversion runs far ahead of playback
(a two-hour film took about a minute in testing) and the player
can seek anywhere already converted. The first text subtitle, English if
there is one, becomes a WebVTT track that is off until chosen. Resuming
starts the conversion at the saved position; the resumed stream cannot rewind
before that point. A film saved within 30 seconds of its end starts over.
The converted film stays in temporary storage while it
plays, so the phone needs about the file's size free, and is removed when the
player closes. An MP4 that Apple's player rejects falls back to the same
conversion. Download remains the way to keep a film.

`scripts/apple-hls/run.sh` (workflow **Apple HLS check**) plays the three
repackaged live forms and a converted MKV movie in AVPlayer on macOS and
requires decoded video from each. It also checks that the growing movie
playlist starts at the beginning and reports what AVPlayer does with HEVC
in MPEG-TS. The loopback relay,
the FFmpeg arguments and the player flow are tested on Linux, including
against a real Xtream source. Behavior on a physical iPhone still needs checking.

## MP4 downloads and existing files

New iPhone movie/episode downloads finish as MP4. The provider’s bytes are
first saved and verified using the existing resumable transfer. Compatible
MP4 is published unchanged. Other containers are remuxed, preserving supported
H.264/HEVC video; incompatible audio becomes AAC and supported text subtitles
become MP4 text tracks. Incompatible video is encoded as H.264 using VideoToolbox.
Bitmap subtitles and attachments cannot be carried into this MP4 output.

The floating transfer indicator stays visible during **Preparing MP4**. Keep
brenTV open; conversion can be paused/resumed, and a completed download can be
retried without another provider request. A file is published only after
codec/duration validation; an existing destination is never overwritten.
Failed or paused work retains the source bytes. Canceling a fully downloaded source requires confirmation before deletion; canceling conversion of an existing file retains its catalog link and original. Open an existing MKV/other
unsupported video in Media to prepare its MP4. Once the MP4 is verified and
saved it replaces the original, which is deleted; originals left beside a
finished MP4 by earlier versions are removed at the next launch.

Conversion uses only local files via the minimal LGPL FFmpegKit 8.1.2 libraries
from [the maintained fork](https://github.com/sk3llo/ffmpeg_kit_flutter/releases/tag/8.1.2-min).
`ios/FFmpegKit.podspec` pins the release archive SHA256; upstream LICENSE files
ship inside the frameworks. About → View licenses also includes the component
notice and complete GPL/LGPL texts from assets. No second playback engine is registered.
The native library bridge and hardware encoder require macOS CI/device testing;
Linux tests exercise the same conversion arguments with system FFmpeg and a
software H.264 encoder for the incompatible-video path.

Diagnostics on 2026-11-15 found movies and episodes in MKV with H.264 plus
E-AC-3/AC-3 and others in MP4/H.264/AAC; asking for an MKV title as MP4
returned an HTTP error. An audio-only live feed used HEVC/AAC in MPEG-TS,
including its HLS endpoint. Apple requires fMP4 for
HEVC HLS; the live repackager above now provides it.

Converter recovery keeps an original catalog download available while its MP4
copy is queued, paused or failed. Legacy queued MKV jobs keep their original
partial-file path and publish to a new MP4 destination. A durable private
publication receipt identifies the exact output inode so a crash after publish
can recover safely without claiming an unrelated existing file. Conversion
stopped by iOS background expiration pauses for foreground retry; it never
selects lossy transcoding just because the background task was canceled.
Probe output is quiet and parsed safely when native diagnostics are merged.
Unknown-duration output reaching the size cap is rejected. Conversion and
network transfer still share the configured concurrency limit in this beta.
