#!/usr/bin/env bash

set -euo pipefail

# This verifier executes the read-only evidence generators and checks that their
# rendered output is usable.
# It does not write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_VERSION="1.0"
EXPECTED_BUILD="16"
EXPECTED_TAG="v1.0+16"
OPENAI_KEY_PATTERN="sk-proj-[A-Za-z0-9_-]{20,}|OPENAI_API_KEY=.*sk-[A-Za-z0-9_-]{20,}"

usage() {
  cat <<'EOF'
Usage: scripts/verify-evidence-generators.sh [--expected-version <version>] [--expected-build <build>] [--expected-tag <tag>]

Runs the read-only launch evidence generators and verifies their rendered
output has the required sections, current dirty-count context, support contact,
and no OpenAI-style secret patterns. This script does not write files, stage,
commit, tag, build, package, deploy, notarize, upload, or mutate external
services.

Examples:
  scripts/verify-evidence-generators.sh
  scripts/verify-evidence-generators.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
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

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: Missing required command: $1" >&2
    exit 2
  }
}

require_output_contains() {
  local output="$1"
  local label="$2"
  local expected="$3"

  if ! grep -Fq -- "$expected" <<<"$output"; then
    echo "error: $label is missing expected output: $expected" >&2
    exit 1
  fi
}

require_output_not_matches() {
  local output="$1"
  local label="$2"
  local regex="$3"

  if grep -Eq -- "$regex" <<<"$output"; then
    echo "error: $label contains a disallowed pattern" >&2
    exit 1
  fi
}

run_generator() {
  local script="$1"
  "$script" --expected-version "$EXPECTED_VERSION" --expected-build "$EXPECTED_BUILD" --expected-tag "$EXPECTED_TAG"
}

require_command grep
require_command git

CURRENT_DIRTY_PATH_COUNT="$(git status --porcelain=v1 --untracked-files=all | sed '/^$/d' | wc -l | tr -d ' ')"
check_output() {
  local label="$1"
  local output="$2"
  shift 2

  for expected in "$@"; do
    require_output_contains "$output" "$label" "$expected"
  done
  require_output_not_matches "$output" "$label" "$OPENAI_KEY_PATTERN"
}

source_disposition_output="$(run_generator scripts/generate-release-source-disposition.sh)"
check_output \
  "release source disposition generator" \
  "$source_disposition_output" \
  "### Release Source Inclusion Review" \
  "Starting branch:" \
  "Starting HEAD:" \
  "\`git status --porcelain=v1 --untracked-files=all\` path count: ${CURRENT_DIRTY_PATH_COUNT}" \
  "#### Dirty-Tree Disposition Summary" \
  "#### Recommended Review Order" \
  "#### Paths Requiring Disposition" \
  "#### Include In Release Candidate" \
  "#### Split Out Before Release" \
  "#### Remove Or Regenerate" \
  "No package, notarize, upload, or R2 mutation before strict source-state passes:" \
  "Source freeze verification commands:" \
  "scripts/verify-release-source-state.sh --expected-version <version> --expected-build <build> --expected-tag <tag>"

launch_evidence_output="$(run_generator scripts/generate-launch-evidence-package.sh)"
check_output \
  "launch evidence package generator" \
  "$launch_evidence_output" \
  "### Launch Evidence Package - YYYY-MM-DD" \
  "Current branch:" \
  "Current HEAD:" \
  "Current dirty path count: ${CURRENT_DIRTY_PATH_COUNT}" \
  "Support contact: aki.b@pentridgemedia.com" \
  "#### Required Command Evidence" \
  "Support inbox test-message evidence:" \
  "P0/P1 escalation path evidence:" \
  "#### Rollback Readiness Evidence" \
  "R2 previous candidate and rollback manifest evidence:" \
  "Resume-after-rollback checklist evidence:" \
  "#### Risk And Exception Register" \
  "Every skipped automated diagnostic has owner-approved replacement evidence:" \
  "Any secret/private-data/payment/unsafe-Act risk reviewed:" \
  "#### Privacy And Security Evidence"

