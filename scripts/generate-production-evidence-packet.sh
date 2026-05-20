#!/usr/bin/env bash

set -euo pipefail

# This helper prints a production/account evidence packet only.
# It does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services.
# Audit guard labels:
# usage-cap env `VOIYCE_ENFORCE_AGENT_USAGE_CAPS`:
# usage-cap env `VOIYCE_ENFORCE_AGENT_USAGE_CAPS` production value:
# `/api/download-health` result:
# `NEXT_PUBLIC_INSFORGE_URL` auth env review:
# `NEXT_PUBLIC_INSFORGE_ANON_KEY` presence, no value:
# `STRIPE_ALLOW_LIVE_MODE` decision:
# Support inbox test message sent and received:

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_VERSION="1.0"
EXPECTED_BUILD="16"
EXPECTED_TAG="v1.0+16"
PRODUCTION_URL="${PRODUCTION_LANDING_URL:-https://voiyce.us}"
SUPPORT_EMAIL="aki.b@pentridgemedia.com"

usage() {
  cat <<'EOF'
Usage: scripts/generate-production-evidence-packet.sh [--expected-version <version>] [--expected-build <build>] [--expected-tag <tag>] [--production-url <url>]

Prints a markdown production/account evidence packet for OpenAI key rotation,
AI usage/quota monitoring, InsForge env/database, Vercel deployment, Cloudflare
R2 artifacts, Stripe mode, support ownership, and no-secret evidence handling.
This script is read-only: it does not read secret values, write files, stage,
commit, tag, build, package, deploy, notarize, upload, or mutate external
services.

Examples:
  scripts/generate-production-evidence-packet.sh
  scripts/generate-production-evidence-packet.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
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
### Production Evidence Packet - YYYY-MM-DD

- Evidence owner:
- Security owner:
- Support contact: ${SUPPORT_EMAIL}
- Production URL: ${PRODUCTION_URL}
- Expected version/build/tag: ${EXPECTED_VERSION} / ${EXPECTED_BUILD} / ${EXPECTED_TAG}
- Current branch: ${BRANCH}
- Current HEAD: ${HEAD_SHA}
- Current dirty path count: ${DIRTY_COUNT}
- Evidence folder/link:
- Dashboard screenshots redacted:
- Command outputs reviewed for secrets/private data:
- No secret values copied into this record:
- Open blockers:
- Final owner sign-off:

#### OpenAI Key Rotation

- Exposed key label/last four, no full key:
- Revoked in OpenAI dashboard or connected OpenAI Platform tooling:
- Replacement key created:
- Replacement key stored only in server-side environments:
- macOS app bundle scan result:
- landing/browser bundle scan result:
- source scan result:
- post-rotation Realtime smoke:
- post-rotation transcription smoke:
- post-rotation screen-context smoke:
- post-rotation Computer Use smoke:
- optional old-key negative check:
- usage/quota alert review:
- no-secret evidence handling:
- security owner sign-off:

#### AI Usage And Quota Monitoring

- Monitoring owner:
- Invite batch or release candidate:
- Window start/end:
- OpenAI usage dashboard reviewed:
- OpenAI hard spend/quota limit visible:
- OpenAI usage alert threshold reviewed:
- Realtime usage trend: normal / elevated / hold
- Transcription usage trend: normal / elevated / hold
- Computer Use usage trend: normal / elevated / hold
- Screen-context usage trend: normal / elevated / hold
- InsForge usage-cap events reviewed:
- usage-cap env \`VOIYCE_ENFORCE_AGENT_USAGE_CAPS\` production value:
- AI kill-switch values reviewed:
- 401/402/429 or quota spikes:
- Support reports linked:
- Pause/narrow/continue decision:
- Next monitoring checkpoint:
- Evidence reviewed for secret/private data:

#### InsForge Functions And Database

- Project id/name:
- Function env evidence, without secret values:
- OpenAI server-side env labels present:
- VideoDB/session-context env labels present:
- usage-cap env \`VOIYCE_ENFORCE_AGENT_USAGE_CAPS\`:
- AI kill-switch env labels:
- billing RPC deployed:
- Stripe subscription RPC deployed:
- usage-cap SQL deployed:
- function smoke evidence:
- database/RPC smoke evidence:
- owner:
- open blockers:

#### Vercel Landing

- Vercel project/team:
- Deployment URL/id:
- Deployed commit:
- Production alias:
- \`NEXT_PUBLIC_DOWNLOAD_URL\` review:
- \`NEXT_PUBLIC_INSFORGE_URL\` auth env review:
- \`NEXT_PUBLIC_INSFORGE_ANON_KEY\` presence, no value:
- Auth provider callback/sign-in smoke:
- \`/api/download-health\` result:
- stale-copy rejection result:
- legal contact result:
- auth/download route result:
- favicon/OG image result:
- rollback deployment/id:
- owner:
- open blockers:

#### Cloudflare R2 Artifacts

- Public manifest URL:
- manifest version/build:
- manifest SHA-256:
- latest DMG URL:
- latest DMG SHA-256:
- latest checksum sidecar:
- versioned DMG URL:
- versioned DMG SHA-256:
- versioned checksum sidecar:
- latest/versioned DMG byte equality:
- previous rollback candidate:
- owner:
- open blockers:

#### Stripe And Billing

- Stripe account mode: test / live
- Live billing review complete before charging:
- product ids:
- price ids:
- checkout evidence:
- billing portal evidence:
- webhook endpoint id:
- webhook signing-secret presence, no value:
- subscription mapping evidence:
- refund/cancellation copy reviewed:
- \`STRIPE_ALLOW_LIVE_MODE\` decision:
- support owner:
- open blockers:

#### Support And Monitoring

- Primary support owner:
- Backup support owner:
- Engineering escalation owner:
- Billing escalation owner:
- Rollback owner:
- First-hour coverage window:
- First-day coverage window:
- Support inbox ready:
- Support inbox test message sent and received:
- First reply template tested:
- P0/P1 escalation path tested:
- Support intake template ready:
- Support export privacy-review instructions ready:
- Invite pause authority:
- OpenAI monitoring:
- Vercel monitoring:
- InsForge monitoring:
- Cloudflare R2 monitoring:
- Stripe monitoring:
- open blockers:

Hold invites, release notes, and paid launch if OpenAI key rotation is incomplete, server-side env proof is missing, production landing/download/R2 verification is stale or failing, Stripe mode is unconfirmed, support ownership is unassigned, or evidence includes secret values.
EOF
