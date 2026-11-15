# Performance measurements

These are records of past measurements. The commit IDs name revisions from
brenTV's development before this repository, whose history starts at 1.0.0,
so the baseline builds and `git archive` commands below can't be rerun from
here. To measure the current tree, build `examples/bench.rs` with
`cargo build --locked --release --example bench`.

## Optional features and desktop comparison · 2026-11-13

This measures the expansion at `4d198d86ffc2a719de2e0fc7cf1fa3528acc31d8`
against the saved, previously installed brenTV baseline
`882a4e389839f824588499cc3a45b36fc615d43e` and installed OpenTV
`open-tv-bin 1.9.1-1`. Older measurements below cover different revisions and
methods; they are historical results, not measurements of this expansion.

Guide off, median (minimum–maximum), five measured runs per app:

| Measure | brenTV baseline | brenTV expansion | OpenTV |
| --- | ---: | ---: | ---: |
| Process-tree PSS, MiB | 126.5 (126.3–133.1) | 143.4 (137.7–143.6) | 281.4 (277.2–284.1) |
| Launch to visible catalog upper bound, s | 0.709 (0.699–0.723) | 0.717 (0.711–0.725) | 0.711 (0.696–0.715) |
| Search result upper bound, s | 0.766 (0.763–0.783) | 0.482 (0.478–0.486) | 0.807 (0.792–0.813) |

Search was ready one observation cycle earlier in 5/5 measured trials
versus each reference, consistent with removing the baseline's 300 ms search
delay. Captures were about 0.28 s apart. Median observed lower–upper readiness
bounds were approximately (0.42, 0.77] s baseline, (0.14, 0.48] s expansion and
(0.45, 0.81] s OpenTV; these overlap, so the upper-bound differences do not
resolve a percentage latency reduction. The delay defaults to 0; Settings
offers Immediate, 100, 300 or 500 ms. Catalog timings are too close, and the
observation intervals too coarse, to establish a startup improvement.

The measured memory medians differ by +16.9 MiB (13.3%) versus baseline.
Both brenTV builds had two stable per-launch PSS clusters about 6 MiB
apart (baseline ~6.6, expansion ~5.7); the baseline median landed in its lower cluster and the expansion
median in its higher cluster. Comparing corresponding observed clusters
instead gives roughly +10–11 MiB. The cause of the launch-state split was
not identified, so the median gap cannot all be attributed to the expansion.
Expansion's median remained 49.0% below OpenTV in this fixture. These are
whole-build costs, not a measurement of any one feature's allocation.

Inline now/next captions, with full guide, XMLTV and playback closed:

| Stationary measure | Baseline off | Baseline on | Expansion off | Expansion on |
| --- | ---: | ---: | ---: | ---: |
| Median PSS, MiB | 126.5 | 128.1 | 143.4 | 143.1 |
| Recorded CPU per ~20 s, ticks | 0 | 2 (0.099% of one core) | 0 | 0 |
| Voluntary context switches, median per ~20 s | 6 | 168 | 6 | 5 |
| Guide HTTP requests during each idle window | 0 | 0 | 0 | 0 |

CPU counters advanced by 0.02 CPU seconds per baseline guide-on window and
zero recorded ticks in the other groups. Each process user/system counter
has 0.01 CPU second resolution, about 0.05% of one core over these windows
per counter. Summing several counters means zero ticks is not a strict
0.05% bound for the process tree, nor does it mean zero cost. The baseline's
recurring guide polling was replaced by one-shot
deadlines. Context switches are not timer wakeups. Caption-on memory ranges
were 127.6–136.8 MiB baseline and 138.2–143.5 MiB expansion; these overlap
their respective off ranges, so the slight negative expansion on/off median
does not establish a memory saving from enabling captions. Both guide-on
versions fetched 60 initial listings per run and then stayed quiet; all
guide-off runs made zero guide requests. OpenTV has no equivalent inline
now/next scheduler, so a corresponding guide-on result is unavailable.

Compiled weight: the complete Flutter bundle grew from 41.51 to 42.13 MiB,
an increase of 0.62 MiB (1.5%). The Dart AOT library grew by 163,840 bytes;
the Rust core by 488,792 bytes. Turning a feature off suppresses its runtime
work but does not remove its compiled code. Full-guide schedule requests
and XMLTV parsing/caching happen on demand; their active memory/CPU costs
were not measured here. XMLTV can retain up to four parsed documents, each
with a 16 MiB input cap and 50,000-entry cap; parsed memory can exceed input
bytes. Disable XMLTV or the master guide to clear that cache. Recording was
not implemented.

### Method and limits

