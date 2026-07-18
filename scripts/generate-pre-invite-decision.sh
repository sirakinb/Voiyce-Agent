#!/usr/bin/env bash

set -euo pipefail

# This helper prints a pre-invite launch decision skeleton only.
# It does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_VERSION="1.0"
EXPECTED_BUILD="16"
EXPECTED_TAG="v1.0+16"
PRODUCTION_URL="${PRODUCTION_LANDING_URL:-https://voiyce.us}"
SUPPORT_EMAIL="aki.b@pentridgemedia.com"

usage() {
  cat <<'EOF'
Usage: scripts/generate-pre-invite-decision.sh [--expected-version <version>] [--expected-build <build>] [--expected-tag <tag>] [--production-url <url>]

Prints a markdown pre-invite launch/no-launch decision skeleton with current
local source facts. This script is read-only and does not read secret values,
write files, stage, commit, tag, build, package, deploy, notarize, upload, or
mutate external services.

Examples:
  scripts/generate-pre-invite-decision.sh
  scripts/generate-pre-invite-decision.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
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
### Pre-Invite Decision - YYYY-MM-DD

- Decision: ship / hold / narrow invite
- Decision owner:
- Support contact: ${SUPPORT_EMAIL}
- Production URL: ${PRODUCTION_URL}
- Release version/build: ${EXPECTED_VERSION} / ${EXPECTED_BUILD}
- Release Git commit:
- Current branch: ${BRANCH}
- Current HEAD: ${HEAD_SHA}
- Release tag: ${EXPECTED_TAG}
- Release tag status: ${TAG_STATUS}
- Current dirty path count: ${DIRTY_COUNT}
- DMG URL:
- DMG checksum:
- Landing deployment URL/id:
- R2 manifest URL:
- Support owner:
- Rollback owner:
- Evidence package link:
- Privacy/security review link:
- Manual UAT pass link:

#### Required Evidence

- Source-state command/result:
- Release-source disposition result:
- Package/archive command/result:
- Launch-site command/result:
- Production-landing command/result:
- Public-download command/result:
- Public-DMG command/result:
- Clean-machine install evidence:
- Manual UAT evidence:
- Production environment evidence without secret values:
- OpenAI key rotation evidence without secret values:
- Stripe/account evidence:
- Support inbox evidence:
- Rollback readiness evidence:
- Privacy/security review evidence:

#### Blocking Decision Checks

- Open P0/P1 blockers:
- Launch-readiness audit blockers:
- Release source tree committed, tagged, and reproducible:
- Exposed OpenAI API key revoked and replaced server-side:
- Package gate passes on the release branch:
- Clean public DMG install passes:
- Act Mode Phase 2 UAT matrix passes:
- Production landing/download/R2 verification after release:
- Internal clean-machine install:
- Internal Dictation, Context, Talk, and Act manual UAT:

#### Launch Decision

- Accepted P2 limitations:
- User-facing workaround copy:
- Release notes match exact artifact:
- Support/contact copy match exact artifact:
- Support inbox first-response path tested:
- Rollback path tested:
- No secrets copied into docs/support/chat:
- No raw transcripts, private screenshots, OAuth tokens, or payment details copied:
- Owner-approved exceptions:
- Invite/release-note decision: hold / narrow invite / broader invite
- Final owner sign-off:

Hold if any P0/P1 blocker, unresolved source-state mismatch, unrotated exposed key, failed package gate, failed clean install, failed core manual UAT, stale production landing, broken R2/download verification, missing support path, missing rollback path, or copied secret/private data remains:
EOF
