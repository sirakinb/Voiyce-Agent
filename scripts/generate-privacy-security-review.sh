#!/usr/bin/env bash

set -euo pipefail

# This helper prints a privacy/security review worksheet only.
# It does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_VERSION="1.0"
EXPECTED_BUILD="16"
EXPECTED_TAG="v1.0+16"
PRODUCTION_URL="${PRODUCTION_LANDING_URL:-https://voiyce.us}"
SUPPORT_EMAIL="aki.b@pentridgemedia.com"

usage() {
  cat <<'EOF'
Usage: scripts/generate-privacy-security-review.sh [--expected-version <version>] [--expected-build <build>] [--expected-tag <tag>] [--production-url <url>]

Prints a markdown privacy/security review worksheet with current local source
facts. This script is read-only and does not read secret values, write files,
stage, commit, tag, build, package, deploy, notarize, upload, or mutate external
services.

Examples:
  scripts/generate-privacy-security-review.sh
  scripts/generate-privacy-security-review.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
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
### Privacy And Security Review - YYYY-MM-DD

- Reviewer:
- Support contact: ${SUPPORT_EMAIL}
- Production URL: ${PRODUCTION_URL}
- Expected version/build/tag: ${EXPECTED_VERSION} / ${EXPECTED_BUILD} / ${EXPECTED_TAG}
- Current branch: ${BRANCH}
- Current HEAD: ${HEAD_SHA}
- Current dirty path count: ${DIRTY_COUNT}
- Evidence folder/link:
- Dashboard screenshots redacted:
- Command outputs reviewed for secrets/private data:
- Screenshots/recordings reviewed for secrets/private data:
- Support exports reviewed before sharing:
- Review decision: pass / hold

#### Secret And Bundle Checks

- Source secret scan result:
- Landing build secret scan result:
- Built app secret scan result:
- Mounted DMG secret scan result:
- OpenAI key rotation evidence, without secret values:
- Replacement key stored only in server-side environments:
- Stripe live-mode decision:
- No secret values copied into this record:

#### Data And Export Checks

- Support export redaction evidence:
- Agent Log redaction evidence:
- Local memory path review:
- Raw screenshot retention review:
- Vault note/frontmatter review:
- Delete-memory control review:
- Manual reset path review:
- Support export reviewed for raw transcripts, private screenshots, OAuth tokens, payment details, and secrets:

#### User-Facing Disclosure Checks

- Privacy policy matches current storage and processors:
- Terms contact and support contact match:
- Beta limitations disclose current manual UAT gaps:
- Support intake avoids raw transcripts, screenshots, secrets, OAuth tokens, and payment details:
- Production environment evidence avoids secret values:
- Accepted limitations have user-facing workaround copy:

#### Decision

- Open privacy/security blockers:
- Accepted limitations and workaround:
- Required fix before invites:
- No raw transcripts, private screenshots, OAuth tokens, payment details, or secrets included:
- Final owner sign-off:

Hold invites, release notes, and paid launch if any copied secret, raw transcript, private screenshot, payment detail, OAuth token, unresolved OpenAI key exposure, unsafe Act behavior, or unreviewed support export remains.
EOF