Intel i5-1240P, 16 logical CPUs, x86_64 Artix Linux, isolated Wayland agent
desk at 1914×1247, scale 1. Each fresh private XDG profile contained the same
9,390 synthetic live channels, 110 categories and two favorites, using each
app's native database schema. Native initialization used each brenTV bundle's
own core. No real provider, artwork, refresh, playback or user database was
used. OpenTV used its installed renderer workaround and saved zoom 150.
brenTV displayed 56 readable channel names in the viewport and OpenTV 18;
different layouts are an explicit load difference, not equal rendered work.

One excluded warm-up followed by five alternating measured runs per group:
three apps guide off, then baseline/expansion guide on, 30 trials total.
Each run waited for the catalog, filled visible captions when enabled,
settled for 30 seconds, confirmed the viewport again, waited three quiet
seconds, then sampled the whole descendant process tree for ~20 seconds.
No capture, OCR or input ran during that sampling window. The app's private
D-Bus session is included; the fixture HTTP server and OCR are outside the
app tree. PSS is each run's median of 21 samples, then the median across five
runs. CPU is summed process user+system tick deltas divided by elapsed time;
all process identities stayed stable throughout every window. Per-thread
context counters have a remaining limitation if threads exit during a window.

Search typed `09390`, which matched one database row. Catalog-area OCR
required two matching ready frames; search OCR used the first result tile,
outside the input. Both ready search frames in all 15 measured guide-off
trials were additionally checked for a single occupied card using viewport
sample points, and all final search frames were visually inspected together.
Timing ends at capture completion of the first of two matching ready frames.
It includes the native input tool's 100 ms keymap delay, debounce, query,
render and screenshot overhead, but excludes subsequent OCR processing and
the second-frame confirmation. Last failed captures provide lower bounds
in the raw data. These are visual proxy intervals, not precise frame,
cold-boot, SQL-only, provider, channel-switching, battery or iOS measurements.

Binary inventories matched before and after all runs. Expansion `libapp.so`
SHA256: `3e4caa32d449cbd0b9d7925c9b978f6391d6f5755c98568ffba008ba51aab1cf`;
core: `ce9ab61fa7810d11ccfba4ec243af5058150ca9c064b856ace720b1c0341fe6e`;
OpenTV: `e44b2307434c353e60fb920e1b5fc6769345bb8e98c501b0246ff80c702bfb3c`.
OpenTV's 22,896,544 package-owned bytes exclude shared system dependencies;
they are not equivalent to the complete Flutter bundle footprint.

Four earlier attempts stopped during setup or warm-ups: onboarding OCR,
sparse-result OCR, waiting for owned process cleanup, and startup helper
process retirement. After fixing the harness, the entire suite restarted;
no measured trials were taken from those attempts. The accepted suite
completed all 30 planned trials without exclusions. Summary statistics,
individual values, screenshots, HTTP counts, process samples, fixture
assertions and before/after hashes are retained locally in
`~/.cache/brentv-expansion/benchmark/results-20261113-160005/`.
Independent recomputation verified the summaries and stable process trees.
The disposable desktop driver is not part of the application. To repeat
the experiment, use the two exact release bundles and OpenTV binary above,
fresh matching synthetic databases, the same settings/geometry/order and
observation/sampling protocol; archive raw evidence and hashes before
removing temporary profiles.

## Core import/query measurements · 2026-11-11

Measured 2026-11-11 on x86_64 Artix Linux, Rust 1.99.1 release builds. Baseline is `a60e490`; final is the working tree with Round 4 A1–A7 fixes. Both binaries use the same final `examples/bench.rs`. Three alternating baseline/final pairs per fixture ran sequentially in fresh processes and databases.

The synthetic fixture has 100,000 live channels, 50,000 movies and 10,000 series across 100 categories per type. M3U uses a local file; Xtream uses loopback HTTP. Import is followed by refresh with 20 favorites and history entries. Every process asserted 160,000 channels, 20 favorites and 20 history entries after refresh, then removed its database. All twelve runs exited 0 with empty stderr.

| Operation | M3U baseline | M3U final | Xtream baseline | Xtream final |
| --- | ---: | ---: | ---: | ---: |
| Import seconds | 3.274 | 2.271 | 3.182 | 2.087 |
| Refresh seconds | 2.686 | 2.028 | 2.633 | 1.903 |
| provider page 1 ms | 36.887 | 0.097 | 34.977 | 0.106 |
| provider page 200 ms | 40.876 | 0.718 | 43.395 | 1.619 |
| all page 1 ms | 0.123 | 0.098 | 0.118 | 0.100 |
| search news ms | 8.071 | 4.857 | 8.097 | 4.824 |
| keywords sport hd ms | 6.991 | 3.883 | 6.885 | 3.900 |
| page 200 ms | 3.840 | 1.104 | 3.662 | 1.055 |
| categories ms | 0.037 | 0.035 | 0.038 | 0.035 |
| favorites ms | 0.083 | 0.072 | 0.084 | 0.071 |
| history ms | 0.077 | 0.067 | 0.077 | 0.066 |
| DB + WAL MiB | 160.445 | 77.879 | 143.650 | 65.230 |
| Peak RSS MiB | 175.691 | 174.672 | 214.438 | 205.133 |

