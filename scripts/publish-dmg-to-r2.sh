#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Voiyce-Agent.xcodeproj"
TARGET_NAME="Voiyce-Agent"
DMG_PATH="${DMG_PATH:-$ROOT_DIR/build/release/Voiyce.dmg}"
DMG_NAME="$(basename "$DMG_PATH")"
PUBLIC_BASE_URL="${R2_PUBLIC_BASE_URL:-https://downloads.voiyce.com}"
ACCOUNT_ID="${CF_R2_ACCOUNT_ID:-}"
BUCKET="${CF_R2_BUCKET:-}"
ACCESS_KEY_ID="${CF_R2_ACCESS_KEY_ID:-}"
SECRET_ACCESS_KEY="${CF_R2_SECRET_ACCESS_KEY:-}"
ENDPOINT_URL=""
VERSION=""
BUILD_NUMBER=""
VERSIONED_DMG_KEY=""
VERSIONED_SHA_KEY=""
LATEST_DMG_KEY="$DMG_NAME"
LATEST_SHA_KEY="$DMG_NAME.sha256"
UPLOAD_CLIENT="${UPLOAD_CLIENT:-}"

usage() {
  cat <<'EOF'
Usage: scripts/publish-dmg-to-r2.sh

Uploads the notarized DMG to Cloudflare R2 using the S3-compatible API.
The script validates the stapled DMG first, then publishes both a stable latest URL and a versioned archive copy.

Required environment variables:
  CF_R2_ACCOUNT_ID
  CF_R2_BUCKET
  CF_R2_ACCESS_KEY_ID
  CF_R2_SECRET_ACCESS_KEY

Optional environment variables:
  R2_PUBLIC_BASE_URL   Defaults to https://downloads.voiyce.com
  DMG_PATH             Defaults to build/release/Voiyce.dmg
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

select_upload_client() {
  if [[ -n "$UPLOAD_CLIENT" ]]; then
    case "$UPLOAD_CLIENT" in
      aws|wrangler)
        printf '%s\n' "$UPLOAD_CLIENT"
        return
        ;;
      *)
        fail "Unsupported UPLOAD_CLIENT: $UPLOAD_CLIENT"
        ;;
    esac
  fi

  if command -v aws >/dev/null 2>&1; then
    printf 'aws\n'
    return
  fi

  if command -v npx >/dev/null 2>&1; then
    printf 'wrangler\n'
    return
  fi

  fail "Missing upload client. Install aws CLI or make npx/wrangler available."
}

build_setting() {
  xcodebuild -showBuildSettings -project "$PROJECT_PATH" -target "$TARGET_NAME" \
    | sed -n "s/^[[:space:]]*$1 = //p" \
    | head -n 1
}

put_object() {
  local source_path="$1"
  local object_key="$2"
  local content_type="$3"
  local cache_control="$4"

  if [[ "$UPLOAD_CLIENT" == "aws" ]]; then
    aws s3 cp "$source_path" "s3://$BUCKET/$object_key" \
      --endpoint-url "$ENDPOINT_URL" \
      --content-type "$content_type" \
      --cache-control "$cache_control" \
      --no-progress
    return
  fi

  if [[ "$UPLOAD_CLIENT" == "wrangler" ]]; then
    npx wrangler r2 object put "$BUCKET/$object_key" \
      --remote \
      --file "$source_path" \
      --content-type "$content_type" \
      --cache-control "$cache_control"
    return
  fi

  fail "Missing upload client. Install aws CLI or make npx/wrangler available."
}

validate_notarized_dmg() {
  local stapler_output
  local spctl_output

  log "Validating notarized DMG"

  if ! stapler_output="$(xcrun stapler validate "$DMG_PATH" 2>&1)"; then
    printf '%s\n' "$stapler_output" >&2
    fail "$DMG_NAME is missing a valid stapled notarization ticket"
  fi
  printf '%s\n' "$stapler_output"

  if ! spctl_output="$(spctl -a -t open --context context:primary-signature -vv "$DMG_PATH" 2>&1)"; then
    printf '%s\n' "$spctl_output" >&2
    fail "Gatekeeper rejected $DMG_NAME"
  fi
  printf '%s\n' "$spctl_output"
}

