#!/bin/sh
set -eu
cd "$(dirname "$0")"
prefix=${PREFIX:-"$HOME/.local"}
case "$prefix" in
    /*) ;;
    *) echo 'PREFIX must be absolute' >&2; exit 1 ;;
esac
app=xyz.brendynmarroquin.brentv
if [ "${1:-}" = --uninstall ]; then
    rm -f "$prefix/bin/brentv" "$prefix/share/applications/$app.desktop" "$prefix/share/icons/hicolor/scalable/apps/$app.svg"
    rm -rf "$prefix/lib/brentv"
    exit
fi
if [ "$#" -ne 0 ]; then
    echo 'Usage: [PREFIX=/usr/local] ./install.sh [--uninstall]' >&2
    exit 1
fi
mkdir -p "$prefix/lib/brentv" "$prefix/bin" "$prefix/share/applications" "$prefix/share/icons/hicolor/scalable/apps"
cp -R bundle/. "$prefix/lib/brentv/"
ln -sfn "$prefix/lib/brentv/brentv" "$prefix/bin/brentv"
cp "$app.desktop" "$prefix/share/applications/"
cp brentv.svg "$prefix/share/icons/hicolor/scalable/apps/$app.svg"
echo "Installed brenTV in $prefix. Ensure $prefix/bin is in PATH."