Values are medians of three processes. Query values are medians of per-process medians (31 calls each, at most 36 returned rows). Provider ordering is explicitly sort 2. OFFSET still scans earlier entries; substring/keyword searches still scan candidates. Indexes avoid catalog sorting, unchanged rows avoid rewrites, and series cache cleanup uses indexed provider identity. The final schema removes redundant indexes. The 16 MiB journal size limit reduces retained WAL after reset; it does not bound active WAL growth.

RSS includes the fixture generator, HTTP server, SQLite and core. Database size includes WAL at the end of queries. These measurements cover local CPU/database costs, with scheduler and allocator variance. They do not establish Internet throughput, Flutter RSS, HLS startup, TLS, playback, or Apple/device performance. Query ordering was not independently compared row for row. Regression tests separately cover identity, progress, failed/malformed/empty refresh retention and cache isolation.

## Individual runs

| Fixture / revision | Import seconds | Refresh seconds | Peak RSS MiB |
| --- | --- | --- | --- |
| m3u baseline | 3.274, 3.241, 3.287 | 2.675, 2.698, 2.686 | 175.691, 176.855, 175.570 |
| m3u final | 2.240, 2.271, 2.410 | 2.023, 2.067, 2.028 | 174.672, 174.613, 174.953 |
| xtream baseline | 3.153, 3.192, 3.182 | 2.621, 2.633, 2.870 | 214.438, 198.141, 242.965 |
| xtream final | 2.065, 2.087, 2.097 | 1.903, 1.884, 1.909 | 240.859, 187.164, 205.133 |

## Reproduce

Run from the final checkout with the pinned Rust toolchain and Cargo.lock.
Scratch lives on the home disk; two separate build targets prevent stale
cross-revision artifacts. Preserve any existing benchmark binary before building.

```sh
set -eu
bench_root=$(mktemp -d "$HOME/brentv-benchmark.XXXXXX")
mkdir -p "$bench_root/baseline" "$bench_root/tmp"
export TMPDIR="$bench_root/tmp"
if [ -f target/release/examples/bench ]; then
    cp target/release/examples/bench "$bench_root/bench-existing"
fi
git archive a60e490 | tar -x -C "$bench_root/baseline"
cp examples/bench.rs "$bench_root/baseline/examples/bench.rs"
CARGO_TARGET_DIR="$bench_root/target-final" cargo build --locked --release --example bench
cp "$bench_root/target-final/release/examples/bench" "$bench_root/bench-final"
CARGO_TARGET_DIR="$bench_root/target-baseline" cargo build --locked --release --example bench \
    --manifest-path "$bench_root/baseline/Cargo.toml"
cp "$bench_root/target-baseline/release/examples/bench" "$bench_root/bench-baseline"
sha256sum "$bench_root/bench-baseline" "$bench_root/bench-final"
for fixture in m3u xtream; do
    for run in 1 2 3; do
        for revision in baseline final; do
            log="$bench_root/$fixture-$revision-$run"
            status=0
            "$bench_root/bench-$revision" "$fixture" > "$log.stdout" 2> "$log.stderr" || status=$?
            echo "$status" > "$log.exit"
            test "$status" -eq 0
        done
    done
done
printf 'Raw results: %s\n' "$bench_root"
```

Run without concurrent builds or benchmarks. Each stdout contains import,
refresh, every query median/p95, peak RSS, database bytes and asserted state.
Compute the median of each set of three values to reproduce the table; divide
RSS kB by 1024 and database bytes by 1048576. Keep the raw stdout/stderr/status
files for audit, then remove the scratch directory when no longer needed.
Exact working-tree provenance and saved measurements belong in the project
handoff; reproduction used only repository sources and the commands above.

## Installed brenTV versus OpenTV · 2026-11-12

These measurements precede the viewport-fill correction, which loads more rows
on tall windows. They do not measure that later build.