manual_uat_output="$(run_generator scripts/generate-manual-uat-pass.sh)"
check_output \
  "manual UAT pass generator" \
  "$manual_uat_output" \
  "### Manual UAT Pass - YYYY-MM-DD" \
  "Current branch:" \
  "Current HEAD:" \
  "Current dirty path count: ${CURRENT_DIRTY_PATH_COUNT}" \
  "#### Surface Assignment" \
  "#### Scripted Rows" \
  "CI-08 Launch location parity" \
  "CI-09 Permission return routing" \
  "DI-07 Wrong-field protection" \
  "DI-08 Short text accuracy" \
  "DI-09 Punctuation handling" \
  "CM-01 Start and stop Context" \
  "CM-02 Memory write" \
  "CM-03 Private Mode" \
  "CM-04 App/site exclusion" \
  "CM-05 Delete memory" \
  "CM-06 Multiple displays" \
  "CM-07 Vault Notes visibility" \
  "CM-08 Cross-app context quality" \
  "TK-02 Current screen question" \
  "TK-03 Memory recall" \
  "TK-06 Network drop" \
  "TK-07 Missing OAuth" \
  "TK-08 Long thought and correction" \
  "TK-09 Repeated tool requests" \
  "DI-01 Native text field" \
  "DI-02 Browser text field" \
  "DI-03 Long paragraph" \
  "DI-04 Cancel mid-dictation" \
  "DI-05 Offline transcription" \
  "DI-06 Microphone denied" \
  "RR-01 Physical no-network app launch from downloaded app" \
  "AC-01 Safety mode required" \
  "AC-02 Native Voiyce navigation" \
  "AC-03 Browser navigation" \
  "AC-04 Public test form" \
  "AC-05 Gmail draft" \
  "AC-06 Calendar read" \
  "AC-07 Desktop app switching" \
  "AC-08 Blocked destructive action" \
  "AC-09 Stop during Action Cursor" \
  "AC-10 Missing Accessibility" \
  "AC-11 Missing Screen Recording" \
  "AC-12 Visit Agent Log mid-task" \
  "AC-13 Confirmation approve path" \
  "AC-14 Confirmation cancel path" \
  "AC-15 Confirmation Stop Session path" \
  "AC-16 Confirmation timeout path" \
  "AC-17 Network drop during Act" \
  "AC-18 Normal safety smoke" \
  "AC-19 Unrestricted safety smoke" \
  "AC-20 Public form submit confirmation" \
  "AC-21 Action log audit trail" \
  "TK-10 Stop during tool call" \
  "TK-11 Agent Log after Talk" \
  "TK-12 Voice input and output smoke" \
  "BA-01 Billing mode sanity" \
  "BA-02 Checkout and portal access" \
  "BA-03 Account access transition" \
  "BA-04 Usage limit recovery" \
  "WEB-01 Public home route" \
  "WEB-02 Auth/download flow" \
  "WEB-03 Legal pages" \
  "WEB-04 Public artifact verification" \
  "WEB-05 Download-health fallback" \
  "UI-01 Onboarding visual pass" \
  "UI-02 Dashboard and sidebar pass" \
  "UI-03 Settings pass" \
  "UI-04 Agent screen pass" \
  "UI-05 Agent Log pass" \
  "UI-06 Menu bar and app menu pass" \
  "UI-07 Keyboard navigation pass" \
  "UI-08 VoiceOver label pass" \
  "UI-09 Motion and contrast comfort pass" \
  "RR-01 Physical no-network app launch from downloaded app" \
  "RR-02 Sleep/wake active-session cleanup" \
  "RR-03 Permission revoked mid-session recovery" \
  "RR-04 Quit while active cleanup" \
  "RR-05 Multi-display connect/disconnect recovery" \
  "RR-06 Support export privacy review" \
  "RR-07 Account access lost while active" \
  "Act confirmation approve/cancel/stop/timeout result:" \
  "Act network-drop recovery result:" \
  "Act Normal safety smoke result:" \
  "Act Unrestricted safety smoke result:" \
  "Act public-form submit confirmation result:" \
  "Act action-log audit trail result:" \
  "Dictation native-field insertion result:" \
  "Dictation browser-field insertion result:" \
  "Dictation long-paragraph result:" \
  "Dictation cancel-mid-dictation result:" \
  "Dictation offline recovery result:" \
  "Dictation microphone-denied recovery result:" \
  "Dictation wrong-field protection result:" \
  "Dictation short-text accuracy result:" \
  "Dictation punctuation result:" \
  "Context start/stop result:" \
  "Context memory write result:" \
  "Context Private Mode result:" \
  "Context app/site exclusion result:" \
  "Context delete-memory result:" \
  "Context multiple-display result:" \
  "Vault Notes visibility result:" \
  "Cross-app context quality result:" \
  "Talk current-screen answer result:" \
  "Talk memory-recall result:" \
  "Talk network-drop recovery result:" \
  "Talk missing-OAuth recovery result:" \
  "Talk long-thought/correction result:" \
  "Talk repeated-tool-requests result:" \
  "Talk stop-during-tool-call result:" \
  "Talk Agent Log review result:" \
  "Talk voice input/output result:" \
  "Act safety-mode-required result:" \
  "Act native-Voiyce-navigation result:" \
  "Act browser-navigation result:" \
  "Act public-test-form-fill result:" \
  "Act Gmail draft result:" \
  "Act Calendar read result:" \
  "Act desktop-app-switching result:" \
  "Act blocked-destructive-action result:" \
  "Act stop-during-Action-Cursor result:" \
  "Act missing-Accessibility recovery result:" \
  "Act missing-Screen-Recording recovery result:" \
  "Act Agent Log mid-task recovery result:" \
  "Physical no-network launch from downloaded app result:" \
  "Sleep/wake active-session cleanup result:" \
  "Permission revoked mid-session recovery result:" \
  "Quit while active cleanup result:" \
  "Multi-display connect/disconnect recovery result:" \
  "Support export privacy review result:" \
  "Launch from DMG and Applications result:" \
  "Permission return routing result:" \
  "Active account access loss result:" \
  "Billing mode sanity result:" \
  "Checkout and portal access result:" \
  "Account access transition result:" \
  "Usage limit recovery result:" \
  "Public home route result:" \
  "Auth/download flow result:" \
  "Legal pages result:" \
  "Public artifact checksum result:" \
  "Download-health fallback result:" \
  "Onboarding visual pass result:" \
  "Dashboard and sidebar pass result:" \
  "Settings pass result:" \
  "Agent screen pass result:" \
  "Agent Log pass result:" \
  "Menu bar and app menu pass result:" \
  "Keyboard navigation pass result:" \
  "VoiceOver label pass result:" \
  "Motion and contrast comfort pass result:" \
  "Hold the release if any required surface is unassigned"

