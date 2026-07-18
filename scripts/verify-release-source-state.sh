#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/Voiyce-Agent.xcodeproj/project.pbxproj"
EXPECTED_VERSION=""
EXPECTED_BUILD=""
EXPECTED_TAG=""
ALLOW_BLOCKERS=0
DIRTY_SUMMARY=0

usage() {
  cat <<'EOF'
Usage: scripts/verify-release-source-state.sh [options]

Verifies that the current source tree is suitable for a reproducible release.
This script does not build, package, deploy, upload, tag, or mutate files.

Checks:
  1. The command is running inside this Git worktree.
  2. The working tree has no tracked, untracked, or merge-conflict changes.
  3. Xcode MARKETING_VERSION and CURRENT_PROJECT_VERSION are present and
     optionally match the expected release version/build.
  4. An optional expected Git tag exists and points at HEAD.

Options:
  --expected-version <version>  Require every MARKETING_VERSION to match.
  --expected-build <build>      Require every CURRENT_PROJECT_VERSION to match.
  --expected-tag <tag>          Require the tag to exist and point at HEAD.
  --allow-blockers             Print blockers but exit 0 for prep-stage audits.
  --dirty-summary               Print a non-mutating dirty-tree status summary.
  -h, --help                   Show this help text.

Examples:
  scripts/verify-release-source-state.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
  scripts/verify-release-source-state.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --allow-blockers --dirty-summary
EOF
}

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 2
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

PASSES=()
BLOCKERS=()

pass() {
  PASSES+=("$1")
}

blocker() {
  BLOCKERS+=("$1")
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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
    --allow-blockers)
      ALLOW_BLOCKERS=1
      shift
      ;;
    --dirty-summary)
      DIRTY_SUMMARY=1
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

require_command git
require_command python3

cd "$ROOT_DIR"

GIT_TOPLEVEL="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ "$GIT_TOPLEVEL" == "$ROOT_DIR" ]]; then
  pass "Running inside the expected Git worktree"
else
  blocker "Git toplevel is ${GIT_TOPLEVEL:-not found}; expected $ROOT_DIR"
fi

HEAD_SHA="$(git rev-parse HEAD 2>/dev/null || true)"
if [[ -n "$HEAD_SHA" ]]; then
  pass "HEAD is $HEAD_SHA"
else
  blocker "HEAD could not be resolved"
fi

BRANCH_NAME="$(git branch --show-current 2>/dev/null || true)"
if [[ -n "$BRANCH_NAME" ]]; then
  pass "Current branch is $BRANCH_NAME"
else
  blocker "HEAD is detached; use a named release branch before tagging"
fi

UNMERGED="$(git diff --name-only --diff-filter=U 2>/dev/null || true)"
if [[ -z "$UNMERGED" ]]; then
  pass "No unresolved merge conflicts"
else
  blocker "Unresolved merge conflicts are present"
fi

STATUS_OUTPUT="$(git status --porcelain=v1 --untracked-files=all)"
if [[ -z "$STATUS_OUTPUT" ]]; then
  pass "Working tree is clean"
else
  STATUS_COUNT="$(printf '%s\n' "$STATUS_OUTPUT" | sed '/^$/d' | wc -l | tr -d ' ')"
  blocker "Working tree has $STATUS_COUNT tracked or untracked paths; commit, split, or remove them before tagging"
fi

if [[ "$DIRTY_SUMMARY" -eq 1 && -n "$STATUS_OUTPUT" ]]; then
  printf '\nDirty tree summary\n'
  STATUS_FOR_SUMMARY="$STATUS_OUTPUT" python3 - <<'PY'
import collections
import os
import sys

status_counts: collections.Counter[str] = collections.Counter()
surface_counts: collections.Counter[str] = collections.Counter()

def surface_for(path: str) -> str:
    path = path.strip()
    if not path:
        return "(unknown)"
    if " -> " in path:
        path = path.rsplit(" -> ", 1)[1]
    if "/" in path:
        return path.split("/", 1)[0] + "/"
    return "(repo root)"

