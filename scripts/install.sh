#!/usr/bin/env bash
# Builds WindowFrames and installs it into /Applications (or ~/Applications
# when /Applications is not writable), then opens it.
set -euo pipefail
cd "$(dirname "$0")/.."

BUNDLE_ID="${BUNDLE_ID:-sh.reddy.windowframes}"
export BUNDLE_ID

./scripts/build-app.sh

DEST="/Applications"
[[ -w "$DEST" ]] || DEST="$HOME/Applications"
mkdir -p "$DEST"

# Quit a running copy before replacing it.
osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
sleep 1

if [[ -d "$DEST/WindowFrames.app" ]]; then
  # A rebuilt app has a new ad hoc signature, so macOS no longer matches the
  # old Accessibility grant. Clear it so the permission prompt appears again.
  tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
  rm -rf "$DEST/WindowFrames.app"
fi

ditto build/WindowFrames.app "$DEST/WindowFrames.app"
echo "Installed $DEST/WindowFrames.app"
open "$DEST/WindowFrames.app"
echo "Allow WindowFrames under System Settings > Privacy & Security > Accessibility."
