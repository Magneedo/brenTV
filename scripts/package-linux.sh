#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
scripts/build-linux.sh
version=$(sed -n 's/^version: *\([^+ ]*\).*/\1/p' flutter/pubspec.yaml)
name=brentv-$version-linux-x86_64
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT HUP INT TERM
mkdir -p "$stage/$name"
cp -R flutter/build/linux/x64/release/bundle "$stage/$name/"
cp LICENSE packaging/linux/install.sh packaging/linux/xyz.brendynmarroquin.brentv.desktop assets/icon/brentv.svg "$stage/$name/"
mkdir -p dist
tar -czf "dist/$name.tar.gz" -C "$stage" "$name"
echo "dist/$name.tar.gz"
