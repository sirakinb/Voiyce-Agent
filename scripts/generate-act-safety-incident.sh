#!/usr/bin/env bash

set -euo pipefail

# This helper prints an Act safety incident record only.
# It does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_VERSION="1.0"
EXPECTED_BUILD="16"
EXPECTED_TAG="v1.0+16"
PRODUCTION_URL="${PRODUCTION_LANDING_URL:-https://voiyce.us}"
SUPPORT_EMAIL="aki.b@pentridgemedia.com"

usage() {
  cat <<'EOF'
Usage: scripts/generate-act-safety-incident.sh [--expected-version <version>] [--expected-build <build>] [--expected-tag <tag>] [--production-url <url>]

Prints a markdown Act safety incident record for unexpected actions, missing
confirmations, blocked actions, sensitive workflows, Stop failures, or user
concerns about app control. This script is read-only and does not read secret
values, write files, stage, commit, tag, build, package, deploy, notarize,
upload, or mutate external services.

Examples:
  scripts/generate-act-safety-incident.sh
  scripts/generate-act-safety-incident.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
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
##### Act Safety Incident - YYYY-MM-DD

- Severity:
- Reporter:
- Owner:
- Support contact: ${SUPPORT_EMAIL}
- Production URL: ${PRODUCTION_URL}
- Release version/build/tag: ${EXPECTED_VERSION} / ${EXPECTED_BUILD} / ${EXPECTED_TAG}
- Current branch: ${BRANCH}
- Current HEAD: ${HEAD_SHA}
- Current dirty path count: ${DIRTY_COUNT}
- Install source:
- Safety mode: Strict / Normal / Unrestricted / unknown
- Requested action:
- Actual visible action:
- Expected confirmation shown: yes / no / not applicable
- Stop button visible: yes / no / unknown
- Stop worked: yes / no / not tried
- Permission state: Accessibility / Screen Recording / Microphone
- Sensitive surface involved: credentials / payment / private data / system settings / destructive action / none
- Agent Log event IDs:
- Support export reviewed before sharing:
- Screenshots/recordings reviewed before sharing:
- Invite decision: pause / narrow / continue
- Kill switch or capability narrowing considered:
- User-facing reply sent:
- Final owner sign-off:

#### Safety Review

- Hidden action occurred:
- Destructive action occurred:
- Credential or payment surface touched:
- Private data surface touched:
- Account-changing action occurred:
- Blocked catastrophic/fraud/illegal-access/credential-theft/malware/hidden-action/platform-abusive request executed any local action:
- Same Act safety report appeared from two users in one invite batch:
- Capability should be narrowed before resume:
- Computer Use kill switch should be changed before resume:
- Release notes or known limitations need an Act workaround update:

#### Privacy Review

- No raw screenshots copied into record:
- No credentials copied into record:
- No private page contents copied into record:
- No payment details copied into record:
- No secret values copied into record:
- Support exports reviewed before linking:

Hold invites if Act performs a hidden, destructive, credential, payment, private-data, or account-changing action without expected confirmation. Hold invites if Stop is not visible or does not cancel visible work. Hold invites if a blocked catastrophic, fraud, illegal-access, credential-theft, malware, hidden-action, or platform-abusive request executes any local action. Hold invites if the same Act safety report appears from two users in one invite batch.
EOF
