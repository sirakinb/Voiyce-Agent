#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Voiyce-Agent.xcodeproj"
SCHEME="Voiyce-Agent"
CHECK_SOURCE_STATE=0
EXPECTED_VERSION=""
EXPECTED_BUILD=""
EXPECTED_TAG=""
RUN_PACKAGE=0
RUN_ARCHIVE_CHECK=0
CHECK_PUBLIC_DOWNLOAD=0
CHECK_PUBLIC_DMG=0
CHECK_PRODUCTION_LANDING=0
RUN_UI_TESTS=1
PUBLIC_BASE_URL="${R2_PUBLIC_BASE_URL:-https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev}"
PRODUCTION_LANDING_URL="${PRODUCTION_LANDING_URL:-https://voiyce.us}"
OPENAI_KEY_PATTERN="sk-proj-[A-Za-z0-9_-]{20,}|OPENAI_API_KEY=.*sk-[A-Za-z0-9_-]{20,}"

usage() {
  cat <<'EOF'
Usage: scripts/verify-release.sh [--source-state-check] [--expected-version <version>] [--expected-build <build>] [--expected-tag <tag>] [--package] [--archive-check] [--public-download-check] [--public-dmg-check] [--production-landing-check] [--production-url <base-url>] [--skip-ui-tests]

Runs the release gate used before shipping:
  1. Secret scan for accidental OpenAI keys
  2. Optional source-state verification for clean tree, version/build, and tag
  3. macOS unit tests
  4. macOS product-flow UI tests
  5. Static server-side usage-cap matrix and wiring verification
  6. Deno tests for backend edge-function request shapes
  7. Landing site launch verification
  8. Release build
  9. Optional temporary Release archive verification without export/DMG/notarization
  10. Optional signed local DMG package with notarization skipped
  11. Optional public R2 download/checksum/manifest verification
  12. Optional public DMG mount, signature, Gatekeeper, and notarization verification
  13. Optional no-build production landing smoke verification

Options:
  --source-state-check        Require a clean, reproducible source tree before continuing.
  --expected-version <value>  Expected Xcode MARKETING_VERSION for --source-state-check.
  --expected-build <value>    Expected Xcode CURRENT_PROJECT_VERSION for --source-state-check.
  --expected-tag <tag>        Expected Git release tag for --source-state-check.
  --package                   Also run scripts/release-macos-dmg.sh --skip-notarize --clean.
  --archive-check             Also run scripts/verify-release-archive.sh without creating a DMG.
  --public-download-check     Verify latest.json, Voiyce.dmg, and Voiyce.dmg.sha256 from R2.
  --public-dmg-check          Download, mount read-only, and verify the public DMG without installing.
  --production-landing-check  Verify the deployed landing page, legal routes, download-health route, and social assets.
  --production-url <base-url> Base URL for --production-landing-check. Defaults to PRODUCTION_LANDING_URL or https://voiyce.us.
  --skip-ui-tests             Skip macOS UI tests for local diagnostics only. Do not use for release candidates.
  -h, --help                  Show this help text.
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
    --source-state-check)
      CHECK_SOURCE_STATE=1
      shift
      ;;
    --expected-version)
      [[ $# -ge 2 ]] || fail "--expected-version requires a value"
      EXPECTED_VERSION="$2"
      shift 2
      ;;
    --expected-build)
      [[ $# -ge 2 ]] || fail "--expected-build requires a value"
      EXPECTED_BUILD="$2"
      shift 2
      ;;
    --expected-tag)
      [[ $# -ge 2 ]] || fail "--expected-tag requires a value"
      EXPECTED_TAG="$2"
      shift 2
      ;;
    --package)
      RUN_PACKAGE=1
      shift
      ;;
    --archive-check)
      RUN_ARCHIVE_CHECK=1
      shift
      ;;
    --public-download-check)
      CHECK_PUBLIC_DOWNLOAD=1
      shift
      ;;
    --public-dmg-check)
      CHECK_PUBLIC_DMG=1
      shift
      ;;
    --production-landing-check)
      CHECK_PRODUCTION_LANDING=1
      shift
      ;;
    --production-url)
      [[ $# -ge 2 ]] || fail "--production-url requires a value"
      PRODUCTION_LANDING_URL="$2"
      shift 2
      ;;
    --skip-ui-tests)
      RUN_UI_TESTS=0
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
require_command deno
require_command rg

cd "$ROOT_DIR"

log "Scanning source for leaked OpenAI API keys"
if rg -n --hidden \
  -g '!/.git/**' \
  -g '!/DerivedData/**' \
  -g '!/build/**' \
  -g '!/node_modules/**' \
  -g '!/landing-page/.next/**' \
  "$OPENAI_KEY_PATTERN" .; then
  fail "Potential OpenAI API key found in source tree. Rotate the key and remove it before release."
fi

if [[ "$CHECK_SOURCE_STATE" -eq 1 ]]; then
  log "Verifying release source state"
  source_state_args=()
  [[ -z "$EXPECTED_VERSION" ]] || source_state_args+=(--expected-version "$EXPECTED_VERSION")
  [[ -z "$EXPECTED_BUILD" ]] || source_state_args+=(--expected-build "$EXPECTED_BUILD")
  [[ -z "$EXPECTED_TAG" ]] || source_state_args+=(--expected-tag "$EXPECTED_TAG")
  scripts/verify-release-source-state.sh "${source_state_args[@]}"
fi

log "Quitting running Voiyce copies"
pkill -f 'Voiyce.app/Contents/MacOS/Voiyce' 2>/dev/null || true

log "Running macOS unit tests"
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination 'platform=macOS' \
  test \
  -only-testing:Voiyce-AgentTests

if [[ "$RUN_UI_TESTS" -eq 1 ]]; then
  log "Running macOS UI tests"
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination 'platform=macOS' \
    test \
    -only-testing:Voiyce-AgentUITests
else
log "Skipping macOS UI tests (--skip-ui-tests)"
fi

log "Verifying agent usage-cap matrix"
scripts/verify-agent-usage-caps.sh --skip-deno-tests

log "Running backend function tests"
deno test --allow-env \
  insforge/functions/*/*.test.ts

if [[ -f landing-page/package.json ]]; then
  log "Running launch site verification"
  scripts/verify-launch-site.sh
fi

log "Building Release app"
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  build

RELEASE_APP="$ROOT_DIR/DerivedData/Voiyce-Agent/Build/Products/Release/Voiyce.app"
if [[ -d "$RELEASE_APP" ]]; then
  log "Scanning built Release app for leaked OpenAI API keys"
  if rg -n --hidden --text "$OPENAI_KEY_PATTERN" "$RELEASE_APP"; then
    fail "Potential OpenAI API key found in built Release app bundle."
  fi
fi

if [[ "$RUN_ARCHIVE_CHECK" -eq 1 ]]; then
  log "Running temporary Release archive verification"
  scripts/verify-release-archive.sh
fi

if [[ "$RUN_PACKAGE" -eq 1 ]]; then
  log "Packaging signed local DMG"
  scripts/release-macos-dmg.sh --skip-notarize --clean

  if [[ -d build/release/export/Voiyce.app ]]; then
    log "Scanning exported app for leaked OpenAI API keys"
    if rg -n --hidden --text "$OPENAI_KEY_PATTERN" build/release/export/Voiyce.app; then
      fail "Potential OpenAI API key found in exported app bundle."
    fi
  fi
fi

if [[ "$CHECK_PUBLIC_DOWNLOAD" -eq 1 ]]; then
  require_command curl
  require_command shasum
  require_command python3

  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT

  log "Verifying public release manifest"
  curl -fsSL "${PUBLIC_BASE_URL%/}/latest.json" -o "$TMP_DIR/latest.json"
  python3 - "$TMP_DIR/latest.json" > "$TMP_DIR/manifest.tsv" <<'PY'
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
  IFS=$'\t' read -r MANIFEST_VERSION MANIFEST_BUILD MANIFEST_SHA LATEST_DMG_URL VERSIONED_DMG_URL < "$TMP_DIR/manifest.tsv"
  printf 'manifest version=%s build=%s\n' "$MANIFEST_VERSION" "$MANIFEST_BUILD"

  log "Verifying public latest DMG checksum"
  mkdir -p "$TMP_DIR/latest" "$TMP_DIR/versioned"
  curl -fsSL "${LATEST_DMG_URL}.sha256" -o "$TMP_DIR/latest/Voiyce.dmg.sha256"
  curl -fsSL "$LATEST_DMG_URL" -o "$TMP_DIR/latest/Voiyce.dmg"
  (cd "$TMP_DIR/latest" && shasum -a 256 -c Voiyce.dmg.sha256)
  LATEST_SHA="$(shasum -a 256 "$TMP_DIR/latest/Voiyce.dmg" | awk '{print $1}')"
  [[ "$LATEST_SHA" == "$MANIFEST_SHA" ]] || fail "Latest DMG checksum does not match latest.json."

  log "Verifying public versioned DMG checksum"
  curl -fsSL "${VERSIONED_DMG_URL}.sha256" -o "$TMP_DIR/versioned/Voiyce.dmg.sha256"
  curl -fsSL "$VERSIONED_DMG_URL" -o "$TMP_DIR/versioned/Voiyce.dmg"
  (cd "$TMP_DIR/versioned" && shasum -a 256 -c Voiyce.dmg.sha256)
  VERSIONED_SHA="$(shasum -a 256 "$TMP_DIR/versioned/Voiyce.dmg" | awk '{print $1}')"
  [[ "$VERSIONED_SHA" == "$MANIFEST_SHA" ]] || fail "Versioned DMG checksum does not match latest.json."

  cmp -s "$TMP_DIR/latest/Voiyce.dmg" "$TMP_DIR/versioned/Voiyce.dmg" \
    || fail "Latest and versioned public DMGs differ."
fi

if [[ "$CHECK_PUBLIC_DMG" -eq 1 ]]; then
  log "Verifying public DMG mount and signature"
  scripts/verify-public-dmg.sh --base-url "$PUBLIC_BASE_URL"
fi

if [[ "$CHECK_PRODUCTION_LANDING" -eq 1 ]]; then
  log "Verifying production landing site"
  scripts/verify-production-landing.sh "$PRODUCTION_LANDING_URL"
fi

log "Release verification passed"
