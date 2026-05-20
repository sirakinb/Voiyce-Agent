#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LANDING_DIR="$ROOT_DIR/landing-page"
CONTACT_EMAIL="aki.b@pentridgemedia.com"
LIVE_URL=""
RUN_VISUAL=0
OPENAI_KEY_PATTERN="sk-proj-[A-Za-z0-9_-]{20,}|OPENAI_API_KEY=.*sk-[A-Za-z0-9_-]{20,}"

usage() {
  cat <<'EOF'
Usage: scripts/verify-launch-site.sh [--url <base-url>] [--visual]

Runs the fast launch-readiness gate for the marketing/legal/download site:
  1. Required route and asset checks
  2. Positioning/copy guardrails
  3. Legal contact verification
  4. Landing page lint
  5. Landing page production build
  6. Optional live route, CTA, and rendered-copy checks when --url is provided
  7. Optional Chrome visual QA screenshots, layout assertions, and color-contrast checks when --visual is provided

Examples:
  scripts/verify-launch-site.sh
  scripts/verify-launch-site.sh --url http://localhost:23000
  scripts/verify-launch-site.sh --url http://localhost:23000 --visual
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

  if rg -q -F "$forbidden" "$file"; then
    fail "Found forbidden $label in $file: $forbidden"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)
      [[ $# -ge 2 ]] || fail "--url requires a value"
      LIVE_URL="$2"
      shift 2
      ;;
    --visual)
      RUN_VISUAL=1
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

require_command npm
require_command rg

cd "$ROOT_DIR"

log "Checking required landing files"
for path in \
  landing-page/src/app/page.tsx \
  landing-page/src/app/layout.tsx \
  landing-page/src/app/auth/page.tsx \
  landing-page/src/app/download/page.tsx \
  landing-page/src/app/api/download-health/route.ts \
  landing-page/src/app/privacy/page.tsx \
  landing-page/src/app/terms/page.tsx \
  landing-page/src/components/HeroAnimation.tsx \
  landing-page/src/lib/voiyce-config.ts \
  landing-page/public/hermes-agent.png \
  landing-page/public/voiyce_logo.png \
  landing-page/public/og-header.png \
  landing-page/src/app/icon.png \
  landing-page/src/app/favicon.ico
do
  [[ -e "$path" ]] || fail "Missing required file: $path"
done

log "Checking launch copy guardrails"
if rg -n -i \
  "boost productivity|revolutionize|unlock your potential|AI-powered|seamless experience|write at the speed|download for macos" \
  landing-page/src/app landing-page/src/components landing-page/src/lib; then
  fail "Forbidden or outdated launch copy found."
fi
if rg -n "<img" \
  landing-page/src/app/page.tsx \
  landing-page/src/components/AuthPageClient.tsx \
  landing-page/src/components/DownloadPageClient.tsx; then
  fail "Raw img elements found on launch-critical landing surfaces. Use next/image or non-image icon presentation."
fi

log "Checking agent context positioning"
for label in "Stop re-explaining your work to AI" "agent context layer" "Claude Code" "Codex" "Hermes Agent" "OpenClaw" "Cursor"; do
  if ! rg -q -F "$label" landing-page/src/app landing-page/src/components; then
    fail "Missing required positioning label: $label"
  fi
done
assert_file_contains "landing-page/src/app/page.tsx" "Hermes local image asset" "/hermes-agent.png"
assert_file_contains "landing-page/src/app/page.tsx" "OpenClaw local image asset" "/openclaw.svg"
if rg -n "https://openclaw[.]ai|favicon[.]svg" landing-page/src/app/page.tsx landing-page/src/components; then
  fail "OpenClaw logo must use the local /openclaw.svg asset, not a remote favicon."
fi
for label in "metadataBase: new URL(\"https://voiyce.us\")" "summary_large_image" "/og-header.png"; do
  if ! rg -q -F "$label" landing-page/src/app/layout.tsx; then
    fail "Missing required metadata label: $label"
  fi
done

log "Checking legal contact email"
assert_file_contains "landing-page/src/lib/voiyce-config.ts" "support email constant" "$CONTACT_EMAIL"
assert_file_contains "landing-page/src/lib/voiyce-config.ts" "support mailto constant" 'supportMailto = `mailto:${supportEmail}`'
for file in landing-page/src/app/terms/page.tsx landing-page/src/app/privacy/page.tsx; do
  assert_file_contains "$file" "support email import" "supportEmail"
  assert_file_contains "$file" "support mailto import" "supportMailto"
done
if rg -n "support@voiyce\.com" landing-page/src/app/terms/page.tsx landing-page/src/app/privacy/page.tsx; then
  fail "Outdated legal support email found in Terms or Privacy."
fi

log "Checking legal product coverage"
for label in "Screen context" "Local memory" "support export" "OpenAI" "VideoDB"; do
  if ! rg -q -F "$label" landing-page/src/app/privacy/page.tsx; then
    fail "Privacy Policy is missing required product coverage: $label"
  fi
done
for label in "Session only" "30 days" "90 days" "Forever" "Raw screenshots" "Private Mode" "app/site" "exclusions skip matching memory writes" "Voiyce-written" "vault notes"; do
  if ! rg -q -F "$label" landing-page/src/app/privacy/page.tsx; then
    fail "Privacy Policy is missing concrete local storage coverage: $label"
  fi
done
for label in "context capture" "local memory" "agent handoff" "screen context"; do
  if ! rg -q -i -F "$label" landing-page/src/app/terms/page.tsx; then
    fail "Terms of Service is missing required product coverage: $label"
  fi
done

log "Checking download URL fallback"
assert_file_contains "landing-page/src/lib/voiyce-config.ts" "default download URL" "DEFAULT_DOWNLOAD_URL"
assert_file_contains "landing-page/src/lib/voiyce-config.ts" "trimmed download URL env" "configuredDownloadUrl"
assert_file_contains "landing-page/src/lib/voiyce-config.ts" "blank download URL fallback" "configuredDownloadUrl || DEFAULT_DOWNLOAD_URL"
assert_file_contains "landing-page/src/app/api/download-health/route.ts" "download health HEAD check" 'method: "HEAD"'
assert_file_contains "landing-page/src/app/api/download-health/route.ts" "download health failure status" "status: 503"
assert_file_contains "landing-page/src/components/DownloadPageClient.tsx" "download source loading state" "Preparing your download"
assert_file_contains "landing-page/src/components/DownloadPageClient.tsx" "download source ready state" "Your account is ready. Install Voiyce on your Mac."
assert_file_contains "landing-page/src/components/DownloadPageClient.tsx" "download health API check" "/api/download-health"
assert_file_contains "landing-page/src/components/DownloadPageClient.tsx" "download failure recovery copy" "Download service needs attention"
assert_file_contains "landing-page/src/components/DownloadPageClient.tsx" "download failure support email" "supportEmail"
assert_file_contains "landing-page/src/components/DownloadPageClient.tsx" "manual download href" "href={downloadUrl}"
assert_file_contains "landing-page/src/components/DownloadPageClient.tsx" "automatic download iframe" "frame.src = downloadUrl"

log "Checking auth recovery copy"
assert_file_contains "landing-page/src/components/AuthPageClient.tsx" "auth source headline" "Create your account"
assert_file_contains "landing-page/src/components/AuthPageClient.tsx" "auth source primary action" "Continue to download"
assert_file_contains "landing-page/src/components/AuthPageClient.tsx" "auth source terms link" 'href="/terms"'
assert_file_contains "landing-page/src/components/AuthPageClient.tsx" "auth source privacy link" 'href="/privacy"'
assert_file_contains "landing-page/src/components/AuthPageClient.tsx" "auth network recovery copy" "Check your connection, then try again."
assert_file_contains "landing-page/src/components/AuthPageClient.tsx" "auth credential recovery copy" "That email or password did not match."
assert_file_contains "landing-page/src/components/AuthPageClient.tsx" "auth support email" "supportEmail"
assert_file_not_contains "landing-page/src/components/AuthPageClient.tsx" "raw auth error return" "return error.message"
assert_file_not_contains "landing-page/src/components/AuthPageClient.tsx" "vague auth error copy" "Something went wrong. Please try again."

log "Checking accessibility smoke guardrails"
assert_file_contains "landing-page/src/app/layout.tsx" "html lang" 'lang="en"'
assert_file_contains "landing-page/src/app/layout.tsx" "skip link" 'href="#main-content"'
assert_file_contains "landing-page/src/app/layout.tsx" "main landmark" 'id="main-content"'
assert_file_contains "landing-page/src/app/globals.css" "keyboard focus style" ":focus-visible"
assert_file_contains "landing-page/src/app/globals.css" "skip link style" ".skip-link"

log "Running landing page lint"
(cd "$LANDING_DIR" && npm run lint -- --max-warnings=0)

log "Building landing page"
(cd "$LANDING_DIR" && npm run build)

log "Scanning landing build for leaked OpenAI API keys"
if rg -n --hidden --text "$OPENAI_KEY_PATTERN" "$LANDING_DIR/.next"; then
  fail "Potential OpenAI API key found in landing build output."
fi

if [[ -n "$LIVE_URL" ]]; then
  require_command curl
  require_command python3
  BASE="${LIVE_URL%/}"
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT

  log "Checking live routes at $BASE"
  curl -fsSL "$BASE/" -o "$TMP_DIR/home.html" || fail "Live route failed: $BASE/"
  curl -fsSL "$BASE/auth?intent=download" -o "$TMP_DIR/auth.html" \
    || fail "Live route failed: $BASE/auth?intent=download"
  curl -fsSL "$BASE/download?intent=download" -o "$TMP_DIR/download.html" \
    || fail "Live route failed: $BASE/download?intent=download"
  curl -fsSL "$BASE/api/download-health" -o "$TMP_DIR/download-health.json" \
    || fail "Live download health route failed: $BASE/api/download-health"
  curl -fsSL "$BASE/privacy" -o "$TMP_DIR/privacy.html" || fail "Live route failed: $BASE/privacy"
  curl -fsSL "$BASE/terms" -o "$TMP_DIR/terms.html" || fail "Live route failed: $BASE/terms"
  curl -fsSL "$BASE/icon.png" -o "$TMP_DIR/icon.png" || fail "Live icon route failed: $BASE/icon.png"
  curl -fsSL "$BASE/favicon.ico" -o "$TMP_DIR/favicon.ico" || fail "Live favicon route failed: $BASE/favicon.ico"
  curl -fsSL "$BASE/og-header.png" -o "$TMP_DIR/og-header.png" || fail "Live OG image route failed: $BASE/og-header.png"

  for file in "$TMP_DIR"/*.html; do
    [[ -s "$file" ]] || fail "Live route returned an empty response: $file"
  done

  log "Checking live social image and favicon payloads"
  python3 - "$TMP_DIR/icon.png" "$TMP_DIR/og-header.png" "$TMP_DIR/favicon.ico" <<'PY' \
    || fail "Live social image or favicon payload validation failed."
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

  log "Checking live home page content and CTAs"
  assert_file_contains "$TMP_DIR/home.html" "home headline" "Stop re-explaining"
  assert_file_contains "$TMP_DIR/home.html" "home headline continuation" "your work to AI"
  assert_file_contains "$TMP_DIR/home.html" "agent context positioning" "agent context layer"
  assert_file_contains "$TMP_DIR/home.html" "auth CTA href" 'href="/auth?intent=download"'
  assert_file_contains "$TMP_DIR/home.html" "how-it-works anchor" 'href="#how-it-works"'
  assert_file_contains "$TMP_DIR/home.html" "privacy footer link" 'href="/privacy"'
  assert_file_contains "$TMP_DIR/home.html" "terms footer link" 'href="/terms"'
  for agent in "Claude Code" "Codex" "Hermes Agent" "OpenClaw" "Cursor"; do
    assert_file_contains "$TMP_DIR/home.html" "agent label" "$agent"
  done
  assert_file_not_contains "$TMP_DIR/home.html" "removed agent label" "ChatGPT"
  assert_file_not_contains "$TMP_DIR/home.html" "removed agent label" "Make.com"

  log "Checking live auth, download, and legal content"
  assert_file_contains "$TMP_DIR/auth.html" "auth route title" "Create Account"
  assert_file_contains "$TMP_DIR/auth.html" "auth route metadata" "Create your Voiyce account"
  assert_file_contains "$TMP_DIR/download.html" "download route title" "Download For Mac"
  assert_file_contains "$TMP_DIR/download.html" "download route metadata" "Download the Voiyce Mac app"
  assert_file_contains "$TMP_DIR/download-health.json" "download health ok" '"ok":true'
  assert_file_contains "$TMP_DIR/privacy.html" "privacy title" "Privacy Policy"
  assert_file_contains "$TMP_DIR/privacy.html" "privacy contact" "$CONTACT_EMAIL"
  assert_file_contains "$TMP_DIR/privacy.html" "privacy screen coverage" "Screen context"
  assert_file_contains "$TMP_DIR/privacy.html" "privacy memory coverage" "Local memory"
  assert_file_contains "$TMP_DIR/privacy.html" "privacy local retention coverage" "Session only"
  assert_file_contains "$TMP_DIR/privacy.html" "privacy raw screenshot coverage" "Raw screenshots"
  assert_file_contains "$TMP_DIR/privacy.html" "privacy private mode coverage" "Private Mode"
  assert_file_contains "$TMP_DIR/privacy.html" "privacy exclusion coverage" "app/site"
  assert_file_contains "$TMP_DIR/privacy.html" "privacy vault-delete coverage" "Voiyce-written"
  assert_file_contains "$TMP_DIR/privacy.html" "privacy vault-delete coverage" "vault notes"
  assert_file_contains "$TMP_DIR/terms.html" "terms title" "Terms of Service"
  assert_file_contains "$TMP_DIR/terms.html" "terms contact" "$CONTACT_EMAIL"
  assert_file_contains "$TMP_DIR/terms.html" "terms context coverage" "context capture"
  assert_file_contains "$TMP_DIR/terms.html" "terms memory coverage" "local memory"

  if [[ "$RUN_VISUAL" -eq 1 ]]; then
    require_command node

    log "Running live visual QA"
    node "$ROOT_DIR/scripts/verify-launch-visuals.mjs" --url "$BASE"
  fi
elif [[ "$RUN_VISUAL" -eq 1 ]]; then
  fail "--visual requires --url so Chrome can load the rendered site."
fi

log "Launch site verification passed"
