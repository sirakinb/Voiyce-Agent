#!/usr/bin/env bash

set -euo pipefail

# This helper prints an invite batch worksheet only.
# It does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_VERSION="1.0"
EXPECTED_BUILD="16"
EXPECTED_TAG="v1.0+16"
PRODUCTION_URL="${PRODUCTION_LANDING_URL:-https://voiyce.us}"
SUPPORT_EMAIL="aki.b@pentridgemedia.com"

usage() {
  cat <<'EOF'
Usage: scripts/generate-invite-batch-record.sh [--expected-version <version>] [--expected-build <build>] [--expected-tag <tag>] [--production-url <url>]

Prints a markdown invite batch record for private beta and post-fix invite
waves. This script is read-only and does not read secret values, write files,
stage, commit, tag, build, package, deploy, notarize, upload, or mutate
external services.

Examples:
  scripts/generate-invite-batch-record.sh
  scripts/generate-invite-batch-record.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
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
### Invite Batch Record - YYYY-MM-DD

- Batch owner:
- Support owner:
- Monitoring owner:
- Rollback owner:
- Support contact: ${SUPPORT_EMAIL}
- Production URL: ${PRODUCTION_URL}
- Release version/build/tag: ${EXPECTED_VERSION} / ${EXPECTED_BUILD} / ${EXPECTED_TAG}
- Current branch: ${BRANCH}
- Current HEAD: ${HEAD_SHA}
- Current dirty path count: ${DIRTY_COUNT}
- Batch number:
- Target user count:
- Target persona:
- Invite source: founder list / design partner / waitlist / internal referral
- Git commit:
- Landing deployment URL/id:
- DMG URL/checksum:
- Known limitations linked:
- Pre-invite decision link:
- Launch evidence package link:
- Launch monitoring record link:
- Risk and exception register link:
- Support response owner confirmed:
- Monitoring window scheduled:
- Pause criteria sent to owners:
- Decision: send / hold / narrow
- Final owner sign-off:

#### Batch Readiness Checks

- P0/P1 queue is empty or explicitly held:
- Repeated P2 issues have workarounds:
- Production download health is passing:
- Checksum identity is clear:
- Support inbox ownership is confirmed:
- Exact artifact copy includes version/build, DMG checksum, known limitations, support email, and privacy/reset-memory guidance:
- Invite count is small enough for current support coverage:
- First-hour monitoring window is reserved before the next batch:
- Start with 3-5 high-trust users before any larger batch:

#### Pause Criteria

- Pause on any P0/P1:
- Pause on repeated install/auth/Dictation/Talk/Act/billing/privacy issue:
- Pause on production download or checksum failure:
- Pause on support inbox ownership gap:
- Pause on unsafe Act report:
- Pause on secret exposure or private-data leakage concern:

#### Privacy Review

- No secret values copied into record:
- No raw transcripts copied into record:
- No private screenshots copied into record:
- No OAuth tokens copied into record:
- No payment details copied into record:
- Invite list stored outside this record:

Do not send a new invite batch while a P0/P1 is open, a repeated P2 lacks a workaround, production download health is failing, checksum identity is unclear, support inbox ownership is missing, or the first-hour monitoring window is not covered. Pause expansion if two users in the same batch hit the same install, auth, Dictation, Talk, Act, billing, or privacy concern.
EOF
