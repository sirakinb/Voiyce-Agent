#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Voiyce-Agent.xcodeproj"
SCHEME="Voiyce-Agent"
APP_NAME="Voiyce"
CONFIGURATION="Release"
TEAM_ID="R28KUQ4KQP"
EXPORT_OPTIONS_PLIST="$ROOT_DIR/config/export-options/developer-id.plist"
BUILD_DIR="$ROOT_DIR/build/release"
ARCHIVE_PATH="$BUILD_DIR/$SCHEME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
DMG_STAGING_DIR="$BUILD_DIR/dmg-root"
RESULT_BUNDLE_PATH="$BUILD_DIR/$SCHEME.xcresult"
DMG_NAME="Voiyce"
DMG_PATH="$BUILD_DIR/$DMG_NAME.dmg"
VOLUME_NAME="Voiyce Installer"

NOTARIZE=1
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
DEVELOPER_IDENTITY="${DEVELOPER_IDENTITY:-}"
KEYCHAIN_PATH="${KEYCHAIN_PATH:-}"

usage() {
  cat <<'EOF'
Usage: scripts/release-macos-dmg.sh [--notary-profile <profile>] [--identity <name>] [--keychain <path>] [--skip-notarize] [--clean]

Builds a signed Release archive, exports a Developer ID signed app,
packages it into a signed .dmg, and notarizes/staples the .dmg by default.

Options:
  --notary-profile <name>    Keychain profile created with `xcrun notarytool store-credentials`.
  --identity <name>          Exact Developer ID Application identity. Skips keychain scanning when provided.
  --keychain <path>          Optional keychain to search for the signing identity.
  --skip-notarize            Skip notarization for a local-only build. Gatekeeper will block this DMG.
  --clean                    Remove previous release artifacts before building.
  -h, --help                 Show this help text.

Environment:
  NOTARY_PROFILE             Alternate way to provide the notarization profile name.
  DEVELOPER_IDENTITY         Alternate way to provide the signing identity.
  KEYCHAIN_PATH              Alternate way to provide the keychain path used for identity lookup.
EOF
}

log() {
  printf '\n==> %s\n' "$1"
}

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

developer_id_identity() {
  local search_args=()

  if [[ -n "$DEVELOPER_IDENTITY" ]]; then
    printf '%s\n' "$DEVELOPER_IDENTITY"
    return
  fi

  if [[ -n "$KEYCHAIN_PATH" ]]; then
    search_args+=("$KEYCHAIN_PATH")
  fi

  security find-identity -v -p codesigning "${search_args[@]}" \
    | sed -n "s/.*\"\\(Developer ID Application: .*(${TEAM_ID})\\)\"/\\1/p" \
    | head -n 1
}

clean_previous_artifacts() {
  rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR" "$DMG_STAGING_DIR" "$RESULT_BUNDLE_PATH"
  rm -f "$DMG_PATH"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --notarize)
      NOTARIZE=1
      shift
      ;;
    --skip-notarize)
      NOTARIZE=0
      shift
      ;;
    --notary-profile)
      [[ $# -ge 2 ]] || fail "--notary-profile requires a value"
      NOTARY_PROFILE="$2"
      shift 2
      ;;
    --identity)
      [[ $# -ge 2 ]] || fail "--identity requires a value"
      DEVELOPER_IDENTITY="$2"
      shift 2
      ;;
    --keychain)
      [[ $# -ge 2 ]] || fail "--keychain requires a value"
      KEYCHAIN_PATH="$2"
      shift 2
      ;;
    --clean)
      clean_previous_artifacts
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

require_command xcodebuild
require_command codesign
require_command hdiutil
require_command xcrun
require_command ditto
require_command security

[[ -f "$PROJECT_PATH/project.pbxproj" ]] || fail "Xcode project not found at $PROJECT_PATH"
[[ -f "$EXPORT_OPTIONS_PLIST" ]] || fail "Export options plist not found at $EXPORT_OPTIONS_PLIST"

IDENTITY="$(developer_id_identity)"
[[ -n "$IDENTITY" ]] || fail "No Developer ID Application certificate found for team $TEAM_ID"

if [[ "$NOTARIZE" -eq 1 && -z "$NOTARY_PROFILE" ]]; then
  fail "No notary profile was provided. Set NOTARY_PROFILE or pass --notary-profile, or use --skip-notarize for a local-only build."
fi

mkdir -p "$BUILD_DIR"

log "Using Developer ID identity"
printf '%s\n' "$IDENTITY"

if [[ -n "$KEYCHAIN_PATH" ]]; then
  log "Using keychain"
  printf '%s\n' "$KEYCHAIN_PATH"
fi

log "Archiving $SCHEME"
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  -resultBundlePath "$RESULT_BUNDLE_PATH" \
  archive

log "Exporting Developer ID signed app"
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

APP_PATH="$EXPORT_DIR/$APP_NAME.app"
[[ -d "$APP_PATH" ]] || fail "Expected exported app at $APP_PATH"

log "Verifying app signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

log "Preparing DMG contents"
rm -rf "$DMG_STAGING_DIR"
mkdir -p "$DMG_STAGING_DIR"
ditto "$APP_PATH" "$DMG_STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"
xattr -cr "$DMG_STAGING_DIR" 2>/dev/null || true

log "Creating DMG"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$DMG_STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

log "Signing DMG"
codesign --force --timestamp --sign "$IDENTITY" "$DMG_PATH"
codesign --verify --verbose=2 "$DMG_PATH"

if [[ "$NOTARIZE" -eq 1 ]]; then
  log "Submitting DMG for notarization"
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

  log "Stapling notarization ticket"
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  spctl -a -t open --context context:primary-signature -vv "$DMG_PATH"
else
  log "Skipping notarization for local-only build"
  printf 'Gatekeeper will reject this DMG. Use NOTARY_PROFILE or --notary-profile to produce a distributable build.\n'
fi

log "Release artifacts"
printf 'Archive: %s\n' "$ARCHIVE_PATH"
printf 'App:     %s\n' "$APP_PATH"
printf 'DMG:     %s\n' "$DMG_PATH"