clean_install_uat_output="$(run_generator scripts/generate-clean-install-uat.sh)"
check_output \
  "clean-install UAT generator" \
  "$clean_install_uat_output" \
  "### Clean Install UAT - YYYY-MM-DD" \
  "Current branch:" \
  "Current HEAD:" \
  "Current dirty path count: ${CURRENT_DIRTY_PATH_COUNT}" \
  "Support contact: aki.b@pentridgemedia.com" \
  "#### Install And First Launch" \
  "First launch opens the downloaded app, not Xcode/local build:" \
  "#### Permission Prompt Matrix" \
  "State after quit/reopen" \
  "#### Core Smoke From Downloaded App" \
  "Act Strict harmless navigation result:" \
  "#### Evidence Review" \
  "No raw transcripts copied into evidence:" \
  "Physical no-network launch from downloaded app result:" \
  "Hold invites, release notes, and paid launch if the downloaded app cannot be installed"

exploratory_qa_output="$(run_generator scripts/generate-exploratory-qa-pass.sh)"
check_output \
  "exploratory QA generator" \
  "$exploratory_qa_output" \
  "### Exploratory QA Pass - YYYY-MM-DD" \
  "Current branch:" \
  "Current HEAD:" \
  "Current dirty path count: ${CURRENT_DIRTY_PATH_COUNT}" \
  "Support contact: aki.b@pentridgemedia.com" \
  "#### Charter Assignment" \
  "EQ-01 Founder work session" \
  "EQ-07 Public web and artifact sweep" \
  "#### Required Observations" \
  "Voiyce avoided re-explaining work across at least two AI tools:" \
  "#### Evidence Review" \
  "No raw transcripts copied into evidence:" \
  "#### Decision" \
  "Hold invites, release notes, and paid launch if any exploratory P0/P1 remains"

launch_monitoring_output="$(run_generator scripts/generate-launch-monitoring-record.sh)"
check_output \
  "launch monitoring generator" \
  "$launch_monitoring_output" \
  "#### Launch Monitoring Record - YYYY-MM-DD HH:MM" \
  "Current branch:" \
  "Current HEAD:" \
  "Current dirty path count: ${CURRENT_DIRTY_PATH_COUNT}" \
  "Support contact: aki.b@pentridgemedia.com" \
  "##### Surface Checks" \
  "OpenAI usage/quota status:" \
  "Support inbox status:" \
  "##### Signals" \
  "Spend or quota anomaly:" \
  "##### Privacy Review" \
  "No secret values copied into record:" \
  "Pause new invites if any P0/P1 appears"

