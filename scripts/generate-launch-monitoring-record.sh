#!/usr/bin/env bash

set -euo pipefail

# This helper prints a launch monitoring worksheet only.
# It does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_VERSION="1.0"
EXPECTED_BUILD="16"
EXPECTED_TAG="v1.0+16"
PRODUCTION_URL="${PRODUCTION_LANDING_URL:-https://voiyce.us}"
SUPPORT_EMAIL="aki.b@pentridgemedia.com"

usage() {
  cat <<'EOF'
Usage: scripts/generate-launch-monitoring-record.sh [--expected-version <version>] [--expected-build <build>] [--expected-tag <tag>] [--production-url <url>]

Prints a markdown launch monitoring record for first-hour, first-day, weekly
expansion, or after-change checks. This script is read-only and does not read
secret values, write files, stage, commit, tag, build, package, deploy,
notarize, upload, or mutate external services.

Examples:
  scripts/generate-launch-monitoring-record.sh
  scripts/generate-launch-monitoring-record.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
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
#### Launch Monitoring Record - YYYY-MM-DD HH:MM

- Monitor owner:
- Support contact: ${SUPPORT_EMAIL}
- Production URL: ${PRODUCTION_URL}
- Window: first hour / first day / weekly expansion / after change
- Release version/build/tag: ${EXPECTED_VERSION} / ${EXPECTED_BUILD} / ${EXPECTED_TAG}
- Current branch: ${BRANCH}
- Current HEAD: ${HEAD_SHA}
- Current dirty path count: ${DIRTY_COUNT}
- Git commit:
- Landing deployment URL/id:
- DMG URL/checksum:
- Invite batch number:
- Invite batch size:
- Decision: continue / pause / rollback / narrow invite

##### Surface Checks

- Website/Vercel status:
- Cloudflare R2 status:
- InsForge functions status:
- OpenAI usage/quota status:
- Stripe mode/webhook status:
- Support inbox status:
- Rollback owner reachable:
- Kill-switch state reviewed:

##### Signals

- P0 count:
- P1 count:
- P2 count:
- New support reports:
- Repeated failure pattern:
- Spend or quota anomaly:
- Download or checksum anomaly:
- Privacy/security concern:
- Unsafe Act report:
- Install or Gatekeeper report:
- Auth/account/billing report:

##### Actions

- Commands run:
- Dashboard evidence links:
- User-facing reply sent:
- Invite pause or resume decision:
- Owner-approved exception:
- Next review time:
- Final owner sign-off:

##### Privacy Review

- No secret values copied into record:
- No raw transcripts copied into record:
- No private screenshots copied into record:
- No OAuth tokens copied into record:
- No payment details copied into record:
- Support exports reviewed before linking:

Pause new invites if any P0/P1 appears, production download health fails, public DMG checksum changes unexpectedly, multiple users hit the same Talk/Act/billing failure, spend/quota jumps unexpectedly, support ownership is unavailable, or any support report suggests secret exposure, private data leakage, unsafe action, crash loop, or broken install.
EOF
