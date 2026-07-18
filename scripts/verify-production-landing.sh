#!/usr/bin/env bash

set -euo pipefail

BASE_URL="${1:-https://voiyce.us}"
CONTACT_EMAIL="aki.b@pentridgemedia.com"

usage() {
  cat <<'EOF'
Usage: scripts/verify-production-landing.sh [base-url]

Runs a no-build production smoke check for the public landing site. This does
not lint, build, deploy, package, notarize, or upload anything. It only fetches
the provided public URL and verifies the deployed page has the current Voiyce
agent-context positioning, legal contact, download-health route, and social
assets.

Examples:
  scripts/verify-production-landing.sh
  scripts/verify-production-landing.sh https://voiyce.us
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

assert_file_contains() {
  local file="$1"
  local label="$2"
  local expected="$3"

  rg -q -F "$expected" "$file" || fail "Missing $label in $file: $expected"
}

assert_file_not_contains() {
  local file="$1"
  local label="$2"
  local forbidden="$3"

  if rg -q -i -F "$forbidden" "$file"; then
    fail "Found forbidden $label in $file: $forbidden"
  fi
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

require_command curl
require_command python3
require_command rg

BASE="${BASE_URL%/}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

log "Fetching production landing routes from $BASE"
curl -fsSL "$BASE/" -o "$TMP_DIR/home.html" || fail "Production home route failed: $BASE/"
curl -fsSL "$BASE/auth?intent=download" -o "$TMP_DIR/auth.html" \
  || fail "Production auth route failed: $BASE/auth?intent=download"
curl -fsSL "$BASE/download?intent=download" -o "$TMP_DIR/download.html" \
  || fail "Production download route failed: $BASE/download?intent=download"
curl -fsSL "$BASE/api/download-health" -o "$TMP_DIR/download-health.json" \
  || fail "Production download-health route failed: $BASE/api/download-health"
curl -fsSL "$BASE/privacy" -o "$TMP_DIR/privacy.html" || fail "Production privacy route failed: $BASE/privacy"
curl -fsSL "$BASE/terms" -o "$TMP_DIR/terms.html" || fail "Production terms route failed: $BASE/terms"
curl -fsSL "$BASE/icon.png" -o "$TMP_DIR/icon.png" || fail "Production icon route failed: $BASE/icon.png"
curl -fsSL "$BASE/favicon.ico" -o "$TMP_DIR/favicon.ico" || fail "Production favicon route failed: $BASE/favicon.ico"
curl -fsSL "$BASE/og-header.png" -o "$TMP_DIR/og-header.png" || fail "Production OG route failed: $BASE/og-header.png"

for file in "$TMP_DIR"/*.html; do
  [[ -s "$file" ]] || fail "Production route returned an empty response: $file"
done

log "Checking production social image and favicon payloads"
python3 - "$TMP_DIR/icon.png" "$TMP_DIR/og-header.png" "$TMP_DIR/favicon.ico" <<'PY' \
  || fail "Production social image or favicon payload validation failed."
import struct
import sys
from pathlib import Path


def require_png(path: Path, expected_size: tuple[int, int]) -> None:
    data = path.read_bytes()
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"{path.name} is not a PNG payload")

    width, height = struct.unpack(">II", data[16:24])
    if (width, height) != expected_size:
        raise SystemExit(
            f"{path.name} dimensions were {width}x{height}, expected "
            f"{expected_size[0]}x{expected_size[1]}"
        )


def require_ico(path: Path) -> None:
    data = path.read_bytes()
    if len(data) < 6 or data[:4] != b"\x00\x00\x01\x00":
        raise SystemExit(f"{path.name} is not an ICO payload")

    image_count = int.from_bytes(data[4:6], "little")
    if image_count < 1:
        raise SystemExit(f"{path.name} does not contain any icon images")


require_png(Path(sys.argv[1]), (256, 256))
require_png(Path(sys.argv[2]), (1200, 630))
require_ico(Path(sys.argv[3]))
PY

log "Checking production agent-context positioning"
assert_file_contains "$TMP_DIR/home.html" "home headline" "Stop re-explaining"
assert_file_contains "$TMP_DIR/home.html" "home headline continuation" "your work to AI"
assert_file_contains "$TMP_DIR/home.html" "agent-context positioning" "agent context layer"
assert_file_contains "$TMP_DIR/home.html" "metadata title" "Stop re-explaining your work to AI."
assert_file_contains "$TMP_DIR/home.html" "twitter summary card" "summary_large_image"
assert_file_contains "$TMP_DIR/home.html" "production OG URL" "${BASE}/og-header.png"
assert_file_contains "$TMP_DIR/home.html" "auth CTA href" 'href="/auth?intent=download"'

for agent in "Claude Code" "Codex" "Hermes Agent" "OpenClaw" "Cursor"; do
  assert_file_contains "$TMP_DIR/home.html" "agent label" "$agent"
done

log "Checking production stale-copy guardrails"
for forbidden in \
  "Write at the speed of thought" \
  "Download Voiyce for macOS" \
  "Download for MacOS" \
  "Accelerate your productivity" \
  "No more typing" \
  "Speak naturally. We handle the rest"
do
  assert_file_not_contains "$TMP_DIR/home.html" "stale launch copy" "$forbidden"
done

log "Checking production auth, download, and legal routes"
assert_file_contains "$TMP_DIR/auth.html" "auth route title" "Create Account"
assert_file_contains "$TMP_DIR/auth.html" "auth route metadata" "Create your Voiyce account"
assert_file_contains "$TMP_DIR/download.html" "download route title" "Download For Mac"
assert_file_contains "$TMP_DIR/download.html" "download route metadata" "Download the Voiyce Mac app"
assert_file_contains "$TMP_DIR/download-health.json" "download health ok" '"ok":true'
assert_file_contains "$TMP_DIR/privacy.html" "privacy title" "Privacy Policy"
assert_file_contains "$TMP_DIR/privacy.html" "privacy contact" "$CONTACT_EMAIL"
assert_file_contains "$TMP_DIR/privacy.html" "privacy memory coverage" "Local memory"
assert_file_contains "$TMP_DIR/terms.html" "terms title" "Terms of Service"
assert_file_contains "$TMP_DIR/terms.html" "terms contact" "$CONTACT_EMAIL"
assert_file_contains "$TMP_DIR/terms.html" "terms context coverage" "context capture"

log "Production landing verification passed"
