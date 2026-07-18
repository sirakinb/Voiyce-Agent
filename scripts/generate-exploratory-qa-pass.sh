#!/usr/bin/env bash

set -euo pipefail

# This helper prints an exploratory QA worksheet only.
# It does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_VERSION="1.0"
EXPECTED_BUILD="16"
EXPECTED_TAG="v1.0+16"
PRODUCTION_URL="${PRODUCTION_LANDING_URL:-https://voiyce.us}"
SUPPORT_EMAIL="aki.b@pentridgemedia.com"

usage() {
  cat <<'EOF'
Usage: scripts/generate-exploratory-qa-pass.sh [--expected-version <version>] [--expected-build <build>] [--expected-tag <tag>] [--production-url <url>]

Prints a markdown exploratory QA worksheet for unscripted founder-work,
permission-chaos, privacy-edge, Agent-stress, account/billing, visual-polish,
and public web/artifact sweeps. This script is read-only and does not read
secret values, write files, stage, commit, tag, build, package, deploy,
notarize, upload, or mutate external services.

Examples:
  scripts/generate-exploratory-qa-pass.sh
  scripts/generate-exploratory-qa-pass.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
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
### Exploratory QA Pass - YYYY-MM-DD

- Tester:
- Session length:
- Machine:
- macOS version:
- Support contact: ${SUPPORT_EMAIL}
- Production URL: ${PRODUCTION_URL}
- Expected version/build/tag: ${EXPECTED_VERSION} / ${EXPECTED_BUILD} / ${EXPECTED_TAG}
- Current branch: ${BRANCH}
- Current HEAD: ${HEAD_SHA}
- Current dirty path count: ${DIRTY_COUNT}
- Install source: public DMG / candidate DMG / local build
- Evidence folder/link:
- Screenshots/recordings reviewed for secrets/private content:
- Agent Log/support export reviewed before sharing:

#### Charter Assignment

| Charter | Owner | Timebox | Environment | Evidence link | Status |
| --- | --- | --- | --- | --- | --- |
| EQ-01 Founder work session |  | 45-90 minutes | Real founder workflow across editor, browser, AI tools, notes |  | not started / pass / hold |
| EQ-02 Permission chaos |  | 30 minutes | Grant, deny, revoke, refresh, quit/reopen, and retry permissions |  | not started / pass / hold |
| EQ-03 Privacy edge sweep |  | 30 minutes | Private Mode, app/site exclusions, sensitive sites/apps, support export |  | not started / pass / hold |
| EQ-04 Agent stress loop |  | 45 minutes | Context/Talk/Act switching, Stop, Agent Log, Settings, long session |  | not started / pass / hold |
| EQ-05 Account and billing edge sweep |  | 30 minutes | signed-out, signed-in, Google disconnected, checkout/portal/account limits |  | not started / pass / hold |
| EQ-06 Visual polish sweep |  | 30 minutes | desktop/mobile landing, app window sizes, keyboard, VoiceOver, contrast/motion |  | not started / pass / hold |
| EQ-07 Public web and artifact sweep |  | 30 minutes | production landing, auth, download, legal, R2 URLs, public DMG identity |  | not started / pass / hold |

#### Required Observations

- Real founder work session produced useful reusable context:
- Voiyce avoided re-explaining work across at least two AI tools:
- Permission failures recovered with concrete next steps:
- Stop stayed visible and effective during active sessions:
- Private Mode/exclusions prevented memory and support-export exposure:
- Agent Log was useful without leaking raw private content:
- Visual layout had no clipping, overlap, unreadable contrast, or keyboard trap:
- Account/billing/access states used user-facing copy:
- Public web/download/legal artifact identity matched the intended release:

#### Findings

| ID | Charter | Severity | Surface | Finding | User impact | Evidence | Workaround | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| EQ-FINDING-001 | EQ-01 / EQ-02 / EQ-03 / EQ-04 / EQ-05 / EQ-06 / EQ-07 | P0 / P1 / P2 / P3 | app / landing / auth / download / billing / support / privacy / artifact |  |  |  |  |  | open / fixed / accepted / hold |

#### Evidence Review

- No raw transcripts copied into evidence:
- No private screenshots copied into evidence:
- No OAuth tokens copied into evidence:
- No payment details copied into evidence:
- No full secret values copied into evidence:
- Support export redaction reviewed:
- Missing evidence owner/reason/replacement proof:

#### Decision

- Open P0/P1 blockers:
- Accepted P2 limitations and user-facing workarounds:
- Release notes/support copy updates needed:
- Invite decision: hold / narrow invite / broader invite
- Final owner sign-off:

Hold invites, release notes, and paid launch if any exploratory P0/P1 remains, any accepted P2 lacks user-facing workaround copy, any privacy/account/billing/artifact risk lacks owner review, or evidence includes secrets/private data.
EOF