for raw_line in os.environ.get("STATUS_FOR_SUMMARY", "").splitlines():
    line = raw_line.rstrip("\n")
    if not line:
        continue
    status = line[:2]
    path = line[3:] if len(line) > 3 else ""
    status_counts[status] += 1
    surface_counts[surface_for(path)] += 1

print("By git status:")
for status, count in sorted(status_counts.items()):
    print(f"  {status or '(blank)'}: {count}")

print("By top-level surface:")
for surface, count in sorted(surface_counts.items(), key=lambda item: (-item[1], item[0])):
    print(f"  {surface}: {count}")
PY
fi

if [[ -f "$PROJECT_FILE" ]]; then
  PROJECT_VALUES="$(python3 - "$PROJECT_FILE" <<'PY'
import re
import sys

text = open(sys.argv[1], encoding="utf-8").read()

def values(key: str) -> str:
    found = sorted({value.strip().strip('"') for value in re.findall(rf"\b{key}\s*=\s*([^;]+);", text)})
    if not found:
        raise SystemExit(f"missing {key}")
    return ",".join(found)

print(values("MARKETING_VERSION"))
print(values("CURRENT_PROJECT_VERSION"))
PY
)"
  MARKETING_VERSIONS="$(printf '%s\n' "$PROJECT_VALUES" | sed -n '1p')"
  BUILD_VERSIONS="$(printf '%s\n' "$PROJECT_VALUES" | sed -n '2p')"
  pass "Xcode MARKETING_VERSION values: $MARKETING_VERSIONS"
  pass "Xcode CURRENT_PROJECT_VERSION values: $BUILD_VERSIONS"

  if [[ -n "$EXPECTED_VERSION" ]]; then
    if [[ "$MARKETING_VERSIONS" == "$EXPECTED_VERSION" ]]; then
      pass "MARKETING_VERSION matches expected $EXPECTED_VERSION"
    else
      blocker "MARKETING_VERSION is $MARKETING_VERSIONS; expected $EXPECTED_VERSION"
    fi
  fi

  if [[ -n "$EXPECTED_BUILD" ]]; then
    if [[ "$BUILD_VERSIONS" == "$EXPECTED_BUILD" ]]; then
      pass "CURRENT_PROJECT_VERSION matches expected $EXPECTED_BUILD"
    else
      blocker "CURRENT_PROJECT_VERSION is $BUILD_VERSIONS; expected $EXPECTED_BUILD"
    fi
  fi
else
  blocker "Xcode project file is missing: $PROJECT_FILE"
fi

if [[ -n "$EXPECTED_TAG" ]]; then
  TAG_SHA="$(git rev-parse -q --verify "refs/tags/$EXPECTED_TAG^{commit}" 2>/dev/null || true)"
  if [[ -z "$TAG_SHA" ]]; then
    blocker "Expected release tag $EXPECTED_TAG does not exist"
  elif [[ "$TAG_SHA" == "$HEAD_SHA" ]]; then
    pass "Release tag $EXPECTED_TAG points at HEAD"
  else
    blocker "Release tag $EXPECTED_TAG points at $TAG_SHA, not HEAD $HEAD_SHA"
  fi
else
  pass "No expected release tag requested"
fi

printf '\nRelease source-state result\n'
printf 'Passed checks: %s\n' "${#PASSES[@]}"
for item in "${PASSES[@]}"; do
  printf '  ok: %s\n' "$item"
done

if [[ "${#BLOCKERS[@]}" -gt 0 ]]; then
  printf '\nSource state: BLOCKED (%s blockers)\n' "${#BLOCKERS[@]}"
  for item in "${BLOCKERS[@]}"; do
    printf '  blocker: %s\n' "$item"
  done
  if [[ "$ALLOW_BLOCKERS" -eq 1 ]]; then
    printf '\nBlockers were allowed for this prep-stage source audit.\n'
    exit 0
  fi
  exit 1
fi

printf '\nSource state: READY for reproducible release tagging.\n'
