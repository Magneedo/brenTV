#!/bin/sh
# Builds the Rust core and the Linux bundle: flutter/build/linux/x64/release/bundle
set -eu
cd "$(dirname "$0")/.."
cargo build --locked --release
target=$(cargo metadata --format-version 1 --no-deps | sed 's/.*"target_directory":"\([^"]*\)".*/\1/')
mkdir -p flutter/linux/libs
cp "$target/release/libbrentv_core.so" flutter/linux/libs/
cd flutter
flutter build linux --release "$@"
