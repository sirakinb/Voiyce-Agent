#!/usr/bin/env bash

set -euo pipefail

# This helper prints an OpenAI key rotation evidence checklist only.
# It does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_VERSION="1.0"
EXPECTED_BUILD="16"
EXPECTED_TAG="v1.0+16"
PRODUCTION_URL="${PRODUCTION_LANDING_URL:-https://voiyce.us}"
SUPPORT_EMAIL="aki.b@pentridgemedia.com"

usage() {
  cat <<'EOF'
Usage: scripts/generate-openai-key-rotation.sh [--expected-version <version>] [--expected-build <build>] [--expected-tag <tag>] [--production-url <url>]

Prints a markdown OpenAI key rotation evidence checklist for exposed-key
revocation, server-side replacement, source/bundle scans, post-rotation smoke,
and usage/quota alert review. This script is read-only and does not read secret
values, write files, stage, commit, tag, build, package, deploy, notarize,
upload, or mutate external services.

Examples:
  scripts/generate-openai-key-rotation.sh
  scripts/generate-openai-key-rotation.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
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
### OpenAI Key Rotation - YYYY-MM-DD

- Security owner:
- Support contact: ${SUPPORT_EMAIL}
- Production URL: ${PRODUCTION_URL}
- Release version/build/tag: ${EXPECTED_VERSION} / ${EXPECTED_BUILD} / ${EXPECTED_TAG}
- Current branch: ${BRANCH}
- Current HEAD: ${HEAD_SHA}
- Current dirty path count: ${DIRTY_COUNT}
- Exposed key label/last-four, if safely known:
- Exposed key revoked in OpenAI dashboard:
- Replacement key created:
- Replacement key stored only in server-side function environment:
- Replacement key absent from local docs/support/chat:
- macOS app bundle does not contain \`OPENAI_API_KEY\` or \`sk-\` values:
- Landing/browser bundle does not contain \`OPENAI_API_KEY\` or \`sk-\` values:
- Source secret scan result:
- Built app secret scan result:
- Landing build secret scan result:
- Mounted DMG secret scan result:
- Production function smoke result after rotation:
- Old-key negative check, if available without exposing the key:
- Usage/quota alerts reviewed:
- OpenAI hard spend/quota limit visible:
- OpenAI usage dashboard reviewed:
- Evidence reviewed for secret values before sharing:
- Remaining key/security blockers:
- Final security owner sign-off:

#### Server-Side Storage Review

- InsForge \`OPENAI_API_KEY\` presence confirmed, value redacted:
- Realtime function env reviewed:
- Transcription function env reviewed:
- Screen-context function env reviewed:
- Computer Use function env reviewed:
- Vercel environment reviewed for accidental secret exposure:
- Public browser env reviewed for no private OpenAI key:

#### Privacy Review

- No full key values copied into record:
- No bearer tokens copied into record:
- No request bodies copied into record:
- No raw transcripts copied into record:
- No private screenshots copied into record:
- No support exports copied into record:

Launch hold rule: if the exposed key is not revoked, the replacement key is not server-side only, any bundle/source scan finds an OpenAI-style key, production function smoke fails after rotation, usage/quota alerts are missing, or the evidence requires copying a full secret value, keep release notes and invites paused.
EOF
