#!/usr/bin/env bash

set -euo pipefail

# This helper prints a launch evidence package skeleton only.
# It does not write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_VERSION="1.0"
EXPECTED_BUILD="16"
EXPECTED_TAG="v1.0+16"
PRODUCTION_URL="${PRODUCTION_LANDING_URL:-https://voiyce.us}"
SUPPORT_EMAIL="aki.b@pentridgemedia.com"

usage() {
  cat <<'EOF'
Usage: scripts/generate-launch-evidence-package.sh [--expected-version <version>] [--expected-build <build>] [--expected-tag <tag>] [--production-url <url>]

Prints a markdown launch evidence package skeleton with current local source
facts. This script is read-only and does not write files, stage, commit, tag,
build, package, deploy, notarize, upload, or mutate external services.

Examples:
  scripts/generate-launch-evidence-package.sh
  scripts/generate-launch-evidence-package.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
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
TAG_SHA="$(git rev-parse -q --verify "${EXPECTED_TAG}^{commit}" 2>/dev/null || true)"
TAG_STATUS="missing"
if [[ -n "$TAG_SHA" ]]; then
  if [[ "$TAG_SHA" == "$HEAD_SHA" ]]; then
    TAG_STATUS="points at HEAD"
  else
    TAG_STATUS="points at ${TAG_SHA}"
  fi
fi

cat <<EOF
### Launch Evidence Package - YYYY-MM-DD

- Evidence owner:
- Support contact: ${SUPPORT_EMAIL}
- Production URL: ${PRODUCTION_URL}
- Expected version/build/tag: ${EXPECTED_VERSION} / ${EXPECTED_BUILD} / ${EXPECTED_TAG}
- Current branch: ${BRANCH}
- Current HEAD: ${HEAD_SHA}
- Release tag status: ${TAG_STATUS}
- Current dirty path count: ${DIRTY_COUNT}
- Evidence folder/link:
- Naming pattern: voiyce-${EXPECTED_VERSION}+${EXPECTED_BUILD}-YYYY-MM-DD-<surface>-<check>
- Command output files reviewed for secrets/private data:
- Screenshots/recordings reviewed for secrets/private data:
- Dashboard screenshots redacted:
- Support exports reviewed before sharing:
- Missing or redacted evidence has owner, reason, and replacement proof:

#### Required Command Evidence

- \`scripts/audit-launch-readiness.sh --allow-blockers\` result:
- \`scripts/verify-release-source-state.sh --expected-version ${EXPECTED_VERSION} --expected-build ${EXPECTED_BUILD} --expected-tag '${EXPECTED_TAG}' --allow-blockers --dirty-summary\` result:
- \`scripts/generate-release-source-disposition.sh --expected-version ${EXPECTED_VERSION} --expected-build ${EXPECTED_BUILD} --expected-tag '${EXPECTED_TAG}'\` output reviewed:
- \`scripts/verify-launch-site.sh --url http://localhost:23000 --visual\` result:
- \`scripts/verify-production-landing.sh ${PRODUCTION_URL}\` result:
- \`scripts/verify-rollback-readiness.sh\` result:
- \`scripts/verify-release.sh --source-state-check --expected-version ${EXPECTED_VERSION} --expected-build ${EXPECTED_BUILD} --expected-tag '${EXPECTED_TAG}' --archive-check --public-download-check --public-dmg-check --production-landing-check\` result:

#### Source And Artifact Evidence

- Release source inclusion decision:
- Exact release commit:
- Exact release tag:
- Build number:
- Local archive path:
- Local DMG path:
- DMG SHA-256:
- Notarization/stapling evidence:
- Public latest DMG URL:
- Public versioned DMG URL:
- Public manifest URL:
- Public DMG checksum match:
- Clean install evidence:

#### Production And Account Evidence

- OpenAI key rotation evidence, without secret values:
- Server-side-only key evidence:
- InsForge function env evidence, without secret values:
- Vercel deployment URL/id:
- Cloudflare R2 artifact identity:
- Stripe mode/products/prices/webhooks:
- Support inbox owner and first-hour coverage:
- Support inbox test-message evidence:
- First reply template evidence:
- P0/P1 escalation path evidence:
- Rollback owner and rollback evidence:

#### Manual UAT Evidence

- Clean install and onboarding:
- Dictation:
- Context and memory:
- Talk Mode:
- Act Mode:
- Website, auth, download, and legal:
- Visual, keyboard, VoiceOver, motion, and contrast:
- Billing, account limits, and access:
- Resilience and recovery:
- Exploratory QA:

#### Rollback Readiness Evidence

- Landing rollback deployment/id:
- R2 previous candidate and rollback manifest evidence:
- Backend function rollback owner and target:
- App artifact rollback target:
- Rollback verifier result:
- Resume-after-rollback checklist evidence:

#### Privacy And Security Evidence

- Source secret scan:
- Landing build secret scan:
- Built app secret scan:
- Mounted DMG secret scan:
- Support export redaction:
- Agent Log redaction:
- Local memory/screenshot retention:
- Privacy policy and Terms support-contact match:
- No raw transcripts, private screenshots, OAuth tokens, payment details, or secrets included:

#### Risk And Exception Register

- Every accepted limitation has user-facing workaround copy:
- Every skipped automated diagnostic has owner-approved replacement evidence:
- Every external/account blocker has owner and next action:
- Every P0/P1 remains a hold unless fixed, rolled back, or explicitly owner-held:
- Every P2 without workaround remains a hold:
- Any secret/private-data/payment/unsafe-Act risk reviewed:
- Release notes and support replies match accepted limitations:
- Risk register reviewed by owner:

#### Launch Decision Evidence

- Open P0/P1 blockers:
- Accepted P2 limitations and workarounds:
- Skipped diagnostics and replacement manual evidence:
- External/account blockers, owners, and next actions:
- Invite/release-note decision: hold / narrow invite / broader invite
- Final owner sign-off:

No package, notarize, upload, deploy, tag, or R2 mutation before strict source-state and exact-candidate checks pass:
EOF
