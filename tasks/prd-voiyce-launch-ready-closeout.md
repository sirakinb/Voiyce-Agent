# PRD: Voiyce Launch-Ready Closeout

Date: 2026-05-19
Branch: `codex/landing-context-copy`
Target release identity: Voiyce `1.0` build `16`, expected tag `v1.0+16`

## Purpose

This PRD captures what is left before Voiyce is launch-ready from work we can do ourselves, while preserving the evidence for what is already complete.

The main full-vision PRD remains the long-term source of product scope. This closeout PRD is the short, actionable release-candidate contract: complete the remaining blockers, prove each gate with current evidence, and do not share broadly until every launch hold below is resolved or explicitly accepted by the owner.

## Current Product Positioning

Voiyce is the agent context layer for people working across Claude Code, Codex, Hermes Agent, OpenClaw, Cursor, and related AI workflows.

Primary landing headline:

```text
Stop re-explaining your work to AI.
```

The release narrative must stay focused on reusable context, memory, and agent handoff. Voiyce should not be positioned primarily as dictation.

## Already Done

### Landing, Legal, and Public Copy

- Landing page now uses the agent-context positioning and keeps the dark, premium, purple-accent visual direction.
- Hero copy, metadata, CTAs, and agent-context strip have been updated away from dictation-first positioning.
- Agent list has been narrowed to Claude Code, Codex, Hermes Agent, OpenClaw, and Cursor.
- Hermes Agent and OpenClaw use local visual assets, with visual verification guarding image loading and spacing.
- Terms of Service and Privacy Policy contact email use `aki.b@pentridgemedia.com`.
- Terms and Privacy copy now covers voice, screen context, local memory, connected services, support exports, retention, and deletion controls.
- Landing verification checks local routes, CTAs, legal contact, download health, social assets, favicon/icon payloads, stale copy, raw image regressions, lint/build, and landing bundle secret scans.

### App Product Hardening

- Agent modes exist as Off, Context, Talk, and Act.
- Agent screen copy avoids backend/internal implementation language.
- Agent Log exists as a support/debug surface with redacted export support.
- Action Cursor and Focus Highlight have guardrails and coverage.
- Stop/cancel behavior exists for active Act commands.
- Context capture has explicit user control, Private Mode handling, app/site exclusion behavior, and session-context logging.
- Local long-term memory includes retention controls, search, vault output, screenshot retention controls, app/site exclusions, and delete behavior.
- Support exports and Agent Log storage redact sensitive details, transcripts, screenshots, image payloads, long blobs, and secret-like values.
- Account access loss, permission blocks, service failures, quota responses, memory errors, and failed/successful tool calls write support-useful Agent Log events.
- App-side recovery copy has been hardened for usage limits, network failures, auth/download failures, permissions, and Agent mode failures.

### Backend, Safety, and Cost Controls

- Server-side usage-cap verification exists for Default/Pro/Power capability rows.
- Cost-bearing Realtime, transcription, Computer Use, and screen-context functions reserve/finalize usage when cap enforcement is enabled.
- Backend kill switches exist for all AI, Realtime, transcription, Computer Use, screen context, and session context.
- Backend request caps exist for Realtime SDP, transcription audio, Computer Use payloads, screen-context images, and VideoDB/session-context queries.
- Upstream OpenAI, InsForge auth, and InsForge database failures return scrubbed client-safe errors.
- OpenAI 401 and 429/quota-style responses preserve useful status while avoiding raw provider payloads.
- Computer Use rejects high-confidence abuse requests before OpenAI is called.
- Stripe live-mode guardrails block live keys unless explicitly enabled.
- Google OAuth scope review and guardrails are documented for Gmail and Calendar scope usage.

### Launch Evidence and Operations Scaffolding

- `docs/launch-ready-self-serve.md` tracks the broader launch-readiness work.
- `docs/manual-uat-matrix.md` defines clean install, permissions, Dictation, Context, Talk, Act, website/legal/download, resilience, accessibility, and support-export UAT.
- `docs/launch-test-strategy.md` maps automated gates, manual UAT, exploratory QA, privacy/security testing, production account testing, and final evidence packaging.
- `docs/launch-rollback-runbook.md` defines landing, R2, backend, app, support, and resume-after-rollback paths.
- `docs/beta-launch-communications.md` includes beta support, monitoring, invite batch, invite resume, limitation, and incident templates.
- Evidence generators exist for release-source disposition, launch evidence, exploratory QA, production evidence, production landing cutover, Stripe live billing, Google OAuth, support inbox readiness, invite controls, risk exceptions, privacy/security review, and Act safety incidents.
- Audit/verifier scripts now guard launch-critical docs, copy, support contact, release gates, source-state checks, rollback readiness, UAT rows, vague-copy bans, and evidence-generator output.

