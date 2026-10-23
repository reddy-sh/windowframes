#!/usr/bin/env bash
# Prints the GitHub release notes for a tag: its CHANGELOG.md section (Keep a
# Changelog format) plus the install steps.
# Usage: ./scripts/release-notes.sh v0.4.0
set -euo pipefail
cd "$(dirname "$0")/.."

TAG="${1:?usage: release-notes.sh <tag>}"
VERSION="${TAG#v}"

SECTION="$(awk -v version="$VERSION" '
  /^## \[/ {
    if (found) exit
    if (index($0, "## [" version "]") == 1) { found = 1; next }
  }
  /^\[[^]]+\]: / { if (found) exit }
  found { print }
' CHANGELOG.md)"

if [[ -z "${SECTION//[[:space:]]/}" ]]; then
  echo "CHANGELOG.md has no section for [$VERSION]" >&2
  exit 1
fi

cat <<EOF
${SECTION}

## Install

1. Download \`WindowFrames-${VERSION}.zip\` below and double-click it.
2. Drag **WindowFrames.app** into **Applications**.
3. The app isn't notarised yet, so run this once in Terminal:
   \`xattr -dr com.apple.quarantine /Applications/WindowFrames.app\`
4. Open WindowFrames and allow it under **System Settings → Privacy & Security → Accessibility**.

Check the download with \`shasum -a 256 -c WindowFrames-${VERSION}.zip.sha256\`.
EOF
