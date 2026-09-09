#!/usr/bin/env bash
#
# Converts a square PNG (ideally 1024×1024) into Resources/AppIcon.icns.
#
#   scripts/make-icon.sh path/to/icon-1024.png [output.icns]

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="${1:-}"
OUTPUT="${2:-$ROOT/Resources/AppIcon.icns}"

[[ -n "$SOURCE" ]] || { echo "usage: $0 <icon.png> [output.icns]" >&2; exit 2; }
[[ -f "$SOURCE" ]] || { echo "error: $SOURCE not found" >&2; exit 1; }

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
ICONSET="$WORK_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"

for size in 16 32 128 256 512; do
    double=$((size * 2))
    sips -z "$size" "$size" "$SOURCE" --out "$ICONSET/icon_${size}x${size}.png" > /dev/null
    sips -z "$double" "$double" "$SOURCE" --out "$ICONSET/icon_${size}x${size}@2x.png" > /dev/null
done

iconutil -c icns "$ICONSET" -o "$OUTPUT"
echo "Wrote $OUTPUT"