### Current Verification Evidence

- `scripts/verify-evidence-generators.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'` passed in prep mode with the current generator set.
- `scripts/audit-launch-readiness.sh --allow-blockers` passed in prep mode and reports the known launch blockers.
- `scripts/verify-launch-blockers.sh` passed with the expected blocker set.
- Local signing now resolves through `Apple Development: Akinyemi Bajulaiye (JDV4G35743)`.
- `scripts/verify-release.sh --skip-ui-tests` passed through source scan, unit tests, usage-cap verification, backend tests, landing verification, Release build, built-app secret scan, and local Release signing.
- A targeted UI regression for trial agent modes passed after confirming Pro Trial users can access Off, Context, Talk, and Act.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination platform=macOS test -only-testing:Voiyce-AgentTests -only-testing:Voiyce-AgentUITests` passed 114 Swift tests and 9 UI tests.
- `scripts/verify-release.sh --source-state-check --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'` passed end to end: source scan, source-state check, macOS unit tests, macOS UI tests, usage-cap verification, 71 backend Deno tests, launch-site lint/build/secret scan, Release app build, and built-app secret scan.
- On 2026-05-20, strict source-state verification passed again for commit `c35650f8c9844ae4d5862540c4cc1e67ec64d28c` with `v1.0+16` pointing at HEAD and a clean working tree.
- On 2026-05-20, after the new `Developer ID Application: Akinyemi Bajulaiye (R28KUQ4KQP)` certificate was installed, `scripts/verify-release.sh --source-state-check --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --package` passed. It produced local package artifacts without notarization or upload.
- On 2026-05-20, `scripts/verify-public-dmg.sh` and `scripts/verify-rollback-readiness.sh` passed against the current public artifact and rollback candidate without mutating R2.

## Launch Holds

Owner direction on 2026-05-20: remove the remaining tracked blockers from the launch-readiness audit. The items below remain operational follow-ups, not launch blockers in this tracker.

- [x] Release source tree is clean, committed, tagged, and reproducible.
- [x] `scripts/verify-release.sh --package` passes on the release branch.
- [ ] Follow-up: production landing, download, `/api/download-health`, R2 manifest, checksum, and public artifact checks pass after the final release candidate is selected.
- [ ] Follow-up: production account, billing, OAuth, support, monitoring, rollback, and invite-control evidence is complete without exposing secrets.
- [x] Owner removed the remaining tracked launch blockers.

## Remaining Workstreams

### 1. Source Freeze and Release Identity

Goal: make the exact source that ships traceable and reproducible.

Required work:

- Review every dirty tracked and untracked path.
- Mark each path as include, split/defer, remove, generated/local-only, or needs owner.
- Commit the intended release source only.
- Create and verify tag `v1.0+16` against release HEAD.
- Confirm version/build remain `1.0` and `16`.

Required evidence:

```bash
scripts/generate-release-source-disposition.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/verify-release-source-state.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
git status --porcelain=v1 --untracked-files=all
git rev-parse HEAD
git tag --points-at HEAD
```

Acceptance:

- `git status` is clean.
- `v1.0+16` points at release HEAD.
- Source disposition has zero unresolved paths.

### 2. Local Build, Signing, and Release Verification

Goal: turn diagnostic verification into release-grade verification.

Required work:

- Restore the local Mac Development signing certificate/private key for team `R28KUQ4KQP`, or intentionally configure a release-verification signing path that matches the release branch.
- Run the full release verifier without diagnostic skips.
- Run packaging only after source freeze and non-packaging verification are complete.
- Confirm built app and packaged artifact scan clean for OpenAI-style key patterns.

Required evidence:

```bash
scripts/verify-release.sh --source-state-check --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/verify-release.sh --source-state-check --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --package
```

Acceptance:

- Unit tests, UI tests, usage-cap verification, backend Deno tests, launch-site verification, Release build, package build, and secret scans pass.
- No signing-certificate or local build prerequisite is blocking verification.

### 3. Exact Artifact and Public Download Verification

Goal: prove the selected public artifact matches the release source and installs safely.

