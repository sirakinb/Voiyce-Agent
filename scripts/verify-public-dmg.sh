#!/usr/bin/env bash

set -euo pipefail

PUBLIC_BASE_URL="${R2_PUBLIC_BASE_URL:-https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev}"
DMG_URL=""
EXPECTED_SHA=""
KEEP=0
OPENAI_KEY_PATTERN="sk-proj-[A-Za-z0-9_-]{20,}|OPENAI_API_KEY=.*sk-[A-Za-z0-9_-]{20,}"

usage() {
  cat <<'EOF'
Usage: scripts/verify-public-dmg.sh [--base-url <r2-base-url>] [--dmg-url <url>] [--expected-sha <sha>] [--keep]

Downloads a public Voiyce DMG into a temporary directory, then verifies it
without installing the app or mutating release artifacts:
  1. Fetches latest.json by default, or uses --dmg-url when provided.
  2. Verifies the DMG checksum from latest.json, --expected-sha, or sidecar.
  3. Verifies the DMG image, Gatekeeper acceptance, and stapled notarization.
  4. Mounts the DMG read-only and no-browse.
  5. Verifies the mounted Voiyce.app, Applications symlink, app signature,
     Gatekeeper acceptance, bundle version/build when latest.json is used, and
     absence of leaked OpenAI keys.
  6. Detaches the DMG and removes temporary files unless --keep is used.

Options:
  --base-url <url>       R2 public base URL for latest.json. Defaults to R2_PUBLIC_BASE_URL or the current r2.dev URL.
  --dmg-url <url>        Direct HTTPS DMG URL to verify instead of latest.json download_url.
  --expected-sha <sha>   Expected SHA-256 for --dmg-url or to override sidecar lookup.
  --keep                Keep the temporary directory for inspection.
  -h, --help            Show this help text.
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

validate_https_url() {
  python3 - "$1" <<'PY'
import sys
from urllib.parse import urlparse

parsed = urlparse(sys.argv[1])
if parsed.scheme != "https" or not parsed.netloc:
    raise SystemExit("URL must be absolute https")
PY
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url)
      [[ $# -ge 2 ]] || fail "--base-url requires a value"
      PUBLIC_BASE_URL="$2"
      shift 2
      ;;
    --dmg-url)
      [[ $# -ge 2 ]] || fail "--dmg-url requires a value"
      DMG_URL="$2"
      shift 2
      ;;
    --expected-sha)
      [[ $# -ge 2 ]] || fail "--expected-sha requires a value"
      EXPECTED_SHA="$2"
      shift 2
      ;;
    --keep)
      KEEP=1
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

require_command codesign
require_command curl
require_command hdiutil
require_command plutil
require_command python3
require_command rg
require_command shasum
require_command spctl
require_command xcrun

TMP_DIR="$(mktemp -d)"
MOUNT_DIR="$TMP_DIR/mount"
DMG_PATH="$TMP_DIR/Voiyce.dmg"
SIDE_CAR_PATH="$TMP_DIR/Voiyce.dmg.sha256"
ATTACHED=0
MANIFEST_VERSION=""
MANIFEST_BUILD=""

cleanup() {
  local status=$?
  if [[ "$ATTACHED" -eq 1 ]]; then
    hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
  fi
  if [[ "$KEEP" -eq 1 ]]; then
    printf 'kept temporary directory: %s\n' "$TMP_DIR"
  else
    rm -rf "$TMP_DIR"
  fi
  exit "$status"
}
trap cleanup EXIT

if [[ -z "$DMG_URL" ]]; then
  log "Fetching public latest manifest"
  curl -fsSL "${PUBLIC_BASE_URL%/}/latest.json" -o "$TMP_DIR/latest.json"
  python3 - "$TMP_DIR/latest.json" > "$TMP_DIR/manifest.tsv" <<'PY'
import json
import sys
from urllib.parse import urlparse

with open(sys.argv[1], encoding="utf-8") as fh:
    manifest = json.load(fh)

required = ["version", "build", "sha256", "download_url"]
missing = [key for key in required if not manifest.get(key)]
if missing:
    raise SystemExit(f"missing manifest fields: {', '.join(missing)}")

download_url = manifest["download_url"]
parsed = urlparse(download_url)
if parsed.scheme != "https" or not parsed.netloc:
    raise SystemExit("download_url must be an absolute https URL")

print(manifest["version"], manifest["build"], manifest["sha256"], download_url, sep="\t")
PY
  IFS=$'\t' read -r MANIFEST_VERSION MANIFEST_BUILD EXPECTED_SHA DMG_URL < "$TMP_DIR/manifest.tsv"
  printf 'manifest version=%s build=%s sha=%s\n' "$MANIFEST_VERSION" "$MANIFEST_BUILD" "$EXPECTED_SHA"
else
  validate_https_url "$DMG_URL"
fi

log "Downloading public DMG"
curl -fsSL "$DMG_URL" -o "$DMG_PATH"
printf 'download_url=%s\n' "$DMG_URL"

if [[ -z "$EXPECTED_SHA" ]]; then
  log "Fetching public DMG checksum sidecar"
  curl -fsSL "${DMG_URL}.sha256" -o "$SIDE_CAR_PATH"
  if ! (cd "$TMP_DIR" && shasum -a 256 -c "$(basename "$SIDE_CAR_PATH")"); then
    SIDE_CAR_SHA="$(awk '{print $1}' "$SIDE_CAR_PATH")"
    ACTUAL_SHA="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
    [[ "$ACTUAL_SHA" == "$SIDE_CAR_SHA" ]] || fail "DMG checksum does not match sidecar."
  fi
  EXPECTED_SHA="$(awk '{print $1}' "$SIDE_CAR_PATH")"
else
  ACTUAL_SHA="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
  [[ "$ACTUAL_SHA" == "$EXPECTED_SHA" ]] || fail "DMG checksum does not match expected SHA."
fi
printf 'verified sha=%s\n' "$EXPECTED_SHA"

log "Verifying DMG image"
hdiutil verify "$DMG_PATH"

log "Checking DMG Gatekeeper and notarization state"
spctl -a -t open --context context:primary-signature -vv "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

log "Mounting DMG read-only"
mkdir -p "$MOUNT_DIR"
hdiutil attach "$DMG_PATH" -readonly -nobrowse -mountpoint "$MOUNT_DIR" -quiet
ATTACHED=1

APP_PATH=""
APP_COUNT=0
while IFS= read -r candidate; do
  APP_PATH="$candidate"
  APP_COUNT=$((APP_COUNT + 1))
done < <(find "$MOUNT_DIR" -maxdepth 2 -type d -name '*.app' -print)

[[ "$APP_COUNT" -eq 1 ]] || fail "Expected exactly one app in the DMG, found $APP_COUNT."
[[ "$(basename "$APP_PATH")" == "Voiyce.app" ]] || fail "Expected mounted app to be Voiyce.app, got $(basename "$APP_PATH")."
printf 'mounted_app=%s\n' "$APP_PATH"

APPLICATIONS_LINK="$MOUNT_DIR/Applications"
[[ -L "$APPLICATIONS_LINK" ]] || fail "Expected mounted DMG to include an Applications symlink."
APPLICATIONS_TARGET="$(readlink "$APPLICATIONS_LINK")"
[[ "$APPLICATIONS_TARGET" == "/Applications" ]] || fail "Applications symlink points to $APPLICATIONS_TARGET, expected /Applications."
printf 'applications_link=%s -> %s\n' "$APPLICATIONS_LINK" "$APPLICATIONS_TARGET"

log "Verifying mounted app signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl -a -t execute -vv "$APP_PATH"

INFO_PLIST="$APP_PATH/Contents/Info.plist"
BUNDLE_VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$INFO_PLIST")"
BUNDLE_BUILD="$(plutil -extract CFBundleVersion raw -o - "$INFO_PLIST")"
printf 'bundle version=%s build=%s\n' "$BUNDLE_VERSION" "$BUNDLE_BUILD"

if [[ -n "$MANIFEST_VERSION" ]]; then
  [[ "$BUNDLE_VERSION" == "$MANIFEST_VERSION" ]] || fail "Bundle version does not match latest.json."
  [[ "$BUNDLE_BUILD" == "$MANIFEST_BUILD" ]] || fail "Bundle build does not match latest.json."
fi

log "Scanning mounted app for leaked OpenAI API keys"
if rg -n --hidden --text "$OPENAI_KEY_PATTERN" "$APP_PATH"; then
  fail "Potential OpenAI API key found in mounted public app bundle."
fi

log "Public DMG verification passed"
