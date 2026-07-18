#!/usr/bin/env bash

set -euo pipefail

# This helper prints a support inbox readiness record only.
# It does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_VERSION="1.0"
EXPECTED_BUILD="16"
EXPECTED_TAG="v1.0+16"
PRODUCTION_URL="${PRODUCTION_LANDING_URL:-https://voiyce.us}"
SUPPORT_EMAIL="aki.b@pentridgemedia.com"

usage() {
  cat <<'EOF'
Usage: scripts/generate-support-inbox-readiness.sh [--expected-version <version>] [--expected-build <build>] [--expected-tag <tag>] [--production-url <url>]

Prints a markdown support inbox readiness record for the first invite batch,
support-owner changes, and post-incident invite resume. This script is read-only
and does not read secret values, write files, stage, commit, tag, build,
package, deploy, notarize, upload, or mutate external services.

Examples:
  scripts/generate-support-inbox-readiness.sh
  scripts/generate-support-inbox-readiness.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
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
#### Support Inbox Readiness - YYYY-MM-DD

- Primary inbox:
- Support contact: ${SUPPORT_EMAIL}
- Production URL: ${PRODUCTION_URL}
- Release version/build/tag: ${EXPECTED_VERSION} / ${EXPECTED_BUILD} / ${EXPECTED_TAG}
- Current branch: ${BRANCH}
- Current HEAD: ${HEAD_SHA}
- Current dirty path count: ${DIRTY_COUNT}
- Primary support owner:
- Backup support owner:
- Engineering escalation owner:
- Billing escalation owner:
- Rollback owner:
- Monitoring cadence:
- First-hour coverage window:
- First-day coverage window:
- P0/P1 escalation path:
- P2 triage path:
- Support intake template ready:
- Support response playbook ready:
- Known limitations link:
- Clean-install evidence link:
- Launch monitoring record link:
- Risk/exception register link:
- Support export privacy review instructions ready:
- User-facing first reply template ready:
- Invite pause authority:
- Final owner sign-off:

#### Support Path Proof

- Support inbox test message sent and received:
- First reply template tested:
- Backup owner handoff tested:
- Engineering escalation tested:
- Billing escalation tested:
- Rollback owner reachable:
- P0/P1 pause decision path tested:
- P2 workaround routing tested:
- Support export redaction instructions reviewed:

#### Privacy Review

- No private user messages copied into record:
- No raw transcripts copied into record:
- No private screenshots copied into record:
- No OAuth tokens copied into record:
- No payment details copied into record:
- No secret values copied into record:
- Support exports reviewed before linking:

Hold invites if no primary owner, backup owner, or P0/P1 escalation owner is assigned. Hold invites if the inbox will not be monitored during the first-hour and first-day windows. Hold invites if support replies still ask for raw transcripts, unreviewed screenshots, OAuth tokens, payment details, or secrets. Hold invites if support cannot pause invite expansion when a P0/P1 report arrives.
EOF
