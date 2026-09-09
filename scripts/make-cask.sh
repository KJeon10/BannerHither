#!/usr/bin/env bash
#
# Renders packaging/homebrew/bannerhither.rb.template into dist/bannerhither.rb using the
# version and SHA-256 of the release archive produced by scripts/notarize.sh.
#
# Environment variables:
#   GITHUB_REPO  owner/name used for the download URL (default: KJeon10/BannerHither)
#   ARCHIVE      release image (default: dist/BannerHither-<version>.dmg)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="BannerHither"
GITHUB_REPO="${GITHUB_REPO:-KJeon10/BannerHither}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
ARCHIVE="${ARCHIVE:-$ROOT/dist/$APP_NAME-$VERSION.dmg}"
TEMPLATE="$ROOT/packaging/homebrew/bannerhither.rb.template"
OUTPUT="$ROOT/dist/bannerhither.rb"

[[ -f "$ARCHIVE" ]] || { echo "error: $ARCHIVE not found; run 'make release' first" >&2; exit 1; }
SHA256="$(shasum -a 256 "$ARCHIVE" | cut -d ' ' -f 1)"

sed -e "s|__VERSION__|$VERSION|g" \
    -e "s|__SHA256__|$SHA256|g" \
    -e "s|__GITHUB_REPO__|$GITHUB_REPO|g" \
    "$TEMPLATE" > "$OUTPUT"
echo "Wrote $OUTPUT (version $VERSION, sha256 $SHA256)"