Local desktop comparison on an Intel i5-1240P, Wayland agent desk at
1914×1247, scale 1. OpenTV is installed open-tv-bin 1.9.1-1 (app 1.9.1),
using its launcher setting `WEBKIT_DISABLE_DMABUF_RENDERER=1` and saved
zoom 150. brenTV is the corrected follow-up build based on dbd01af; its
compiled UI SHA256 is cded19e4d8f0dd0eb23c9b4020e31193d1a1180fbb0059a730e05f3b0093a046.

Both apps used private, isolated copies of their respective database schemas,
with the same 9,390 generated live channels, 110 categories and 2 favorite channels.
Artwork was null and refresh-on-start disabled; URLs pointed to a closed
loopback port and no playback was requested. No provider performance is inferred.
The user databases were untouched by these measurement runs.

One warm-up per app was discarded, then five runs per app alternated order.
Timing uses monotonic launch/input timestamps and visual recognition of the
first channel or the single `09390` search result. Screenshots were sampled
after 100 ms waits plus OCR processing, so these are observed upper bounds,
not precise frame latency. Search includes VNC input, debounce, query and render;
Flutter waited 500 ms before a search (300 ms since), OpenTV 300 ms. PSS sums the process tree
(OpenTV includes WebKit); each run uses the median of five samples 200 ms apart
after 3 s of settling, then the table takes the median across five runs.
Parent builds and tests were finished before measurement.

Values are median (minimum–maximum). Lower is better.

| Measure | brenTV | OpenTV |
| --- | --- | --- |
| Whole-process-tree PSS | 122.1 (114.8–122.5) MiB | 282.9 (280.3–285.6) MiB |
| Launch to visible catalog | 0.369 (0.363–0.386) s | 0.638 (0.616–0.645) s |
| Input to search result | 1.031 (0.810–1.047) s | 0.815 (0.805–0.821) s |

brenTV used less memory and displayed the catalog sooner in this setup;
OpenTV completed the search sooner. These runs do not compare real-provider
refreshes, playback startup/quality, channel switching, cold caches or iOS.
An initial OCR failure missed a correctly displayed search result; that trial
was excluded and the entire measurement restarted after correcting the detector.
Raw 12-process records (two warm-ups plus ten measured runs), screenshots, logs
and summary are retained locally in `~/.cache/brentv-followups/`. The throwaway
measurement script is removed after use.

## Provider playback and native startup · 2026-11-12

Base: 07d8244, installed mpv 0.41 on an Artix/Wayland laptop. Three
live news and sports channels (A, B and C), three rounds, alternating
configuration order; each configuration opened A and then replaced it with B
and C in the same mpv process, on one muted stream. Native startup/build work did not overlap these timing runs.

Measurement starts at the mpv IPC loadfile command and ends at its
playback-restart event (the installed mpv manual describes this as playback
starting after loading/seeking). This is a playback-ready proxy, not GPU
presentation or end-to-end Flutter click latency. Each successful run had
video parameters, audio and advancing playback over the following 1.5 seconds;
this does not establish long-run stability. MPV launch/IPC readiness was
measured separately. Current settings: VAAPI, 3 s / 64 MiB cache, low-latency
profile enabled. Normal removes that profile; small-probe retains it and
sets demuxer-lavf-probesize=32768. All other settings stayed the same.

| Configuration | Successful runs | Median ready time | Range |
| --- | --- | --- | --- |
| current-low-latency | 9/9 | 0.604s | 0.532–1.447s |
| normal | 9/9 | 0.648s | 0.553–1.151s |
| small-probe | 9/9 | 0.624s | 0.491–1.503s |

No additional probe/buffering change was selected: the small sample did not
show a useful consistent improvement over the current configuration.
Channel B reported software decoding in 2 of 9 runs (both with the low-latency
profile) and VAAPI otherwise; the other two channels reported VAAPI.
No claim is made that every provider codec uses hardware.

Compression: three identity and three gzip-requested get_live_streams
responses all arrived uncompressed at 3,128,126 bytes. Enabling a gzip feature
would provide no measured benefit with this provider, so no dependency was
added. No source/catalog refresh or user-state writes were performed.

Native startup: 10 fresh databases and 10 copies of the real v5 database, each
in a new process through the installed Rust FFI initialize function. All
20 succeeded with zero database-is-locked warnings. Existing-database
initialization median 2.457 ms (1.949–2.887ms), fresh-schema median 126.552 ms
(121.885–131.628ms). One or two SQLite connections were observed. This
measures native initialization, not Flutter/window startup. The current
pool is already capped at 8 with minimum idle 1, so it was left unchanged.

Raw safe metrics/statuses: ~/.cache/brentv-navigation/{playback.json,
playback-summary.json,compression.json,startup.json}. Provider URLs, headers
and credentials are excluded. Measurement scripts and copied databases
are disposable and removed after use.
