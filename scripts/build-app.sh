#!/usr/bin/env bash
# Builds build/WindowFrames.app.
#   ARCHS=native     (default) this Mac's architecture
#   ARCHS=universal  Apple silicon + Intel (needs full Xcode)
#   SIGN_IDENTITY    codesign identity; "-" (default) is ad hoc signing
#   BUNDLE_ID        bundle identifier (default sh.reddy.windowframes)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(tr -d '[:space:]' < VERSION)"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
BUNDLE_ID="${BUNDLE_ID:-sh.reddy.windowframes}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
ARCHS="${ARCHS:-native}"

if [[ "$ARCHS" == "universal" ]]; then
  SLICES=()
  for arch in arm64 x86_64; do
    # A separate scratch path per architecture, so one build can't
    # overwrite the other's product.
    args=(-c release --triple "$arch-apple-macosx13.0" --scratch-path ".build/$arch")
    swift build "${args[@]}"
    SLICES+=("$(swift build "${args[@]}" --show-bin-path)/WindowFrames")
  done
  mkdir -p build
  BIN="build/WindowFrames-universal"
  lipo -create "${SLICES[@]}" -output "$BIN"
else
  swift build -c release
  BIN="$(swift build -c release --show-bin-path)/WindowFrames"
fi

APP="build/WindowFrames.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/WindowFrames"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUMBER/" -e "s/__BUNDLE_ID__/$BUNDLE_ID/" \
  Resources/Info.plist > "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" >/dev/null

if [[ "$SIGN_IDENTITY" == "-" ]]; then
  codesign --force --options runtime --sign - "$APP"
else
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
fi
codesign --verify --strict "$APP"

echo "Built $APP ($VERSION, build $BUILD_NUMBER, $(lipo -archs "$APP/Contents/MacOS/WindowFrames"))"
