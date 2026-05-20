#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_VERSION=""
EXPECTED_BUILD=""
EXPECTED_TAG=""

usage() {
  cat <<'EOF'
Usage: scripts/generate-release-source-disposition.sh [options]

Prints a markdown release-source disposition skeleton from the current Git
status. This script does not write files, stage, commit, tag, build, package,
deploy, upload, or mutate release artifacts.

Options:
  --expected-version <version>  Version to include in the review header.
  --expected-build <build>      Build number to include in the review header.
  --expected-tag <tag>          Intended release tag to include in the header.
  -h, --help                    Show this help text.

Example:
  scripts/generate-release-source-disposition.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
EOF
}

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 2
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
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

BRANCH_NAME="$(git branch --show-current 2>/dev/null || true)"
HEAD_SHA="$(git rev-parse HEAD 2>/dev/null || true)"
STATUS_OUTPUT="$(git status --porcelain=v1 --untracked-files=all)"
STATUS_COUNT="$(printf '%s\n' "$STATUS_OUTPUT" | sed '/^$/d' | wc -l | tr -d ' ')"

STATUS_FOR_DISPOSITION="$STATUS_OUTPUT" \
BRANCH_NAME="$BRANCH_NAME" \
HEAD_SHA="$HEAD_SHA" \
EXPECTED_VERSION="$EXPECTED_VERSION" \
EXPECTED_BUILD="$EXPECTED_BUILD" \
EXPECTED_TAG="$EXPECTED_TAG" \
STATUS_COUNT="$STATUS_COUNT" \
python3 - <<'PY'
import collections
import datetime as _dt
import os

status_lines = [line for line in os.environ.get("STATUS_FOR_DISPOSITION", "").splitlines() if line.strip()]
branch = os.environ.get("BRANCH_NAME") or "(detached)"
head = os.environ.get("HEAD_SHA") or "(unknown)"
expected_version = os.environ.get("EXPECTED_VERSION")
expected_build = os.environ.get("EXPECTED_BUILD")
expected_tag = os.environ.get("EXPECTED_TAG")
status_count = os.environ.get("STATUS_COUNT") or "0"

def surface_for(path: str) -> str:
    if " -> " in path:
        path = path.rsplit(" -> ", 1)[1]
    if "/" in path:
        return path.split("/", 1)[0] + "/"
    return "(repo root)"

def status_label(status: str) -> str:
    return {
        " M": "modified",
        "M ": "staged modified",
        "MM": "staged and unstaged modified",
        "A ": "staged added",
        " A": "added",
        "D ": "staged deleted",
        " D": "deleted",
        "R ": "renamed",
        "??": "untracked",
    }.get(status, status.strip() or "unknown")

by_status: collections.Counter[str] = collections.Counter()
by_surface: collections.defaultdict[str, list[tuple[str, str]]] = collections.defaultdict(list)

for line in status_lines:
    status = line[:2]
    path = line[3:] if len(line) > 3 else ""
    by_status[status_label(status)] += 1
    by_surface[surface_for(path)].append((status_label(status), path))

print(f"### Release Source Inclusion Review - {_dt.date.today().isoformat()}")
print()
print("- Reviewer:")
print(f"- Target release version/build: {expected_version or '<version>'}/{expected_build or '<build>'}")
print("- Target release branch:")
print(f"- Intended release tag: {expected_tag or '<tag>'}")
print(f"- Starting branch: {branch}")
print(f"- Starting HEAD: `{head}`")
print(f"- `git status --porcelain=v1 --untracked-files=all` path count: {status_count}")
print("- `scripts/verify-release-source-state.sh --expected-version <version> --expected-build <build> --expected-tag <tag> --allow-blockers --dirty-summary` result:")
print()
print("#### Dirty-Tree Disposition Summary")
print()
print("- Include-in-release path count:")
print("- Split-out/defer path count:")
print("- Remove/regenerate path count:")
print("- Generated/local-only path count:")
print("- Needs-owner-decision path count:")
print("- High-risk surfaces touched: macOS app / backend functions / landing / release scripts / legal docs / billing / auth / memory / Act mode / other")
print("- Every included path has matching test or manual evidence:")
print("- Unresolved path count before source freeze:")
print()
print("#### Recommended Review Order")
print()
print("1. Release-critical scripts, launch docs, and exact-artifact records.")
print("2. macOS app source, tests, project files, and entitlements.")
print("3. Backend functions, shared helpers, SQL, and backend tests.")
print("4. Landing page source, public assets, legal pages, and landing tests.")
print("5. Generated files, local-only folders, caches, and temporary artifacts.")
print()
print("##### Current Dirty Summary")
print()
print("| Group | Count |")
print("| --- | --- |")
for label, count in sorted(by_status.items()):
    print(f"| {label} | {count} |")
for surface, paths in sorted(by_surface.items(), key=lambda item: (-len(item[1]), item[0])):
    print(f"| {surface} | {len(paths)} |")
print()
print("#### Paths Requiring Disposition")
print()
if not status_lines:
    print("- None. Working tree is clean.")
else:
    for surface, paths in sorted(by_surface.items(), key=lambda item: (-len(item[1]), item[0])):
        print(f"##### {surface}")
        print()
        for label, path in paths:
            print(f"- [ ] `{path}` ({label}) - include / split out / remove-regenerate / generated-local-only / needs owner")
        print()
print("#### Include In Release Candidate")
print()
print("- Paths/features intentionally included:")
print("- Reason they belong in this release:")
print("- Required tests/gates:")
print()
print("#### Split Out Before Release")
print()
print("- Paths/features to move to a later branch:")
print("- Reason excluded from this release:")
print("- Owner/action:")
print()
print("#### Remove Or Regenerate")
print()
print("- Generated files to remove:")
print("- Local-only files to remove:")
print("- Regeneration command, if applicable:")
print()
print("#### Final Source-State Decision")
print()
print("- Unresolved merge conflicts: yes / no")
print("- All unrelated local changes split, removed, or documented as excluded:")
print("- Xcode version/build match target:")
print("- Release tag will be created only after clean-tree verification:")
print("- No package, notarize, upload, or R2 mutation before strict source-state passes:")
print("- Source freeze verification commands:")
print("  - `git status --porcelain=v1 --untracked-files=all`")
print("  - `scripts/verify-release-source-state.sh --expected-version <version> --expected-build <build> --expected-tag <tag>`")
print("  - `scripts/verify-launch-blockers.sh`")
print("  - `scripts/verify-release.sh --source-state-check --expected-version <version> --expected-build <build> --expected-tag <tag>`")
print("- Owner-approved exceptions:")
print("- Final owner sign-off:")
PY
