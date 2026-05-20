#!/usr/bin/env bash

set -euo pipefail

# This helper prints a clean-install UAT worksheet only.
# It does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_VERSION="1.0"
EXPECTED_BUILD="16"
EXPECTED_TAG="v1.0+16"
PRODUCTION_URL="${PRODUCTION_LANDING_URL:-https://voiyce.us}"
SUPPORT_EMAIL="aki.b@pentridgemedia.com"

usage() {
  cat <<'EOF'
Usage: scripts/generate-clean-install-uat.sh [--expected-version <version>] [--expected-build <build>] [--expected-tag <tag>] [--production-url <url>]

Prints a markdown clean-install UAT worksheet for downloaded-DMG install,
first launch, sign-in, permission prompts, quit/reopen permission sync, offline
launch, Agent Log, Settings, and privacy-safe evidence capture. This script is
read-only and does not read secret values, write files, stage, commit, tag,
build, package, deploy, notarize, upload, or mutate external services.

Examples:
  scripts/generate-clean-install-uat.sh
  scripts/generate-clean-install-uat.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
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
### Clean Install UAT - YYYY-MM-DD

- Tester:
- Test machine or macOS user:
- macOS version:
- Support contact: ${SUPPORT_EMAIL}
- Production URL: ${PRODUCTION_URL}
- Expected version/build/tag: ${EXPECTED_VERSION} / ${EXPECTED_BUILD} / ${EXPECTED_TAG}
- Current branch: ${BRANCH}
- Current HEAD: ${HEAD_SHA}
- Release tag status: ${TAG_STATUS}
- Current dirty path count: ${DIRTY_COUNT}
- DMG source URL:
- DMG SHA-256:
- Manifest URL:
- Gatekeeper/notarization evidence:
- Evidence folder/link:
- Screenshots/recordings reviewed for secrets/private content:
- Agent Log/support export reviewed before sharing:

#### Install And First Launch

- Downloaded from production URL:
- Downloaded DMG matches expected SHA-256:
- DMG mounts read-only and shows Voiyce.app plus Applications symlink:
- App copies to Applications:
- First launch opens the downloaded app, not Xcode/local build:
- Bundle version/build shown in app:
- Gatekeeper prompt result:
- Sign-in path result:
- Signed-out/offline recovery copy result:

#### Permission Prompt Matrix

| Permission | First prompt result | Settings state immediately after | State after refresh | State after quit/reopen | Revoke/regrant result | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| Microphone |  |  |  |  |  |  |
| Speech Recognition |  |  |  |  |  |  |
| Accessibility |  |  |  |  |  |  |
| Screen Recording |  |  |  |  |  |  |

#### Core Smoke From Downloaded App

- Dictation native text field result:
- Dictation browser text field result:
- Context start/stop result:
- Memory write/read/delete result:
- Talk current-screen question result:
- Act Strict harmless navigation result:
- Act blocked destructive-action result:
- Agent Log event review result:
- Redacted support export result:
- Settings memory/privacy controls result:

#### Resilience Checks

- Quit/reopen keeps permission state accurate:
- Physical no-network launch from downloaded app result:
- Permission revoked mid-session recovery:
- Sleep/wake active-session cleanup:
- Display change overlay/focus cleanup:
- Private Mode and app/site exclusion spot check:
- Uninstall/reset-memory instructions checked:

#### Evidence Review

- No raw transcripts copied into evidence:
- No private screenshots copied into evidence:
- No OAuth tokens copied into evidence:
- No payment details copied into evidence:
- No full secret values copied into evidence:
- Redactions reviewed by:
- Missing evidence owner/reason/replacement proof:

#### Decision

- Open P0/P1 blockers:
- Accepted P2 limitations and user-facing workarounds:
- Required fixes before broader invite:
- Release notes/support copy updates needed:
- Clean-install decision: pass / hold
- Final owner sign-off:

Hold invites, release notes, and paid launch if the downloaded app cannot be installed, first launch fails, permission state is stale after quit/reopen, offline launch is broken, core Dictation/Context/Talk/Act smoke fails, support export is not redacted, or evidence contains secrets/private data.
EOF