[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && { usage; exit 0; }

require_command spctl
require_command xcrun

[[ -f "$DMG_PATH" ]] || fail "DMG not found at $DMG_PATH"

validate_notarized_dmg

require_command shasum
require_command xcodebuild

UPLOAD_CLIENT="$(select_upload_client)"
[[ -n "$BUCKET" ]] || fail "CF_R2_BUCKET is required"

if [[ "$UPLOAD_CLIENT" == "aws" ]]; then
  [[ -n "$ACCOUNT_ID" ]] || fail "CF_R2_ACCOUNT_ID is required when using aws uploads"
  [[ -n "$ACCESS_KEY_ID" ]] || fail "CF_R2_ACCESS_KEY_ID is required when using aws uploads"
  [[ -n "$SECRET_ACCESS_KEY" ]] || fail "CF_R2_SECRET_ACCESS_KEY is required when using aws uploads"
fi

VERSION="$(build_setting MARKETING_VERSION)"
BUILD_NUMBER="$(build_setting CURRENT_PROJECT_VERSION)"
[[ -n "$VERSION" ]] || fail "Unable to determine MARKETING_VERSION from Xcode project"
[[ -n "$BUILD_NUMBER" ]] || fail "Unable to determine CURRENT_PROJECT_VERSION from Xcode project"

if [[ "$UPLOAD_CLIENT" == "aws" ]]; then
  ENDPOINT_URL="https://${ACCOUNT_ID}.r2.cloudflarestorage.com"
fi
VERSIONED_DMG_KEY="releases/Voiyce-${VERSION}+${BUILD_NUMBER}.dmg"
VERSIONED_SHA_KEY="${VERSIONED_DMG_KEY}.sha256"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

CHECKSUM="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
CHECKSUM_FILE="$TMP_DIR/${DMG_NAME}.sha256"
MANIFEST_FILE="$TMP_DIR/latest.json"

printf '%s  %s\n' "$CHECKSUM" "$DMG_NAME" > "$CHECKSUM_FILE"
cat > "$MANIFEST_FILE" <<EOF
{
  "version": "$VERSION",
  "build": "$BUILD_NUMBER",
  "file": "$DMG_NAME",
  "sha256": "$CHECKSUM",
  "download_url": "${PUBLIC_BASE_URL%/}/$LATEST_DMG_KEY",
  "versioned_download_url": "${PUBLIC_BASE_URL%/}/$VERSIONED_DMG_KEY"
}
EOF

if [[ "$UPLOAD_CLIENT" == "aws" ]]; then
  export AWS_ACCESS_KEY_ID="$ACCESS_KEY_ID"
  export AWS_SECRET_ACCESS_KEY="$SECRET_ACCESS_KEY"
  export AWS_REGION="auto"
  export AWS_DEFAULT_REGION="auto"
  export AWS_EC2_METADATA_DISABLED="true"
  export AWS_PAGER=""
fi

log "Uploading versioned DMG"
put_object "$DMG_PATH" "$VERSIONED_DMG_KEY" "application/x-apple-diskimage" "public, max-age=31536000, immutable"

log "Uploading stable latest DMG"
put_object "$DMG_PATH" "$LATEST_DMG_KEY" "application/x-apple-diskimage" "public, max-age=300, must-revalidate"

log "Uploading checksums"
put_object "$CHECKSUM_FILE" "$VERSIONED_SHA_KEY" "text/plain; charset=utf-8" "public, max-age=31536000, immutable"
put_object "$CHECKSUM_FILE" "$LATEST_SHA_KEY" "text/plain; charset=utf-8" "public, max-age=300, must-revalidate"

log "Uploading release manifest"
put_object "$MANIFEST_FILE" "latest.json" "application/json; charset=utf-8" "public, max-age=300, must-revalidate"

log "Publish complete"
printf 'Latest DMG:      %s\n' "${PUBLIC_BASE_URL%/}/$LATEST_DMG_KEY"
printf 'Latest checksum: %s\n' "${PUBLIC_BASE_URL%/}/$LATEST_SHA_KEY"
printf 'Versioned DMG:   %s\n' "${PUBLIC_BASE_URL%/}/$VERSIONED_DMG_KEY"
printf 'Manifest:        %s\n' "${PUBLIC_BASE_URL%/}/latest.json"