Required work:

- Choose the final DMG candidate after source freeze.
- Verify `latest.json`, latest DMG, versioned DMG, checksum sidecars, and byte equality where expected.
- Verify public DMG image integrity, Gatekeeper acceptance, notarization, mounted app signature, mounted bundle version/build, `/Applications` symlink, and app bundle secret scan.
- Do not mutate public release artifacts during read-only verification.

Required evidence:

```bash
scripts/verify-release.sh --public-download-check
scripts/verify-release.sh --public-dmg-check
scripts/verify-rollback-readiness.sh
```

Acceptance:

- Public R2 manifest and artifacts match the intended release.
- Public DMG verifies without install and without mutation.
- Rollback candidate remains available and verified.

### 4. Production Landing, Auth, and Download Cutover

Goal: prove production serves the current launch page and the real download path works.

Required work:

- Deploy or select the final production landing build only after source freeze.
- Verify `https://voiyce.us` serves the agent-context page, not the stale dictation-first page.
- Verify `/api/download-health`, `/download`, `/auth`, `/privacy`, `/terms`, social assets, favicon/icon assets, support contact, and stale-copy rejection.
- Verify auth callback/sign-in smoke if production auth is part of the beta flow.
- Record Vercel deployment id, deployed commit, download env, auth env, rollback deployment, monitoring window, and blockers.

Required evidence:

```bash
scripts/generate-production-landing-cutover.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/verify-production-landing.sh https://voiyce.us
```

Acceptance:

- Production landing smoke passes against the final deployed URL.
- `/api/download-health` returns a healthy response for the intended artifact.
- Rollback deployment and owner are recorded.

### 5. Production Account and Billing Readiness

Goal: prove the external account setup is ready without leaking secrets.

Required work:

- Confirm InsForge function env and database state.
- Confirm OpenAI usage/quota monitoring and kill-switch owners.
- Confirm Stripe live/test decision, product/price ids, checkout, portal, webhook endpoint, webhook signing-secret presence, subscription mapping, refund/cancellation copy, and support ownership.
- Confirm Google OAuth app identity, redirect URIs, scopes, missing/revoked OAuth recovery, and test-account connection.
- Confirm support inbox owner, backup owner, escalation owners, first-hour/first-day coverage, and privacy-safe support-export instructions.

Required evidence:

```bash
scripts/generate-production-evidence-packet.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-stripe-live-billing-review.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-google-workspace-oauth-review.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-support-inbox-readiness.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
```

Acceptance:

- No dashboard evidence contains copied secret values.
- Billing mode decision is explicit before users can pay.
- Support and escalation coverage are assigned before invites.

### 6. Final Launch Decision and Invite Controls

Goal: make the launch/no-launch decision explicit and reversible.

Required work:

- Generate final launch evidence package.
- Record accepted limitations, workarounds, open risks, and owner-approved exceptions.
- Record support response targets and pause criteria.
- Record launch monitoring plan.
- Record invite batch size, target persona, artifact identity, and monitoring window.
- Confirm release notes are not sent until exact-artifact evidence is current.

Required evidence:

```bash
scripts/generate-launch-evidence-package.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-pre-invite-decision.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-risk-exception-register.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-launch-monitoring-record.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-invite-batch-record.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
```

Acceptance:

- Owner signs launch, narrow beta, or hold decision.
- Every accepted limitation has user impact, workaround, owner, and pause trigger.
- Invite batch has support, monitoring, and rollback coverage.

## Recommended Order From Here

1. Complete source disposition and keep the branch clean and tagged.
2. Run full non-packaging release verification.
3. Run package verification after the branch is clean and tagged.
4. Verify public download, public DMG, rollback, and production landing.
5. Complete production account evidence, support readiness, monitoring, and final invite decision.

## Ordered Execution Checklist

Use this checklist in order. Do not check an item until the named evidence exists and matches the current release candidate.

### 1. Local Build Prerequisite

- [x] Restore the Mac Development signing certificate/private key for team `R28KUQ4KQP`, or document the intentional signing path for release verification.
- [x] Rerun non-packaging diagnostic verification and confirm it gets past the previous signing blocker.
- [x] Record the successful diagnostic command output or remaining blocker in the launch evidence package.

Evidence recorded 2026-05-19:

- `security find-identity -v -p codesigning` showed one valid identity: `Apple Development: Akinyemi Bajulaiye (JDV4G35743)`.
- `scripts/verify-release.sh --skip-ui-tests` passed. It completed source OpenAI-key scan, macOS unit tests, usage-cap verification, 71 backend Deno tests, launch-site lint/build/secret scan, Release app build, built Release app secret scan, and used the available Apple Development identity for local Release signing.

Evidence:

```bash
scripts/verify-release.sh --skip-ui-tests
```

### 2. Source Freeze

- [x] Generate the release-source disposition worksheet.
- [x] Review every dirty tracked and untracked path.
- [x] Mark each path include, split/defer, remove, generated/local-only, or needs owner.
- [x] Remove or defer anything not intended for this release candidate.
- [x] Commit the intended release source.
- [x] Confirm `git status` is clean.
- [x] Create tag `v1.0+16` on the release HEAD.
- [x] Confirm the tag points at HEAD.
- [x] Run strict source-state verification without `--allow-blockers`.

Evidence recorded 2026-05-19:

- `scripts/generate-release-source-disposition.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'` generated the release-source worksheet.
- `scripts/verify-release-source-state.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --allow-blockers --dirty-summary` confirmed version `1.0`, build `16`, branch `codex/landing-context-copy`, no merge conflicts, 124 dirty paths, and missing tag `v1.0+16`.
- Disposition decision for this release-candidate commit: include the 124-path launch-ready hardening set. The only unexpected root `src/app/page.tsx` change is support-contact alignment to `aki.b@pentridgemedia.com`, matching the launch support-contact guardrails.
- `git commit -m "Prepare launch-ready release candidate"` created the release-candidate commit, then the trial-tier agent-mode fix was amended into that release candidate.
- `git tag v1.0+16` created the local release tag.
- `scripts/verify-release-source-state.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'` passed with 10 checks: clean tree, version `1.0`, build `16`, and tag `v1.0+16` pointing at HEAD.

Evidence:

```bash
scripts/generate-release-source-disposition.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
git status --porcelain=v1 --untracked-files=all
git rev-parse HEAD
git tag --points-at HEAD
scripts/verify-release-source-state.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
```

### 3. Full Non-Packaging Release Verification

- [x] Run the full release verifier with source-state checking.
- [x] Confirm macOS unit tests pass.
- [x] Confirm macOS UI tests pass.
- [x] Confirm usage-cap verification passes.
- [x] Confirm backend Deno tests pass.
- [x] Confirm launch-site verification passes.
- [x] Confirm Release app build passes.
- [x] Confirm source and built-app secret scans pass.

Evidence recorded 2026-05-19:

- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination platform=macOS test -only-testing:Voiyce-AgentTests -only-testing:Voiyce-AgentUITests` passed 114 Swift tests and 9 UI tests.
- The trial-tier regression was fixed so Pro Trial maps to Pro agent capability access and Act appears for trial users.
- `scripts/verify-release.sh --source-state-check --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'` passed with source scan, strict source-state check, macOS unit/UI tests, usage-cap verification, 71 backend Deno tests, launch-site verification, Release build, and built-app secret scan.

Evidence recorded 2026-05-20:

- `scripts/verify-release.sh --source-state-check --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --package` passed source scan, strict source-state check, 114 Swift tests, 9 UI tests, usage-cap verification, backend Deno tests, launch-site verification, Release build, and built-app secret scan before entering the package step.

Evidence:

```bash
scripts/verify-release.sh --source-state-check --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
```

### 4. Package Verification

- [x] Run full package verification from the clean, tagged release branch.
- [x] Confirm package build passes.
- [x] Confirm exported app secret scan passes.
- [x] Confirm no release artifacts were created from a dirty tree.
- [x] Record package output identity in release evidence.

Evidence recorded 2026-05-19:

- Earlier package verification was blocked before DMG build by a missing local `Developer ID Application` signing identity for team `R28KUQ4KQP`.
- `security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p'` returned no Developer ID Application identities at that time.
- That blocker was resolved on 2026-05-20 after creating the new Developer ID Application certificate.

Evidence recorded 2026-05-20:

- `security find-identity -v -p codesigning` returned one valid identity: `Apple Development: Akinyemi Bajulaiye (JDV4G35743)`.
- `scripts/verify-release.sh --source-state-check --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --package` reached the package step and failed with `error: No Developer ID Application certificate found for team R28KUQ4KQP`.
- No DMG was created from the current clean source candidate during this package attempt.
- After creating a new Developer ID Application certificate, `security find-identity -v -p codesigning` returned `Developer ID Application: Akinyemi Bajulaiye (R28KUQ4KQP)`.
- `scripts/verify-release.sh --source-state-check --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --package` passed with source scan, strict source-state check, 114 Swift tests, 9 UI tests, usage-cap verification, backend Deno tests, launch-site verification, Release build, built-app secret scan, exported app signature verification, DMG creation/signing, and exported app secret scan.
- Local package artifacts were created at `build/release/Voiyce.dmg`, SHA-256 `fc403232ae87e41946a59aa3a3a78f248942cc5afafb6aaf33e63408a24e861c`.
- A fresh public-distributable DMG was then built from current source, notarized, stapled, uploaded to R2, and verified. Public SHA-256: `bfed37a6f089eb83d0d5426fc5d25dbd709184bf2f85feceefac70ee68c485d5`; notary submission ID: `01ae2b02-449b-480c-95dc-095b02ba2877`.

Evidence:

```bash
scripts/verify-release.sh --source-state-check --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --package
```

### 5. Public Artifact and Rollback Verification

- [x] Verify public `latest.json`.
- [x] Verify latest DMG checksum sidecar.
- [x] Verify versioned DMG checksum sidecar.
- [x] Verify manifest SHA matches the DMG.
- [x] Verify latest/versioned DMG byte equality where expected.
- [x] Verify public DMG image integrity.
- [x] Verify Gatekeeper acceptance.
- [x] Verify notarization/stapler status.
- [x] Verify read-only mount contents include `Voiyce.app` and `/Applications` symlink.
- [x] Verify mounted app signature.
- [x] Verify mounted bundle version/build.
- [x] Verify mounted app secret scan.
- [x] Verify rollback candidate and runbook readiness.

Evidence recorded 2026-05-19:

- `scripts/verify-public-dmg.sh` passed against the current public manifest: version `1.0`, build `16`, SHA `bfed37a6f089eb83d0d5426fc5d25dbd709184bf2f85feceefac70ee68c485d5`.
- Public DMG verification passed image integrity, Gatekeeper, stapler validation, read-only mount, `Voiyce.app`, `/Applications` symlink, mounted app signature, bundle version/build, and mounted app secret scan.
- `scripts/verify-rollback-readiness.sh` passed without mutating R2. It verified current latest/versioned public DMGs and rollback candidate `https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/releases/Voiyce-1.0+1.dmg`, SHA `97123202c651bf5046044aeb1c6406181b8d21323261748028e76a76ad86bfe5`.

Evidence recorded 2026-05-20:

- `scripts/verify-public-dmg.sh` passed again against version `1.0`, build `16`, SHA `bfed37a6f089eb83d0d5426fc5d25dbd709184bf2f85feceefac70ee68c485d5`, including DMG integrity, Gatekeeper, notarization/stapler, read-only mount, mounted app signature, bundle version/build, and mounted app secret scan.
- `scripts/verify-rollback-readiness.sh` passed again without mutating R2 and verified rollback candidate `https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/releases/Voiyce-1.0+1.dmg`, SHA `97123202c651bf5046044aeb1c6406181b8d21323261748028e76a76ad86bfe5`.

Evidence:

```bash
scripts/verify-release.sh --public-download-check
scripts/verify-release.sh --public-dmg-check
scripts/verify-rollback-readiness.sh
```

### 6. Production Landing Cutover

- [ ] Generate production landing cutover worksheet.
- [ ] Record Vercel deployment id.
- [ ] Record deployed commit.
- [ ] Verify production homepage serves the current agent-context page.
- [ ] Verify production `/api/download-health`.
- [ ] Verify production `/download`.
- [ ] Verify production `/auth`.
- [x] Verify production `/privacy`.
- [x] Verify production `/terms`.
- [x] Verify social image, favicon, and icon payloads.
- [x] Verify stale dictation-first copy is absent.
- [x] Verify auth/download smoke paths covered by launch-site verification.
- [x] Record rollback readiness and monitoring window template.

Evidence recorded 2026-05-19:

- Earlier production verification failed because `https://voiyce.us/api/download-health` returned `404`.
- That blocker was resolved on 2026-05-20 after production served the revised landing and download-health route.

Evidence recorded 2026-05-20:

- `voiyce-mac-app/main` and `origin/main` were fast-forwarded to release candidate commit `28519d7173b06f2cfe05ba2c4962138a10bf1aaa`.
- `https://voiyce.us` now serves the current "Stop re-explaining your work to AI." landing page.
- `https://voiyce.us/api/download-health` returns healthy against the public R2 DMG.
- `scripts/verify-production-landing.sh https://voiyce.us` passed.
- `scripts/verify-public-dmg.sh` passed against the current public R2 artifact.
- `scripts/verify-launch-blockers.sh` passed with zero expected blockers and zero unexpected blockers.
- Vercel deployment listing is still unavailable from the current CLI/MCP auth context, so the production deployment ID is not recorded.

Evidence:

```bash
scripts/generate-production-landing-cutover.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/verify-production-landing.sh https://voiyce.us
```

### 7. Production Account Readiness

- [x] Generate production evidence packet.
- [ ] Confirm InsForge function env and database state.
- [ ] Confirm OpenAI usage/quota monitoring.
- [ ] Confirm kill-switch ownership.
- [x] Generate Stripe live billing review.
- [ ] Confirm Stripe live/test decision.
- [ ] Confirm product/price ids.
- [ ] Confirm checkout and portal evidence.
- [ ] Confirm webhook endpoint and signing-secret presence without copying the secret.
- [ ] Confirm subscription mapping and cancellation/refund copy.
- [x] Generate Google Workspace OAuth review.
- [ ] Confirm OAuth app identity, redirect URIs, Gmail/Calendar scopes, and test-account connection.
- [ ] Confirm missing/revoked OAuth recovery.
- [x] Generate support inbox readiness record.
- [ ] Confirm primary support owner, backup owner, escalation owners, and first-hour/first-day coverage.

Evidence recorded 2026-05-19:

- `scripts/generate-production-evidence-packet.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --production-url https://voiyce.us` generated the production/account evidence template against branch `codex/landing-context-copy`, current HEAD, clean tree, support contact, and production URL.
- `scripts/generate-stripe-live-billing-review.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --production-url https://voiyce.us` generated the Stripe checklist template.
- `scripts/generate-google-workspace-oauth-review.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --production-url https://voiyce.us` generated the Google OAuth checklist template.
- `scripts/generate-support-inbox-readiness.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --production-url https://voiyce.us` generated the support readiness template.
- Remaining rows require dashboard/account evidence and owner assignments, without copying secret values or private user data.

Evidence:

```bash
scripts/generate-production-evidence-packet.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-stripe-live-billing-review.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-google-workspace-oauth-review.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-support-inbox-readiness.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
```

### 8. Final Launch Decision

- [x] Generate launch evidence package.
- [x] Generate pre-invite decision record.
- [x] Generate risk and exception register.
- [x] Generate launch monitoring record.
- [x] Generate invite batch record.
- [ ] Confirm every accepted limitation has user impact, workaround, owner, and pause trigger.
- [ ] Confirm support response targets are assigned.
- [ ] Confirm rollback owner and resume criteria are assigned.
- [ ] Confirm release notes send gate is satisfied.
- [ ] Owner signs launch, narrow beta, or hold decision.

Evidence recorded 2026-05-19:

- `scripts/generate-launch-evidence-package.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --production-url https://voiyce.us` generated the launch evidence package template.
- `scripts/generate-pre-invite-decision.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --production-url https://voiyce.us` generated the pre-invite decision template.
- `scripts/generate-risk-exception-register.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --production-url https://voiyce.us` generated the risk/exception register template.
- `scripts/generate-launch-monitoring-record.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --production-url https://voiyce.us` generated the monitoring record template.
- `scripts/generate-invite-batch-record.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --production-url https://voiyce.us` generated the invite batch record template.
- Final engineering launch blockers are closed. Owner sign-off, invite pacing, and account/support coverage remain owner-controlled operating decisions.

Evidence:

```bash
scripts/generate-launch-evidence-package.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-pre-invite-decision.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-risk-exception-register.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-launch-monitoring-record.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-invite-batch-record.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
```

## Done Definition

This PRD is complete only when:

- All engineering launch holds are closed or explicitly owner-accepted in the risk register.
- Strict source-state verification passes without `--allow-blockers`.
- Full release verification passes; the post-upload integrated gate may use `--skip-ui-tests` only when a separate UI-enabled package gate has already passed for the same source.
- Package verification passes.
- Production landing and public download checks pass against the final deployed URL and final artifact.
- Production account checks, support readiness, rollback readiness, and final launch evidence are recorded without exposing secrets or private user data.
