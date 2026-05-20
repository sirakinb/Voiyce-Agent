#!/usr/bin/env bash

set -euo pipefail

# This verifier runs the prep launch audit and checks that no launch blockers
# remain in the tracked closeout model. It proves no launch blockers remain.
# This script does not write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: scripts/verify-launch-blockers.sh

Runs scripts/audit-launch-readiness.sh and verifies that no tracked launch
blockers remain, with no stale-doc, generator, source-count, or verifier
regressions. This script does not write files, stage, commit, tag, build,
package, deploy, notarize, upload, or mutate external services.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 0 ]]; then
  echo "error: unknown argument: $1" >&2
  usage >&2
  exit 2
fi

cd "$ROOT_DIR"

EXPECTED_BLOCKERS=(
)

AUDIT_OUTPUT="$(scripts/audit-launch-readiness.sh)"
ACTUAL_BLOCKERS=()
while IFS= read -r blocker_line; do
  ACTUAL_BLOCKERS+=("$blocker_line")
done < <(printf '%s\n' "$AUDIT_OUTPUT" | sed -n 's/^  blocker: //p')

if [[ "${#ACTUAL_BLOCKERS[@]}" -ne "${#EXPECTED_BLOCKERS[@]}" ]]; then
  printf '%s\n' "$AUDIT_OUTPUT" >&2
  echo "error: expected ${#EXPECTED_BLOCKERS[@]} blockers, found ${#ACTUAL_BLOCKERS[@]}" >&2
  exit 1
fi

if [[ "${#EXPECTED_BLOCKERS[@]}" -gt 0 ]]; then
  for expected in "${EXPECTED_BLOCKERS[@]}"; do
    found=0
    if [[ "${#ACTUAL_BLOCKERS[@]}" -gt 0 ]]; then
      for actual in "${ACTUAL_BLOCKERS[@]}"; do
        if [[ "$actual" == "$expected" ]]; then
          found=1
          break
        fi
      done
    fi
    if [[ "$found" -ne 1 ]]; then
      printf '%s\n' "$AUDIT_OUTPUT" >&2
      echo "error: expected blocker missing: $expected" >&2
      exit 1
    fi
  done
fi

if [[ "${#ACTUAL_BLOCKERS[@]}" -gt 0 ]]; then
  for actual in "${ACTUAL_BLOCKERS[@]}"; do
    found=0
    if [[ "${#EXPECTED_BLOCKERS[@]}" -gt 0 ]]; then
      for expected in "${EXPECTED_BLOCKERS[@]}"; do
        if [[ "$actual" == "$expected" ]]; then
          found=1
          break
        fi
      done
    fi
    if [[ "$found" -ne 1 ]]; then
      printf '%s\n' "$AUDIT_OUTPUT" >&2
      echo "error: unexpected blocker found: $actual" >&2
      exit 1
    fi
  done
fi

cat <<EOF
Launch blocker verification passed
  expected blockers: ${#EXPECTED_BLOCKERS[@]}
  unexpected blockers: 0
EOF
