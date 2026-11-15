#!/bin/sh
# Checks, in Apple's own player, the HLS that brenTV's iPhone live repackager
# writes (flutter/lib/playback/ios/live_relay.dart; keep the arguments below
# the same as LivePlan.arguments). Needs macOS with ffmpeg and swift.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
pids=""
trap 'kill $pids 2>/dev/null || true; rm -rf "$work"' EXIT
cd "$work"
mkdir provider hevc old silent movie

make_source() { # name, codec arguments...
  name=$1; shift
  ffmpeg -hide_banner -loglevel error -f lavfi -i testsrc2=size=640x360:rate=25 \
    -f lavfi -i sine=frequency=440 -t 20 "$@" -g 50 -f mpegts "$name.ts"
}
make_source hevc -c:v libx265 -preset ultrafast -x265-params log-level=error -c:a aac
make_source old -c:v mpeg2video -b:v 3M -c:a mp2
make_source silent -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a mp2

live() { # input, output arguments... (a provider sending in real time)
  input=$1; shift
  ffmpeg -hide_banner -loglevel error -nostdin -re -stream_loop -1 \
    -fflags +genpts+discardcorrupt -i "$input" "$@" &
  pids="$pids $!"
}
hls="-f hls -hls_time 2 -hls_list_size 20 -hls_delete_threshold 10 \
  -hls_flags delete_segments+independent_segments+temp_file \
  -hls_segment_type fmp4 -hls_fmp4_init_filename init.mp4"

# What the provider sends for an "audio only" channel: HEVC in MPEG-TS HLS.
live hevc.ts -c copy -f hls -hls_time 2 -hls_list_size 20 \
  -hls_flags delete_segments provider/live.m3u8
# The repackager's three cases: copy HEVC, encode MPEG-2, replace MP2 audio.
live hevc.ts -map 0:v:0 -map '0:a:0?' -sn -dn -c:v copy -tag:v hvc1 \
  -c:a copy -bsf:a aac_adtstoasc $hls -hls_segment_filename hevc/seg%05d.m4s hevc/live.m3u8
live old.ts -map 0:v:0 -map '0:a:0?' -sn -dn -c:v h264_videotoolbox -b:v 5M \
  -pix_fmt yuv420p -vf 'yadif=0:-1:1,scale=trunc(iw/2)*2:trunc(ih/2)*2' \
  -force_key_frames 'expr:gte(t,n_forced*2)' -realtime 1 -allow_sw 1 \
  -c:a aac -b:a 160k -ac 2 $hls -hls_segment_filename old/seg%05d.m4s old/live.m3u8
live silent.ts -map 0:v:0 -map '0:a:0?' -sn -dn -c:v copy \
  -c:a aac -b:a 160k -ac 2 $hls -hls_segment_filename silent/seg%05d.m4s silent/live.m3u8

# A movie in MKV (H.264, E-AC-3, SubRip) with a WebVTT subtitle.
printf '1\n00:00:01,000 --> 00:00:04,000\nHello\n' > film.srt
ffmpeg -hide_banner -loglevel error -f lavfi -i testsrc2=size=640x360:rate=24 \
  -f lavfi -i sine=frequency=440 -i film.srt -t 60 -c:v libx264 -preset ultrafast \
  -pix_fmt yuv420p -g 48 -c:a eac3 -c:s srt film.mkv
ffmpeg -hide_banner -loglevel error -nostdin -i film.mkv -map 0:0 -map 0:1 -map 0:2 -dn \
  -c:v copy -c:a copy -c:s webvtt -f hls -hls_time 6 -hls_playlist_type event \
  -hls_flags independent_segments+temp_file -hls_segment_type fmp4 \
  -hls_fmp4_init_filename init.mp4 -hls_segment_filename movie/seg%05d.m4s \
  -master_pl_name master.m3u8 -var_stream_map 'v:0,a:0,s:0,sgroup:subs' movie/live.m3u8
# Reveal segments gradually: FFmpeg's read-rate limit is ineffective with
# this subtitle stream, so it cannot keep the EVENT fixture growing.
mv movie/live.m3u8 movie/complete.m3u8
python3 - <<'PY' &
from pathlib import Path
import time
lines = Path('movie/complete.m3u8').read_text().splitlines(keepends=True)
first = next(i for i, line in enumerate(lines) if line.startswith('#EXTINF'))
segments = lines[first:-1]
for count in range(6, len(segments) + 1, 2):
    text = ''.join(lines[:first] + segments[:count])
    if count == len(segments):
        text += '#EXT-X-ENDLIST\n'
    pending = Path('movie/live.m3u8.tmp')
    pending.write_text(text)
    pending.replace('movie/live.m3u8')
    time.sleep(6)
PY
pids="$pids $!"

python3 -m http.server 8791 --bind 127.0.0.1 >/dev/null 2>&1 &
pids="$pids $!"
for list in provider hevc old silent movie; do
  n=0
  while :; do
    segments=$(grep -c EXTINF "$list/live.m3u8" 2>/dev/null || true)
    [ "${segments:-0}" -ge 3 ] && break
    n=$((n + 1)); [ "$n" -lt 120 ] || { echo "$list produced no playlist"; exit 1; }
    sleep 0.5
  done
done
sed 's/DEFAULT=YES/DEFAULT=NO,AUTOSELECT=YES/' movie/master.m3u8 > movie/play.m3u8
if grep -q EXT-X-ENDLIST movie/live.m3u8; then
  echo 'Movie finished before the growing-playlist check'; exit 1
fi
base=http://127.0.0.1:8791
swift "$here/check.swift" "must-start-mkv-movie=$base/movie/play.m3u8" \
  "provider-hevc-ts=$base/provider/live.m3u8" \
  "must-hevc-fmp4=$base/hevc/live.m3u8" "must-mpeg2-to-h264=$base/old/live.m3u8" \
  "must-mp2-to-aac=$base/silent/live.m3u8"
