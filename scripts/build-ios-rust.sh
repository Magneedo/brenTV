#!/bin/sh
# Builds the Rust core as a static library for iOS devices; Xcode links
# flutter/ios/rust/libbrentv_core.a with -force_load (see project.pbxproj).
set -eu
cd "$(dirname "$0")/.."
rustup target add aarch64-apple-ios >/dev/null
IPHONEOS_DEPLOYMENT_TARGET="${IPHONEOS_DEPLOYMENT_TARGET:-13.0}" \
  cargo rustc --locked --release --lib --target aarch64-apple-ios --crate-type staticlib
target=$(cargo metadata --format-version 1 --no-deps | sed 's/.*"target_directory":"\([^"]*\)".*/\1/')
mkdir -p flutter/ios/rust
cp "$target/aarch64-apple-ios/release/libbrentv_core.a" flutter/ios/rust/
