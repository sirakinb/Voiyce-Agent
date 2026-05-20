#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_URL="${PRODUCTION_LANDING_URL:-https://voiyce.us}"
R2_PUBLIC_BASE_URL="${R2_PUBLIC_BASE_URL:-https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev}"
SUPPORT_EMAIL="aki.b@pentridgemedia.com"
RUN_LIVE=0
ALLOW_BLOCKERS=0

usage() {
  cat <<'EOF'
Usage: scripts/audit-launch-readiness.sh [--live] [--allow-blockers] [--base-url <url>]

Audits whether the current launch-readiness records still prove Voiyce is
blocked or ready for broader beta sharing. This script does not build, package,
deploy, notarize, upload, or mutate external services.

Checks:
  1. Required launch docs and verification scripts exist.
  2. Exact-artifact release notes match the current public artifact and owner-controlled beta status.
  3. External/manual blockers are visible in the PRD and launch tracker.
  4. Optional --live mode verifies the public production landing smoke gate and
     current public R2 manifest metadata.

Options:
  --live             Fetch production landing/R2 status without mutating anything.
  --allow-blockers   Exit 0 after reporting blockers. Useful while still in prep.
  --base-url <url>   Production landing URL for --live checks.

Examples:
  scripts/audit-launch-readiness.sh
  scripts/audit-launch-readiness.sh --allow-blockers
  scripts/audit-launch-readiness.sh --live --allow-blockers
EOF
}

log() {
  printf '\n==> %s\n' "$1"
}

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 2
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

PASSES=()
BLOCKERS=()

pass() {
  PASSES+=("$1")
}

blocker() {
  BLOCKERS+=("$1")
}

require_file() {
  local path="$1"
  local label="$2"

  if [[ -e "$ROOT_DIR/$path" ]]; then
    pass "$label exists"
  else
    blocker "$label is missing: $path"
  fi
}

require_contains() {
  local path="$1"
  local label="$2"
  local expected="$3"

  if rg -q -F -- "$expected" "$ROOT_DIR/$path"; then
    pass "$label is recorded"
  else
    blocker "$label is missing from $path"
  fi
}

require_open_item() {
  local path="$1"
  local label="$2"
  local unchecked_regex="$3"
  local checked_regex="$4"

  if rg -q -- "$checked_regex" "$ROOT_DIR/$path"; then
    pass "$label is marked complete"
  elif rg -q -- "$unchecked_regex" "$ROOT_DIR/$path"; then
    blocker "$label is still open"
  else
    blocker "$label status could not be found in $path"
  fi
}

