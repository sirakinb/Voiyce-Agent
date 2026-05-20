#!/usr/bin/env bash

set -euo pipefail

# This helper prints a manual UAT execution worksheet only.
# It does not write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_VERSION="1.0"
EXPECTED_BUILD="16"
EXPECTED_TAG="v1.0+16"
INSTALL_SOURCE="public DMG / candidate DMG / local build"

usage() {
  cat <<'EOF'
Usage: scripts/generate-manual-uat-pass.sh [--expected-version <version>] [--expected-build <build>] [--expected-tag <tag>] [--install-source <label>]

Prints a markdown manual UAT execution worksheet for clean install, Dictation,
Context, Talk, Act, web/legal/download, accessibility, billing/account,
resilience, and exploratory QA. This script is read-only and does not write
files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate
external services.

Examples:
  scripts/generate-manual-uat-pass.sh
  scripts/generate-manual-uat-pass.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
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
    --install-source)
      [[ $# -ge 2 ]] || { echo "error: --install-source requires a value" >&2; exit 2; }
      INSTALL_SOURCE="$2"
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
### Manual UAT Pass - YYYY-MM-DD

- Tester:
- Date:
- Machine:
- macOS version:
- Voiyce version/build: ${EXPECTED_VERSION} / ${EXPECTED_BUILD}
- Expected release tag: ${EXPECTED_TAG}
- Current branch: ${BRANCH}
- Current HEAD: ${HEAD_SHA}
- Current dirty path count: ${DIRTY_COUNT}
- Install source: ${INSTALL_SOURCE}
- DMG URL:
- DMG SHA-256:
- Network: normal / offline test / throttled
- Google OAuth account: connected / not connected / not tested
- Stripe mode: test / live / not tested
- Evidence folder/link:
- Screenshots/recordings reviewed for sensitive content:
- Agent Log/support export reviewed for sensitive content:
- Owner-approved automated exceptions:

#### Surface Assignment

| Surface | Owner | Required environment | Evidence link | Status |
| --- | --- | --- | --- | --- |
| Clean install and onboarding |  | Fresh macOS user or separate Mac, exact DMG |  | not started / pass / hold |
| Dictation |  | Native app, browser field, normal/offline paths |  | not started / pass / hold |
| Context and memory |  | Screen Recording granted, Private Mode, exclusions, memory delete path |  | not started / pass / hold |
| Talk Mode |  | Microphone, Screen Recording, normal network, network-drop test |  | not started / pass / hold |
| Act Mode |  | Accessibility, Screen Recording, Strict safety, harmless public targets |  | not started / pass / hold |
| Website, auth, download, and legal |  | Production landing, auth/download routes, R2 public artifacts |  | not started / pass / hold |
| Visual, keyboard, VoiceOver, motion, and contrast |  | Supported window sizes, keyboard-only path, VoiceOver, Reduce Motion/Increase Contrast |  | not started / pass / hold |
| Billing, account limits, and access |  | Intended Stripe mode, account states, usage-limit simulation |  | not started / pass / hold |
| Resilience and recovery |  | Offline launch, sleep/wake, permission revoke, quit-active, active account access loss, display change, support export |  | not started / pass / hold |
| Exploratory QA charters |  | Real founder work session plus privacy/account/visual/artifact sweeps |  | not started / pass / hold |

#### Scripted Rows

| ID | Result | Severity | Evidence link | Notes / workaround |
| --- | --- | --- | --- | --- |
| CI-01 Fresh install from DMG | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| CI-02 First launch state | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| CI-03 Grant all permissions | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| CI-04 Deny permissions one by one | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| CI-05 Revoke after grant | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| CI-06 Sign in/out recovery | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| CI-07 Clean user quit/reopen permission sync | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| CI-08 Launch location parity | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| CI-09 Permission return routing | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| DI-01 Native text field | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| DI-02 Browser text field | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| DI-03 Long paragraph | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| DI-04 Cancel mid-dictation | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| DI-05 Offline transcription | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| DI-06 Microphone denied | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| DI-07 Wrong-field protection | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| DI-08 Short text accuracy | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| DI-09 Punctuation handling | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| CM-01 Start and stop Context | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| CM-02 Memory write | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| CM-03 Private Mode | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| CM-04 App/site exclusion | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| CM-05 Delete memory | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| CM-06 Multiple displays | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| CM-07 Vault Notes visibility | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| CM-08 Cross-app context quality | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| TK-01 Simple spoken question and first-response timing | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| TK-02 Current screen question | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| TK-03 Memory recall | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| TK-04 Interruption and settling timing | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| TK-05 Tool delay progress phrase | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| TK-06 Network drop | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| TK-07 Missing OAuth | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| TK-08 Long thought and correction | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| TK-09 Repeated tool requests | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| TK-10 Stop during tool call | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| TK-11 Agent Log after Talk | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| TK-12 Voice input and output smoke | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| AC-01 Safety mode required | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| AC-02 Native Voiyce navigation | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| AC-03 Browser navigation | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| AC-04 Public test form | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| AC-05 Gmail draft | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| AC-06 Calendar read | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| AC-07 Desktop app switching | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| AC-08 Blocked destructive action | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| AC-09 Stop during Action Cursor | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| AC-10 Missing Accessibility | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| AC-11 Missing Screen Recording | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| AC-12 Visit Agent Log mid-task | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| AC-13 Confirmation approve path | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| AC-14 Confirmation cancel path | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| AC-15 Confirmation Stop Session path | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| AC-16 Confirmation timeout path | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| AC-17 Network drop during Act | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| AC-18 Normal safety smoke | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| AC-19 Unrestricted safety smoke | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| AC-20 Public form submit confirmation | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| AC-21 Action log audit trail | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| WEB-01 Public home route | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| WEB-02 Auth/download flow | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| WEB-03 Legal pages | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| WEB-04 Public artifact verification | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| WEB-05 Download-health fallback | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| UI-01 Onboarding visual pass | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| UI-02 Dashboard and sidebar pass | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| UI-03 Settings pass | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| UI-04 Agent screen pass | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| UI-05 Agent Log pass | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| UI-06 Menu bar and app menu pass | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| UI-07 Keyboard navigation pass | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| UI-08 VoiceOver label pass | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| UI-09 Motion and contrast comfort pass | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| BA-01 Billing mode sanity | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| BA-02 Checkout and portal access | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| BA-03 Account access transition | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| BA-04 Usage limit recovery | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| RR-01 Physical no-network app launch from downloaded app | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| RR-02 Sleep/wake active-session cleanup | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| RR-03 Permission revoked mid-session recovery | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| RR-04 Quit while active cleanup | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| RR-05 Multi-display connect/disconnect recovery | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| RR-06 Support export privacy review | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| RR-07 Account access lost while active | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |
| EQ-01 to EQ-07 Exploratory QA charters | pass / fail / skipped | P0 / P1 / P2 / P3 / none |  |  |

#### Required Measurements

- Talk first-response timing:
- Talk interruption settling timing:
- Talk tool-delay progress phrase observed:
- Dictation native-field insertion result:
- Dictation browser-field insertion result:
- Dictation long-paragraph result:
- Dictation cancel-mid-dictation result:
- Dictation offline recovery result:
- Dictation microphone-denied recovery result:
- Dictation wrong-field protection result:
- Dictation short-text accuracy result:
- Dictation punctuation result:
- Context start/stop result:
- Context memory write result:
- Context Private Mode result:
- Context app/site exclusion result:
- Context delete-memory result:
- Context multiple-display result:
- Vault Notes visibility result:
- Cross-app context quality result:
- Talk current-screen answer result:
- Talk memory-recall result:
- Talk network-drop recovery result:
- Talk missing-OAuth recovery result:
- Talk long-thought/correction result:
- Talk repeated-tool-requests result:
- Talk stop-during-tool-call result:
- Talk Agent Log review result:
- Talk voice input/output result:
- Act safety-mode-required result:
- Act native-Voiyce-navigation result:
- Act browser-navigation result:
- Act public-test-form-fill result:
- Act Gmail draft result:
- Act Calendar read result:
- Act desktop-app-switching result:
- Act blocked-destructive-action result:
- Act stop-during-Action-Cursor result:
- Act missing-Accessibility recovery result:
- Act missing-Screen-Recording recovery result:
- Act Agent Log mid-task recovery result:
- Act confirmation approve/cancel/stop/timeout result:
- Act network-drop recovery result:
- Act Normal safety smoke result:
- Act Unrestricted safety smoke result:
- Act public-form submit confirmation result:
- Act action-log audit trail result:
- Physical no-network launch from downloaded app result:
- Sleep/wake active-session cleanup result:
- Permission revoked mid-session recovery result:
- Quit while active cleanup result:
- Multi-display connect/disconnect recovery result:
- Support export privacy review result:
- Clean user permission sync after quit/reopen result:
- Launch from DMG and Applications result:
- Permission return routing result:
- Active account access loss result:
- Billing mode sanity result:
- Checkout and portal access result:
- Account access transition result:
- Usage limit recovery result:
- Public home route result:
- Auth/download flow result:
- Legal pages result:
- Public artifact checksum result:
- Download-health fallback result:
- Onboarding visual pass result:
- Dashboard and sidebar pass result:
- Settings pass result:
- Agent screen pass result:
- Agent Log pass result:
- Menu bar and app menu pass result:
- Keyboard navigation pass result:
- VoiceOver label pass result:
- Motion and contrast comfort pass result:
- Permission refresh after quit/reopen result:

#### Bugs Found

- P0:
- P1:
- P2:
- P3:
- No known P0/P1 remain:
- Every P2 has owner-approved workaround:
- Every skipped diagnostic has owner-approved replacement evidence:

#### Decision

- Ship / hold:
- Required fixes before sharing:
- Accepted limitations:
- Release notes/support copy updates needed:
- Support/contact/release notes match exact build:
- Final owner sign-off:

Hold the release if any required surface is unassigned, lacks evidence, has a P0/P1, has a P2 without a workaround, or has skipped diagnostics without owner-approved replacement evidence.
EOF
