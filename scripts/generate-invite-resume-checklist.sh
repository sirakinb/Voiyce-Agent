#!/usr/bin/env bash

set -euo pipefail

# This helper prints an invite resume checklist only.
# It does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_VERSION="1.0"
EXPECTED_BUILD="16"
EXPECTED_TAG="v1.0+16"
PRODUCTION_URL="${PRODUCTION_LANDING_URL:-https://voiyce.us}"
SUPPORT_EMAIL="aki.b@pentridgemedia.com"

usage() {
  cat <<'EOF'
Usage: scripts/generate-invite-resume-checklist.sh [--expected-version <version>] [--expected-build <build>] [--expected-tag <tag>] [--production-url <url>]

Prints a markdown invite-resume checklist for restarting beta invites after a
pause, incident, failed verification command, backend change, landing
deployment, billing configuration change, or DMG/artifact change. This script
is read-only and does not read secret values, write files, stage, commit, tag,
build, package, deploy, notarize, upload, or mutate external services.

Examples:
  scripts/generate-invite-resume-checklist.sh
  scripts/generate-invite-resume-checklist.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
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
### Invite Resume Checklist - YYYY-MM-DD

- Resume owner:
- Support owner:
- Monitoring owner:
- Rollback owner:
- Support contact: ${SUPPORT_EMAIL}
- Production URL: ${PRODUCTION_URL}
- Release version/build/tag: ${EXPECTED_VERSION} / ${EXPECTED_BUILD} / ${EXPECTED_TAG}
- Current branch: ${BRANCH}
- Current HEAD: ${HEAD_SHA}
- Current dirty path count: ${DIRTY_COUNT}
- Resume trigger: pause condition / incident / failed verification / backend change / landing deployment / billing change / DMG artifact change
- Previous pause or hold reason:
- Next invite batch link:
- Decision: resume / hold / narrow
- Final owner sign-off:

#### Required Verification

- Current P0/P1 queue is empty or each item has an owner, mitigation, and explicit hold decision:
- Any accepted P2 limitation has a user-facing workaround in beta notes or support replies:
- \`scripts/audit-launch-readiness.sh --live --allow-blockers\` shows only known prep-stage blockers, or strict mode passes for a release candidate:
- \`scripts/verify-production-landing.sh https://voiyce.us\` passes for the deployed landing page:
- \`scripts/verify-release.sh --skip-ui-tests --public-download-check --public-dmg-check --production-landing-check\` passes for the intended public artifact:
- Pre-invite decision record updated with release version/build, Git commit, DMG checksum, landing deployment, R2 manifest, support owner, and rollback owner:
- Clean-machine or clean-user install evidence is current for the exact DMG users will receive:
- Manual UAT evidence covers onboarding, Dictation, Context, Talk, Act in Strict, Agent Log, Settings, billing/account access, and legal/download paths:
- Production environment evidence covers OpenAI key rotation, InsForge function env, usage-cap decision, Vercel env, R2 objects, Stripe mode, and support inbox ownership without copying secret values:
- Rollback readiness evidence identifies the previous known-good landing deployment, R2 latest object, backend function version, app artifact, and owner:
- Support/contact/release notes match the exact artifact and still use ${SUPPORT_EMAIL}:

#### Resume Safety Checks

- Support inbox first-hour coverage scheduled:
- Support inbox first-day coverage scheduled:
- Launch monitoring record prepared:
- Invite batch record prepared:
- Known limitations and workaround copy reviewed:
- Privacy/security review remains current:
- Stripe mode and webhook status reviewed:
- OpenAI usage/quota monitoring reviewed:
- Kill-switch state reviewed:
- Pause authority confirmed:

#### Privacy Review

- No secret values copied into record:
- No raw transcripts copied into record:
- No private screenshots copied into record:
- No OAuth tokens copied into record:
- No payment details copied into record:
- Support exports reviewed before linking:

Do not resume invites if any P0/P1 remains without an explicit hold decision, any P2 lacks a workaround, production landing/download checks fail, clean-install or manual UAT evidence is stale, support coverage is unavailable, rollback ownership is unclear, OpenAI key rotation remains unresolved, or any evidence includes unreviewed secrets, raw transcripts, private screenshots, OAuth tokens, or payment details.
EOF
