#!/usr/bin/env bash

set -euo pipefail

PUBLIC_BASE_URL="${R2_PUBLIC_BASE_URL:-https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev}"
ROLLBACK_VERSIONED_DMG_URL="${ROLLBACK_VERSIONED_DMG_URL:-${PUBLIC_BASE_URL%/}/releases/Voiyce-1.0+1.dmg}"

usage() {
  cat <<'EOF'
Usage: scripts/verify-rollback-readiness.sh [--rollback-url <versioned-dmg-url>]

Dry-runs R2 DMG rollback readiness without mutating Cloudflare R2. The script:
  1. Verifies the current public latest.json, latest DMG, versioned DMG, and checksum sidecars.
  2. Verifies a previous versioned DMG rollback candidate and its checksum sidecar.
  3. Generates a rollback latest.json locally for review.

Defaults:
  R2_PUBLIC_BASE_URL defaults to the current public r2.dev base URL.
  ROLLBACK_VERSIONED_DMG_URL defaults to releases/Voiyce-1.0+1.dmg under that base URL.

Examples:
  scripts/verify-rollback-readiness.sh
  scripts/verify-rollback-readiness.sh --rollback-url https://.../releases/Voiyce-1.0+1.dmg
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rollback-url)
      [[ $# -ge 2 ]] || fail "--rollback-url requires a value"
      ROLLBACK_VERSIONED_DMG_URL="$2"
      shift 2
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

require_command curl
require_command python3
require_command shasum

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

log "Verifying current public latest manifest"
curl -fsSL "${PUBLIC_BASE_URL%/}/latest.json" -o "$TMP_DIR/latest.json"
python3 - "$TMP_DIR/latest.json" > "$TMP_DIR/current.tsv" <<'PY'
import json
import sys
from urllib.parse import urlparse

manifest = json.load(open(sys.argv[1]))
required = ["version", "build", "sha256", "download_url"]
missing = [key for key in required if not manifest.get(key)]
versioned_url = manifest.get("versioned_download_url") or manifest.get("versioned_url")
if not versioned_url:
    missing.append("versioned_download_url or versioned_url")
if missing:
    raise SystemExit(f"missing manifest fields: {', '.join(missing)}")

for key, value in {
    "download_url": manifest["download_url"],
    "versioned_download_url": versioned_url,
}.items():
    parsed = urlparse(value)
    if parsed.scheme != "https" or not parsed.netloc:
        raise SystemExit(f"{key} must be an absolute https URL")

print(
    manifest["version"],
    manifest["build"],
    manifest["sha256"],
    manifest["download_url"],
    versioned_url,
    sep="\t",
)
PY
IFS=$'\t' read -r CURRENT_VERSION CURRENT_BUILD CURRENT_SHA CURRENT_LATEST_URL CURRENT_VERSIONED_URL < "$TMP_DIR/current.tsv"
printf 'current version=%s build=%s sha=%s\n' "$CURRENT_VERSION" "$CURRENT_BUILD" "$CURRENT_SHA"

log "Verifying current latest and versioned public DMGs"
mkdir -p "$TMP_DIR/current/latest" "$TMP_DIR/current/versioned"
curl -fsSL "${CURRENT_LATEST_URL}.sha256" -o "$TMP_DIR/current/latest/Voiyce.dmg.sha256"
curl -fsSL "$CURRENT_LATEST_URL" -o "$TMP_DIR/current/latest/Voiyce.dmg"
(cd "$TMP_DIR/current/latest" && shasum -a 256 -c Voiyce.dmg.sha256)
CURRENT_LATEST_SHA="$(shasum -a 256 "$TMP_DIR/current/latest/Voiyce.dmg" | awk '{print $1}')"
[[ "$CURRENT_LATEST_SHA" == "$CURRENT_SHA" ]] || fail "Current latest DMG checksum does not match latest.json."

curl -fsSL "${CURRENT_VERSIONED_URL}.sha256" -o "$TMP_DIR/current/versioned/Voiyce.dmg.sha256"
curl -fsSL "$CURRENT_VERSIONED_URL" -o "$TMP_DIR/current/versioned/Voiyce.dmg"
(cd "$TMP_DIR/current/versioned" && shasum -a 256 -c Voiyce.dmg.sha256)
CURRENT_VERSIONED_SHA="$(shasum -a 256 "$TMP_DIR/current/versioned/Voiyce.dmg" | awk '{print $1}')"
[[ "$CURRENT_VERSIONED_SHA" == "$CURRENT_SHA" ]] || fail "Current versioned DMG checksum does not match latest.json."
cmp -s "$TMP_DIR/current/latest/Voiyce.dmg" "$TMP_DIR/current/versioned/Voiyce.dmg" \
  || fail "Current latest and versioned public DMGs differ."

log "Verifying rollback candidate"
mkdir -p "$TMP_DIR/rollback"
curl -fsSL "${ROLLBACK_VERSIONED_DMG_URL}.sha256" -o "$TMP_DIR/rollback/Voiyce.dmg.sha256"
curl -fsSL "$ROLLBACK_VERSIONED_DMG_URL" -o "$TMP_DIR/rollback/Voiyce.dmg"
(cd "$TMP_DIR/rollback" && shasum -a 256 -c Voiyce.dmg.sha256)
ROLLBACK_SHA="$(shasum -a 256 "$TMP_DIR/rollback/Voiyce.dmg" | awk '{print $1}')"
printf 'rollback candidate=%s\n' "$ROLLBACK_VERSIONED_DMG_URL"
printf 'rollback sha=%s\n' "$ROLLBACK_SHA"

if [[ "$ROLLBACK_SHA" == "$CURRENT_SHA" ]]; then
  fail "Rollback candidate SHA matches the current latest SHA; choose a previous known-good artifact."
fi

log "Generating rollback latest.json locally"
python3 - \
  "$ROLLBACK_VERSIONED_DMG_URL" \
  "$ROLLBACK_SHA" \
  "$CURRENT_LATEST_URL" \
  > "$TMP_DIR/rollback-latest.json" <<'PY'
import json
import re
import sys
from urllib.parse import urlparse

versioned_url, sha256, latest_url = sys.argv[1:4]
parsed = urlparse(versioned_url)
if parsed.scheme != "https" or not parsed.netloc:
    raise SystemExit("rollback versioned DMG URL must be absolute https")

match = re.search(r"/Voiyce-([^/]+)\.dmg$", parsed.path)
if not match:
    raise SystemExit("rollback URL must end with /Voiyce-<version>+<build>.dmg")

version_build = match.group(1)
if "+" not in version_build:
    raise SystemExit("rollback filename must include +build, for example Voiyce-1.0+1.dmg")

version, build = version_build.split("+", 1)
manifest = {
    "version": version,
    "build": build,
    "file": "Voiyce.dmg",
    "sha256": sha256,
    "download_url": latest_url,
    "versioned_download_url": versioned_url,
}
print(json.dumps(manifest, indent=2))
PY

python3 -m json.tool "$TMP_DIR/rollback-latest.json" >/dev/null
cat "$TMP_DIR/rollback-latest.json"

log "Rollback readiness dry run passed"
printf 'dry-run manifest path: %s\n' "$TMP_DIR/rollback-latest.json"
printf 'No R2 objects were changed.\n'
