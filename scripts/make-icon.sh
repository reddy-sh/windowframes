#!/usr/bin/env bash
# Regenerates Resources/AppIcon.icns and docs/icon.png from scripts/make-icon.swift.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p docs
swift scripts/make-icon.swift "$TMP/AppIcon.iconset" docs/icon.png
iconutil -c icns "$TMP/AppIcon.iconset" -o Resources/AppIcon.icns
echo "Wrote Resources/AppIcon.icns and docs/icon.png"
