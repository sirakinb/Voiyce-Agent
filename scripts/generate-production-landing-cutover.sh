#!/usr/bin/env bash

set -euo pipefail

# This helper prints a production landing cutover evidence checklist only.
# It does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_VERSION="1.0"
EXPECTED_BUILD="16"
EXPECTED_TAG="v1.0+16"
PRODUCTION_URL="${PRODUCTION_LANDING_URL:-https://voiyce.us}"
SUPPORT_EMAIL="aki.b@pentridgemedia.com"

usage() {
  cat <<'EOF'
Usage: scripts/generate-production-landing-cutover.sh [--expected-version <version>] [--expected-build <build>] [--expected-tag <tag>] [--production-url <url>]

Prints a markdown production landing cutover evidence checklist for Vercel
deployment identity, deployed commit, download and auth env review, production
smoke verification, stale-copy rejection, R2 artifact identity, rollback deployment,
monitoring, blockers, and final sign-off. This script is read-only and does not
read secret values, write files, stage, commit, tag, build, package, deploy,
notarize, upload, or mutate external services.

Examples:
  scripts/generate-production-landing-cutover.sh
  scripts/generate-production-landing-cutover.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
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
### Production Landing Cutover - YYYY-MM-DD

- Cutover owner:
- Support contact: ${SUPPORT_EMAIL}
- Production URL: ${PRODUCTION_URL}
- Release version/build/tag: ${EXPECTED_VERSION} / ${EXPECTED_BUILD} / ${EXPECTED_TAG}
- Current branch: ${BRANCH}
- Current HEAD: ${HEAD_SHA}
- Current dirty path count: ${DIRTY_COUNT}
- Vercel project/team:
- Deployment URL/id:
- Deployed commit:
- Production alias:
- Cutover time:
- Monitoring window:
- Final cutover sign-off:

#### Deployment Identity

- Deployment created from the intended release source:
- Deployment commit matches release candidate or documented landing-only source:
- Deployment environment: production / preview / rollback
- Production domain points at the intended deployment:
- Previous known-good deployment/id:
- Rollback deployment/id:
- Rollback owner:

#### Download Configuration

- \`NEXT_PUBLIC_DOWNLOAD_URL\` review:
- Configured download URL:
- Download URL points at the intended latest DMG:
- Download URL matches release record:

#### Auth Configuration

- \`NEXT_PUBLIC_INSFORGE_URL\` auth env review:
- \`NEXT_PUBLIC_INSFORGE_ANON_KEY\` presence, no value:
- Auth provider callback/sign-in smoke:
- Auth route uses intended production project:
- Auth/download handoff result:

#### Production Route Checks

- \`/api/download-health\` result:
- Download page result:
- Auth route result:
- Terms route result:
- Privacy route result:

#### Production Smoke

- \`scripts/verify-production-landing.sh ${PRODUCTION_URL}\` result:
- Agent-context headline/copy present:
- Stale dictation-first copy absent:
- Legal/support contact result:
- favicon payload result:
- OG/social image payload result:
- Mobile viewport smoke:
- Desktop viewport smoke:
- No secret values in captured evidence:

#### R2 Artifact Identity

- Public manifest URL:
- Manifest version/build:
- Manifest SHA-256:
- Latest DMG URL:
- Latest DMG SHA-256:
- Versioned DMG URL:
- Versioned DMG SHA-256:
- latest/versioned byte equality:
- R2 identity matches release record:
- Previous rollback candidate:

#### Monitoring And Resume

- Vercel monitoring reviewed:
- Download-health monitoring reviewed:
- Support inbox first-hour coverage:
- Support inbox first-day coverage:
- Launch monitoring record link:
- Invite resume checklist link:
- Open production landing blockers:
- Invite/release-note decision: hold / narrow / resume

#### Privacy Review

- No secret values copied into record:
- No bearer tokens copied into record:
- No private screenshots copied into record:
- No raw transcripts copied into record:
- No OAuth tokens copied into record:
- No payment details copied into record:

Launch hold rule: if production serves stale copy, \`/api/download-health\` fails, the download URL points at the wrong artifact, R2 identity does not match the release record, no rollback deployment is identified, or evidence includes unreviewed secrets/private data/payment details, keep invites and release notes paused.
EOF