invite_batch_output="$(run_generator scripts/generate-invite-batch-record.sh)"
check_output \
  "invite batch generator" \
  "$invite_batch_output" \
  "### Invite Batch Record - YYYY-MM-DD" \
  "Current branch:" \
  "Current HEAD:" \
  "Current dirty path count: ${CURRENT_DIRTY_PATH_COUNT}" \
  "Support contact: aki.b@pentridgemedia.com" \
  "#### Batch Readiness Checks" \
  "Exact artifact copy includes version/build, DMG checksum, known limitations, support email, and privacy/reset-memory guidance:" \
  "#### Pause Criteria" \
  "Pause on any P0/P1:" \
  "#### Privacy Review" \
  "No secret values copied into record:" \
  "Do not send a new invite batch while a P0/P1 is open"

invite_resume_output="$(run_generator scripts/generate-invite-resume-checklist.sh)"
check_output \
  "invite resume generator" \
  "$invite_resume_output" \
  "### Invite Resume Checklist - YYYY-MM-DD" \
  "Current branch:" \
  "Current HEAD:" \
  "Current dirty path count: ${CURRENT_DIRTY_PATH_COUNT}" \
  "Support contact: aki.b@pentridgemedia.com" \
  "#### Required Verification" \
  'scripts/audit-launch-readiness.sh --live --allow-blockers' \
  'scripts/verify-production-landing.sh https://voiyce.us' \
  'scripts/verify-release.sh --skip-ui-tests --public-download-check --public-dmg-check --production-landing-check' \
  "Clean-machine or clean-user install evidence is current for the exact DMG users will receive:" \
  "#### Resume Safety Checks" \
  "Launch monitoring record prepared:" \
  "Pause authority confirmed:" \
  "#### Privacy Review" \
  "No secret values copied into record:" \
  "Do not resume invites if any P0/P1 remains"

support_inbox_output="$(run_generator scripts/generate-support-inbox-readiness.sh)"
check_output \
  "support inbox generator" \
  "$support_inbox_output" \
  "#### Support Inbox Readiness - YYYY-MM-DD" \
  "Current branch:" \
  "Current HEAD:" \
  "Current dirty path count: ${CURRENT_DIRTY_PATH_COUNT}" \
  "Support contact: aki.b@pentridgemedia.com" \
  "Primary support owner:" \
  "Backup support owner:" \
  "P0/P1 escalation path:" \
  "Support export privacy review instructions ready:" \
  "#### Support Path Proof" \
  "Support inbox test message sent and received:" \
  "P0/P1 pause decision path tested:" \
  "#### Privacy Review" \
  "No secret values copied into record:" \
  "Hold invites if no primary owner, backup owner, or P0/P1 escalation owner is assigned."

act_safety_output="$(run_generator scripts/generate-act-safety-incident.sh)"
check_output \
  "act safety incident generator" \
  "$act_safety_output" \
  "##### Act Safety Incident - YYYY-MM-DD" \
  "Current branch:" \
  "Current HEAD:" \
  "Current dirty path count: ${CURRENT_DIRTY_PATH_COUNT}" \
  "Support contact: aki.b@pentridgemedia.com" \
  "Safety mode: Strict / Normal / Unrestricted / unknown" \
  "Expected confirmation shown: yes / no / not applicable" \
  "Stop worked: yes / no / not tried" \
  "Sensitive surface involved: credentials / payment / private data / system settings / destructive action / none" \
  "Agent Log event IDs:" \
  "#### Safety Review" \
  "Blocked catastrophic/fraud/illegal-access/credential-theft/malware/hidden-action/platform-abusive request executed any local action:" \
  "#### Privacy Review" \
  "No secret values copied into record:" \
  "Hold invites if Act performs a hidden, destructive, credential, payment, private-data, or account-changing action without expected confirmation."

openai_key_rotation_output="$(run_generator scripts/generate-openai-key-rotation.sh)"
check_output \
  "OpenAI key rotation generator" \
  "$openai_key_rotation_output" \
  "### OpenAI Key Rotation - YYYY-MM-DD" \
  "Current branch:" \
  "Current HEAD:" \
  "Current dirty path count: ${CURRENT_DIRTY_PATH_COUNT}" \
  "Support contact: aki.b@pentridgemedia.com" \
  "Exposed key revoked in OpenAI dashboard:" \
  "Replacement key stored only in server-side function environment:" \
  "macOS app bundle does not contain \`OPENAI_API_KEY\` or \`sk-\` values:" \
  "Production function smoke result after rotation:" \
  "Usage/quota alerts reviewed:" \
  "#### Server-Side Storage Review" \
  "InsForge \`OPENAI_API_KEY\` presence confirmed, value redacted:" \
  "#### Privacy Review" \
  "No full key values copied into record:" \
  "Launch hold rule: if the exposed key is not revoked"

