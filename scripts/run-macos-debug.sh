#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Voiyce-Agent.xcodeproj"
SCHEME="Voiyce-Agent"
CONFIGURATION="Debug"
BUNDLE_ID="business.Voiyce-Agent"
BUILD_APP_PATH="$ROOT_DIR/DerivedData/Voiyce-Agent/Build/Products/Debug/Voiyce.app"
SKIP_BUILD=0

usage() {
  cat <<'EOF'
Usage: scripts/run-macos-debug.sh [--skip-build]

Builds the macOS app in Debug, quits the currently running local app,
and launches the fresh build from DerivedData.

Options:
  --skip-build   Reuse the existing Debug app bundle and just relaunch it.
  -h, --help     Show this help text.
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

quit_running_app() {
  osascript <<EOF >/dev/null 2>&1 || true
tell application id "$BUNDLE_ID"
  quit
end tell
EOF

  for _ in {1..20}; do
    if ! pgrep -f "$BUILD_APP_PATH/Contents/MacOS/Voiyce" >/dev/null 2>&1; then
      break
    fi
    sleep 0.2
  done

  pkill -f "$BUILD_APP_PATH/Contents/MacOS/Voiyce" >/dev/null 2>&1 || true
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build)
      SKIP_BUILD=1
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
require_command open
require_command osascript

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  log "Building Debug app"
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=macOS" \
    build \
    -quiet
fi

[[ -d "$BUILD_APP_PATH" ]] || fail "Debug app not found at $BUILD_APP_PATH"

log "Quitting running app"
quit_running_app

log "Launching fresh Debug build"
open "$BUILD_APP_PATH"

printf 'App: %s\n' "$BUILD_APP_PATH"
