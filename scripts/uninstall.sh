#!/usr/bin/env bash
# Quits and removes WindowFrames and clears its Accessibility permission.
set -euo pipefail

BUNDLE_ID="${BUNDLE_ID:-sh.reddy.windowframes}"

osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
sleep 1
for dir in /Applications "$HOME/Applications"; do
  if [[ -d "$dir/WindowFrames.app" ]]; then
    rm -rf "$dir/WindowFrames.app"
    echo "Removed $dir/WindowFrames.app"
  fi
done
tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
echo "WindowFrames uninstalled."