production_evidence_output="$(run_generator scripts/generate-production-evidence-packet.sh)"
check_output \
  "production evidence packet generator" \
  "$production_evidence_output" \
  "### Production Evidence Packet - YYYY-MM-DD" \
  "Current branch:" \
  "Current HEAD:" \
  "Current dirty path count: ${CURRENT_DIRTY_PATH_COUNT}" \
  "Support contact: aki.b@pentridgemedia.com" \
  "#### OpenAI Key Rotation" \
  "#### AI Usage And Quota Monitoring" \
  "OpenAI usage dashboard reviewed:" \
  "Pause/narrow/continue decision:" \
  'usage-cap env `VOIYCE_ENFORCE_AGENT_USAGE_CAPS`:' \
  '`NEXT_PUBLIC_INSFORGE_URL` auth env review:' \
  '`NEXT_PUBLIC_INSFORGE_ANON_KEY` presence, no value:' \
  "Auth provider callback/sign-in smoke:" \
  'Support inbox test message sent and received:' \
  'P0/P1 escalation path tested:' \
  'webhook signing-secret presence, no value:'

production_landing_cutover_output="$(run_generator scripts/generate-production-landing-cutover.sh)"
check_output \
  "production landing cutover generator" \
  "$production_landing_cutover_output" \
  "### Production Landing Cutover - YYYY-MM-DD" \
  "Current branch:" \
  "Current HEAD:" \
  "Current dirty path count: ${CURRENT_DIRTY_PATH_COUNT}" \
  "Support contact: aki.b@pentridgemedia.com" \
  "#### Deployment Identity" \
  "Deployment URL/id:" \
  "Deployed commit:" \
  "Rollback deployment/id:" \
  "#### Download Configuration" \
  'NEXT_PUBLIC_DOWNLOAD_URL' \
  "#### Auth Configuration" \
  'NEXT_PUBLIC_INSFORGE_URL' \
  'NEXT_PUBLIC_INSFORGE_ANON_KEY' \
  "Auth provider callback/sign-in smoke:" \
  "Auth/download handoff result:" \
  "#### Production Route Checks" \
  '`/api/download-health` result:' \
  "#### Production Smoke" \
  "scripts/verify-production-landing.sh https://voiyce.us" \
  "Stale dictation-first copy absent:" \
  "#### R2 Artifact Identity" \
  "R2 identity matches release record:" \
  "#### Monitoring And Resume" \
  "Invite/release-note decision: hold / narrow / resume" \
  "#### Privacy Review" \
  "No secret values copied into record:" \
  "Launch hold rule: if production serves stale copy"

stripe_live_billing_output="$(run_generator scripts/generate-stripe-live-billing-review.sh)"
check_output \
  "Stripe live billing review generator" \
  "$stripe_live_billing_output" \
  "### Stripe Live Billing Review - YYYY-MM-DD" \
  "Current branch:" \
  "Current HEAD:" \
  "Current dirty path count: ${CURRENT_DIRTY_PATH_COUNT}" \
  "Support contact: aki.b@pentridgemedia.com" \
  "#### Live Mode Decision" \
  'STRIPE_ALLOW_LIVE_MODE' \
  "Beta stays in test mode unless explicitly approved:" \
  "#### Product And Price Review" \
  "Monthly price id:" \
  "Yearly price id:" \
  "Fallback \`STRIPE_PRICE_ID\` decision:" \
  "#### Checkout And Portal Evidence" \
  "Checkout session evidence:" \
  "Billing portal evidence:" \
  "#### Webhook And Subscription Mapping" \
  "Webhook endpoint id:" \
  "STRIPE_WEBHOOK_SECRET" \
  "Subscription RPC/mapping evidence:" \
  "#### Privacy Review" \
  "No Stripe secret keys copied into record:" \
  "Launch hold rule: if the live-mode decision"

