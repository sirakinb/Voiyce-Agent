#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Voiyce-Agent.xcodeproj"
SCHEME="Voiyce-Agent"
APP_NAME="Voiyce"
ARCHIVE_DIR=""
KEEP_ARCHIVE=0
OPENAI_KEY_PATTERN="sk-proj-[A-Za-z0-9_-]{20,}|OPENAI_API_KEY=.*sk-[A-Za-z0-9_-]{20,}"

usage() {
  cat <<'EOF'
Usage: scripts/verify-release-archive.sh [--archive-dir <dir>] [--keep]

Builds a temporary Release archive to verify the Xcode archive path without
exporting an app, creating a DMG, notarizing, uploading, or changing the
existing build/release artifacts.

Options:
  --archive-dir <dir>  Directory where the archive check should write output.
                       Defaults to a temporary directory that is deleted after
                       a successful run.
  --keep               Keep the generated archive directory for inspection.
  -h, --help           Show this help text.
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
    --archive-dir)
      [[ $# -ge 2 ]] || fail "--archive-dir requires a value"
      ARCHIVE_DIR="$2"
      shift 2
      ;;
    --keep)
      KEEP_ARCHIVE=1
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
require_command rg

[[ -f "$PROJECT_PATH/project.pbxproj" ]] || fail "Xcode project not found at $PROJECT_PATH"

if [[ -z "$ARCHIVE_DIR" ]]; then
  ARCHIVE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/voiyce-release-archive-check.XXXXXX")"
else
  mkdir -p "$ARCHIVE_DIR"
fi

if [[ "$KEEP_ARCHIVE" -eq 0 ]]; then
  trap 'rm -rf "$ARCHIVE_DIR"' EXIT
fi

ARCHIVE_PATH="$ARCHIVE_DIR/$SCHEME.xcarchive"
RESULT_BUNDLE_PATH="$ARCHIVE_DIR/$SCHEME.xcresult"
APP_PATH="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"

rm -rf "$ARCHIVE_PATH" "$RESULT_BUNDLE_PATH"

cd "$ROOT_DIR"

log "Archiving Release app to a temporary directory"
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  -resultBundlePath "$RESULT_BUNDLE_PATH" \
  archive

[[ -d "$ARCHIVE_PATH" ]] || fail "Archive was not created at $ARCHIVE_PATH"
[[ -d "$APP_PATH" ]] || fail "Archived app was not created at $APP_PATH"

log "Verifying archived app signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

log "Scanning archived app for leaked OpenAI API keys"
if rg -n --hidden --text "$OPENAI_KEY_PATTERN" "$APP_PATH"; then
  fail "Potential OpenAI API key found in archived app bundle."
fi

log "Release archive verification passed"
printf 'Archive: %s\n' "$ARCHIVE_PATH"
if [[ "$KEEP_ARCHIVE" -eq 0 ]]; then
  printf 'Temporary archive will be removed at exit.\n'
else
  printf 'Archive was kept for inspection.\n'
fi
