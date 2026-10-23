#!/usr/bin/env bash
# Checks that VERSION is a Semantic Versioning 2.0.0 version and, when a tag
# is given, that the tag is exactly v<VERSION> with a CHANGELOG.md section.
# Usage: ./scripts/check-version.sh [v1.2.3]
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(tr -d '[:space:]' < VERSION)"
SEMVER='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'

if [[ ! "$VERSION" =~ $SEMVER ]]; then
  echo "VERSION '$VERSION' is not MAJOR.MINOR.PATCH (semver.org)" >&2
  exit 1
fi

if [[ $# -ge 1 ]]; then
  TAG="$1"
  if [[ "$TAG" != "v$VERSION" ]]; then
    echo "Tag '$TAG' doesn't match VERSION '$VERSION' (expected v$VERSION)" >&2
    exit 1
  fi
  if ! grep -q "^## \[$VERSION\] - [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}$" CHANGELOG.md; then
    echo "CHANGELOG.md needs a '## [$VERSION] - YYYY-MM-DD' section" >&2
    exit 1
  fi
fi

echo "Version $VERSION OK${1:+ for tag $1}"