google_workspace_oauth_output="$(run_generator scripts/generate-google-workspace-oauth-review.sh)"
check_output \
  "Google Workspace OAuth review generator" \
  "$google_workspace_oauth_output" \
  "### Google Workspace OAuth Review - YYYY-MM-DD" \
  "Current branch:" \
  "Current HEAD:" \
  "Current dirty path count: ${CURRENT_DIRTY_PATH_COUNT}" \
  "Support contact: aki.b@pentridgemedia.com" \
  "#### OAuth App And Redirects" \
  "Authorized redirect URI evidence:" \
  "OAuth consent screen copy matches Gmail/Calendar feature surface:" \
  "#### Scope Review" \
  "Requested scopes match current app behavior:" \
  "App copy does not imply Gmail/Calendar access before connection:" \
  "#### Test Account Evidence" \
  "Missing-OAuth recovery result:" \
  "Revoked-OAuth recovery result:" \
  "Gmail read/query smoke result:" \
  "Calendar read/query smoke result:" \
  "#### Token And Privacy Review" \
  "No OAuth access tokens copied into record:" \
  "No raw email or calendar content copied into evidence:" \
  "#### Support And Launch Decision" \
  "Invite/release-note decision: hold / narrow / proceed" \
  "Launch hold rule: if OAuth app identity"

risk_exception_output="$(run_generator scripts/generate-risk-exception-register.sh)"
check_output \
  "risk/exception register generator" \
  "$risk_exception_output" \
  "### Launch Risk And Exception Register - YYYY-MM-DD" \
  "Current branch:" \
  "Current HEAD:" \
  "Current dirty path count: ${CURRENT_DIRTY_PATH_COUNT}" \
  "Support contact: aki.b@pentridgemedia.com" \
  "#### Risk Rows" \
  "accepted P2 / skipped diagnostic / manual UAT gap / external blocker / support exception" \
  "#### Required Checks" \
  "No accepted P0/P1 exceptions:" \
  "Every accepted P2 has user-facing workaround copy:" \
  "Every skipped diagnostic has owner-approved manual coverage:" \
  "Every manual UAT gap has replacement evidence or hold decision:" \
  "Every external/account blocker has owner and next action:" \
  "No OAuth tokens copied into record:" \
  "No payment details copied into record:" \
  "No unsafe Act behavior accepted without a fix:" \
  "#### Launch Decision" \
  "Invite/release-note decision: hold / narrow / proceed" \
  "Open risk blockers:" \
  "Launch hold rule: if any P0/P1 is accepted without a fix"

privacy_security_output="$(run_generator scripts/generate-privacy-security-review.sh)"
check_output \
  "privacy/security review generator" \
  "$privacy_security_output" \
  "### Privacy And Security Review - YYYY-MM-DD" \
  "Current branch:" \
  "Current HEAD:" \
  "Current dirty path count: ${CURRENT_DIRTY_PATH_COUNT}" \
  "Support contact: aki.b@pentridgemedia.com" \
  "#### Secret And Bundle Checks" \
  "OpenAI key rotation evidence, without secret values:" \
  "#### Data And Export Checks" \
  "Support export reviewed for raw transcripts, private screenshots, OAuth tokens, payment details, and secrets:" \
  "#### User-Facing Disclosure Checks" \
  "No raw transcripts, private screenshots, OAuth tokens, payment details, or secrets included:"

pre_invite_decision_output="$(run_generator scripts/generate-pre-invite-decision.sh)"
check_output \
  "pre-invite decision generator" \
  "$pre_invite_decision_output" \
  "### Pre-Invite Decision - YYYY-MM-DD" \
  "Current branch:" \
  "Current HEAD:" \
  "Current dirty path count: ${CURRENT_DIRTY_PATH_COUNT}" \
  "Support contact: aki.b@pentridgemedia.com" \
  "#### Required Evidence" \
  "OpenAI key rotation evidence without secret values:" \
  "#### Blocking Decision Checks" \
  "Release source tree committed, tagged, and reproducible:" \
  "Internal Dictation, Context, Talk, and Act manual UAT:" \
  "#### Launch Decision" \
  "No raw transcripts, private screenshots, OAuth tokens, or payment details copied:" \
  "Hold if any P0/P1 blocker, unresolved source-state mismatch, unrotated exposed key"

cat <<EOF
Evidence generator verification passed
  version/build/tag: ${EXPECTED_VERSION} / ${EXPECTED_BUILD} / ${EXPECTED_TAG}
  dirty path count reflected: ${CURRENT_DIRTY_PATH_COUNT}
  generators checked: 18
EOF
