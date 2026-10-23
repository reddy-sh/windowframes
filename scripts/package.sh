#!/usr/bin/env bash
# Builds a universal app and zips it as build/WindowFrames-<version>.zip.
set -euo pipefail
cd "$(dirname "$0")/.."

ARCHS="${ARCHS:-universal}" ./scripts/build-app.sh
VERSION="$(tr -d '[:space:]' < VERSION)"
ZIP="build/WindowFrames-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent build/WindowFrames.app "$ZIP"
# Bare file name, so `shasum -a 256 -c` works next to the downloaded zip.
(cd build && shasum -a 256 "WindowFrames-$VERSION.zip" | tee "WindowFrames-$VERSION.zip.sha256")
echo "Packaged $ZIP"
