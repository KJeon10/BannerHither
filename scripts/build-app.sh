#!/usr/bin/env bash
#
# Builds BannerHither with SwiftPM and assembles a signed .app bundle.
#
# Environment variables:
#   CONFIGURATION      release (default) | debug
#   ARCHS              universal (default) | arm64 | x86_64 | native
#   CODESIGN_IDENTITY  "-" (default: ad-hoc), "auto" (first "Developer ID Application"
#                      identity in the keychain), or an explicit identity name
#   BUILD_NUMBER       CFBundleVersion; defaults to the git commit count, or 1
#   OUTPUT_DIR         where <OUTPUT_DIR>/BannerHither.app is written (default: ./build)
#
# Note on ad-hoc signing: macOS ties the Accessibility permission to the code signature,
# and an ad-hoc signature changes with every build. After rebuilding you may need to remove
# and re-add BannerHither in System Settings › Privacy & Security › Accessibility. Signing
# with a stable identity (Developer ID, or a self-signed certificate) avoids that.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="BannerHither"
CONFIGURATION="${CONFIGURATION:-release}"
ARCHS="${ARCHS:-universal}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT/build}"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

ARCH_FLAGS=()
case "$ARCHS" in
    universal) ARCH_FLAGS=(--arch arm64 --arch x86_64) ;;
    arm64|x86_64) ARCH_FLAGS=(--arch "$ARCHS") ;;
    native) ;;
    *) die "Unknown ARCHS '$ARCHS' (use universal, arm64, x86_64 or native)" ;;
esac

if [[ "$CODESIGN_IDENTITY" == "auto" ]]; then
    CODESIGN_IDENTITY="$(security find-identity -v -p codesigning | sed -nE 's/.*"(Developer ID Application: [^"]+)".*/\1/p' | head -n 1)"
    [[ -n "$CODESIGN_IDENTITY" ]] || die "No 'Developer ID Application' identity found in the keychain"
fi

cd "$ROOT"

log "Building $APP_NAME ($CONFIGURATION, $ARCHS)"
swift build -c "$CONFIGURATION" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --product "$APP_NAME"
BIN_DIR="$(swift build -c "$CONFIGURATION" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"

APP="$OUTPUT_DIR/$APP_NAME.app"
CONTENTS="$APP/Contents"
log "Assembling $APP"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN_DIR/$APP_NAME" "$CONTENTS/MacOS/$APP_NAME"
cp -R "$BIN_DIR/${APP_NAME}_${APP_NAME}.bundle" "$CONTENTS/Resources/"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
printf 'APPL????' > "$CONTENTS/PkgInfo"

BUILD_NUMBER="${BUILD_NUMBER:-$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)}"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$CONTENTS/Info.plist"

log "Signing with identity: $CODESIGN_IDENTITY"
SIGN_FLAGS=(--force --options runtime)
if [[ "$CODESIGN_IDENTITY" != "-" ]]; then
    SIGN_FLAGS+=(--timestamp)
fi
codesign "${SIGN_FLAGS[@]}" --sign "$CODESIGN_IDENTITY" "$APP"
codesign --verify --strict --deep "$APP"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$CONTENTS/Info.plist")"
log "Built $APP_NAME $VERSION ($BUILD_NUMBER) → $APP"
