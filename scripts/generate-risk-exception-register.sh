#!/usr/bin/env bash

set -euo pipefail

# This helper prints a launch risk and exception register only.
# It does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, charge users, or mutate external services.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_VERSION="1.0"
EXPECTED_BUILD="16"
EXPECTED_TAG="v1.0+16"
PRODUCTION_URL="${PRODUCTION_LANDING_URL:-https://voiyce.us}"
SUPPORT_EMAIL="aki.b@pentridgemedia.com"

usage() {
  cat <<'EOF'
Usage: scripts/generate-risk-exception-register.sh [--expected-version <version>] [--expected-build <build>] [--expected-tag <tag>] [--production-url <url>]

Prints a markdown launch risk and exception register for accepted P2s, skipped
diagnostics, manual UAT gaps, production/account blockers, support exceptions,
workaround copy, owner assignment, hold triggers, and final invite/release
decision. This script is read-only and does not read secret values, write files,
stage, commit, tag, build, package, deploy, notarize, upload, charge users, or
mutate external services.

Examples:
  scripts/generate-risk-exception-register.sh
  scripts/generate-risk-exception-register.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --expected-version)
      [[ $# -ge 2 ]] || { echo "error: --expected-version requires a value" >&2; exit 2; }
      EXPECTED_VERSION="$2"
      shift 2
      ;;
    --expected-build)
      [[ $# -ge 2 ]] || { echo "error: --expected-build requires a value" >&2; exit 2; }
      EXPECTED_BUILD="$2"
      shift 2
      ;;
    --expected-tag)
      [[ $# -ge 2 ]] || { echo "error: --expected-tag requires a value" >&2; exit 2; }
      EXPECTED_TAG="$2"
      shift 2
      ;;
    --production-url)
      [[ $# -ge 2 ]] || { echo "error: --production-url requires a value" >&2; exit 2; }
      PRODUCTION_URL="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

cd "$ROOT_DIR"

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'unknown')"
HEAD_SHA="$(git rev-parse HEAD 2>/dev/null || printf 'unknown')"
DIRTY_COUNT="$(git status --porcelain=v1 --untracked-files=all | sed '/^$/d' | wc -l | tr -d ' ')"

cat <<EOF
### Launch Risk And Exception Register - YYYY-MM-DD

- Register owner:
- Support contact: ${SUPPORT_EMAIL}
- Production URL: ${PRODUCTION_URL}
- Release version/build/tag: ${EXPECTED_VERSION} / ${EXPECTED_BUILD} / ${EXPECTED_TAG}
- Current branch: ${BRANCH}
- Current HEAD: ${HEAD_SHA}
- Current dirty path count: ${DIRTY_COUNT}
- Decision: continue / hold / narrow invite
- Final owner sign-off:

#### Risk Rows

| ID | Type | Severity | Surface | Description | User impact | Workaround or mitigation | Escalates to hold when | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RISK-001 | accepted P2 / skipped diagnostic / manual UAT gap / external blocker / support exception | P0 / P1 / P2 / P3 | landing / auth / download / DMG / app / backend / billing / account / support |  |  |  |  |  | open / accepted / fixed / hold |

#### Required Checks

- No accepted P0/P1 exceptions:
- Every accepted P2 has user-facing workaround copy:
- Every skipped diagnostic has owner-approved manual coverage:
- Every manual UAT gap has replacement evidence or hold decision:
- Every external/account blocker has owner and next action:
- Release notes include accepted limitations:
- Support replies include accepted limitations:
- Support intake and monitoring templates cover the risk:
- Rollback or kill-switch path exists where applicable:
- No secret values copied into record:
- No raw transcripts copied into record:
- No private screenshots copied into record:
- No OAuth tokens copied into record:
- No payment details copied into record:
- No unsafe Act behavior accepted without a fix:

#### Launch Decision

- Invite/release-note decision: hold / narrow / proceed
- Narrow invite audience, if any:
- User-facing workaround copy link:
- Monitoring record link:
- Support owner:
- Engineering owner:
- Open risk blockers:

Launch hold rule: if any P0/P1 is accepted without a fix, any P2 lacks a workaround, any skipped diagnostic lacks manual replacement evidence, any manual UAT gap lacks replacement evidence, any external blocker lacks an owner/next action, or any risk could expose secrets/private data/payment issues/unsafe Act behavior, keep invites and release notes paused.
EOF