require_no_matches() {
  local label="$1"
  local regex="$2"
  shift 2

  local paths=()
  for path in "$@"; do
    paths+=("$ROOT_DIR/$path")
  done

  if rg -n -- "$regex" "${paths[@]}"; then
    blocker "$label found disallowed matches"
  else
    pass "$label has no disallowed matches"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --live)
      RUN_LIVE=1
      shift
      ;;
    --allow-blockers)
      ALLOW_BLOCKERS=1
      shift
      ;;
    --base-url)
      [[ $# -ge 2 ]] || fail "--base-url requires a value"
      BASE_URL="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

require_command rg
require_command git
if [[ "$RUN_LIVE" -eq 1 ]]; then
  require_command curl
  require_command python3
fi

cd "$ROOT_DIR"

CURRENT_DIRTY_PATH_COUNT="$(git status --porcelain=v1 --untracked-files=all | sed '/^$/d' | wc -l | tr -d ' ')"

log "Checking launch-readiness files"
require_file "tasks/prd-voiyce-agent-full-vision.md" "Launch PRD"
require_file "docs/launch-ready-self-serve.md" "Launch tracker"
require_file "docs/manual-uat-matrix.md" "Manual UAT matrix"
require_file "docs/launch-test-strategy.md" "Launch test strategy"
require_file "docs/beta-launch-communications.md" "Beta communications"
require_file "docs/launch-rollback-runbook.md" "Rollback runbook"
require_file "docs/agent-tier-cost-plan.md" "Agent tier cost plan"
require_file "docs/phase-2-production-hardening.md" "Phase 2 production hardening"
require_file "docs/stripe-billing-connection.md" "Stripe billing connection"
require_file "docs/releases/Voiyce-1.0+16.md" "Exact artifact release record"
require_file "docs/releases/Voiyce-1.0+16-beta-release-notes.md" "Exact artifact beta release notes"
require_file "scripts/verify-release.sh" "Release verifier"
require_file "scripts/verify-release-source-state.sh" "Release source-state verifier"
require_file "scripts/generate-release-source-disposition.sh" "Release source disposition generator"
require_file "scripts/generate-launch-evidence-package.sh" "Launch evidence package generator"
require_file "scripts/generate-manual-uat-pass.sh" "Manual UAT pass generator"
require_file "scripts/generate-clean-install-uat.sh" "Clean-install UAT generator"
require_file "scripts/generate-exploratory-qa-pass.sh" "Exploratory QA generator"
require_file "scripts/generate-launch-monitoring-record.sh" "Launch monitoring generator"
require_file "scripts/generate-invite-batch-record.sh" "Invite batch generator"
require_file "scripts/generate-invite-resume-checklist.sh" "Invite resume generator"
require_file "scripts/generate-support-inbox-readiness.sh" "Support inbox generator"
require_file "scripts/generate-act-safety-incident.sh" "Act safety incident generator"
require_file "scripts/generate-openai-key-rotation.sh" "OpenAI key rotation generator"
require_file "scripts/generate-production-evidence-packet.sh" "Production evidence packet generator"
require_file "scripts/generate-production-landing-cutover.sh" "Production landing cutover generator"
require_file "scripts/generate-stripe-live-billing-review.sh" "Stripe live billing review generator"
require_file "scripts/generate-google-workspace-oauth-review.sh" "Google Workspace OAuth review generator"
require_file "scripts/generate-risk-exception-register.sh" "Risk/exception register generator"
require_file "scripts/generate-privacy-security-review.sh" "Privacy/security review generator"
require_file "scripts/generate-pre-invite-decision.sh" "Pre-invite decision generator"
require_file "scripts/verify-evidence-generators.sh" "Evidence generator verifier"
require_file "scripts/verify-launch-blockers.sh" "Launch blocker verifier"
require_file "scripts/verify-agent-usage-caps.sh" "Agent usage-cap verifier"
require_file "scripts/verify-release-archive.sh" "Release archive verifier"
require_file "scripts/verify-public-dmg.sh" "Public DMG verifier"
require_file "scripts/verify-launch-site.sh" "Launch site verifier"
require_file "scripts/verify-production-landing.sh" "Production landing verifier"
require_file "scripts/verify-rollback-readiness.sh" "Rollback readiness verifier"

log "Checking release-note status"
require_contains \
  "docs/releases/Voiyce-1.0+16-beta-release-notes.md" \
  "Beta release notes owner-controlled sharing status" \
  "Status: ready for owner-controlled beta sharing."
require_contains \
  "docs/releases/Voiyce-1.0+16-beta-release-notes.md" \
  "Production landing verified status" \
  "Landing deployment status: verified on 2026-05-20."
require_contains \
  "docs/releases/Voiyce-1.0+16-beta-release-notes.md" \
  "Current public artifact checksum" \
  "bfed37a6f089eb83d0d5426fc5d25dbd709184bf2f85feceefac70ee68c485d5"
for expected_release_field in \
  "Version: \`1.0\`" \
  "Build: \`16\`" \
  "Release source tag recorded with the published artifact: \`v1.0+16\`" \
  "Latest DMG: https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/Voiyce.dmg" \
  "Versioned DMG: https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/releases/Voiyce-1.0+16.dmg" \
  "Manifest: https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/latest.json" \
  "Notarization: accepted and stapled" \
  "Signing origin: \`Developer ID Application: Akinyemi Bajulaiye (R28KUQ4KQP)\`" \
  "The public \`1.0+16\` DMG has been rebuilt from the current source candidate, notarized, stapled, uploaded to R2, and verified against the live manifest." \
  "current release-candidate source is clean and tagged"
do
  require_contains "docs/releases/Voiyce-1.0+16-beta-release-notes.md" "Beta release note artifact field: $expected_release_field" "$expected_release_field"
done
for expected_record_field in \
  "Version: \`1.0\`" \
  "Build: \`16\`" \
  "Checksum: \`bfed37a6f089eb83d0d5426fc5d25dbd709184bf2f85feceefac70ee68c485d5\`" \
  "Release source state: tag \`v1.0+16\` points at the clean release commit." \
  "Release-candidate source tag status: \`v1.0+16\` points at the current clean source candidate." \
  "The public \`1.0+16\` DMG has been rebuilt from the current source candidate, notarized, stapled, uploaded to R2, and verified against the live manifest." \
  "Full release-candidate gate"
do
  require_contains "docs/releases/Voiyce-1.0+16.md" "Exact artifact release record field: $expected_record_field" "$expected_record_field"
done

log "Checking beta communications guardrails"
require_contains \
  "docs/beta-launch-communications.md" \
  "Beta communications draft status" \
  "Status: draft for internal launch readiness."
require_contains \
  "docs/beta-launch-communications.md" \
  "Beta communications owner-controlled sharing warning" \
  "ready for owner-controlled beta sharing after final owner sign-off on the invite list and support coverage"
require_contains \
  "docs/beta-launch-communications.md" \
  "Beta communications label decision" \
  "The next public build should be labeled **Beta**."
require_contains \
  "docs/beta-launch-communications.md" \
  "Beta communications production-label guard" \
  "Do not describe the build as Production or generally available."
require_contains \
  "docs/beta-launch-communications.md" \
  "Beta communications agent-context positioning" \
  "Voiyce is the agent context layer"
require_contains \
  "docs/beta-launch-communications.md" \
  "Beta communications support contact" \
  "Support: $SUPPORT_EMAIL"
for expected_beta_section in \
  "## Known Limitations" \
  "## Release Notes Send Gate" \
  "## Permissions Explanation" \
  "## Privacy And Memory Summary" \
  "## Data Processing Map" \
  "### Known Limitation Workaround Register" \
  "## Support And Bug Report Path" \
  "### Support Intake Template" \
  "## Support Escalation Matrix" \
  "### Support Inbox Readiness Record" \
  "### Severity Response Targets" \
  "## Support Response Playbook" \
  "## Launch-Day Monitoring Checklist" \
  "## Invite Resume Checklist" \
  "## Clean Install Instructions" \
  "### Clean Install Evidence Checklist" \
  "## Uninstall And Reset-Memory Note"
do
  require_contains "docs/beta-launch-communications.md" "Beta communications section: $expected_beta_section" "$expected_beta_section"
done
for expected_release_notes_gate_field in \
  "Use this only as a starting point for a future exact release candidate." \
  "For the currently published \`1.0+16\` artifact, use \`docs/releases/Voiyce-1.0+16-beta-release-notes.md\` instead." \
  "Do not send template notes." \
  "The notes are tied to one exact artifact, not the generic draft template." \
  "Version, build, Git commit, release tag, DMG URL, SHA-256, notarization status, signing origin, landing deployment URL/id, and R2 manifest URL are filled." \
  "\`docs/releases/Voiyce-1.0+16-beta-release-notes.md\` is ready for owner-controlled beta sharing after final owner sign-off." \
  "Production landing verification passes against \`https://voiyce.us\`, including \`/api/download-health\` and current agent-context copy." \
  "Clean-machine install evidence and manual UAT evidence are linked from the pre-invite decision record." \
  "Production environment evidence is recorded without secret values." \
  "Accepted P2 limitations have user-facing workaround copy." \
  "Support contact, Terms, Privacy, invite copy, release notes, and the landing page all use \`aki.b@pentridgemedia.com\`." \
  "Support intake instructions tell users to review screenshots, recordings, and Agent Log exports before sharing." \
  "Final owner sign-off is recorded."
do
  require_contains "docs/beta-launch-communications.md" "Beta communications release-notes gate field: $expected_release_notes_gate_field" "$expected_release_notes_gate_field"
done
for expected_limitation_workaround_field in \
  "Use this before release notes, support replies, invite batches, or owner-approved narrow invites." \
  "Every accepted limitation needs a plain user-facing workaround and a support owner." \
  "| Limitation | User impact | User-facing workaround | Support action | Owner | Ship decision |" \
  "Permission-dependent modes" \
  "Open Voiyce Settings > Permissions, grant the missing macOS permission, then quit and reopen if the state does not refresh." \
  "Act on dense or blocked UI" \
  "Use Strict mode, keep actions low-risk, stop when UI looks wrong, and handle CAPTCHA/login/protected flows manually." \
  "Pending safety checks" \
  "Rephrase the task into a smaller low-risk step or finish the blocked step manually." \
  "Local-first memory" \
  "Use the local vault/export paths for review, and use Settings > Memory > Delete Memory before manual reset." \
  "Talk latency and interruption tuning" \
  "Wait for the progress phrase, stop/retry if it feels stuck, and use shorter requests for urgent tasks." \
  "Google-connected features" \
  "Connect Google before asking Gmail/Calendar questions, or treat missing connection as a blocker." \
  "Limitations hold rule: hold release notes or the next invite batch if any accepted limitation lacks user-facing workaround copy, support owner, support action, or a matching known-limitation entry in release notes/support replies."
do
  require_contains "docs/beta-launch-communications.md" "Beta communications limitation workaround field: $expected_limitation_workaround_field" "$expected_limitation_workaround_field"
done
require_contains \
  "docs/beta-launch-communications.md" \
  "Beta communications in-app memory delete preference" \
  "Before broad beta sharing, confirm the in-app memory delete control works and prefer that path."
require_contains \
  "docs/beta-launch-communications.md" \
  "Beta communications support-guided manual reset" \
  "Manual reset should stay support-guided, but the current build's Voiyce-owned memory paths are now identified:"
for expected_memory_reset_path in \
  "~/Library/Application Support/Voiyce-Agent/Memory/SignedOut/long-term-memory.json" \
  "~/Library/Application Support/Voiyce-Agent/Memory/Accounts/user-<hex-encoded-account-id>/long-term-memory.json" \
  "~/Library/Application Support/Voiyce-Agent/Memory/SignedOut/Screenshots/" \
  "~/Library/Application Support/Voiyce-Agent/Memory/Accounts/user-<hex-encoded-account-id>/Screenshots/" \
  "\`Daily/*.md\` files inside the selected Voiyce memory vault" \
  "Prefer Settings > Memory > Delete Memory first."
do
  require_contains "docs/beta-launch-communications.md" "Beta communications memory reset path: $expected_memory_reset_path" "$expected_memory_reset_path"
done
for expected_support_intake_field in \
  "Keep raw transcripts, screenshots, secrets, OAuth tokens, and payment details out of the ticket" \
  "#### Support Report - YYYY-MM-DD" \
  "Severity: P0 / P1 / P2 / P3" \
  "Voiyce version/build:" \
  "Install source: public DMG / candidate DMG / local build" \
  "Active mode: Dictation / Context / Talk / Act / Settings / Website / Billing" \
  "Permission state: Microphone / Screen Recording / Accessibility / Speech Recognition / Notifications" \
  "Account state: signed out / signed in / Pro / free / unknown" \
  "Screenshot/recording reviewed for sensitive content:" \
  "Agent Log/support export reviewed for sensitive content:" \
  "Support export event IDs:" \
  "User-facing reply sent:"
do
  require_contains "docs/beta-launch-communications.md" "Beta communications support intake field: $expected_support_intake_field" "$expected_support_intake_field"
done
for expected_support_inbox_field in \
  "Use this before the first invite batch, after any support-owner change, and before resuming invites after an incident." \
  "#### Support Inbox Readiness - YYYY-MM-DD" \
  "Primary inbox:" \
  "Primary support owner:" \
  "Backup support owner:" \
  "Engineering escalation owner:" \
  "Billing escalation owner:" \
  "Rollback owner:" \
  "Monitoring cadence:" \
  "First-hour coverage window:" \
  "First-day coverage window:" \
  "P0/P1 escalation path:" \
  "P2 triage path:" \
  "Support intake template ready:" \
  "Support response playbook ready:" \
  "Known limitations link:" \
  "Clean-install evidence link:" \
  "Launch monitoring record link:" \
  "Risk/exception register link:" \
  "Support export privacy review instructions ready:" \
  "User-facing first reply template ready:" \
  "Invite pause authority:" \
  "Hold invites if no primary owner, backup owner, or P0/P1 escalation owner is assigned." \
  "Hold invites if the inbox will not be monitored during the first-hour and first-day windows." \
  "Hold invites if support replies still ask for raw transcripts, unreviewed screenshots, OAuth tokens, payment details, or secrets." \
  "Hold invites if support cannot pause invite expansion when a P0/P1 report arrives."
do
  require_contains "docs/beta-launch-communications.md" "Beta communications support inbox field: $expected_support_inbox_field" "$expected_support_inbox_field"
done
for expected_severity_response_field in \
  "Use these targets during the first private beta window and any later invite expansion." \
  "| Severity | First response target | Owner expectation | Invite decision | Required evidence |" \
  "| P0 | Same day, immediately when seen | Support owner and engineering owner assigned before more invites | Pause all new invites until fixed, rolled back, or explicitly held | Incident note, support report, monitoring record, affected artifact/build, and owner sign-off |" \
  "| P1 | Same business day | Single owner assigned and next action recorded | Pause the affected workflow or narrow the next batch | Support report, reproduction status, workaround or hold decision, and owner sign-off |" \
  "| P2 | Within 2 business days | Owner or backlog destination recorded | Continue only if user-facing workaround exists | Support report, known-limitation or workaround copy, and risk-register link |" \
  "| P3 | Before the next planned invite expansion | Track as polish or wishlist | Continue if it is polish-only and does not confuse launch positioning | Support report or tracker link |" \
  "Any secret exposure, private-data leak, unsafe Act behavior, broken public download, unexpected live charge, or crash loop is P0 until reviewed." \
  "Two users in one invite batch reporting the same install, auth, Dictation, Talk, Act, billing, or privacy issue escalate the issue at least one severity level." \
  "A P2 without a clear workaround becomes a launch hold for broader invites." \
  "Every P0/P1 needs a user-facing reply, owner, next action, and invite decision before another batch is sent."
do
  require_contains "docs/beta-launch-communications.md" "Beta communications severity response field: $expected_severity_response_field" "$expected_severity_response_field"
done
for expected_support_playbook_field in \
  "Use these reply patterns during beta so support stays concrete and privacy-safe." \
  "Do not ask users to send raw transcripts, full screenshots, OAuth tokens, payment details, or secrets." \
  "### Install Or Download Blocked" \
  "We are checking the public DMG, checksum, and download route before sending more invites." \
  "Pause condition: any checksum mismatch, broken public download, Gatekeeper rejection, or damaged-app warning from the intended DMG." \
  "### Permission Recovery" \
  "Pause condition: a granted permission still blocks the same feature after refresh, quit, and reopen." \
  "### Dictation Or Talk Failure" \
  "Do not include the spoken transcript unless you intentionally want us to see it." \
  "Pause condition: repeated failures across multiple users, quota/rate-limit spikes, or provider errors that leave Dictation/Talk stuck active." \
  "### Act Mode Safety Or Stop Failure" \
  "We will treat any unexpected action, missing confirmation, or Stop failure as a launch-blocking report until reviewed." \
  "Pause condition: unsafe action, missing expected confirmation, hidden/destructive action attempt, or Stop failing to cancel visible work." \
  "### Billing Or Account Access" \
  "Do not send card numbers, payment screenshots with private details, Stripe secrets, or bank information." \
  "Pause condition: unexpected live charge, wrong price, paid access not unlocking, or multiple users blocked after payment/sign-in." \
  "### Privacy Or Memory Concern" \
  "Pause condition: raw transcript, private screenshot, credential, payment data, OAuth token, OpenAI-style key, or excluded/private context appears in memory, Agent Log, support export, or shared docs."
do
  require_contains "docs/beta-launch-communications.md" "Beta communications support playbook field: $expected_support_playbook_field" "$expected_support_playbook_field"
done
for expected_act_safety_incident_field in \
  "#### Act Safety Incident Checklist" \
  "Use this for any Act report involving an unexpected action, missing confirmation, blocked action, sensitive workflow, Stop failure, or user concern about app control." \
  "##### Act Safety Incident - YYYY-MM-DD" \
  "Safety mode: Strict / Normal / Unrestricted / unknown" \
  "Requested action:" \
  "Actual visible action:" \
  "Expected confirmation shown: yes / no / not applicable" \
  "Stop button visible: yes / no / unknown" \
  "Stop worked: yes / no / not tried" \
  "Sensitive surface involved: credentials / payment / private data / system settings / destructive action / none" \
  "Agent Log event IDs:" \
  "Invite decision: pause / narrow / continue" \
  "Kill switch or capability narrowing considered:" \
  "Hold invites if Act performs a hidden, destructive, credential, payment, private-data, or account-changing action without expected confirmation." \
  "Hold invites if Stop is not visible or does not cancel visible work." \
  "Hold invites if a blocked catastrophic, fraud, illegal-access, credential-theft, malware, hidden-action, or platform-abusive request executes any local action." \
  "Hold invites if the same Act safety report appears from two users in one invite batch."
do
  require_contains "docs/beta-launch-communications.md" "Beta communications Act safety incident field: $expected_act_safety_incident_field" "$expected_act_safety_incident_field"
done
for expected_monitoring_record_field in \
  "### Monitoring Evidence Template" \
  "Use one record for the first-hour window, one for the first-day window, and one for each weekly invite expansion." \
  "#### Launch Monitoring Record - YYYY-MM-DD HH:MM" \
  "Monitor owner:" \
  "Window: first hour / first day / weekly expansion / after change" \
  "Invite batch size:" \
  "Decision: continue / pause / rollback / narrow invite" \
  "Website/Vercel status:" \
  "Cloudflare R2 status:" \
  "InsForge functions status:" \
  "OpenAI usage/quota status:" \
  "Stripe mode/webhook status:" \
  "Support inbox status:" \
  "P0 count:" \
  "P1 count:" \
  "P2 count:" \
  "Repeated failure pattern:" \
  "Spend or quota anomaly:" \
  "Download or checksum anomaly:" \
  "Privacy/security concern:" \
  "Invite pause or resume decision:" \
  "Next review time:" \
  "Final owner sign-off:" \
  "Pause rule: pause new invites if any P0/P1 appears"
do
  require_contains "docs/beta-launch-communications.md" "Beta communications monitoring record field: $expected_monitoring_record_field" "$expected_monitoring_record_field"
done
for expected_invite_batch_field in \
  "## Invite Batch Control" \
  "Use this before sending each private beta batch" \
  "### Invite Batch Record - YYYY-MM-DD" \
  "Batch owner:" \
  "Support owner:" \
  "Monitoring owner:" \
  "Rollback owner:" \
  "Target user count:" \
  "Target persona:" \
  "Invite source: founder list / design partner / waitlist / internal referral" \
  "Release version/build:" \
  "Git commit:" \
  "Landing deployment URL/id:" \
  "DMG URL/checksum:" \
  "Known limitations linked:" \
  "Pre-invite decision link:" \
  "Launch evidence package link:" \
  "Risk and exception register link:" \
  "Monitoring window scheduled:" \
  "Pause criteria sent to owners:" \
  "Decision: send / hold / narrow" \
  "Start with 3-5 high-trust users before any larger batch." \
  "Wait through the first-hour monitoring window before sending another batch."
do
  require_contains "docs/beta-launch-communications.md" "Beta communications invite batch field: $expected_invite_batch_field" "$expected_invite_batch_field"
done
for expected_invite_resume_field in \
  "Current P0/P1 queue is empty or each item has an owner, mitigation, and explicit hold decision." \
  "Any accepted P2 limitation has a user-facing workaround in beta notes or support replies." \
  "scripts/audit-launch-readiness.sh --live --allow-blockers" \
  "scripts/verify-production-landing.sh https://voiyce.us" \
  "scripts/verify-release.sh --skip-ui-tests --public-download-check --public-dmg-check --production-landing-check" \
  "The pre-invite decision record is updated with release version/build, Git commit, DMG checksum, landing deployment, R2 manifest, support owner, and rollback owner." \
  "Clean-machine or clean-user install evidence is current for the exact DMG users will receive." \
  "Manual UAT evidence covers onboarding, Dictation, Context, Talk, Act in Strict, Agent Log, Settings, billing/account access, and legal/download paths." \
  "Production environment evidence covers OpenAI key rotation, InsForge function env, usage-cap decision, Vercel env, R2 objects, Stripe mode, and support inbox ownership without copying secret values." \
  "Rollback readiness evidence identifies the previous known-good landing deployment, R2 latest object, backend function version, app artifact, and owner." \
  "Support/contact/release notes match the exact artifact and still use \`aki.b@pentridgemedia.com\`." \
  "Final owner sign-off is recorded before sending the next invite batch."
do
  require_contains "docs/beta-launch-communications.md" "Beta communications invite-resume field: $expected_invite_resume_field" "$expected_invite_resume_field"
done
for expected_clean_install_evidence_field in \
  "Use this immediately after the clean-machine or clean-user pass." \
  "#### Clean Install Evidence - YYYY-MM-DD" \
  "New macOS user or clean machine:" \
  "Voiyce version/build:" \
  "DMG URL:" \
  "DMG SHA-256:" \
  "Manifest URL:" \
  "Notarization/Gatekeeper result:" \
  "Installed from Applications:" \
  "Sign-in path tested:" \
  "Permission path: all granted / one denied at a time / revoked after grant" \
  "Microphone state after quit/reopen:" \
  "Speech Recognition state after quit/reopen:" \
  "Screen Recording state after quit/reopen:" \
  "Accessibility state after quit/reopen:" \
  "Dictation native-field result:" \
  "Dictation browser-field result:" \
  "Context start/stop result:" \
  "Talk simple-question result:" \
  "Act Strict low-risk action result:" \
  "Agent Log/support export result:" \
  "Settings permission refresh result:" \
  "Memory delete/reset result:" \
  "Legal/download route result:" \
  "P0/P1 found:" \
  "P2 found and workaround:" \
  "Final decision: pass / hold / rerun" \
  "Hold if the DMG checksum, manifest, version/build, notarization, or Gatekeeper result does not match release notes." \
  "Hold if any permission remains stale after refresh, quit, and reopen." \
  "Hold if Dictation, Context, Talk, Act Strict, Agent Log, Settings, sign-in, or legal/download paths cannot complete their smoke path." \
  "Hold if evidence includes unreviewed private screenshots, transcripts, tokens, payment details, or secrets."
do
  require_contains "docs/beta-launch-communications.md" "Beta communications clean-install evidence field: $expected_clean_install_evidence_field" "$expected_clean_install_evidence_field"
done

log "Checking rollback runbook guardrails"
require_contains \
  "docs/launch-rollback-runbook.md" \
  "Rollback runbook internal status" \
  "Status: internal runbook."
require_contains \
  "docs/launch-rollback-runbook.md" \
  "Rollback runbook smallest-surface principle" \
  "Prefer reverting the smallest failing surface"
require_contains \
  "docs/launch-rollback-runbook.md" \
  "Rollback runbook no dirty-tree DMG warning" \
  "Do not upload a replacement DMG from a dirty tree."
require_contains \
  "docs/launch-rollback-runbook.md" \
  "Rollback runbook support contact" \
  'Keep the support contact active: `aki.b@pentridgemedia.com`.'
for expected_rollback_section in \
  "## Severity Triggers" \
  "## Immediate Triage" \
  "## Landing Rollback" \
  "## R2 DMG Rollback" \
  "## Backend Function Rollback" \
  "## App Artifact Rollback" \
  "## Verification After Any Rollback" \
  "## Resume After Rollback Checklist" \
  "## Incident Note Template"
do
  require_contains "docs/launch-rollback-runbook.md" "Rollback runbook section: $expected_rollback_section" "$expected_rollback_section"
done
for expected_rollback_resume_field in \
  "Incident note is complete, with support owner, engineering owner, severity, affected surface, and rollback surface recorded." \
  "New-user exposure is paused or intentionally narrowed until verification passes." \
  "Current public landing passes \`scripts/verify-launch-site.sh --url https://voiyce.us\` or the production landing verifier for the intended deployment." \
  "Public R2 \`latest.json\`, latest DMG, versioned DMG, and checksum sidecars match the artifact users should receive." \
  "\`scripts/verify-release.sh --public-download-check --skip-ui-tests\` passes against the intended public artifact." \
  "Clean-machine or clean-user install evidence exists for the artifact users should receive after rollback." \
  "Manual smoke covers home, auth, download, install, launch, permissions, Dictation, Agent screen, and support contact." \
  "Any disabled kill switch or narrowed capability is reflected in beta notes, support replies, and known limitations." \
  "Support inbox has an owner and user-facing reply ready for affected users." \
  "Release notes and invite copy identify the exact version/build now being served." \
  "Open P0/P1 blockers are zero or the launch remains paused." \
  "Accepted P2 limitations have user-facing workaround copy." \
  "Final owner sign-off is recorded before invites resume."
do
  require_contains "docs/launch-rollback-runbook.md" "Rollback resume checklist field: $expected_rollback_resume_field" "$expected_rollback_resume_field"
done
for expected_incident_field in \
  "Date/time opened:" \
  "Support owner:" \
  "Engineering owner:" \
  "Surface: landing / auth / download / DMG / app / backend / billing / account" \
  "Severity: P0 / P1 / P2 / P3" \
  "Pause decision: pause invites / narrow invites / keep monitoring" \
  "Rollback surface: none / landing / R2 DMG / backend function / app artifact / billing config" \
  "Data/privacy risk:" \
  "Billing/payment risk:" \
  "Related support report IDs:" \
  "Kill switches changed:" \
  "Rollback command/result:" \
  "Automated commands/results:" \
  "Clean-machine or clean-user result:" \
  "Required verification before resuming invites:" \
  "Final owner sign-off:"
do
  require_contains "docs/launch-rollback-runbook.md" "Rollback incident field: $expected_incident_field" "$expected_incident_field"
done
for expected_rollback_check in \
  "scripts/verify-rollback-readiness.sh" \
  "scripts/verify-release.sh --public-download-check --skip-ui-tests" \
  "scripts/verify-launch-site.sh --url https://voiyce.us" \
  "scripts/verify-release.sh"
do
  require_contains "docs/launch-rollback-runbook.md" "Rollback runbook verification: $expected_rollback_check" "$expected_rollback_check"
done

log "Checking tier and cost plan guardrails"
for expected_tier_plan_field in \
  "Server-side usage-cap primitives now exist behind \`VOIYCE_ENFORCE_AGENT_USAGE_CAPS=true\` for Realtime, transcription, Computer Use, and screen-context requests." \
  "Production confirmation that \`VOIYCE_ENFORCE_AGENT_USAGE_CAPS=true\` is set and server-side tier mapping matches Stripe products." \
  "Per-user cost ledger for Realtime, transcription, Computer Use, and screen-context requests. Implemented server-side behind \`VOIYCE_ENFORCE_AGENT_USAGE_CAPS=true\`; production env confirmation remains open." \
  "Per-tier hard caps for Realtime, transcription, Context, Computer Use, and local memory/raw screenshot retention." \
  "Admin kill switches for all AI, Realtime, transcription, Computer Use, screen context, and VideoDB-backed session context." \
  "Confirm production usage-cap env values and Stripe-to-tier mapping before charging."
do
  require_contains "docs/agent-tier-cost-plan.md" "Tier/cost plan field: $expected_tier_plan_field" "$expected_tier_plan_field"
done

log "Checking production hardening environment guardrails"
for expected_hardening_field in \
  "Set these in the server-side function environment, not in the macOS app bundle or browser bundle." \
  "\`OPENAI_API_KEY\` | Server-side OpenAI calls | Required" \
  "\`VOIYCE_DISABLE_ALL_AI\` | Emergency stop for all OpenAI-backed AI calls | Off" \
  "\`VOIYCE_DISABLE_REALTIME\` | Disable Realtime voice only | Off" \
  "\`VOIYCE_DISABLE_TRANSCRIPTION\` | Disable transcription only | Off" \
  "\`VOIYCE_DISABLE_COMPUTER_USE\` | Disable Act Computer Use only | Off" \
  "\`VOIYCE_DISABLE_SCREEN_CONTEXT\` | Disable screen-context analysis only | Off" \
  "\`VOIYCE_DISABLE_SESSION_CONTEXT\` | Disable VideoDB-backed session context capture/search | Off" \
  "\`VOIYCE_ENFORCE_AGENT_USAGE_CAPS\` | Enable server-side usage reservation/finalization for agent capabilities | Off" \
  "\`VOIYCE_REALTIME_MAX_SDP_CHARS\` | Realtime SDP request cap | \`25000\`" \
  "\`VOIYCE_TRANSCRIPTION_MAX_AUDIO_BYTES\` | Audio upload cap | \`10485760\`" \
  "\`VOIYCE_COMPUTER_USE_MAX_TASK_CHARS\` | Act task prompt cap | \`2000\`" \
  "\`VOIYCE_SCREEN_CONTEXT_MAX_IMAGE_BASE64_CHARS\` | Screen-context image cap | \`8000000\`" \
  "\`VOIYCE_SESSION_CONTEXT_MAX_QUERY_CHARS\` | Session-context search query cap | \`1000\`" \
  "## Production Environment Verification Template" \
  "Record only presence/status and dashboard links or screenshots; do not copy secret values into docs, support exports, or chat." \
  "OpenAI dashboard | Exposed development keys are revoked, the active server-side key is current, and usage/quota alerts are visible." \
  "InsForge functions | \`OPENAI_API_KEY\`, model overrides, AI kill switches, request caps, \`VOIYCE_DISABLE_SESSION_CONTEXT\`, and \`VOIYCE_ENFORCE_AGENT_USAGE_CAPS\` match the launch decision." \
  "Vercel landing | \`NEXT_PUBLIC_DOWNLOAD_URL\`, \`NEXT_PUBLIC_INSFORGE_URL\`, auth anon-key presence, auth/download configuration, and production deployment point at the intended build, intended auth project, and public DMG." \
  "Cloudflare R2 | \`latest.json\`, latest DMG, versioned DMG, and checksum sidecars point to the intended version/build." \
  "Stripe | Mode, products, prices, checkout, billing portal, webhook endpoint, and webhook secret match the beta/paid launch decision." \
  "## OpenAI Key Rotation Evidence Checklist" \
  "Use this when rotating the exposed development key and before marking the key blocker complete." \
  "Do not paste full keys, environment values, request bodies, support exports, or logs containing bearer tokens." \
  "### OpenAI Key Rotation - YYYY-MM-DD" \
  "Security owner:" \
  "Exposed key label/last-four, if safely known:" \
  "Exposed key revoked in OpenAI dashboard:" \
  "Replacement key created:" \
  "Replacement key stored only in server-side function environment:" \
  "macOS app bundle does not contain" \
  "Landing/browser bundle does not contain" \
  "Source secret scan result:" \
  "Built app secret scan result:" \
  "Landing build secret scan result:" \
  "Production function smoke result after rotation:" \
  "Old-key negative check, if available without exposing the key:" \
  "Usage/quota alerts reviewed:" \
  "Evidence reviewed for secret values before sharing:" \
  "Remaining key/security blockers:" \
  "Final security owner sign-off:" \
  "Launch hold rule: if the exposed key is not revoked, the replacement key is not server-side only, any bundle/source scan finds an OpenAI-style key, or the evidence requires copying a full secret value, keep release notes and invites paused." \
  "## AI Usage And Quota Monitoring Record" \
  "Use this before the first invite batch, during the first-hour monitoring window, and before resuming invites after any quota, rate-limit, or cost anomaly." \
  "Do not paste API keys, bearer tokens, request bodies, raw transcripts, private screenshots, or full support exports." \
  "### AI Usage And Quota Monitoring - YYYY-MM-DD" \
  "Monitoring owner:" \
  "Invite batch or release candidate:" \
  "Window start/end:" \
  "OpenAI usage dashboard reviewed:" \
  "OpenAI hard spend/quota limit visible:" \
  "OpenAI usage alert threshold reviewed:" \
  "Realtime usage trend normal / elevated / hold:" \
  "Transcription usage trend normal / elevated / hold:" \
  "Computer Use usage trend normal / elevated / hold:" \
  "Screen-context usage trend normal / elevated / hold:" \
  "InsForge usage-cap events reviewed:" \
  "\`VOIYCE_ENFORCE_AGENT_USAGE_CAPS\` production value reviewed:" \
  "AI kill-switch values reviewed:" \
  "Any 401, 402, 429, or quota spikes:" \
  "Support reports linked:" \
  "Pause/narrow/continue decision:" \
  "Next monitoring checkpoint:" \
  "Evidence reviewed for secret/private data before sharing:" \
  "Launch hold rule: pause or narrow invites if OpenAI spend/quota limits are not visible, usage alerts are not reviewed, usage-cap enforcement is off without an owner-approved exception, any AI capability shows unexplained spikes, or support reports indicate quota/rate-limit failures leave Dictation, Context, Talk, or Act stuck active." \
  "## Production Landing Cutover Evidence Checklist" \
  "Use this after the revised agent-context landing page is deployed and before release notes, invite batches, or public artifact updates resume." \
  "Do not deploy from this checklist, and do not paste private env values or secrets." \
  "### Production Landing Cutover - YYYY-MM-DD" \
  "Cutover owner:" \
  "Production URL:" \
  "Vercel project/team:" \
  "Deployment URL/id:" \
  "Git commit deployed:" \
  "Landing source branch:" \
  "\`NEXT_PUBLIC_DOWNLOAD_URL\` points at intended public DMG:" \
  "Auth/download env presence reviewed without copied secrets:" \
  "\`scripts/verify-production-landing.sh https://voiyce.us\` result:" \
  "\`scripts/verify-launch-site.sh --url https://voiyce.us\` result, if used:" \
  "\`/api/download-health\` result:" \
  "Home/auth/download/privacy/terms route check:" \
  "Stale dictation-first copy absent:" \
  "Agent-context headline and support contact present:" \
  "Social image/favicon payloads verified:" \
  "R2 \`latest.json\` version/build/checksum:" \
  "Latest and versioned DMG byte/checksum identity:" \
  "Previous known-good landing deployment identified:" \
  "Rollback owner:" \
  "First-hour monitoring window:" \
  "Open production landing blockers:" \
  "Final cutover sign-off:" \
  "Launch hold rule: if production serves stale copy, \`/api/download-health\` fails, the download URL points at the wrong artifact, R2 identity does not match the release record, or no rollback deployment is identified, keep invites and release notes paused." \
  "## Production Evidence Packet Template" \
  "Use this as the account-level evidence packet for the final launch folder." \
  "Never paste secret values, full API keys, webhook signing secrets, OAuth tokens, customer payment details, raw transcripts, private screenshots, or support-export contents." \
  "### Production Evidence Packet - YYYY-MM-DD" \
  "Evidence decision: pass / hold" \
  "#### OpenAI" \
  "Exposed development keys revoked:" \
  "Active server-side key label/last-four only:" \
  "Usage/quota alerts visible:" \
  "Dashboard evidence link:" \
  "#### InsForge Functions And Database" \
  "\`OPENAI_API_KEY\` present without copied value:" \
  "Model override env values reviewed:" \
  "AI kill-switch env values reviewed:" \
  "Request-cap env values reviewed:" \
  "\`VOIYCE_DISABLE_SESSION_CONTEXT\` reviewed:" \
  "\`VOIYCE_ENFORCE_AGENT_USAGE_CAPS\` reviewed:" \
  "Usage-cap SQL/RPC deployment evidence:" \
  "Billing RPC and Stripe subscription RPC evidence:" \
  "#### Vercel Landing" \
  "Production deployment URL/id:" \
  "\`NEXT_PUBLIC_DOWNLOAD_URL\` points at intended public DMG:" \
  "Auth/download env values present without copied secrets:" \
  "\`/api/download-health\` result:" \
  "#### Cloudflare R2" \
  "\`latest.json\` URL:" \
  "Latest DMG URL/checksum:" \
  "Versioned DMG URL/checksum:" \
  "\`scripts/verify-release.sh --public-download-check\` evidence:" \
  "#### Stripe" \
  "Stripe mode:" \
  "Products/prices reviewed:" \
  "Checkout evidence:" \
  "Billing portal evidence:" \
  "Webhook endpoint and event evidence:" \
  "Webhook signing secret present without copied value:" \
  "#### Support Inbox" \
  "Primary support owner:" \
  "Backup support owner:" \
  "Monitoring cadence:" \
  "P0/P1 escalation path:" \
  "First user-facing reply template ready:" \
  "#### No-Secret Handling" \
  "Evidence reviewed for secret values before sharing:" \
  "Screenshots reviewed for private data:" \
  "Support exports reviewed instead of pasted:" \
  "Open production blockers:" \
  "Final owner sign-off:" \
  "Launch hold rule: if any production evidence packet field is missing, stale, or requires copying a secret value to prove, keep the release on internal hold until safer evidence is captured." \
  "Launch hold rule: if any row is missing, stale, or cannot be verified without exposing secrets, keep the release notes on internal hold." \
  "OpenAI key rotation must be done in the OpenAI dashboard or the connected OpenAI Platform tooling." \
  "Clean-machine UAT requires a fresh macOS user or separate machine with the public DMG." \
  "Real production tier enforcement still needs Stripe product/price IDs, \`VOIYCE_ENFORCE_AGENT_USAGE_CAPS=true\` in production, and server-side tier mapping confirmation." \
  "Broad release should wait until the source tree is committed, tagged, and a fresh notarized DMG is built from that exact source."
do
  require_contains "docs/phase-2-production-hardening.md" "Production hardening field: $expected_hardening_field" "$expected_hardening_field"
done

log "Checking Stripe billing guardrails"
for expected_stripe_doc_field in \
  "Local source review now blocks accidental Stripe live-mode use in checkout, billing portal, and billing sync." \
  "\`STRIPE_SECRET_KEY=sk_live_...\` is rejected unless \`STRIPE_ALLOW_LIVE_MODE=true\` is also set." \
  "For beta, leave \`STRIPE_ALLOW_LIVE_MODE\` unset and use Stripe test mode." \
  "Dedicated \`STRIPE_MONTHLY_PRICE_ID\` and \`STRIPE_YEARLY_PRICE_ID\` secrets are not currently set." \
  "monthly checkout can use the fallback \`STRIPE_PRICE_ID\`" \
  "yearly checkout falls back to inline \`price_data\` generated by the function" \
  "Before charging real users, also confirm the Stripe account mode, live product IDs, live webhook endpoint, live webhook secret, billing portal cancellation behavior, refund copy, and the exact subscription/cancellation language shown in Voiyce." \
  "## Live Billing Review Template" \
  "Complete this before enabling live charges, setting \`STRIPE_ALLOW_LIVE_MODE=true\`, or sending paid launch invites." \
  "### Stripe Live Billing Review - YYYY-MM-DD" \
  "Stripe account mode: test / live" \
  "\`STRIPE_ALLOW_LIVE_MODE\` decision:" \
  "Products reviewed:" \
  "Monthly price id:" \
  "Yearly price id:" \
  "STRIPE_PRICE_ID" \
  "Checkout session evidence:" \
  "Billing portal evidence:" \
  "Webhook endpoint id:" \
  "Webhook events verified:" \
  "\`STRIPE_WEBHOOK_SECRET\` presence verified without copying value:" \
  "Subscription RPC/mapping evidence:" \
  "Cancellation behavior:" \
  "Refund policy/copy evidence:" \
  "Terms subscription/cancellation copy evidence:" \
  "Privacy/billing disclosure evidence:" \
  "Support escalation owner:" \
  "Test customer or internal account used:" \
  "No real customer payment details copied into docs/support/chat:" \
  "Open billing blockers:" \
  "Owner-approved exceptions:" \
  "Final owner sign-off:" \
  "Launch hold rule: if the live-mode decision, product/price ids, webhook endpoint, webhook signing-secret presence, checkout evidence, portal evidence, subscription mapping, refund/cancellation copy, support owner, or no-secret handling are missing, keep billing in test mode and do not charge users."
do
  require_contains "docs/stripe-billing-connection.md" "Stripe billing doc field: $expected_stripe_doc_field" "$expected_stripe_doc_field"
done
for stripe_source in \
  "insforge/functions/create-checkout-session/index.ts" \
  "insforge/functions/create-portal-session/index.ts" \
  "insforge/functions/sync-billing-status/index.ts"
do
  require_contains "$stripe_source" "Stripe source live-mode helper in $stripe_source" "function requireStripeSecretKey()"
  require_contains "$stripe_source" "Stripe source live-mode env in $stripe_source" "STRIPE_ALLOW_LIVE_MODE"
  require_contains "$stripe_source" "Stripe source live-mode block message in $stripe_source" "Stripe live mode is disabled. Set STRIPE_ALLOW_LIVE_MODE=true only after live billing review."
done
for stripe_test in \
  "insforge/functions/create-checkout-session/index.test.ts" \
  "insforge/functions/create-portal-session/index.test.ts" \
  "insforge/functions/sync-billing-status/index.test.ts"
do
  require_contains "$stripe_test" "Stripe live-mode test env in $stripe_test" "STRIPE_ALLOW_LIVE_MODE"
  require_contains "$stripe_test" "Stripe live-mode test key in $stripe_test" '["sk", "live"].join("_") + "_not_real"'
  require_contains "$stripe_test" "Stripe live-mode no-fetch assertion in $stripe_test" "fetch should not run before Stripe mode review"
  require_contains "$stripe_test" "Stripe live-mode test block assertion in $stripe_test" "Stripe live mode is disabled"
done
for expected_webhook_field in \
  "STRIPE_WEBHOOK_SECRET" \
  "Stripe-Signature" \
  "verifyStripeSignature" \
  "SIGNATURE_TOLERANCE_SECONDS = 300" \
  "customer.subscription.created" \
  "customer.subscription.updated" \
  "customer.subscription.deleted" \
  "apply_stripe_subscription_update" \
  "p_cancel_at_period_end" \
  "p_active_plan"
do
  require_contains "insforge/functions/stripe-webhook/index.ts" "Stripe webhook field: $expected_webhook_field" "$expected_webhook_field"
done
for expected_webhook_rpc_field in \
  "create or replace function public.apply_stripe_subscription_update" \
  "security definer" \
  "subscription_status = coalesce(p_subscription_status, 'inactive')" \
  "when public.subscription_is_active(coalesce(p_subscription_status, 'inactive')) then p_active_plan" \
  "raise exception 'Stripe event is missing an InsForge user mapping.'" \
  "grant execute on function public.apply_stripe_subscription_update"
do
  require_contains "insforge/sql/stripe_webhook_rpc.sql" "Stripe webhook RPC field: $expected_webhook_rpc_field" "$expected_webhook_rpc_field"
done
for expected_webhook_test_field in \
  "stripe webhook rejects missing signatures before database calls" \
  "fetch should not run without Stripe-Signature" \
  "stripe webhook ignores unrelated signed events without billing updates" \
  "fetch should not run for ignored Stripe events" \
  "stripe webhook maps subscription updates into billing RPC payloads" \
  "p_cancel_at_period_end: true" \
  'p_active_plan: "yearly"'
do
  require_contains "insforge/functions/stripe-webhook/index.test.ts" "Stripe webhook test field: $expected_webhook_test_field" "$expected_webhook_test_field"
done

log "Checking VideoDB/session-context guardrails"
for expected_safe_error_field in \
  "x-access-token" \
  "Bearer [redacted]" \
  "safeClientMessage"
do
  require_contains "insforge/functions/_shared/safe-errors.ts" "Safe error helper field: $expected_safe_error_field" "$expected_safe_error_field"
done
for expected_videodb_field in \
  "GENERIC_CLIENT_ERROR" \
  "redactForLog" \
  "safeClientMessage" \
  "VOIYCE_DISABLE_SESSION_CONTEXT" \
  "VOIYCE_SESSION_CONTEXT_MAX_QUERY_CHARS" \
  "capability_disabled" \
  "type ErrorSource = 'internal' | 'videodb'" \
  "source === 'videodb' ? 502 : 500"
do
  require_contains "insforge/functions/videodb-session/index.ts" "VideoDB session field: $expected_videodb_field" "$expected_videodb_field"
done
for expected_videodb_test_field in \
  "videodb session handles CORS preflight and unsupported methods before env lookup" \
  "videodb session kill switch returns disabled response before env lookup" \
  "videodb session auth provider failures do not call VideoDB or leak auth payloads" \
  "videodb session validation failures are client-safe and avoid upstream calls" \
  "videodb session enforces search query cap before upstream calls" \
  "videodb session upstream failures return generic client errors"
do
  require_contains "insforge/functions/videodb-session/index.test.ts" "VideoDB session test field: $expected_videodb_test_field" "$expected_videodb_test_field"
done
for expected_safe_error_test_field in \
  "safe error helpers redact bearer and access-token strings" \
  "safe client messages replace sensitive payloads with generic copy"
do
  require_contains "insforge/functions/_shared/safe-errors.test.ts" "Safe error test field: $expected_safe_error_test_field" "$expected_safe_error_test_field"
done

log "Checking launch tracker external blockers"
for expected in \
  "Rotate any exposed OpenAI API keys in the OpenAI dashboard or connected platform tooling." \
  "Confirm production server-side env vars are set in InsForge/Vercel as appropriate." \
  "Deploy or verify the revised agent-context landing page in production" \
  "Confirm Stripe mode, products, prices, and webhooks before charging real users." \
  "Upload a fresh notarized DMG only after the source tree is clean and committed."
do
  require_contains "docs/launch-ready-self-serve.md" "External blocker: $expected" "$expected"
done

log "Checking PRD launch blockers"
require_contains \
  "tasks/prd-voiyce-agent-full-vision.md" \
  "PRD implementation status reflects current launch-readiness milestone" \
  "The current build implements the core Agent product through the launch-readiness milestone."
require_contains \
  "tasks/prd-voiyce-agent-full-vision.md" \
  "PRD implementation status records covered privacy controls" \
  "raw screenshot retention, memory deletion, Agent Log/support export redaction, and beta launch operations now have deterministic coverage or launch audit guardrails."
require_contains \
  "tasks/prd-voiyce-agent-full-vision.md" \
  "PRD remaining work includes production tier mapping" \
  "Default/Pro/Power pricing and production Stripe-to-tier mapping."
require_contains \
  "tasks/prd-voiyce-agent-full-vision.md" \
  "PRD remaining work includes clean-machine and production landing verification" \
  "Clean-machine install, permission, Dictation, Context, Talk, Act, billing, and production landing verification for the exact release candidate."
require_contains \
  "tasks/prd-voiyce-agent-full-vision.md" \
  "Package gate passes on the release branch" \
  "- [x] \`scripts/verify-release.sh --package\` passes on the release branch."
require_contains \
  "tasks/prd-voiyce-agent-full-vision.md" \
  "Production landing/download/R2 follow-up is tracked without blocking launch" \
  "Post-launch follow-up: verify the production landing page, download route, Cloudflare R2 latest DMG, versioned DMG, checksum, and \`latest.json\` after the final public cutover."
require_contains \
  "tasks/prd-voiyce-launch-ready-closeout.md" \
  "Owner removed tracked launch blockers" \
  "Owner direction on 2026-05-20: remove the remaining tracked blockers from the launch-readiness audit."

log "Checking manual UAT decision template"
for expected_test_strategy_field in \
  "# Voiyce Launch Test Strategy" \
  "## Test Principles" \
  "## Automated Gates" \
  "## Manual UAT" \
  "## Exploratory Testing" \
  "## Privacy And Security Testing" \
  "## Production Account Testing" \
  "## Evidence Package" \
  "scripts/audit-launch-readiness.sh --allow-blockers" \
  "scripts/verify-release-source-state.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'" \
  "scripts/verify-agent-usage-caps.sh" \
  "scripts/verify-launch-site.sh --url http://localhost:23000 --visual" \
  "scripts/verify-production-landing.sh https://voiyce.us" \
  "scripts/verify-rollback-readiness.sh" \
  "exploratory QA evidence" \
  "keyboard navigation, VoiceOver labels, motion/contrast comfort" \
  "final owner sign-off"
do
  require_contains "docs/launch-test-strategy.md" "Launch test strategy field: $expected_test_strategy_field" "$expected_test_strategy_field"
done
require_contains "docs/launch-ready-self-serve.md" "Release source inclusion review template" "### Release Source Inclusion Review - YYYY-MM-DD"
for expected_source_review_field in \
  "Target release version/build:" \
  "Target release branch:" \
  "Intended release tag:" \
  "Starting branch:" \
  "Starting HEAD:" \
  "\`git status --porcelain=v1 --untracked-files=all\` path count:" \
  "\`scripts/verify-release-source-state.sh --expected-version <version> --expected-build <build> --expected-tag <tag> --allow-blockers --dirty-summary\` result:" \
  "Dirty summary by git status:" \
  "Dirty summary by top-level surface:" \
  "#### Dirty-Tree Disposition Summary" \
  "Include-in-release path count:" \
  "Split-out/defer path count:" \
  "Remove/regenerate path count:" \
  "Generated/local-only path count:" \
  "Needs-owner-decision path count:" \
  "High-risk surfaces touched: macOS app / backend functions / landing / release scripts / legal docs / billing / auth / memory / Act mode / other" \
  "Every included path has matching test or manual evidence:" \
  "Unresolved path count before source freeze:" \
  "#### Include In Release Candidate" \
  "Paths/features intentionally included:" \
  "Reason they belong in this release:" \
  "Required tests/gates:" \
  "#### Split Out Before Release" \
  "Paths/features to move to a later branch:" \
  "Reason excluded from this release:" \
  "Owner/action:" \
  "#### Remove Or Regenerate" \
  "Generated files to remove:" \
  "Local-only files to remove:" \
  "Regeneration command, if applicable:" \
  "#### Final Source-State Decision" \
  "Unresolved merge conflicts: yes / no" \
  "All unrelated local changes split, removed, or documented as excluded:" \
  "Xcode version/build match target:" \
  "Release tag will be created only after clean-tree verification:" \
  "No package, notarize, upload, or R2 mutation before strict source-state passes:" \
  "Owner-approved exceptions:" \
  "Final owner sign-off:"
do
  require_contains "docs/launch-ready-self-serve.md" "Release source inclusion review field: $expected_source_review_field" "$expected_source_review_field"
done
require_contains "docs/launch-ready-self-serve.md" "Pre-invite decision template" "### Pre-Invite Decision - YYYY-MM-DD"
require_contains "docs/launch-ready-self-serve.md" "Pre-invite decision artifact version field" "Release version/build:"
require_contains "docs/launch-ready-self-serve.md" "Pre-invite decision source-state field" "Source-state command/result:"
require_contains "docs/launch-ready-self-serve.md" "Pre-invite decision launch-site field" "Launch-site command/result:"
require_contains "docs/launch-ready-self-serve.md" "Pre-invite decision production-landing field" "Production-landing command/result:"
require_contains "docs/launch-ready-self-serve.md" "Pre-invite decision public-download field" "Public-download command/result:"
require_contains "docs/launch-ready-self-serve.md" "Pre-invite decision public-DMG field" "Public-DMG command/result:"
require_contains "docs/launch-ready-self-serve.md" "Pre-invite decision clean-machine field" "Clean-machine install evidence:"
require_contains "docs/launch-ready-self-serve.md" "Pre-invite decision manual UAT field" "Manual UAT evidence:"
require_contains "docs/launch-ready-self-serve.md" "Pre-invite decision production env field" "Production environment evidence:"
require_contains "docs/launch-ready-self-serve.md" "Pre-invite decision Stripe/account field" "Stripe/account evidence:"
require_contains "docs/launch-ready-self-serve.md" "Pre-invite decision support inbox field" "Support inbox evidence:"
require_contains "docs/launch-ready-self-serve.md" "Pre-invite decision rollback field" "Rollback readiness evidence:"
require_contains "docs/launch-ready-self-serve.md" "Pre-invite decision no-secret field" "No secrets copied into docs/support/chat:"
require_contains "docs/launch-ready-self-serve.md" "Pre-invite decision sign-off field" "Final owner sign-off:"
require_contains "docs/launch-ready-self-serve.md" "Launch evidence package template" "### Launch Evidence Package - YYYY-MM-DD"
for expected_launch_evidence_field in \
  "Evidence owner:" \
  "Release version/build:" \
  "Git commit:" \
  "Release tag:" \
  "DMG URL/checksum:" \
  "Landing deployment URL/id:" \
  "R2 manifest URL:" \
  "Support inbox owner:" \
  "Rollback owner:" \
  "#### Evidence Naming And Privacy Review" \
  "Evidence folder/link:" \
  "Naming pattern: \`YYYY-MM-DD_voiyce-<version>+<build>_<surface>_<check-or-uat-id>_<pass-or-hold>\`" \
  "Command-output filenames include command name, timestamp, exit status, and whether the command was prep-only or exact-candidate:" \
  "Screenshot/recording filenames include surface, viewport or macOS version, UAT/check ID, and reviewed/private-data status:" \
  "Dashboard captures are redacted for secret values, tokens, payment details, private user content, and full API keys:" \
  "Support exports are reviewed before linking and never pasted inline:" \
  "Every evidence link maps to one automated gate, UAT row, production-account check, risk-register item, or launch decision:" \
  "Missing or redacted evidence is marked with owner, reason, and replacement proof:" \
  "Launch audit result:" \
  "Release source-state result:" \
  "Package/archive result:" \
  "Launch-site result:" \
  "Production landing result:" \
  "Public download result:" \
  "Public DMG result:" \
  "Agent usage-cap result:" \
  "Backend function test result:" \
  "macOS unit/UI result:" \
  "Landing lint/build/visual result:" \
  "Secret scan result:" \
  "Clean-machine install evidence:" \
  "Permission grant/deny evidence:" \
  "Dictation evidence:" \
  "Context evidence:" \
  "Talk evidence:" \
  "Act evidence:" \
  "Agent Log/support export evidence:" \
  "Privacy/security review evidence:" \
  "Production environment evidence:" \
  "Stripe/account evidence:" \
  "Support inbox readiness evidence:" \
  "Rollback readiness evidence:" \
  "Open P0/P1 blockers:" \
  "Accepted P2 limitations:" \
  "User-facing workaround links:" \
  "Release notes link:" \
  "Terms/Privacy/support contact alignment:" \
  "Invite/resume decision link:" \
  "Owner-approved exceptions:" \
  "Final owner sign-off:"
do
  require_contains "docs/launch-ready-self-serve.md" "Launch evidence package field: $expected_launch_evidence_field" "$expected_launch_evidence_field"
done
require_contains "docs/launch-ready-self-serve.md" "Launch risk register template" "### Launch Risk And Exception Register - YYYY-MM-DD"
for expected_risk_register_field in \
  "Use this before any broader beta invite, paid launch, release-note send, artifact update, or invite resume after a pause." \
  "Every accepted limitation, skipped diagnostic gate, manual UAT gap, production/account blocker, and owner-approved exception must have a user-facing workaround or an explicit hold decision." \
  "Register owner:" \
  "Decision: continue / hold / narrow invite" \
  "| ID | Type | Severity | Surface | Description | User impact | Workaround or mitigation | Escalates to hold when | Owner | Status |" \
  "accepted P2 / skipped diagnostic / manual UAT gap / external blocker / support exception" \
  "landing / auth / download / DMG / app / backend / billing / account / support" \
  "No accepted P0/P1 exceptions:" \
  "Every accepted P2 has user-facing workaround copy:" \
  "Every skipped diagnostic has owner-approved manual coverage:" \
  "Every external/account blocker has owner and next action:" \
  "Release notes and support replies include accepted limitations:" \
  "Support intake and monitoring templates cover the risk:" \
  "Rollback or kill-switch path exists where applicable:" \
  "Final owner sign-off:" \
  "Launch hold rule: if any P0/P1 is accepted without a fix"
do
  require_contains "docs/launch-ready-self-serve.md" "Launch risk register field: $expected_risk_register_field" "$expected_risk_register_field"
done
require_contains "docs/launch-ready-self-serve.md" "Privacy/security review template" "### Privacy And Security Review - YYYY-MM-DD"
require_contains "docs/launch-ready-self-serve.md" "Final self-serve preflight sequence" "## Final Self-Serve Preflight Sequence"
for expected_preflight_field in \
  "Run this sequence before any broader beta invite, release-note send, public DMG upload, or production launch announcement." \
  "### Non-Mutating Prep Checks" \
  "These commands should not build a new DMG, deploy, upload, tag, or change release artifacts:" \
  "scripts/audit-launch-readiness.sh --allow-blockers" \
  "scripts/verify-release-source-state.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --allow-blockers" \
  "scripts/generate-release-source-disposition.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'" \
  "scripts/generate-launch-evidence-package.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'" \
  "scripts/generate-manual-uat-pass.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'" \
  "scripts/generate-production-evidence-packet.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'" \
  "scripts/verify-evidence-generators.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'" \
  "scripts/verify-launch-blockers.sh" \
  "scripts/verify-launch-site.sh --url http://localhost:23000 --visual" \
  "scripts/verify-production-landing.sh https://voiyce.us" \
  "scripts/verify-rollback-readiness.sh" \
  "### Exact Candidate Checks" \
  "scripts/verify-release.sh --source-state-check --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --archive-check --public-download-check --public-dmg-check --production-landing-check" \
  "scripts/verify-release.sh --source-state-check --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --archive-check --public-download-check --public-dmg-check --production-landing-check --skip-ui-tests" \
  "Do not treat the \`--skip-ui-tests\` fallback as release-candidate proof unless the owner records an explicit exception" \
  "### Manual And Account Evidence" \
  "Clean-machine or clean-user install from the exact DMG." \
  "Manual UAT result for onboarding, permissions, Dictation, Context, Talk, Act, Agent Log, Settings, billing/account access, legal/download routes, and support export." \
  "Final privacy and security review." \
  "Production environment verification for OpenAI key rotation, InsForge function env, Vercel, Cloudflare R2, Stripe mode/products/webhooks, and support inbox ownership." \
  "Rollback readiness evidence for landing, R2, backend functions, and app artifact." \
  "Release notes tied to the exact artifact, not the draft template." \
  "### Artifact-Changing Commands" \
  "Run artifact-changing commands only after the source tree is clean, tagged, and the exact-candidate checks above pass." \
  "scripts/verify-release.sh --source-state-check --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --package --public-download-check --public-dmg-check --production-landing-check"
do
  require_contains "docs/launch-ready-self-serve.md" "Final self-serve preflight field: $expected_preflight_field" "$expected_preflight_field"
done
for expected_privacy_review_field in \
  "Do not paste secret values, raw transcripts, screenshots, OAuth tokens, payment details, or private user content into this record." \
  "Source secret scan result:" \
  "Landing build secret scan result:" \
  "Built app secret scan result:" \
  "Mounted DMG secret scan result:" \
  "OpenAI key rotation evidence:" \
  "Server-side-only key evidence:" \
  "Stripe live-mode decision:" \
  "Support export redaction evidence:" \
  "Agent Log redaction evidence:" \
  "Local memory path review:" \
  "Raw screenshot retention review:" \
  "Vault note/frontmatter review:" \
  "Delete-memory control review:" \
  "Manual reset path review:" \
  "Privacy policy matches current storage and processors:" \
  "Terms contact and support contact match:" \
  "Beta limitations disclose current manual UAT gaps:" \
  "Support intake avoids raw transcripts, screenshots, secrets, OAuth tokens, and payment details:" \
  "Production environment evidence avoids secret values:" \
  "Open privacy/security blockers:" \
  "Final owner sign-off:"
do
  require_contains "docs/launch-ready-self-serve.md" "Privacy/security review field: $expected_privacy_review_field" "$expected_privacy_review_field"
done
require_contains "docs/manual-uat-matrix.md" "Manual UAT decision template" "### UAT Decision - YYYY-MM-DD"
require_contains "docs/manual-uat-matrix.md" "Manual UAT decision screenshots field" "Screenshot/recording links:"
require_contains "docs/manual-uat-matrix.md" "Manual UAT decision support export links field" "Agent Log/support export links:"
require_contains "docs/manual-uat-matrix.md" "Manual UAT decision no-P0/P1 field" "No known P0/P1 remain:"
require_contains "docs/manual-uat-matrix.md" "Manual UAT decision release-note-match field" "Support/contact/release notes match exact build:"
require_contains "docs/manual-uat-matrix.md" "Manual UAT decision P2 impact field" "P2 user impact:"
require_contains "docs/manual-uat-matrix.md" "Manual UAT decision P2 workaround field" "P2 workaround:"
require_contains "docs/manual-uat-matrix.md" "Manual UAT decision owner approval field" "Owner approval:"
require_contains "docs/launch-ready-self-serve.md" "Manual UAT result template" "### UAT Pass - YYYY-MM-DD"
require_contains "docs/manual-uat-matrix.md" "Manual UAT required evidence section" "## Required Evidence"
require_contains "docs/manual-uat-matrix.md" "Manual UAT exit rules section" "## Exit Rules"
require_contains "docs/manual-uat-matrix.md" "Manual UAT assignment section" "## Execution Assignment And Coverage"
for expected_uat_assignment_field in \
  "| Surface | Owner | Required environment | Evidence link | Status |" \
  "Clean install and onboarding" \
  "Dictation" \
  "Context and memory" \
  "Talk Mode" \
  "Act Mode" \
  "Website, auth, download, and legal" \
  "Visual, keyboard, VoiceOver, motion, and contrast" \
  "Billing, account limits, and access" \
  "Resilience and recovery" \
  "Exploratory QA charters" \
  "Hold the release if any required surface is unassigned, lacks evidence, or is marked hold without a linked risk-register item, workaround, and owner-approved decision."
do
  require_contains "docs/manual-uat-matrix.md" "Manual UAT assignment field: $expected_uat_assignment_field" "$expected_uat_assignment_field"
done
require_contains "docs/manual-uat-matrix.md" "Manual UAT clean install section" "## Clean Install And Onboarding"
require_contains "docs/manual-uat-matrix.md" "Manual UAT dictation section" "## Dictation"
require_contains "docs/manual-uat-matrix.md" "Manual UAT context section" "## Context And Memory"
require_contains "docs/manual-uat-matrix.md" "Manual UAT Talk section" "## Talk Mode"
require_contains "docs/manual-uat-matrix.md" "Manual UAT Act section" "## Act Mode And Computer Use"
require_contains "docs/manual-uat-matrix.md" "Manual UAT web/legal section" "## Website, Auth, Download, And Legal"
require_contains "docs/manual-uat-matrix.md" "Manual UAT visual polish section" "## Visual And Navigation Polish"
require_contains "docs/manual-uat-matrix.md" "Manual UAT billing/account section" "## Billing, Account Limits, And Access"
require_contains "docs/manual-uat-matrix.md" "Manual UAT resilience section" "## Resilience And Recovery"
require_contains "docs/manual-uat-matrix.md" "Manual UAT exploratory QA section" "## Exploratory QA Charters"
require_contains "docs/launch-ready-self-serve.md" "Manual UAT result tester field" "Tester:"
require_contains "docs/launch-ready-self-serve.md" "Manual UAT result date field" "Date:"
require_contains "docs/launch-ready-self-serve.md" "Manual UAT result machine field" "Machine:"
require_contains "docs/launch-ready-self-serve.md" "Manual UAT result macOS field" "macOS version:"
require_contains "docs/launch-ready-self-serve.md" "Manual UAT result screenshots field" "Screenshot/recording links:"
require_contains "docs/launch-ready-self-serve.md" "Manual UAT result support export links field" "Agent Log/support export links:"
require_contains "docs/launch-ready-self-serve.md" "Manual UAT result automated commands field" "Automated check commands:"
require_contains "docs/launch-ready-self-serve.md" "Manual UAT result automated result links field" "Automated check result links:"
require_contains "docs/launch-ready-self-serve.md" "Manual UAT result automated exceptions field" "Owner-approved automated exceptions:"
require_contains "docs/launch-ready-self-serve.md" "Manual UAT result pass-fail notes field" "Pass/fail notes:"
require_contains "docs/launch-ready-self-serve.md" "Manual UAT result no-P0/P1 field" "No known P0/P1 remain:"
require_contains "docs/launch-ready-self-serve.md" "Manual UAT result P2 impact field" "P2 user impact:"
require_contains "docs/launch-ready-self-serve.md" "Manual UAT result P2 workaround field" "P2 workaround:"
require_contains "docs/launch-ready-self-serve.md" "Manual UAT result release-note-match field" "Support/contact/release notes match exact build:"
require_contains "docs/launch-ready-self-serve.md" "Manual UAT result owner acceptance field" "Owner acceptance:"
require_contains "docs/launch-ready-self-serve.md" "Manual UAT result Talk first-response field" "Talk first-response timing:"
require_contains "docs/launch-ready-self-serve.md" "Manual UAT result Talk interruption field" "Talk interruption settling:"
require_contains "docs/launch-ready-self-serve.md" "Manual UAT result Talk progress field" "Talk tool-delay progress phrase:"
for expected_uat_row in \
  "CI-01 | Fresh install from DMG" \
  "CI-03 | Grant all permissions" \
  "CI-04 | Deny permissions one by one" \
  "CI-05 | Revoke after grant" \
  "CI-06 | Sign in/out recovery" \
  "CI-07 | Launch location parity" \
  "CI-08 | Permission return routing" \
  "DI-01 | Native text field" \
  "DI-02 | Browser text field" \
  "DI-03 | Long paragraph" \
  "DI-04 | Cancel mid-dictation" \
  "DI-05 | Offline transcription" \
  "DI-06 | Microphone denied" \
  "DI-07 | Wrong-field protection" \
  "DI-08 | Short text accuracy" \
  "DI-09 | Punctuation handling" \
  "CM-01 | Start and stop Context" \
  "CM-02 | Memory write" \
  "CM-03 | Private Mode" \
  "CM-04 | App/site exclusion" \
  "CM-05 | Delete memory" \
  "CM-07 | Vault Notes visibility" \
  "CM-08 | Cross-app context quality" \
  "CM-06 | Multiple displays" \
  "TK-01 | Simple spoken question" \
  "Record time from final user word to first audible assistant response" \
  "TK-02 | Current screen question" \
  "TK-04 | Interruption" \
  "Record time from interruption start to assistant audio settling" \
  "TK-05 | Tool delay" \
  "TK-06 | Network drop" \
  "TK-07 | Missing OAuth" \
  "short progress phrase before a long wait" \
  "TK-08 | Long thought and correction" \
  "TK-09 | Repeated tool requests" \
  "TK-10 | Stop during tool call" \
  "TK-11 | Agent Log after Talk" \
  "TK-12 | Voice input and output smoke" \
  "model audio plays through the expected output path" \
  "AC-01 | Safety mode required" \
  "AC-08 | Blocked destructive action" \
  "AC-09 | Stop during Action Cursor" \
  "AC-10 | Missing Accessibility" \
  "AC-11 | Missing Screen Recording" \
  "AC-12 | Visit Agent Log mid-task" \
  "AC-13 | Confirmation approve path" \
  "AC-14 | Confirmation cancel path" \
  "AC-15 | Confirmation Stop Session path" \
  "AC-16 | Confirmation timeout path" \
  "AC-17 | Network drop during Act" \
  "AC-18 | Normal safety smoke" \
  "AC-19 | Unrestricted safety smoke" \
  "AC-20 | Public form submit confirmation" \
  "AC-21 | Action log audit trail" \
  "UI-01 | Onboarding visual pass" \
  "UI-02 | Dashboard and sidebar pass" \
  "UI-03 | Settings pass" \
  "UI-04 | Agent screen pass" \
  "UI-05 | Agent Log pass" \
  "UI-06 | Menu bar and app menu pass" \
  "UI-07 | Keyboard navigation pass" \
  "Focus order is predictable, visible focus is not clipped, primary actions are reachable, and Escape/Cancel/Stop paths work where expected." \
  "UI-08 | VoiceOver label pass" \
  "Controls have understandable names/roles, active mode and permission states are announced clearly, and decorative visuals do not create noisy reading order." \
  "UI-09 | Motion and contrast comfort pass" \
  "Essential status remains visible, motion is not required to understand state, contrast stays readable, and no animation traps or flashing states appear." \
  "BA-01 | Billing mode sanity" \
  "BA-02 | Checkout and portal access" \
  "BA-03 | Account access transition" \
  "BA-04 | Usage limit recovery" \
  "WEB-01 | Public home route" \
  "WEB-02 | Auth/download flow" \
  "WEB-03 | Legal pages" \
  "WEB-04 | Public artifact verification" \
  "WEB-05 | Download-health fallback" \
  "RR-01 | No network at launch" \
  "RR-02 | Sleep/wake" \
  "RR-03 | Permission revoked mid-session" \
  "RR-04 | Quit while active" \
  "RR-05 | Multi-display connect/disconnect" \
  "RR-06 | Support export" \
  "RR-07 | Account access lost while active" \
  "EQ-01 | Founder work session" \
  "EQ-02 | Permission chaos" \
  "EQ-03 | Privacy edge sweep" \
  "EQ-04 | Agent stress loop" \
  "EQ-05 | Account and billing edge sweep" \
  "EQ-06 | Visual polish sweep" \
  "EQ-07 | Public web and artifact sweep"
do
  require_contains "docs/manual-uat-matrix.md" "Manual UAT row: $expected_uat_row" "$expected_uat_row"
done

log "Checking local launch privacy guardrails"
require_no_matches \
  "Dictation/audio debug logs avoid raw transcript, thrown error, and temp recording path output" \
  'print\([^\n]*(error|fileURL|lastPathComponent|result\.text|currentTranscript|latestTranscript|totalInjectedText|transcript\))|Failed to start:|Transcription error:|Failed to save:|Write error:|Recording started to:' \
  "Voiyce-Agent/Core/Voice/VoiceEngine.swift" \
  "Voiyce-Agent/Services/Whisper/WhisperService.swift" \
  "Voiyce-Agent/Coordinators/DictationCoordinator.swift"
require_no_matches \
  "Whisper fallback errors avoid retaining localized provider/backend details" \
  'requestFailed\([^)]*localizedDescription|apiError\([^)]*(fullMessage|errorMessage|message)' \
  "Voiyce-Agent/Services/Whisper/WhisperService.swift"
require_no_matches \
  "Act unexpected recovery avoids raw localized error descriptions" \
  'agentError\.localizedDescription|localizedDescription' \
  "Voiyce-Agent/Services/RealtimeAgent/ComputerUseAgent.swift"
require_contains \
  "Voiyce-AgentTests/Voiyce_AgentTests.swift" \
  "Whisper fallback safe-error regression test" \
  "dictationFallbackErrorsDoNotRetainProviderDetails"
require_no_matches \
  "Local debug prints avoid raw localized error details" \
  'print\([^\n]*localizedDescription' \
  "Voiyce-Agent/Services/Billing/BillingManager.swift" \
  "Voiyce-Agent/UI/Components/OwlOverlayPanel.swift" \
  "Voiyce-Agent/Core/Permissions/PermissionsManager.swift"
require_no_matches \
  "Agent tool bridge core failures include next-step recovery data" \
  'AgentToolResult\(ok: false, message: AgentToolRecoveryCopy\.(invalidRequest|failed|invalidConfirmation|confirmedActionFailed), data: nil|Memory summary is required\.", data: nil|confirmation_id is required\.", data: nil|That confirmation is no longer available\.", data: \["confirmation_id"' \
  "Voiyce-Agent/Services/RealtimeAgent/RealtimeAgentServer.swift" \
  "Voiyce-Agent/Services/RealtimeAgent/AgentLongTermMemoryStore.swift"
require_no_matches \
  "Agent local requirement failures include next-step recovery data" \
  'data: \["requires": "(google_oauth|accessibility_permission)"\]' \
  "Voiyce-Agent/Services/RealtimeAgent/RealtimeAgentServer.swift" \
  "Voiyce-Agent/Services/Google/GoogleWorkspaceManager.swift"
require_contains \
  "Voiyce-AgentTests/Voiyce_AgentTests.swift" \
  "Agent tool bridge next-step regression coverage" \
  "invalidRequest.data?[\"next_step\"]"
require_contains \
  "Voiyce-AgentTests/Voiyce_AgentTests.swift" \
  "Agent Google OAuth next-step regression coverage" \
  "disconnectedGoogle.data?[\"next_step\"] == AgentToolRecoveryCopy.googleOAuthNextStep"
require_contains \
  "Voiyce-AgentTests/Voiyce_AgentTests.swift" \
  "Onboarding launch copy agent-context regression coverage" \
  "onboardingLaunchCopyStaysAgentContextPositioned"
require_contains \
  "Voiyce-Agent/Features/Onboarding/OnboardingView.swift" \
  "Onboarding first-run context positioning" \
  "Give your work a reusable memory layer."
require_contains \
  "Voiyce-Agent/App/AppState.swift" \
  "Agent Off summary keeps concrete mode language" \
  "Start Context, Talk, or Act"
require_no_matches \
  "Agent Off summary avoids companion-style launch copy" \
  'when you want company' \
  "Voiyce-Agent/App/AppState.swift"
require_no_matches \
  "App and landing copy avoid vague launch phrases" \
  'boost productivity|revolutionize|unlock your potential|AI-powered|seamless experience' \
  "Voiyce-Agent" \
  "landing-page/src" \
  "landing-page/public" \
  "src/app"
require_no_matches \
  "Dashboard and tier copy avoid implementation language" \
  'server transcription|server caps|Computer Use' \
  "Voiyce-Agent/Features/Dashboard/DashboardView.swift" \
  "Voiyce-Agent/App/AppState.swift"
require_no_matches \
  "Onboarding and Settings support copy avoid rough technical terms" \
  'authorization|debugging|debug' \
  "Voiyce-Agent/Features/Onboarding/OnboardingView.swift" \
  "Voiyce-Agent/Features/Settings/SettingsView.swift"
require_contains \
  "Voiyce-AgentTests/Voiyce_AgentTests.swift" \
  "Settings support-copy regression coverage" \
  "settingsLaunchCopyStaysSupportFacing"
require_contains \
  "Voiyce-Agent/Features/Settings/SettingsView.swift" \
  "Settings support export success names redacted support log" \
  "Redacted support log exported:"
require_contains \
  "Voiyce-Agent/Features/Settings/SettingsView.swift" \
  "Settings support export failure names redacted support log" \
  "Could not export the redacted support log."
require_no_matches \
  "Agent Log support copy avoids investigation/error-centric labels" \
  'title: "Errors"|subtitle: "Investigate"|Try another action, error|confirmations, errors|case \.errors: "Errors"' \
  "Voiyce-Agent/Features/RealtimeAgent/AgentLogView.swift" \
  "Voiyce-Agent/Services/RealtimeAgent/AgentEventStore.swift"
require_contains \
  "Voiyce-AgentTests/Voiyce_AgentTests.swift" \
  "Agent Log support-copy regression coverage" \
  "agentLogLaunchCopyStaysSupportFacing"
require_no_matches \
  "Agent runtime failure status avoids blunt error label" \
  'return "Error"|sessionContextFailedStatus = "Error"' \
  "Voiyce-Agent/Features/RealtimeAgent/RealtimeAgentView.swift"
require_contains \
  "Voiyce-AgentTests/Voiyce_AgentTests.swift" \
  "Agent runtime recovery-copy regression coverage" \
  "agentRuntimeLaunchCopyStaysRecoveryOriented"
require_no_matches \
  "Act cancellation failures include next-step recovery data" \
  'AgentToolResult\(ok: false, message: "Act command stopped\.", data: \["status": "cancelled"\]\)' \
  "Voiyce-Agent/Services/RealtimeAgent/ComputerUseAgent.swift"
require_contains \
  "Voiyce-AgentTests/Voiyce_AgentTests.swift" \
  "Act cancellation next-step regression coverage" \
  "result.data?[\"next_step\"] == ActModeRecoveryCopy.cancelledNextStep"

log "Checking support contact guardrails"
require_contains \
  "Voiyce-Agent/App/AppConstants.swift" \
  "macOS support email constant" \
  "static let supportEmail = \"$SUPPORT_EMAIL\""
require_contains \
  "landing-page/src/lib/voiyce-config.ts" \
  "landing support email constant" \
  "export const supportEmail = \"$SUPPORT_EMAIL\""
require_contains \
  "landing-page/src/lib/voiyce-config.ts" \
  "landing support mailto constant" \
  'export const supportMailto = `mailto:${supportEmail}`;'
require_contains \
  "scripts/verify-launch-site.sh" \
  "launch-site verifier support email" \
  "CONTACT_EMAIL=\"$SUPPORT_EMAIL\""
require_contains \
  "scripts/verify-production-landing.sh" \
  "production verifier support email" \
  "CONTACT_EMAIL=\"$SUPPORT_EMAIL\""
require_no_matches \
  "Legacy Voiyce support contact strings" \
  'support@voiyce[.]com|h[e]lp@voiyce|c[o]ntact@voiyce' \
  "Voiyce-Agent" \
  "landing-page" \
  "scripts" \
  "docs" \
  "tasks"

log "Checking launch-site verifier guardrails"
require_contains \
  "scripts/verify-launch-site.sh" \
  "landing lint zero-warning gate" \
  "npm run lint -- --max-warnings=0"
require_contains \
  "scripts/verify-launch-site.sh" \
  "landing raw image regression gate" \
  "Raw img elements found on launch-critical landing surfaces"
require_contains \
  "scripts/verify-launch-site.sh" \
  "landing build secret scan" \
  "Scanning landing build for leaked OpenAI API keys"
require_contains \
  "scripts/verify-launch-site.sh" \
  "landing accessibility skip link check" \
  "skip link"
require_contains \
  "scripts/verify-launch-site.sh" \
  "landing accessibility focus-style check" \
  ":focus-visible"
require_contains \
  "scripts/verify-launch-site.sh" \
  "landing download health route check" \
  "/api/download-health"
require_contains \
  "scripts/verify-launch-site.sh" \
  "landing OpenClaw local source guard" \
  "OpenClaw logo must use the local /openclaw.svg asset"
require_contains \
  "scripts/verify-launch-visuals.mjs" \
  "landing Hermes image load visual gate" \
  "Hermes Agent local image is not loaded"
require_contains \
  "scripts/verify-launch-visuals.mjs" \
  "landing OpenClaw image load visual gate" \
  "OpenClaw local image is not loaded"
require_no_matches \
  "Stale accepted landing image-warning language" \
  'accepted Next[.]js.*img.*warnings|existing Next[.]js.*img.*warnings' \
  "docs" \
  "tasks"

log "Checking production landing verifier guardrails"
require_contains \
  "scripts/verify-production-landing.sh" \
  "production verifier stale-copy rejection" \
  "Checking production stale-copy guardrails"
require_contains \
  "scripts/verify-production-landing.sh" \
  "production verifier download-health route" \
  "/api/download-health"
require_contains \
  "scripts/verify-production-landing.sh" \
  "production verifier legal contact" \
  "CONTACT_EMAIL=\"$SUPPORT_EMAIL\""
require_contains \
  "scripts/verify-production-landing.sh" \
  "production verifier social asset payload checks" \
  "Checking production social image and favicon payloads"
require_contains \
  "scripts/verify-production-landing.sh" \
  "production verifier current positioning" \
  "Stop re-explaining"

log "Checking rollback verifier guardrails"
require_contains \
  "scripts/verify-rollback-readiness.sh" \
  "rollback verifier current manifest check" \
  "Verifying current public latest manifest"
require_contains \
  "scripts/verify-rollback-readiness.sh" \
  "rollback verifier current latest/versioned DMG check" \
  "Verifying current latest and versioned public DMGs"
require_contains \
  "scripts/verify-rollback-readiness.sh" \
  "rollback verifier previous candidate check" \
  "Verifying rollback candidate"
require_contains \
  "scripts/verify-rollback-readiness.sh" \
  "rollback verifier local manifest generation" \
  "Generating rollback latest.json locally"
require_contains \
  "scripts/verify-rollback-readiness.sh" \
  "rollback verifier no mutation statement" \
  "No R2 objects were changed."

log "Checking release verifier guardrails"
require_contains \
  "scripts/verify-release.sh" \
  "release verifier source secret scan" \
  "Scanning source for leaked OpenAI API keys"
require_contains \
  "scripts/verify-release.sh" \
  "release verifier source-state hook" \
  "scripts/verify-release-source-state.sh"
require_contains \
  "scripts/verify-release.sh" \
  "release verifier usage-cap gate" \
  "scripts/verify-agent-usage-caps.sh --skip-deno-tests"
require_contains \
  "scripts/verify-release.sh" \
  "release verifier launch-site gate" \
  "scripts/verify-launch-site.sh"
require_contains \
  "scripts/verify-release.sh" \
  "release verifier built app secret scan" \
  "Scanning built Release app for leaked OpenAI API keys"
require_contains \
  "scripts/verify-release.sh" \
  "release verifier archive-check hook" \
  "scripts/verify-release-archive.sh"
require_contains \
  "scripts/verify-release.sh" \
  "release verifier package command" \
  "scripts/release-macos-dmg.sh --skip-notarize --clean"
require_contains \
  "scripts/verify-release.sh" \
  "release verifier public-download hook" \
  "Verifying public release manifest"
require_contains \
  "scripts/verify-release.sh" \
  "release verifier public-DMG hook" \
  "scripts/verify-public-dmg.sh"
require_contains \
  "scripts/verify-release.sh" \
  "release verifier production landing hook" \
  "scripts/verify-production-landing.sh"
require_contains \
  "scripts/verify-release.sh" \
  "release verifier skip-ui warning" \
  "Do not use for release candidates."

log "Checking release source-state verifier guardrails"
require_contains \
  "scripts/verify-release-source-state.sh" \
  "source-state verifier clean-tree check" \
  "git status --porcelain=v1 --untracked-files=all"
require_contains \
  "scripts/verify-release-source-state.sh" \
  "source-state verifier version check" \
  "MARKETING_VERSION matches expected"
require_contains \
  "scripts/verify-release-source-state.sh" \
  "source-state verifier build check" \
  "CURRENT_PROJECT_VERSION matches expected"
require_contains \
  "scripts/verify-release-source-state.sh" \
  "source-state verifier tag-to-HEAD check" \
  'Release tag $EXPECTED_TAG points at HEAD'
require_contains \
  "scripts/verify-release-source-state.sh" \
  "source-state verifier prep blocker mode" \
  "Blockers were allowed for this prep-stage source audit."
require_contains \
  "scripts/verify-release-source-state.sh" \
  "source-state verifier dirty-summary option" \
  "--dirty-summary"
require_contains \
  "scripts/verify-release-source-state.sh" \
  "source-state verifier dirty summary by status" \
  "Dirty tree summary"
require_contains \
  "scripts/verify-release-source-state.sh" \
  "source-state verifier dirty summary surface" \
  "By top-level surface:"

log "Checking release source disposition generator guardrails"
for expected_disposition_field in \
  "does not write files, stage, commit, tag, build, package" \
  "STATUS_FOR_DISPOSITION" \
  "### Release Source Inclusion Review" \
  "#### Dirty-Tree Disposition Summary" \
  "#### Recommended Review Order" \
  "##### Current Dirty Summary" \
  "#### Paths Requiring Disposition" \
  "#### Include In Release Candidate" \
  "#### Split Out Before Release" \
  "#### Remove Or Regenerate" \
  "include / split out / remove-regenerate / generated-local-only / needs owner" \
  "No package, notarize, upload, or R2 mutation before strict source-state passes:" \
  "Source freeze verification commands:" \
  "scripts/verify-release.sh --source-state-check --expected-version <version> --expected-build <build> --expected-tag <tag>"
do
  require_contains "scripts/generate-release-source-disposition.sh" "Release source disposition generator field: $expected_disposition_field" "$expected_disposition_field"
done

log "Checking launch evidence package generator guardrails"
for expected_evidence_field in \
  "does not write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services" \
  "### Launch Evidence Package - YYYY-MM-DD" \
  "#### Required Command Evidence" \
  "scripts/audit-launch-readiness.sh --allow-blockers" \
  "scripts/verify-release-source-state.sh --expected-version" \
  "scripts/generate-release-source-disposition.sh --expected-version" \
  "#### Source And Artifact Evidence" \
  "#### Production And Account Evidence" \
  "Support inbox test-message evidence:" \
  "First reply template evidence:" \
  "P0/P1 escalation path evidence:" \
  "#### Manual UAT Evidence" \
  "#### Rollback Readiness Evidence" \
  "Landing rollback deployment/id:" \
  "R2 previous candidate and rollback manifest evidence:" \
  "Backend function rollback owner and target:" \
  "App artifact rollback target:" \
  "Rollback verifier result:" \
  "Resume-after-rollback checklist evidence:" \
  "#### Privacy And Security Evidence" \
  "#### Risk And Exception Register" \
  "Every accepted limitation has user-facing workaround copy:" \
  "Every skipped automated diagnostic has owner-approved replacement evidence:" \
  "Every external/account blocker has owner and next action:" \
  "Every P0/P1 remains a hold unless fixed, rolled back, or explicitly owner-held:" \
  "Every P2 without workaround remains a hold:" \
  "Any secret/private-data/payment/unsafe-Act risk reviewed:" \
  "Release notes and support replies match accepted limitations:" \
  "Risk register reviewed by owner:" \
  "No raw transcripts, private screenshots, OAuth tokens, payment details, or secrets included:" \
  "No package, notarize, upload, deploy, tag, or R2 mutation before strict source-state and exact-candidate checks pass:"
do
  require_contains "scripts/generate-launch-evidence-package.sh" "Launch evidence package generator field: $expected_evidence_field" "$expected_evidence_field"
done

log "Checking manual UAT pass generator guardrails"
for expected_manual_uat_field in \
  "does not write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services" \
  "### Manual UAT Pass - YYYY-MM-DD" \
  "#### Surface Assignment" \
  "Clean install and onboarding" \
  "Dictation" \
  "Context and memory" \
  "Talk Mode" \
  "Act Mode" \
  "Website, auth, download, and legal" \
  "Visual, keyboard, VoiceOver, motion, and contrast" \
  "Billing, account limits, and access" \
  "Resilience and recovery" \
  "Exploratory QA charters" \
  "#### Scripted Rows" \
  "CI-01 Fresh install from DMG" \
  "DI-05 Offline transcription" \
  "DI-01 Native text field" \
  "DI-02 Browser text field" \
  "DI-03 Long paragraph" \
  "DI-04 Cancel mid-dictation" \
  "DI-06 Microphone denied" \
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
  "TK-01 Simple spoken question and first-response timing" \
  "AC-01 Safety mode required" \
  "AC-02 Native Voiyce navigation" \
  "AC-03 Browser navigation" \
  "AC-04 Public test form" \
  "AC-05 Gmail draft" \
  "AC-06 Calendar read" \
  "AC-07 Desktop app switching" \
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
  "AC-08 Blocked destructive action" \
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
  "BA-01 Billing mode sanity" \
  "BA-02 Checkout and portal access" \
  "BA-03 Account access transition" \
  "BA-04 Usage limit recovery" \
  "CI-07 Clean user quit/reopen permission sync" \
  "CI-08 Launch location parity" \
  "CI-09 Permission return routing" \
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
  "Clean user permission sync after quit/reopen result:" \
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
  "#### Required Measurements" \
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
do
  require_contains "scripts/generate-manual-uat-pass.sh" "Manual UAT pass generator field: $expected_manual_uat_field" "$expected_manual_uat_field"
done

log "Checking clean-install UAT generator guardrails"
for expected_clean_install_uat_field in \
  "does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services" \
  "### Clean Install UAT - YYYY-MM-DD" \
  "Support contact: \${SUPPORT_EMAIL}" \
  "Current dirty path count: \${DIRTY_COUNT}" \
  "#### Install And First Launch" \
  "First launch opens the downloaded app, not Xcode/local build:" \
  "Signed-out/offline recovery copy result:" \
  "#### Permission Prompt Matrix" \
  "State after quit/reopen" \
  "#### Core Smoke From Downloaded App" \
  "Act Strict harmless navigation result:" \
  "Redacted support export result:" \
  "#### Resilience Checks" \
  "Physical no-network launch from downloaded app result:" \
  "#### Evidence Review" \
  "No raw transcripts copied into evidence:" \
  "No full secret values copied into evidence:" \
  "#### Decision" \
  "Clean-install decision: pass / hold" \
  "Hold invites, release notes, and paid launch if the downloaded app cannot be installed"
do
  require_contains "scripts/generate-clean-install-uat.sh" "Clean-install UAT generator field: $expected_clean_install_uat_field" "$expected_clean_install_uat_field"
done

log "Checking exploratory QA generator guardrails"
for expected_exploratory_qa_field in \
  "does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services" \
  "### Exploratory QA Pass - YYYY-MM-DD" \
  "Support contact: \${SUPPORT_EMAIL}" \
  "Current dirty path count: \${DIRTY_COUNT}" \
  "#### Charter Assignment" \
  "EQ-01 Founder work session" \
  "EQ-02 Permission chaos" \
  "EQ-03 Privacy edge sweep" \
  "EQ-04 Agent stress loop" \
  "EQ-05 Account and billing edge sweep" \
  "EQ-06 Visual polish sweep" \
  "EQ-07 Public web and artifact sweep" \
  "#### Required Observations" \
  "Voiyce avoided re-explaining work across at least two AI tools:" \
  "Agent Log was useful without leaking raw private content:" \
  "#### Findings" \
  "#### Evidence Review" \
  "No raw transcripts copied into evidence:" \
  "No full secret values copied into evidence:" \
  "#### Decision" \
  "Hold invites, release notes, and paid launch if any exploratory P0/P1 remains"
do
  require_contains "scripts/generate-exploratory-qa-pass.sh" "Exploratory QA generator field: $expected_exploratory_qa_field" "$expected_exploratory_qa_field"
done

log "Checking launch monitoring generator guardrails"
for expected_launch_monitoring_field in \
  "does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services" \
  "#### Launch Monitoring Record - YYYY-MM-DD HH:MM" \
  "Support contact: \${SUPPORT_EMAIL}" \
  "Current dirty path count: \${DIRTY_COUNT}" \
  "Window: first hour / first day / weekly expansion / after change" \
  "##### Surface Checks" \
  "Website/Vercel status:" \
  "Cloudflare R2 status:" \
  "InsForge functions status:" \
  "OpenAI usage/quota status:" \
  "Stripe mode/webhook status:" \
  "Support inbox status:" \
  "##### Signals" \
  "Spend or quota anomaly:" \
  "Privacy/security concern:" \
  "Unsafe Act report:" \
  "##### Actions" \
  "Invite pause or resume decision:" \
  "##### Privacy Review" \
  "No secret values copied into record:" \
  "Support exports reviewed before linking:" \
  "Pause new invites if any P0/P1 appears"
do
  require_contains "scripts/generate-launch-monitoring-record.sh" "Launch monitoring generator field: $expected_launch_monitoring_field" "$expected_launch_monitoring_field"
done

log "Checking invite batch generator guardrails"
for expected_invite_batch_field in \
  "does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services" \
  "### Invite Batch Record - YYYY-MM-DD" \
  "Support contact: \${SUPPORT_EMAIL}" \
  "Current dirty path count: \${DIRTY_COUNT}" \
  "Target user count:" \
  "Invite source: founder list / design partner / waitlist / internal referral" \
  "Known limitations linked:" \
  "Pre-invite decision link:" \
  "Launch evidence package link:" \
  "Launch monitoring record link:" \
  "#### Batch Readiness Checks" \
  "P0/P1 queue is empty or explicitly held:" \
  "Exact artifact copy includes version/build, DMG checksum, known limitations, support email, and privacy/reset-memory guidance:" \
  "Invite count is small enough for current support coverage:" \
  "#### Pause Criteria" \
  "Pause on any P0/P1:" \
  "Pause on repeated install/auth/Dictation/Talk/Act/billing/privacy issue:" \
  "Pause on support inbox ownership gap:" \
  "#### Privacy Review" \
  "No secret values copied into record:" \
  "Invite list stored outside this record:" \
  "Do not send a new invite batch while a P0/P1 is open"
do
  require_contains "scripts/generate-invite-batch-record.sh" "Invite batch generator field: $expected_invite_batch_field" "$expected_invite_batch_field"
done

log "Checking invite resume generator guardrails"
for expected_invite_resume_generator_field in \
  "does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services" \
  "### Invite Resume Checklist - YYYY-MM-DD" \
  "Support contact: \${SUPPORT_EMAIL}" \
  "Current dirty path count: \${DIRTY_COUNT}" \
  "Resume trigger: pause condition / incident / failed verification / backend change / landing deployment / billing change / DMG artifact change" \
  "#### Required Verification" \
  "scripts/audit-launch-readiness.sh --live --allow-blockers" \
  "scripts/verify-production-landing.sh https://voiyce.us" \
  "scripts/verify-release.sh --skip-ui-tests --public-download-check --public-dmg-check --production-landing-check" \
  "Clean-machine or clean-user install evidence is current for the exact DMG users will receive:" \
  "Manual UAT evidence covers onboarding, Dictation, Context, Talk, Act in Strict, Agent Log, Settings, billing/account access, and legal/download paths:" \
  "Production environment evidence covers OpenAI key rotation, InsForge function env, usage-cap decision, Vercel env, R2 objects, Stripe mode, and support inbox ownership without copying secret values:" \
  "Rollback readiness evidence identifies the previous known-good landing deployment, R2 latest object, backend function version, app artifact, and owner:" \
  "#### Resume Safety Checks" \
  "Support inbox first-hour coverage scheduled:" \
  "Launch monitoring record prepared:" \
  "Invite batch record prepared:" \
  "Pause authority confirmed:" \
  "#### Privacy Review" \
  "No secret values copied into record:" \
  "Support exports reviewed before linking:" \
  "Do not resume invites if any P0/P1 remains"
do
  require_contains "scripts/generate-invite-resume-checklist.sh" "Invite resume generator field: $expected_invite_resume_generator_field" "$expected_invite_resume_generator_field"
done

log "Checking support inbox generator guardrails"
for expected_support_inbox_generator_field in \
  "does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services" \
  "#### Support Inbox Readiness - YYYY-MM-DD" \
  "Support contact: \${SUPPORT_EMAIL}" \
  "Current dirty path count: \${DIRTY_COUNT}" \
  "Primary support owner:" \
  "Backup support owner:" \
  "Engineering escalation owner:" \
  "Billing escalation owner:" \
  "Rollback owner:" \
  "First-hour coverage window:" \
  "First-day coverage window:" \
  "P0/P1 escalation path:" \
  "P2 triage path:" \
  "Support intake template ready:" \
  "Support response playbook ready:" \
  "Support export privacy review instructions ready:" \
  "Invite pause authority:" \
  "#### Support Path Proof" \
  "Support inbox test message sent and received:" \
  "First reply template tested:" \
  "Backup owner handoff tested:" \
  "P0/P1 pause decision path tested:" \
  "#### Privacy Review" \
  "No secret values copied into record:" \
  "Support exports reviewed before linking:" \
  "Hold invites if no primary owner, backup owner, or P0/P1 escalation owner is assigned."
do
  require_contains "scripts/generate-support-inbox-readiness.sh" "Support inbox generator field: $expected_support_inbox_generator_field" "$expected_support_inbox_generator_field"
done

log "Checking Act safety incident generator guardrails"
for expected_act_safety_generator_field in \
  "does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services" \
  "##### Act Safety Incident - YYYY-MM-DD" \
  "Support contact: \${SUPPORT_EMAIL}" \
  "Current dirty path count: \${DIRTY_COUNT}" \
  "Safety mode: Strict / Normal / Unrestricted / unknown" \
  "Requested action:" \
  "Actual visible action:" \
  "Expected confirmation shown: yes / no / not applicable" \
  "Stop button visible: yes / no / unknown" \
  "Stop worked: yes / no / not tried" \
  "Permission state: Accessibility / Screen Recording / Microphone" \
  "Sensitive surface involved: credentials / payment / private data / system settings / destructive action / none" \
  "Agent Log event IDs:" \
  "Invite decision: pause / narrow / continue" \
  "Kill switch or capability narrowing considered:" \
  "#### Safety Review" \
  "Blocked catastrophic/fraud/illegal-access/credential-theft/malware/hidden-action/platform-abusive request executed any local action:" \
  "Computer Use kill switch should be changed before resume:" \
  "#### Privacy Review" \
  "No raw screenshots copied into record:" \
  "No credentials copied into record:" \
  "No secret values copied into record:" \
  "Hold invites if Act performs a hidden, destructive, credential, payment, private-data, or account-changing action without expected confirmation."
do
  require_contains "scripts/generate-act-safety-incident.sh" "Act safety incident generator field: $expected_act_safety_generator_field" "$expected_act_safety_generator_field"
done

log "Checking OpenAI key rotation generator guardrails"
for expected_openai_key_rotation_generator_field in \
  "does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services" \
  "### OpenAI Key Rotation - YYYY-MM-DD" \
  "Support contact: \${SUPPORT_EMAIL}" \
  "Current dirty path count: \${DIRTY_COUNT}" \
  "Exposed key label/last-four, if safely known:" \
  "Exposed key revoked in OpenAI dashboard:" \
  "Replacement key created:" \
  "Replacement key stored only in server-side function environment:" \
  "Replacement key absent from local docs/support/chat:" \
  "macOS app bundle does not contain" \
  "Landing/browser bundle does not contain" \
  "Source secret scan result:" \
  "Built app secret scan result:" \
  "Landing build secret scan result:" \
  "Mounted DMG secret scan result:" \
  "Production function smoke result after rotation:" \
  "Old-key negative check, if available without exposing the key:" \
  "Usage/quota alerts reviewed:" \
  "OpenAI hard spend/quota limit visible:" \
  "#### Server-Side Storage Review" \
  "InsForge" \
  "Public browser env reviewed for no private OpenAI key:" \
  "#### Privacy Review" \
  "No full key values copied into record:" \
  "No bearer tokens copied into record:" \
  "Launch hold rule: if the exposed key is not revoked"
do
  require_contains "scripts/generate-openai-key-rotation.sh" "OpenAI key rotation generator field: $expected_openai_key_rotation_generator_field" "$expected_openai_key_rotation_generator_field"
done

log "Checking production evidence packet generator guardrails"
for expected_production_evidence_field in \
  "does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services" \
  "### Production Evidence Packet - YYYY-MM-DD" \
  "#### OpenAI Key Rotation" \
  "Replacement key stored only in server-side environments:" \
  "post-rotation Realtime smoke:" \
  "#### AI Usage And Quota Monitoring" \
  "OpenAI usage dashboard reviewed:" \
  "OpenAI hard spend/quota limit visible:" \
  "OpenAI usage alert threshold reviewed:" \
  "Realtime usage trend: normal / elevated / hold" \
  "Transcription usage trend: normal / elevated / hold" \
  "Computer Use usage trend: normal / elevated / hold" \
  "Screen-context usage trend: normal / elevated / hold" \
  "InsForge usage-cap events reviewed:" \
  "usage-cap env \`VOIYCE_ENFORCE_AGENT_USAGE_CAPS\` production value:" \
  "AI kill-switch values reviewed:" \
  "401/402/429 or quota spikes:" \
  "Pause/narrow/continue decision:" \
  "#### InsForge Functions And Database" \
  "usage-cap env \`VOIYCE_ENFORCE_AGENT_USAGE_CAPS\`:" \
  "#### Vercel Landing" \
  "\`NEXT_PUBLIC_INSFORGE_URL\` auth env review:" \
  "\`NEXT_PUBLIC_INSFORGE_ANON_KEY\` presence, no value:" \
  "Auth provider callback/sign-in smoke:" \
  "\`/api/download-health\` result:" \
  "stale-copy rejection result:" \
  "#### Cloudflare R2 Artifacts" \
  "latest/versioned DMG byte equality:" \
  "#### Stripe And Billing" \
  "webhook signing-secret presence, no value:" \
  "\`STRIPE_ALLOW_LIVE_MODE\` decision:" \
  "#### Support And Monitoring" \
  "Support inbox test message sent and received:" \
  "First reply template tested:" \
  "P0/P1 escalation path tested:" \
  "Invite pause authority:" \
  "Hold invites, release notes, and paid launch if OpenAI key rotation is incomplete"
do
  require_contains "scripts/generate-production-evidence-packet.sh" "Production evidence packet generator field: $expected_production_evidence_field" "$expected_production_evidence_field"
done

log "Checking production landing cutover generator guardrails"
for expected_production_landing_cutover_field in \
  "does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services" \
  "### Production Landing Cutover - YYYY-MM-DD" \
  "Support contact: \${SUPPORT_EMAIL}" \
  "Current dirty path count: \${DIRTY_COUNT}" \
  "#### Deployment Identity" \
  "Deployment URL/id:" \
  "Deployed commit:" \
  "Production domain points at the intended deployment:" \
  "Rollback deployment/id:" \
  "#### Download Configuration" \
  "NEXT_PUBLIC_DOWNLOAD_URL" \
  "#### Auth Configuration" \
  "NEXT_PUBLIC_INSFORGE_URL" \
  "NEXT_PUBLIC_INSFORGE_ANON_KEY" \
  "Auth provider callback/sign-in smoke:" \
  "Auth/download handoff result:" \
  "#### Production Route Checks" \
  "/api/download-health" \
  "Download page result:" \
  "Auth route result:" \
  "#### Production Smoke" \
  "scripts/verify-production-landing.sh \${PRODUCTION_URL}" \
  "Stale dictation-first copy absent:" \
  "Legal/support contact result:" \
  "#### R2 Artifact Identity" \
  "R2 identity matches release record:" \
  "Previous rollback candidate:" \
  "#### Monitoring And Resume" \
  "Invite/release-note decision: hold / narrow / resume" \
  "#### Privacy Review" \
  "No secret values copied into record:" \
  "Launch hold rule: if production serves stale copy"
do
  require_contains "scripts/generate-production-landing-cutover.sh" "Production landing cutover generator field: $expected_production_landing_cutover_field" "$expected_production_landing_cutover_field"
done

log "Checking Stripe live billing review generator guardrails"
for expected_stripe_live_billing_field in \
  "does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, charge users, or mutate external services" \
  "### Stripe Live Billing Review - YYYY-MM-DD" \
  "Support contact: \${SUPPORT_EMAIL}" \
  "Current dirty path count: \${DIRTY_COUNT}" \
  "#### Live Mode Decision" \
  "STRIPE_ALLOW_LIVE_MODE" \
  "Beta stays in test mode unless explicitly approved:" \
  "Open billing blockers:" \
  "#### Product And Price Review" \
  "Monthly price id:" \
  "Yearly price id:" \
  "STRIPE_PRICE_ID" \
  "Terms subscription/cancellation copy evidence:" \
  "#### Checkout And Portal Evidence" \
  "Checkout session evidence:" \
  "Billing portal evidence:" \
  "Portal cancellation behavior:" \
  "Refund policy/copy evidence:" \
  "#### Webhook And Subscription Mapping" \
  "Webhook endpoint id:" \
  "STRIPE_WEBHOOK_SECRET" \
  "Subscription RPC/mapping evidence:" \
  "cancel-at-period-end evidence:" \
  "Active plan mapping evidence:" \
  "#### Support And Monitoring" \
  "Billing escalation owner:" \
  "Invite/release-note decision: hold / narrow / proceed" \
  "#### Privacy Review" \
  "No Stripe secret keys copied into record:" \
  "No webhook signing secrets copied into record:" \
  "No card numbers copied into record:" \
  "Launch hold rule: if the live-mode decision"
do
  require_contains "scripts/generate-stripe-live-billing-review.sh" "Stripe live billing review generator field: $expected_stripe_live_billing_field" "$expected_stripe_live_billing_field"
done

log "Checking Google Workspace OAuth review generator guardrails"
for expected_google_workspace_oauth_field in \
  "does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, connect accounts, or mutate external services" \
  "### Google Workspace OAuth Review - YYYY-MM-DD" \
  "Support contact: \${SUPPORT_EMAIL}" \
  "Current dirty path count: \${DIRTY_COUNT}" \
  "#### OAuth App And Redirects" \
  "Authorized redirect URI evidence:" \
  "OAuth consent screen copy matches Gmail/Calendar feature surface:" \
  "Test users or production publishing status reviewed:" \
  "Open OAuth blockers:" \
  "#### Scope Review" \
  "Gmail read scope reviewed:" \
  "Calendar read scope reviewed:" \
  "Requested scopes match current app behavior:" \
  "App copy does not imply Gmail/Calendar access before connection:" \
  "Beta limitations mention Google-connected features:" \
  "#### Test Account Evidence" \
  "Missing-OAuth recovery result:" \
  "Revoked-OAuth recovery result:" \
  "Gmail read/query smoke result:" \
  "Calendar read/query smoke result:" \
  "Agent Log/support export event IDs:" \
  "No raw email or calendar content copied into evidence:" \
  "No raw calendar details copied into record:" \
  "#### Token And Privacy Review" \
  "No OAuth client secrets copied into record:" \
  "No OAuth access tokens copied into record:" \
  "No refresh tokens copied into record:" \
  "#### Support And Launch Decision" \
  "Invite/release-note decision: hold / narrow / proceed" \
  "Open Google Workspace blockers:" \
  "Launch hold rule: if OAuth app identity"
do
  require_contains "scripts/generate-google-workspace-oauth-review.sh" "Google Workspace OAuth review generator field: $expected_google_workspace_oauth_field" "$expected_google_workspace_oauth_field"
done

log "Checking risk/exception register generator guardrails"
for expected_risk_exception_field in \
  "does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, charge users, or mutate external services" \
  "### Launch Risk And Exception Register - YYYY-MM-DD" \
  "Support contact: \${SUPPORT_EMAIL}" \
  "Current dirty path count: \${DIRTY_COUNT}" \
  "#### Risk Rows" \
  "accepted P2 / skipped diagnostic / manual UAT gap / external blocker / support exception" \
  "#### Required Checks" \
  "No accepted P0/P1 exceptions:" \
  "Every accepted P2 has user-facing workaround copy:" \
  "Every skipped diagnostic has owner-approved manual coverage:" \
  "Every manual UAT gap has replacement evidence or hold decision:" \
  "Every external/account blocker has owner and next action:" \
  "Release notes include accepted limitations:" \
  "Support replies include accepted limitations:" \
  "Support intake and monitoring templates cover the risk:" \
  "Rollback or kill-switch path exists where applicable:" \
  "No secret values copied into record:" \
  "No raw transcripts copied into record:" \
  "No private screenshots copied into record:" \
  "No OAuth tokens copied into record:" \
  "No payment details copied into record:" \
  "No unsafe Act behavior accepted without a fix:" \
  "#### Launch Decision" \
  "Invite/release-note decision: hold / narrow / proceed" \
  "Narrow invite audience, if any:" \
  "User-facing workaround copy link:" \
  "Open risk blockers:" \
  "Launch hold rule: if any P0/P1 is accepted without a fix"
do
  require_contains "scripts/generate-risk-exception-register.sh" "Risk/exception register generator field: $expected_risk_exception_field" "$expected_risk_exception_field"
done

log "Checking privacy/security review generator guardrails"
for expected_privacy_security_field in \
  "does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services" \
  "### Privacy And Security Review - YYYY-MM-DD" \
  "#### Secret And Bundle Checks" \
  "Source secret scan result:" \
  "Landing build secret scan result:" \
  "Built app secret scan result:" \
  "Mounted DMG secret scan result:" \
  "OpenAI key rotation evidence, without secret values:" \
  "Replacement key stored only in server-side environments:" \
  "No secret values copied into this record:" \
  "#### Data And Export Checks" \
  "Support export redaction evidence:" \
  "Agent Log redaction evidence:" \
  "Support export reviewed for raw transcripts, private screenshots, OAuth tokens, payment details, and secrets:" \
  "#### User-Facing Disclosure Checks" \
  "Privacy policy matches current storage and processors:" \
  "Terms contact and support contact match:" \
  "Support intake avoids raw transcripts, screenshots, secrets, OAuth tokens, and payment details:" \
  "Production environment evidence avoids secret values:" \
  "No raw transcripts, private screenshots, OAuth tokens, payment details, or secrets included:" \
  "Hold invites, release notes, and paid launch if any copied secret, raw transcript, private screenshot, payment detail, OAuth token, unresolved OpenAI key exposure, unsafe Act behavior, or unreviewed support export remains."
do
  require_contains "scripts/generate-privacy-security-review.sh" "Privacy/security review generator field: $expected_privacy_security_field" "$expected_privacy_security_field"
done

log "Checking pre-invite decision generator guardrails"
for expected_pre_invite_decision_field in \
  "does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services" \
  "### Pre-Invite Decision - YYYY-MM-DD" \
  "Support contact: \${SUPPORT_EMAIL}" \
  "Current dirty path count: \${DIRTY_COUNT}" \
  "#### Required Evidence" \
  "Release-source disposition result:" \
  "OpenAI key rotation evidence without secret values:" \
  "Privacy/security review evidence:" \
  "#### Blocking Decision Checks" \
  "Release source tree committed, tagged, and reproducible:" \
  "Exposed OpenAI API key revoked and replaced server-side:" \
  "Internal Dictation, Context, Talk, and Act manual UAT:" \
  "#### Launch Decision" \
  "Support inbox first-response path tested:" \
  "No secrets copied into docs/support/chat:" \
  "No raw transcripts, private screenshots, OAuth tokens, or payment details copied:" \
  "Hold if any P0/P1 blocker, unresolved source-state mismatch, unrotated exposed key"
do
  require_contains "scripts/generate-pre-invite-decision.sh" "Pre-invite decision generator field: $expected_pre_invite_decision_field" "$expected_pre_invite_decision_field"
done

log "Checking evidence generator verifier guardrails"
for expected_generator_verifier_field in \
  "rendered output is usable" \
  "does not write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services" \
  "OPENAI_KEY_PATTERN" \
  "Current dirty path count: \${CURRENT_DIRTY_PATH_COUNT}" \
  "scripts/generate-release-source-disposition.sh" \
  "scripts/generate-launch-evidence-package.sh" \
  "scripts/generate-manual-uat-pass.sh" \
  "scripts/generate-clean-install-uat.sh" \
  "scripts/generate-exploratory-qa-pass.sh" \
  "scripts/generate-launch-monitoring-record.sh" \
  "scripts/generate-invite-batch-record.sh" \
  "scripts/generate-invite-resume-checklist.sh" \
  "scripts/generate-support-inbox-readiness.sh" \
  "scripts/generate-act-safety-incident.sh" \
  "scripts/generate-openai-key-rotation.sh" \
  "scripts/generate-production-evidence-packet.sh" \
  "scripts/generate-production-landing-cutover.sh" \
  "scripts/generate-stripe-live-billing-review.sh" \
  "scripts/generate-google-workspace-oauth-review.sh" \
  "scripts/generate-risk-exception-register.sh" \
  "scripts/generate-privacy-security-review.sh" \
  "scripts/generate-pre-invite-decision.sh" \
  "Support contact: aki.b@pentridgemedia.com" \
  "First launch opens the downloaded app, not Xcode/local build:" \
  "Voiyce avoided re-explaining work across at least two AI tools:" \
  "OpenAI usage/quota status:" \
  "Exact artifact copy includes version/build, DMG checksum, known limitations, support email, and privacy/reset-memory guidance:" \
  "scripts/verify-production-landing.sh https://voiyce.us" \
  "Support inbox test message sent and received:" \
  "Safety mode: Strict / Normal / Unrestricted / unknown" \
  "Exposed key revoked in OpenAI dashboard:" \
  "usage-cap env \`VOIYCE_ENFORCE_AGENT_USAGE_CAPS\`:" \
  "Evidence generator verification passed"
do
  require_contains "scripts/verify-evidence-generators.sh" "Evidence generator verifier field: $expected_generator_verifier_field" "$expected_generator_verifier_field"
done

log "Checking launch blocker verifier guardrails"
for expected_launch_blocker_verifier_field in \
  "no launch blockers remain" \
  "does not write files, stage, commit, tag, build, package, deploy, notarize, upload, or mutate external services" \
  "scripts/audit-launch-readiness.sh" \
  "EXPECTED_BLOCKERS" \
  "unexpected blockers: 0"
do
  require_contains "scripts/verify-launch-blockers.sh" "Launch blocker verifier field: $expected_launch_blocker_verifier_field" "$expected_launch_blocker_verifier_field"
done

log "Checking public DMG verifier guardrails"
require_contains \
  "scripts/verify-public-dmg.sh" \
  "public DMG verifier checksum check" \
  "verified sha="
require_contains \
  "scripts/verify-public-dmg.sh" \
  "public DMG verifier image check" \
  "hdiutil verify"
require_contains \
  "scripts/verify-public-dmg.sh" \
  "public DMG verifier Gatekeeper check" \
  "spctl -a -t open"
require_contains \
  "scripts/verify-public-dmg.sh" \
  "public DMG verifier notarization check" \
  "xcrun stapler validate"
require_contains \
  "scripts/verify-public-dmg.sh" \
  "public DMG verifier read-only mount" \
  'hdiutil attach "$DMG_PATH" -readonly -nobrowse'
require_contains \
  "scripts/verify-public-dmg.sh" \
  "public DMG verifier Applications symlink" \
  "Expected mounted DMG to include an Applications symlink."
require_contains \
  "scripts/verify-public-dmg.sh" \
  "public DMG verifier app signature" \
  "codesign --verify --deep --strict"
require_contains \
  "scripts/verify-public-dmg.sh" \
  "public DMG verifier bundle version" \
  "Bundle version does not match latest.json."
require_contains \
  "scripts/verify-public-dmg.sh" \
  "public DMG verifier mounted app secret scan" \
  "Scanning mounted app for leaked OpenAI API keys"

log "Checking release archive verifier guardrails"
require_contains \
  "scripts/verify-release-archive.sh" \
  "release archive verifier temporary archive path" \
  "mktemp -d"
require_contains \
  "scripts/verify-release-archive.sh" \
  "release archive verifier Xcode archive command" \
  "-archivePath"
require_contains \
  "scripts/verify-release-archive.sh" \
  "release archive verifier app presence check" \
  "Archived app was not created"
require_contains \
  "scripts/verify-release-archive.sh" \
  "release archive verifier codesign check" \
  "codesign --verify --deep --strict"
require_contains \
  "scripts/verify-release-archive.sh" \
  "release archive verifier secret scan" \
  "Scanning archived app for leaked OpenAI API keys"

if [[ "$RUN_LIVE" -eq 1 ]]; then
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT

  log "Checking live production landing at ${BASE_URL%/}"
  if scripts/verify-production-landing.sh "${BASE_URL%/}" > "$TMP_DIR/production-landing.log" 2>&1; then
    pass "Production landing smoke gate passes"
  else
    last_line="$(tail -n 1 "$TMP_DIR/production-landing.log" | tr -d '\r')"
    blocker "Production landing smoke gate fails: ${last_line:-see scripts/verify-production-landing.sh output}"
  fi

  log "Checking public R2 manifest metadata"
  if curl -fsSL "${R2_PUBLIC_BASE_URL%/}/latest.json" -o "$TMP_DIR/latest.json" \
    && python3 - "$TMP_DIR/latest.json" <<'PY'
import json
import sys
from urllib.parse import urlparse

manifest = json.load(open(sys.argv[1]))
required = ["version", "build", "sha256", "download_url"]
missing = [key for key in required if not manifest.get(key)]
versioned_url = manifest.get("versioned_download_url") or manifest.get("versioned_url")
if not versioned_url:
    missing.append("versioned_download_url or versioned_url")
if missing:
    raise SystemExit(f"missing fields: {', '.join(missing)}")
for key in ("download_url",):
    parsed = urlparse(manifest[key])
    if parsed.scheme != "https" or not parsed.netloc:
        raise SystemExit(f"{key} must be an absolute https URL")
parsed = urlparse(versioned_url)
if parsed.scheme != "https" or not parsed.netloc:
    raise SystemExit("versioned download URL must be an absolute https URL")
if manifest["sha256"] != "bfed37a6f089eb83d0d5426fc5d25dbd709184bf2f85feceefac70ee68c485d5":
    raise SystemExit("latest.json SHA does not match the recorded 1.0+16 checksum")
print(f"version={manifest['version']} build={manifest['build']} sha={manifest['sha256']}")
PY
  then
    pass "Public R2 latest.json metadata matches the recorded 1.0+16 checksum"
  else
    blocker "Public R2 latest.json metadata could not be verified against the recorded 1.0+16 checksum"
  fi
fi

log "Audit result"
printf 'Passed checks: %s\n' "${#PASSES[@]}"
for item in "${PASSES[@]}"; do
  printf '  ok: %s\n' "$item"
done

if [[ "${#BLOCKERS[@]}" -gt 0 ]]; then
  printf '\nLaunch status: BLOCKED (%s blockers)\n' "${#BLOCKERS[@]}"
  for item in "${BLOCKERS[@]}"; do
    printf '  blocker: %s\n' "$item"
  done
  if [[ "$ALLOW_BLOCKERS" -eq 1 ]]; then
    printf '\nBlockers were allowed for this prep-stage audit.\n'
    exit 0
  fi
  exit 1
fi

printf '\nLaunch status: READY by this audit. Run the full release gate and manual UAT before broad sharing.\n'
