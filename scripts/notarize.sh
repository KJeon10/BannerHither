#!/usr/bin/env bash
#
# Notarizes a Developer ID-signed BannerHither.app and packages it as a notarized disk image.
#
#   dist/BannerHither-<version>.dmg         create-dmg image with an Applications shortcut,
#                                           signed, notarized and stapled
#   dist/BannerHither-<version>.dmg.sha256  checksum, also used by scripts/make-cask.sh
#
# Steps: notarize + staple the app itself (skipped when it already carries a ticket), build the
# DMG around the stapled app, sign the DMG, notarize + staple the DMG. Both the image and the
# app copied out of it therefore validate offline.
#
# Requirements: Xcode command line tools (notarytool, stapler) and create-dmg
# (`brew install create-dmg`).
#
# Credentials for notarytool, one of:
#   NOTARY_KEYCHAIN_PROFILE  profile created with `xcrun notarytool store-credentials <name>`
#                            (default: BannerHither)
#   NOTARY_API_KEY_PATH + NOTARY_API_KEY_ID + NOTARY_API_ISSUER   App Store Connect API key
#
# Environment variables:
#   APP_PATH           app to notarize (default: ./build/BannerHither.app)
#   OUTPUT_DIR         where the image goes (default: ./dist)
#   CODESIGN_IDENTITY  identity for signing the DMG; unset, "-" or "auto" reuse the app's identity
#   DMG_SKIP_FINDER    set to 1 to skip create-dmg's Finder layout step (headless machines / CI)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="BannerHither"
APP_PATH="${APP_PATH:-$ROOT/build/$APP_NAME.app}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT/dist}"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[[ -d "$APP_PATH" ]] || die "$APP_PATH does not exist; run scripts/build-app.sh first"
command -v create-dmg > /dev/null || die "create-dmg is not installed (brew install create-dmg)"

APP_IDENTITY="$(codesign -d --verbose=2 "$APP_PATH" 2>&1 | sed -nE 's/^Authority=(Developer ID Application: .*)$/\1/p' | head -n 1)"
[[ -n "$APP_IDENTITY" ]] || die "$APP_PATH is not signed with a Developer ID Application identity (set CODESIGN_IDENTITY=auto)"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-auto}"
if [[ "$CODESIGN_IDENTITY" == "-" || "$CODESIGN_IDENTITY" == "auto" ]]; then
    CODESIGN_IDENTITY="$APP_IDENTITY"
fi

AUTH_FLAGS=()
if [[ -n "${NOTARY_API_KEY_PATH:-}" ]]; then
    [[ -n "${NOTARY_API_KEY_ID:-}" && -n "${NOTARY_API_ISSUER:-}" ]] \
        || die "NOTARY_API_KEY_PATH requires NOTARY_API_KEY_ID and NOTARY_API_ISSUER"
    AUTH_FLAGS=(--key "$NOTARY_API_KEY_PATH" --key-id "$NOTARY_API_KEY_ID" --issuer "$NOTARY_API_ISSUER")
else
    AUTH_FLAGS=(--keychain-profile "${NOTARY_KEYCHAIN_PROFILE:-BannerHither}")
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
mkdir -p "$OUTPUT_DIR"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# 1. The app itself
if xcrun stapler validate "$APP_PATH" > /dev/null 2>&1; then
    log "$APP_NAME.app already carries a notarization ticket"
else
    log "Submitting $APP_NAME.app $VERSION for notarization"
    ditto -c -k --keepParent "$APP_PATH" "$WORK_DIR/$APP_NAME.zip"
    xcrun notarytool submit "$WORK_DIR/$APP_NAME.zip" "${AUTH_FLAGS[@]}" --wait
    xcrun stapler staple "$APP_PATH"
fi

# 2. The disk image
DMG="$OUTPUT_DIR/$APP_NAME-$VERSION.dmg"
STAGING="$WORK_DIR/staging"
mkdir -p "$STAGING"
ditto "$APP_PATH" "$STAGING/$APP_NAME.app"
rm -f "$DMG" "$DMG.sha256"

log "Creating $DMG"
DMG_FLAGS=(
    --volname "$APP_NAME"
    --volicon "$ROOT/Resources/AppIcon.icns"
    --window-pos 200 120
    --window-size 600 400
    --icon-size 128
    --icon "$APP_NAME.app" 150 185
    --hide-extension "$APP_NAME.app"
    --app-drop-link 450 185
    --no-internet-enable
)
if [[ "${DMG_SKIP_FINDER:-0}" == "1" ]]; then
    DMG_FLAGS+=(--skip-jenkins)
fi
create-dmg "${DMG_FLAGS[@]}" "$DMG" "$STAGING"

log "Signing the image with: $CODESIGN_IDENTITY"
codesign --force --timestamp --sign "$CODESIGN_IDENTITY" "$DMG"

log "Submitting the image for notarization"
xcrun notarytool submit "$DMG" "${AUTH_FLAGS[@]}" --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"

(cd "$OUTPUT_DIR" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
cat "$DMG.sha256"
log "Done. Upload $DMG to the GitHub release for tag v$VERSION"
