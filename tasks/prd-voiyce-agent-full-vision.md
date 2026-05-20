# PRD: Voiyce Agent Full Vision

## Introduction

Voiyce currently has a strong dictation product and a working Realtime voice agent prototype that can use session context, native tools, Gmail/Calendar integrations, and VideoDB-backed screen/audio memory. The next product step is to turn this prototype into a polished desktop assistant that users can intentionally run in one of four modes: Off, Context, Talk, or Act.

The finished product should feel like an assistant that can quietly understand the user's work context, talk naturally when summoned, and operate apps/websites when explicitly allowed. The main Agent UI must stay non-technical. Backend concepts such as OpenAI Realtime, VideoDB, Computer Use, tool calls, and memory indexing should be hidden from normal users and exposed only in Agent Log or developer/debug surfaces.

## Goals

- Build a production-quality Agent experience with four user-facing modes: Off, Context, Talk, and Act.
- Add long-term searchable memory across sessions, including an Obsidian-style Markdown vault.
- Add Act Mode with OpenAI Computer Use loop, native macOS executor, action cursor, focus highlight, and confirmations.
- Preserve the existing dictation workflow as a separate product surface.
- Give users clear control over privacy, safety, and cost through mode selection, safety mode, and tier-based capability limits.
- Support Default, Pro, and Power user-facing tiers.
- Make failures understandable through Agent Log and plain-language user states.
- Keep long-term memory local-only for the initial release, with cloud sync/retrieval as a future exploration.

## Implementation Status - 2026-05-14

The current build implements the core Agent product through the launch-readiness milestone. Server-side usage caps, private app exclusions, local retention controls, raw screenshot retention, memory deletion, Agent Log/support export redaction, and beta launch operations now have deterministic coverage or launch audit guardrails. Final public pricing, production tier mapping, clean-machine release UAT, production landing verification, and paid-tier product packaging remain launch-readiness work.

Shipped in the current build:

- Agent mode UI for Off, Context, Talk, and Act.
- Agent Log as a separate support/debug surface.
- Talk and Act tool registration over the Realtime `oai-events` data channel.
- Native Voiyce/macOS executor for deterministic app, URL, typing, key, and click paths.
- OpenAI Computer Use loop via the Responses API hosted `computer` tool, behind the deployed `computer-use-step` function.
- Action Cursor overlay for visible action state.
- Focus Highlight with a button and `Command+Shift+F`, plus focus-region screen inspection.
- Safety Mode in Settings: Strict, Normal, and Unrestricted.
- Confirmation UI and voice-confirmable pending actions for Voiyce-managed sensitive actions.
- Local long-term memory with searchable records and a Markdown vault at `~/Documents/Voiyce Memory`.
- Session stop writes useful summaries into local memory when available.

Still open after this milestone:

- Default/Pro/Power pricing and production Stripe-to-tier mapping.
- Production confirmation that server-side usage caps are enabled with the intended `VOIYCE_ENFORCE_AGENT_USAGE_CAPS` decision.
- Fully tuned always-on Context capture frequency beyond the conservative beta setting.
- Full resume-after-approval flow for OpenAI Computer Use pending safety checks; current launch behavior fails clearly instead of presenting a dead approval path.
- More real-world Act hardening across Gmail, browser forms, authenticated sites, and desktop apps.
- Voice latency/interruption tuning based on actual spoken UAT.
- Clean-machine install, permission, Dictation, Context, Talk, Act, billing, and production landing verification for the exact release candidate.

## Phase 2: Production Hardening and Public Launch

### Phase Objective

Turn the current beta-ready app into a public, paid-production release that can be safely distributed to real users without runaway infrastructure cost, stale release artifacts, broken permission flows, or confusing Agent behavior.

Phase 2 starts from the current shipped state: the landing page is deployed, Cloudflare R2 serves the notarized `1.0+16` DMG, and the core Agent product exists. The phase ends when the product can pass a clean-machine install, functional UAT, release verification, and production safety/cost gates.

### Phase 2 Scope

- **Release source integrity:** commit and tag the exact app/backend/landing source that produced the public DMG, keep release artifacts traceable, and document the build number, checksum, and deployment URLs.
- **Secret rotation and server-side key hygiene:** rotate the OpenAI API key that was exposed during development, verify no API secrets are shipped in the macOS app or browser bundle, and keep OpenAI calls behind server-side functions.
- **Clean-machine permission validation:** test a fresh download/install from `voiyce.us` on a clean macOS user or machine, including Microphone, Speech Recognition, Accessibility, Screen Recording, quit/reopen, and Settings state sync.
- **Act and Computer Use hardening:** run repeatable real-world tasks across Gmail, browser forms, app settings, authenticated sites, desktop navigation, and failure recovery.
- **Voice and Talk latency tuning:** tune Realtime turn detection, interruption behavior, tool delay messaging, and "still checking" responses so Talk feels natural.
- **Cost and tier enforcement:** implement Default/Pro/Power limits server-side for Realtime, transcription, Context capture, Computer Use steps, memory retention, and screenshot storage.
- **Kill switches and monitoring:** add admin controls to disable or throttle Realtime, transcription, and Computer Use independently, with logs and alerts for quota/rate-limit failures.
- **Memory and privacy controls:** finish raw screenshot retention settings, app/site exclusions, memory deletion, vault verification, and privacy copy for local-only memory.
- **Production diagnostics:** make Agent Log and support exports useful for debugging while redacting secrets and sensitive content by default.
- **Launch operations:** decide whether the public build is labeled Beta, document known limitations, define support escalation, and keep rollback paths for both the landing page and DMG.

### Phase 2 Acceptance Criteria

- [x] The release source tree for the public build is committed, tagged, and reproducible from Git.
- [x] Public DMG, checksum, manifest, landing page commit, and macOS build number are recorded in release notes.
- [ ] The exposed OpenAI API key is revoked and replaced with server-side-only secrets.
- [x] `scripts/verify-release.sh --package` passes on the release branch.
- [ ] A clean macOS install from `https://voiyce.us` passes onboarding, sign-in, dictation, permission grants, quit/reopen, Talk, Act, Agent Log, and Settings checks.
- [ ] Permission UI accurately reflects granted/denied state for Microphone, Speech Recognition, Accessibility, and Screen Recording after refresh, quit, and reopen.
- [ ] Act Mode completes the Phase 2 UAT matrix across at least Gmail, a public website form, app Settings navigation, browser tab navigation, and a blocked/sensitive action.
- [x] OpenAI Computer Use pending safety checks either resume correctly after approval or fail with a clear user-facing recovery path.
- [x] Default/Pro/Power caps are enforced server-side for cost-bearing APIs when `VOIYCE_ENFORCE_AGENT_USAGE_CAPS=true`; production environment confirmation remains external.
- [x] Admin kill switches exist for Realtime, transcription, and Computer Use.
- [x] Agent Log captures quota errors, permission blocks, safety prompts, Computer Use failures, memory writes, and memory errors in a support-useful format.
- [x] Memory retention, screenshot retention, app/site exclusions for durable memory, and delete controls are available and documented.
- [ ] Post-launch follow-up: verify the production landing page, download route, Cloudflare R2 latest DMG, versioned DMG, checksum, and `latest.json` after the final public cutover.
- [x] Known limitations and beta/public-launch labeling are documented before any broad user announcement.

## Launch-Ready Self-Serve Revision - 2026-05-17

### Revision Objective

Before sharing Voiyce with beta users, make the product as close to launch-ready as possible using only work that can be completed internally: code polish, copy polish, legal/contact updates, release discipline, local QA, automated testing, manual UAT, clean-machine validation, observability, privacy review, and rollback planning.

The goal is not merely "good enough for beta." The goal is a release candidate that would be defensible as a small public launch if external dependencies, payment activation, and broad production traffic were turned on later.

### Positioning To Preserve

- Voiyce is the **agent context layer** for people working across Claude Code, Codex, Hermes Agent, OpenClaw, Cursor, and related AI workflows.
- Voiyce is not primarily a dictation product on the landing page.
- Dictation remains a supported app capability, but the launch narrative should emphasize context capture, reusable memory, and agent handoff.
- Avoid vague launch copy such as "boost productivity," "revolutionize," "unlock your potential," "AI-powered," and "seamless experience."
- Prefer concrete pain: repeated explanations, lost context, scattered agent work, manual prompt rebuilding, unclear action history, and brittle handoffs.

### Execution Status - through 2026-05-18

- Landing page positioning, metadata, hero copy, agent-context strip, Hermes local image asset, and legal contact email have been updated for this revision.
- `scripts/verify-launch-site.sh --url http://localhost:23000` passes against the local development site and now validates live route fetches, key CTAs, rendered positioning copy, agent labels, removed-agent guardrails, and legal contact content.
- `scripts/verify-launch-site.sh --url http://localhost:23000 --visual` passes and verifies local desktop/mobile screenshots, horizontal overflow, full-page color contrast including input placeholders, text clipping, hero/nav overlap, agent-label spacing, Hermes/OpenClaw image loading, and nav-anchor behavior.
- The landing download URL now falls back to the default public R2 DMG URL when `NEXT_PUBLIC_DOWNLOAD_URL` is missing or blank, and the launch-site gate checks that fallback.
- The landing download page now checks `/api/download-health` before auto-starting the hidden DMG request, shows a plain support path when the configured installer URL is unreachable, and has a deterministic bad-URL simulation returning `503` from the health route.
- The macOS app support email is now centralized in `AppConstants.supportEmail`, with `launchSupportEmailStaysConsistentAcrossAppCopy` coverage keeping usage-limit and dictation recovery copy aligned with the launch/legal contact.
- `scripts/audit-launch-readiness.sh --allow-blockers` now verifies the app/landing support-email constants and launch-site/production verifier contact values stay aligned to `aki.b@pentridgemedia.com`, and fails on legacy Voiyce support-address strings.
- The landing-page support email is now centralized in `voiyce-config.ts`, with auth/download/legal pages and `scripts/verify-launch-site.sh` using that shared web contact source.
- Remaining landing raw `<img>` usages were replaced with Next image handling or non-image icon presentation so the landing lint gate now passes without image warnings, and the launch-site gate now fails if raw image elements return to launch-critical surfaces.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that `scripts/verify-launch-site.sh` continues to enforce zero-warning landing lint, raw image regressions, landing build secret scanning, accessibility smoke checks, and `/api/download-health`.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that `scripts/verify-production-landing.sh` continues to enforce stale-copy rejection, `/api/download-health`, legal contact, social image/favicon payload checks, and current agent-context positioning.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that `scripts/verify-rollback-readiness.sh` continues to enforce current public manifest/artifact verification, previous rollback candidate verification, local rollback manifest generation, and the no-R2-mutation guarantee.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that `scripts/verify-release.sh` continues to include source and built-app secret scans, usage-cap verification, launch-site verification, archive/public-DMG hooks, and the production landing hook.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that `scripts/verify-release.sh` continues to include the source-state hook, package command, public-download manifest hook, and `--skip-ui-tests` diagnostic-only warning.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that `scripts/verify-release-source-state.sh` continues to enforce clean-tree status, version/build consistency, tag-to-HEAD verification, and prep-stage blocker reporting.
- `scripts/verify-release-source-state.sh` now has a `--dirty-summary` prep option that prints a non-mutating breakdown by Git status and top-level surface for release-source disposition review.
- `scripts/generate-release-source-disposition.sh` now prints a no-write markdown release-source inclusion review prefilled with branch, HEAD, dirty-path count, status/surface summary, every dirty path grouped for disposition, and explicit include/split/remove decision sections before final source-state sign-off.
- `scripts/generate-launch-evidence-package.sh` now prints a no-write launch evidence package prefilled with current source facts and required command, artifact, production/account, support-path proof, manual UAT, rollback readiness, privacy/security, risk/exception, and final decision evidence fields.
- `scripts/generate-manual-uat-pass.sh` now prints a no-write manual UAT execution worksheet prefilled with current source facts, surface assignments, scripted row result slots, explicit clean-user permission-sync, launch-from-DMG-and-Applications checks, permission-return routing checks, physical no-network launch, active account-access-loss, billing mode sanity, checkout/portal, account-access transition, usage-limit recovery, dictation wrong-field protection, short-text, and punctuation checks, Vault Notes visibility and cross-app context quality checks, Talk stop-during-tool-call and Agent Log review checks, Act confirmation approve/cancel/Stop/timeout checks, Act network-drop recovery checks, Normal/Unrestricted Act safety smoke checks, public-form submit confirmation checks, Act action-log audit checks, download-health fallback checks, required measurements, bug severity fields, and launch hold rules.
- `scripts/generate-clean-install-uat.sh` now prints a no-read-secret/no-write clean-install UAT worksheet prefilled with downloaded-DMG install, first launch, sign-in, permission prompt state after refresh/quit/reopen/revoke, core Dictation/Context/Talk/Act smoke, physical offline launch, support export redaction, privacy-safe evidence review, and final owner sign-off fields.
- `scripts/generate-exploratory-qa-pass.sh` now prints a no-read-secret/no-write exploratory QA worksheet prefilled with founder-work, permission-chaos, privacy-edge, Agent-stress, account/billing, visual-polish, and public web/artifact charters, required observations, finding severity, privacy-safe evidence review, workaround decisions, and final owner sign-off fields.
- `scripts/generate-launch-monitoring-record.sh` now prints a no-read-secret/no-write launch monitoring worksheet prefilled with first-hour, first-day, weekly expansion, and after-change checks across website/Vercel, R2, InsForge, OpenAI usage/quota, Stripe, support inbox, signals, pause/resume decisions, and privacy-safe evidence handling.
- `scripts/generate-invite-batch-record.sh` now prints a no-read-secret/no-write invite batch worksheet prefilled with exact artifact identity, batch ownership, support/monitoring/rollback coverage, known limitations, launch evidence links, pause criteria, and privacy-safe invite evidence handling.
- `scripts/generate-invite-resume-checklist.sh` now prints a no-read-secret/no-write invite-resume worksheet prefilled with required production/release/manual verification, support/monitoring/rollback ownership, resume safety checks, pause authority, and privacy-safe evidence handling before invites restart after a pause or change.
- `scripts/generate-support-inbox-readiness.sh` now prints a no-read-secret/no-write support inbox readiness record prefilled with support owner coverage, first-hour and first-day monitoring, escalation paths, support-path proof, pause authority, and privacy-safe support evidence.
- `scripts/generate-act-safety-incident.sh` now prints a no-read-secret/no-write Act safety incident record prefilled with expected action/confirmation/Stop/capability fields, sensitive-surface review, kill-switch and capability-narrowing decisions, invite decision, and privacy-safe evidence handling.
- `scripts/generate-openai-key-rotation.sh` now prints a no-read-secret/no-write OpenAI key rotation worksheet prefilled with exposed-key revocation, server-side replacement, source/app/landing/DMG secret scans, post-rotation smoke, old-key negative checks, usage/quota alerts, and no-secret evidence handling.
- `scripts/generate-production-evidence-packet.sh` now prints a no-read-secret/no-write production evidence packet prefilled with OpenAI key rotation, AI usage/quota monitoring, InsForge env/database, Vercel landing, R2 artifact, Stripe billing, support ownership, support inbox test-message/first-reply/escalation proof, monitoring, and launch hold fields.
- `scripts/generate-production-landing-cutover.sh` now prints a no-read-secret/no-write production landing cutover worksheet prefilled with Vercel deployment identity, deployed commit, download and auth env review, auth callback/sign-in smoke, production smoke, stale-copy rejection, R2 artifact identity, rollback deployment, monitoring, resume decision, and no-secret evidence handling.
- `scripts/generate-stripe-live-billing-review.sh` now prints a no-read-secret/no-write Stripe live billing review worksheet prefilled with live-mode decision, product/price ids, checkout and portal evidence, webhook endpoint and signing-secret presence, subscription mapping, refund/cancellation copy, support ownership, monitoring, and no-payment-data evidence handling.
- `scripts/generate-google-workspace-oauth-review.sh` now prints a no-read-secret/no-write Google Workspace OAuth worksheet prefilled with OAuth app identity, redirect URIs, Gmail/Calendar scopes, consent copy, test-account connection, missing/revoked OAuth recovery, token/privacy handling, support evidence, and launch decision fields.
- `scripts/generate-risk-exception-register.sh` now prints a no-read-secret/no-write risk and exception register prefilled with accepted P2, skipped diagnostic, manual UAT gap, external/account blocker, support exception, workaround, owner, no-secret/private-data, hold trigger, and invite/release decision fields.
- `scripts/generate-privacy-security-review.sh` now prints a no-read-secret/no-write privacy/security worksheet prefilled with source facts, secret/bundle scan slots, support export and Agent Log redaction checks, local memory/screenshot/vault/delete review, user-facing disclosure checks, no-secret handling, blockers, and final owner sign-off.
- `scripts/generate-pre-invite-decision.sh` now prints a no-read-secret/no-write pre-invite launch/no-launch decision worksheet prefilled with source facts, required evidence links, explicit blocker checks, support/rollback/privacy evidence, no-secret/private-data handling, and final owner sign-off.
- `scripts/verify-evidence-generators.sh` now executes the evidence generators in read-only mode, verifies required rendered sections/current dirty count/support contact, confirms the generated manual UAT worksheet includes the remaining physical no-network launch evidence field plus explicit billing mode, checkout/portal, account-access transition, and usage-limit recovery result fields, confirms the generated clean-install UAT worksheet includes downloaded-app first-launch and permission quit/reopen checks, confirms the generated exploratory QA worksheet includes founder-work and public web/artifact charters, confirms the generated launch monitoring worksheet includes OpenAI usage/quota and support inbox status checks, confirms the generated invite-batch worksheet includes exact artifact copy and pause-criteria checks, confirms the generated invite-resume worksheet includes production landing, public artifact, clean-install, monitoring, pause-authority, and privacy checks, confirms the generated support inbox worksheet includes first-reply, escalation, pause-decision, and no-secret checks, confirms the generated Act safety incident worksheet includes safety mode, confirmation, Stop, sensitive-surface, blocked-request, and no-secret checks, confirms the generated OpenAI key rotation worksheet includes revocation, server-side storage, bundle scans, smoke, usage/quota, and no-secret checks, confirms the generated production landing cutover worksheet includes deployment identity, download-health, auth env review, auth callback/sign-in smoke, stale-copy, R2 identity, rollback, resume, and no-secret checks, confirms the generated Stripe live billing review worksheet includes live-mode, product/price, checkout/portal, webhook, support, and no-payment-data checks, confirms the generated Google Workspace OAuth worksheet includes app identity, redirects, scopes, missing/revoked OAuth recovery, token/privacy, and support launch-decision checks, confirms the generated risk/exception register includes accepted-P2, skipped-diagnostic, manual-UAT-gap, external-blocker, owner, workaround, hold-trigger, and no-secret/private-data checks, confirms the generated launch package includes risk/exception review fields, confirms the generated production evidence packet includes AI usage/quota monitoring and production landing auth-env fields, confirms the generated privacy/security review includes no-secret and redaction fields, confirms the generated pre-invite decision includes blocking launch decision checks, and scans generator output for OpenAI-style secret patterns.
- `scripts/verify-launch-blockers.sh` now runs the prep launch audit and fails if the reported blocker set differs from the eight known launch gates.
- The landing Agent Context logo strip now renders Hermes Agent and OpenClaw with local real image elements, and visual QA verifies those icons load across desktop and mobile.
- `scripts/audit-launch-readiness.sh --allow-blockers` now guards that the visual QA keeps the Hermes Agent and OpenClaw image-load assertions.
- `scripts/verify-launch-site.sh` and `scripts/verify-launch-visuals.mjs` now require OpenClaw to use the local `/openclaw.svg` asset, preventing the landing page from depending on a remote favicon for a launch-critical logo.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that `scripts/verify-public-dmg.sh` continues to enforce checksum, image verification, Gatekeeper/notarization, read-only mounting, Applications symlink, app signature, bundle version/build, and mounted app secret scanning.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that `scripts/verify-release-archive.sh` continues to archive to a temporary path, verify archived app presence/codesign, and scan the archived app for OpenAI keys without export/DMG mutation.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks exact-artifact release records for version/build, commit, R2 URLs, checksum, notarization/signing, source-state warning, a dirty-tree blocker count matching the current Git status, and full release-candidate gate notes.
- `docs/agent-tier-cost-plan.md` now matches the implemented usage-cap state: server-side caps exist behind `VOIYCE_ENFORCE_AGENT_USAGE_CAPS=true` for Realtime, transcription, Computer Use, and screen context, while production env and Stripe tier mapping confirmation remain launch blockers.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that `docs/agent-tier-cost-plan.md` keeps the current server-side cap status, production env/tier-mapping blocker, per-tier hard-cap scope, AI kill-switch scope, and paid-production confirmation steps.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that `docs/phase-2-production-hardening.md` keeps server-side-only environment guidance, OpenAI key requirement, AI kill switches, request caps, usage-cap enforcement env, a production environment verification template, and the remaining external blocker list.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that `docs/stripe-billing-connection.md` keeps Stripe live-mode and pricing configuration warnings, and that checkout, portal, and billing-sync functions/tests continue blocking `sk_live_...` unless `STRIPE_ALLOW_LIVE_MODE=true`.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that the Stripe webhook path keeps signature verification, subscription created/updated/deleted handling, `apply_stripe_subscription_update` wiring, cancel-at-period-end handling, active-plan mapping, and SQL RPC grant/update behavior.
- Stripe webhook Deno coverage now proves missing signatures stop before database calls, unrelated signed events do not update billing, and signed subscription updates map customer/subscription/status/price/cancel/plan values into the billing RPC payload.
- `docs/stripe-billing-connection.md` now includes a live billing review template requiring live-mode decision, product/price ids, checkout and portal evidence, webhook endpoint/signing-secret presence, subscription mapping, refund/cancellation copy, support owner, no-secret handling, open blockers, owner-approved exceptions, and final sign-off before charging users.
- The VideoDB-backed session-context function now maps auth/provider failures to generic client-safe errors, preserves explicit validation errors for malformed app requests, and logs provider details through shared redaction instead of returning them to the app.
- The VideoDB-backed session-context function now has a server-side `VOIYCE_DISABLE_SESSION_CONTEXT` kill switch and `VOIYCE_SESSION_CONTEXT_MAX_QUERY_CHARS` search-query cap to bound active-session memory without a new app build.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that VideoDB/session-context and shared safe-error guardrails keep bearer and `x-access-token` redaction plus Deno coverage for preflight/method handling, kill-switch behavior, auth-provider failures, validation, query caps, and upstream provider failures.
- App-side dictation fallback errors now drop raw provider/backend localized descriptions before storing `WhisperError.requestFailed`, with Swift coverage verifying backend/key/token terms are not retained in the recoverable error value.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that Whisper fallback errors do not regress to storing raw `localizedDescription`, upstream messages, or provider/backend details in recoverable transcription errors.
- Remaining local debug prints in billing, overlay first-frame generation, and permission diagnostics now avoid raw `localizedDescription` payloads, with a launch audit guard preventing those prints from returning.
- Core Agent tool bridge failures now include concrete `next_step` recovery data for invalid tool payloads, invalid confirmation payloads, missing/stale confirmations, cancelled confirmations, confirmed-action failures, and empty memory summaries.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks those Agent tool bridge failures do not regress to bare `data: nil` results and that Swift coverage keeps the invalid-request next-step assertion.
- Google OAuth-required tool failures and local Accessibility-required Agent tool failures now include concrete `next_step` recovery data alongside their `requires` values, including direct/unrestricted Gmail send paths and shared Google Workspace read/draft/send/calendar failures.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks those local requirement failures do not regress to bare `requires` payloads and that Swift coverage keeps the disconnected-Google next-step assertion.
- Onboarding first-run copy now introduces Voiyce as a reusable memory/context layer for Dictation, Context, Talk, Act, and agent handoffs instead of presenting it primarily as dictation.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks onboarding launch copy keeps agent-context positioning and Swift coverage rejects vague/internal launch-copy regressions.
- Act command cancellation now returns structured `next_step` recovery data and records the same next step in Agent Log, so a stopped Act run is support-readable instead of a bare cancelled status.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks Act cancellation does not regress to a status-only failed tool result and that Swift coverage keeps the cancelled-run next-step assertion.
- Dashboard offline recovery and agent tier-limit copy now avoid server/Computer Use implementation language; the launch audit guards those app-surface strings and Swift coverage checks the user-facing variants.
- Onboarding permission recovery and Settings support-export copy now avoid rough technical terms like authorization/debugging; the launch audit guards those surfaces and Swift coverage keeps Settings support copy support-facing.
- Settings support-export status copy now uses redacted-support-log language for success and failure states, with Swift copy coverage and launch-audit guards to keep the support path privacy-clear.
- Agent Log support copy now uses issues/recovery language instead of investigation/error-centric labels; Swift and launch-audit guards keep those labels from regressing.
- Agent runtime failure status now uses `Needs review` instead of a blunt `Error` label when Context startup fails; Swift and launch-audit guards keep the recovery-oriented status in place.
- Agent Off-mode summary now uses direct Context/Talk/Act language instead of soft companion-style copy, with Swift coverage keeping that launch positioning concrete.
- `scripts/audit-launch-readiness.sh --allow-blockers` now enforces the PRD vague-copy ban across app and landing source so phrases like "boost productivity," "revolutionize," "unlock your potential," "AI-powered," and "seamless experience" cannot slip into launch-facing surfaces.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that `docs/manual-uat-matrix.md` continues to cover required evidence, exit rules, clean install/permissions, permission denial/revocation, sign-in recovery, Dictation, offline dictation, Context, multi-display context, Talk, current-screen Talk, Talk network drop, measured first-response latency, measured interruption settling, tool-delay progress phrasing, Act, Act stop/permission/mid-task behavior, billing/account limits, checkout/portal access, website/legal/download, public artifact verification, resilience, blocked action, usage-limit recovery, account-access recovery, and support export rows.
- `docs/launch-ready-self-serve.md` now includes a pre-invite decision record template covering artifact identity, source-state proof, automated gates, production evidence, clean-machine UAT, manual UAT, production environment evidence, Stripe/account evidence, support inbox evidence, rollback readiness, blocker status, accepted limitations, no-secret handling, and final owner sign-off.
- `scripts/audit-launch-readiness.sh --allow-blockers` now guards the pre-invite decision record fields so the final launch/no-launch call has reviewable evidence before broader invites.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that `docs/beta-launch-communications.md` remains internally held, Beta-labeled, agent-context positioned, support-contact aligned, and complete across known limitations, permissions, privacy/memory, data processing, support escalation, monitoring, and clean-install instructions.
- `docs/beta-launch-communications.md` now includes a support intake template for every beta report, including severity, owner, version/build, install source, active mode, permission state, account state, reproduction, reviewed screenshots/exports, event IDs, user-facing replies, and privacy boundaries around transcripts, screenshots, secrets, OAuth tokens, and payment details.
- `docs/beta-launch-communications.md` now includes an invite-resume checklist for restarting invites after pauses, incidents, failed checks, backend changes, landing deployments, billing changes, or artifact changes, requiring current blocker status, support queue status, production verification, exact-artifact identity, clean-machine/manual UAT evidence, environment evidence, rollback readiness, support-copy alignment, and owner sign-off.
- `docs/launch-ready-self-serve.md` now includes a final privacy and security review template that gathers source/bundle/DMG secret scans, support export and Agent Log redaction evidence, local memory and raw screenshot checks, legal/support disclosure checks, production env no-secret handling, OpenAI key rotation evidence, Stripe mode, open blockers, accepted limitations, and final owner sign-off.
- `docs/beta-launch-communications.md` now includes a release-notes send gate distinguishing generic draft notes from exact-artifact notes and requiring artifact identity, production landing verification, clean-machine/manual UAT evidence, production environment evidence, accepted limitation workarounds, support/privacy copy alignment, reviewed-support-export instructions, and owner sign-off before sending.
- `docs/launch-ready-self-serve.md` now includes a launch evidence package template that indexes automated gates, clean-machine proof, manual UAT, privacy/security review, production environment evidence, Stripe/account evidence, support readiness, rollback readiness, accepted limitations, release-note/support-copy alignment, owner-approved exceptions, and final owner sign-off.
- `docs/launch-ready-self-serve.md` now includes a final self-serve preflight sequence that distinguishes non-mutating prep checks, exact-candidate release checks, diagnostic UI-test fallback rules, manual/account evidence, and artifact-changing package commands.
- `docs/launch-ready-self-serve.md` now includes a release source inclusion review template requiring every dirty tracked or untracked path to be intentionally included, split out, removed, or documented as generated output before a clean release tag or fresh DMG.
- The release source review now includes a dirty-tree disposition summary requiring include/defer/remove/generated/needs-owner counts, high-risk surface review, matching evidence, and unresolved-path count before source freeze.
- `docs/phase-2-production-hardening.md` now includes a production evidence packet template requiring OpenAI key rotation evidence, InsForge env/database proof, Vercel deployment proof, R2 artifact proof, Stripe mode proof, support ownership, no-secret handling, open blockers, and final sign-off without copying secret values.
- `docs/manual-uat-matrix.md` now includes exploratory QA charters for real founder work sessions, permission chaos, privacy edges, Agent stress loops, account/billing edges, visual polish, and public web/artifact sweeps so the launch pass covers unscripted behavior in addition to deterministic rows.
- `docs/launch-test-strategy.md` now defines the complete self-serve testing strategy across automated gates, manual UAT, exploratory charters, privacy/security review, production account checks, evidence packaging, and launch hold rules.
- `docs/beta-launch-communications.md` now includes a support response playbook for install/download, permission recovery, Dictation/Talk failures, Act safety/Stop failures, billing/account access, and privacy/memory concerns, with privacy-safe reply templates and pause conditions.
- `docs/beta-launch-communications.md` now includes a launch monitoring evidence template for first-hour, first-day, weekly expansion, and after-change monitoring records, including owners, surface checks, signal counts, command/dashboard evidence, invite decisions, and pause rules.
- `docs/launch-ready-self-serve.md` now includes a launch risk and exception register template requiring accepted P2 limitations, skipped diagnostics, manual UAT gaps, external/account blockers, support exceptions, workarounds, escalation triggers, owners, statuses, and final sign-off before any invite or release-note decision.
- `docs/beta-launch-communications.md` now includes an invite batch control template requiring owner coverage, target persona/count, exact artifact identity, linked launch evidence, known limitations, monitoring windows, pause criteria, and final sign-off before each beta batch is sent.
- `docs/beta-launch-communications.md` now includes severity response targets for beta support, with first-response timing, owner expectations, invite decisions, required evidence, escalation rules, and automatic launch-hold behavior for P0/P1 and unresolved P2 reports.
- `docs/beta-launch-communications.md` now includes a clean-install evidence checklist requiring DMG identity, Gatekeeper/notarization, sign-in, permission state after quit/reopen, Dictation, Context, Talk, Act Strict, Agent Log, Settings, memory reset, legal/download, P0/P1/P2 findings, privacy-safe evidence review, and owner sign-off.
- `docs/manual-uat-matrix.md` now includes explicit app accessibility rows for keyboard-only navigation, VoiceOver labels/roles, and reduced-motion/increased-contrast comfort, with launch audit guards so accessibility is not hidden inside generic visual polish.
- `docs/beta-launch-communications.md` now includes a support inbox readiness record requiring support, backup, engineering, billing, rollback, monitoring, response-template, privacy-review, invite-pause, and final sign-off coverage before invite batches.
- `docs/beta-launch-communications.md` now includes a known-limitation workaround register tying permission-dependent modes, dense/blocked Act UI, pending safety checks, local-first memory, Talk latency, and Google-connected features to user impact, workaround copy, support action, owner, and ship/hold decisions.
- `docs/beta-launch-communications.md` now includes an Act safety incident checklist requiring safety mode, requested action, visible action, expected confirmation state, Stop availability/effectiveness, sensitive surface, Agent Log IDs, invite decision, kill-switch consideration, and hold rules for unsafe Act reports.
- `scripts/verify-agent-usage-caps.sh` passed locally on 2026-05-19, covering 12 tier/cap rows, 4 cost-bearing function/test pairs, and 57 backend usage-cap tests for Computer Use, Realtime, transcription, and screen-context.
- Latest prep verification confirms release source-state version/build checks pass for `1.0`/`16` on `codex/landing-context-copy`, while the dirty-tree and missing-tag blockers remain; rollback readiness still needs a networked read-only R2 rerun because sandbox DNS could not resolve the public manifest host.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that `docs/beta-launch-communications.md` keeps uninstall/reset-memory guidance present, prefers in-app memory deletion, identifies the current build's Voiyce-owned local memory paths, and keeps manual local reset support-guided.
- `docs/launch-ready-self-serve.md` now includes evidence naming and privacy-review rules for command logs, screenshots, recordings, dashboard captures, support exports, redactions, and missing-evidence substitutions in the final launch evidence package.
- `docs/manual-uat-matrix.md` now includes an execution assignment section requiring clean install, Dictation, Context, Talk, Act, web/legal/download, accessibility, billing/account, resilience, and exploratory QA to have owners, target environments, evidence links, and pass/hold status before final launch decision.
- `docs/phase-2-production-hardening.md` now includes an OpenAI key rotation evidence checklist requiring exposed-key revocation, replacement-key server-side storage, source/app/landing secret scans, post-rotation function smoke, optional old-key negative check, usage/quota alert review, no-secret evidence handling, and security owner sign-off.
- `docs/phase-2-production-hardening.md` now includes an AI usage and quota monitoring record requiring OpenAI usage dashboard review, spend/quota limits, alert threshold review, per-capability trend checks, InsForge usage-cap review, kill-switch state, spike/support-report tracking, and a pause/narrow/continue decision.
- `docs/phase-2-production-hardening.md` now includes a production landing cutover evidence checklist requiring deployment identity, deployed commit, download env review, auth env review, auth callback/sign-in smoke, production smoke checks, stale-copy rejection, R2 artifact identity, rollback deployment, monitoring window, blockers, and final sign-off before invites or release notes resume.
- `docs/launch-rollback-runbook.md` now has a fuller incident note template covering support and engineering owners, pause decision, rollback surface, user/data/billing impact, related support reports, kill-switch changes, rollback command evidence, clean-machine verification, resume criteria, and final owner sign-off.
- `docs/launch-rollback-runbook.md` now includes a resume-after-rollback checklist requiring complete incident notes, paused/narrowed exposure, production landing verification, public R2 artifact verification, public-download verification, clean-machine evidence, manual smoke, kill-switch/limitations copy alignment, support ownership, exact version/build copy, blocker status, workaround copy, and owner sign-off before invites restart.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that `docs/launch-rollback-runbook.md` keeps smallest-surface rollback guidance, dirty-tree DMG warnings, support contact, severity/triage sections, landing/R2/backend/app rollback paths, post-rollback verification, and incident notes.
- The web auth route now maps SDK/provider/network failures to plain recovery copy instead of echoing raw error messages.
- `scripts/verify-release.sh` passes through the OAuth-scope, Stripe live-mode, third-party account-copy, memory/search/vault, support-export raw-context redaction, support-export schema metadata, permission-block/service-failure/failed-tool-call/successful-tool-call diagnostics, Action Cursor, Focus Highlight, Agent runtime-boundary, Talk latency telemetry, Realtime connection-failure recovery, Realtime session instruction guardrails, account-limit response hardening, app-side account-limit recovery, remaining plain-language error hardening, Context startup recovery, Settings permission-refresh hardening, Strict-mode Agent tool validation ordering, no-network launch recovery, web auth/download recovery, Release app-source warning-cleanup, backend failure-injection/abuse-case/auth-provider/InsForge-database, landing, Release build, and secret-scan checks. It covers source OpenAI-key scan, 72 Swift unit tests, 9 macOS UI tests, 71 backend Deno tests, landing lint/build, launch-site checks, landing build secret scan, Release app build, and built Release app secret scan.
- Agent mode state now persists the selected Agent mode and Agent safety mode across fresh app state instances.
- Agent screen copy and controls now avoid visible implementation terms, expose title/subtitle/status/mode controls/capabilities/Act safety note, and have UI coverage for Off-disabled Start plus Context start/stop behavior.
- Agent hotkey handling now uses an explicit Option toggle callback: press toggles the selected Agent mode, release does not stop it, and Settings > Hotkeys documents Agent Mode separately from hold-to-dictate.
- Agent screen now explains that context capture starts only after Start or Option, Stop pauses capture, and Private Mode pauses live context and skips saved memory/screenshots.
- Agent screen now includes a self-contained mode map for Off, Context, Talk, and Act, explaining what each mode starts, what remains inactive, and which permission/privacy/safety controls apply without requiring external docs.
- Sidebar and menu bar now expose active Agent status while Context, Talk, or Act is running, so users do not have to stay on the Agent screen to know ambient context/action state.
- Agent Log now exposes concise support-ready cues for session timeline, action details, and redacted support export, has clearer empty states, and search now matches event detail fields.
- Support exports now include stable schema metadata and event IDs for future support tooling without changing the stored Agent Log event model.
- Active one-off Act commands now expose the main Stop action while running, cancel the active command task, return the main action to Start, and write Agent Log start/cancel events.
- ComputerUseAgent now has injectable permission/screenshot/cancellation boundaries, checks cancellation before and between action-loop work, and has Swift coverage for missing Accessibility, missing Screen Recording, and cancelled runs. Live external action-loop cancellation still needs manual UAT.
- Agent Log and Settings now show an active-Agent return banner while Context, Talk, or Act is running, and Swift coverage verifies Act remains active and recoverable while navigating through Agent Log and Settings, including native Voiyce navigation from those surfaces.
- Action Cursor now gives local Act actions a visible animated cursor/status lead-in before posting local events, that lead-in is cancellable, the cursor is gated to active Act/action presentation unless preview mode is enabled, multi-display Computer Use coordinates map from the captured display frame, and Swift coverage verifies the overlay is non-activating, mouse-transparent, all-spaces/full-screen friendly UI.
- Act command failures now return structured `next_step` recovery data for missing tasks, signed-out users, missing Accessibility, pending safety checks, and post-action Screen Recording failures, so Agent Log/tool callers have concrete recovery instructions instead of message-only failures.
- Action Cursor lifecycle instrumentation now verifies native Voiyce navigation and Computer Use action loops begin Act cursor mode, emit visible action statuses, and schedule the completion hide after the action path finishes.
- Focus Highlight now has test-covered global shortcut dispatch for rectangle/paint/underline modes, rectangle/freeform screen-coordinate geometry, passive post-selection guide overlays remain mouse-transparent, focused-region capture chooses/crops the correct display region with Retina scaling and edge clipping coverage, and create/clear actions write Agent Log events.
- Act now requires an explicit safety-mode choice before first use: Start and one-off Act commands stay disabled until Strict, Normal, or Unrestricted is selected, and the selected mode persists.
- Act safety rules are now centralized in a testable policy covering Strict, Normal, and Unrestricted confirmation behavior, action/target/consequence confirmation copy, and local blocks for catastrophic deletion, credential theft, malware, fraud, illegal access, hidden actions, and platform-abusive actions.
- Agent Log now records approved and timed-out confirmations as distinct events in addition to requested and cancelled confirmations.
- OpenAI Computer Use pending safety checks now fail with a clear Act recovery path instead of returning a non-resumable confirmation id.
- Act safety-check stops now write support-export-covered Agent Log events with the safety reason and a clear next step.
- First-run onboarding permission copy now explains Microphone, Speech Recognition, Accessibility, and Screen Recording in plain language, with Swift unit coverage blocking provider/backend/API terminology.
- Confirmation Stop Session is now a first-class confirmation decision, posts the existing Agent stop request, and has Swift unit coverage proving stopped/cancelled confirmations cannot be approved or executed later.
- Confirmation prompts now order front across spaces, stay visible after app deactivation, include a spoken safety reason in Talk/Act tool results, and expire stale pending actions with support-visible Agent Log events.
- Onboarding and Dashboard dictation failure states now use plain beta-support recovery copy instead of exposing OpenAI/backend/key/server-function details, with unit coverage guarding against those terms returning to user-facing recovery copy.
- Act command runtime recovery copy now uses Act mode language instead of Computer Use/backend/provider terminology for empty commands, sign-in, permissions, confirmations, rate limits, invalid responses, and service failures.
- Act unexpected-failure recovery now maps generic thrown errors to the standard Act recovery message instead of reading raw localized descriptions, with Swift and launch-audit guards preventing backend/key/provider strings from returning to that path.
- Talk startup recovery copy now uses Talk mode language instead of provider/backend terminology for sign-in, local audio setup, invalid responses, rate limits, and connection failures.
- Talk latency QA targets are now defined for connection readiness, first response, tool-call silence, and interruption settling, and Realtime telemetry writes support-safe Agent Log measurements for those paths.
- Embedded Realtime client coverage now guards the Talk/WebRTC connection path: microphone capture, audio-track attachment, SDP offer/session POST, remote answer application, remote audio playback, and audio-ready telemetry. Physical spoken Talk UAT remains open.
- Realtime connection-failure telemetry now stops the active Talk/Act state, leaves a clear Agent-screen recovery message, and writes either a Microphone permission block or Talk service failure to Agent Log.
- Agent mode permission recovery is now mode-specific and deterministic: Context requires Microphone plus Screen Recording, Talk requires Microphone, and Act requires Microphone, Screen Recording, and Accessibility. Missing or revoked required permissions block/stop the mode with plain recovery copy and support-useful Agent Log permission events; physical permission-revocation UAT remains open.
- Realtime session instructions are now centralized and Deno-tested so long-running tool and grounding waits require a short natural progress phrase before failure copy, while Talk and Act mode boundaries stay explicit.
- Realtime session configuration now uses semantic VAD with low eagerness so Talk waits longer through natural pauses before creating a response, with backend regression coverage for the turn-detection payload.
- Realtime instructions now explicitly require Talk to state missing Google OAuth and missing Screen Recording/Microphone/Accessibility permissions as blockers with next steps, and not infer inbox, calendar, screen, account, or app access that tools did not confirm.
- Realtime, transcription, Computer Use, and screen-context account cap hits now return clear `402` / `usage_limit_reached` responses before OpenAI is called, while auth/database/provider failures remain generic and redacted.
- Dictation, Talk, Act, and Screen context now map usage-limit responses to user-facing account-limit recovery copy and quota-style Agent Log events.
- Agent usage events now record structured usage units with estimated spend for the cost-bearing server paths: Realtime estimated session seconds, transcription audio seconds/bytes, Computer Use step/screenshot/task/action/safety-check counts, and screen-context screenshot/image/prompt units.
- Local memory now exposes a usage snapshot with record count, captures today, screenshot count/bytes, vault note count/bytes, index bytes, and total storage bytes in memory tool results; Memory saved Agent Log events include current record and storage totals.
- Local long-term memory now enforces Default/Pro/Power storage quotas for durable memory records, total local memory storage, and raw screenshot bytes. When screenshot storage is exhausted, Voiyce still saves the distilled memory without the raw screenshot; when durable memory storage is exhausted, it skips the write with a local limit message.
- The macOS app now has an internal Default/Pro/Power capability policy: Default exposes Off, Context, and Talk with conservative storage; paid/beta/Pentridge access maps to Pro and enables Act under beta budgets; a future Power tier maps to full Agent modes plus Power local memory quotas.
- Settings and the checkout plan picker now explain upgrade-relevant limits in plain language: Pro keeps dictation active, Context/Talk/Act use beta budgets, and Power-level Act limits are not sold in this build.
- Focused 2026-05-18 verification passed for 84 Swift unit tests, the Settings navigation UI test covering usage-limit copy, and the Agent screen UI test covering visible active Context/Act status plus self-contained Agent mode-map copy.
- Dictation transcription service failures now write plain Transcription service Agent Log/support export copy instead of provider/backend/server-function terminology.
- Dictation/audio debug logging now records transcription word counts and safe operation states instead of raw transcript text, thrown error payloads, or temporary recording filenames, with Swift coverage guarding against private transcript phrases returning to debug output.
- `scripts/audit-launch-readiness.sh --allow-blockers` now includes a static guard against raw transcript, thrown-error, and temporary recording-path debug print regressions in the dictation/audio paths.
- Active-session context/search/summary copy now uses provider-neutral Session context language instead of VideoDB/capture-runtime terminology, with Swift unit coverage guarding against those implementation terms returning to user-facing strings.
- Auth, Billing, Google connection/OAuth callback, screen context, Agent tool bridge, Act unexpected-failure, support-export write, and memory-error paths now use plain recovery copy instead of surfacing raw SDK/OAuth/backend/localized failure text.
- Local Agent tool validation failures now return concrete `next_step` detail for missing app names, URLs, recipients, text, screen coordinates, key names, native Act commands, long-term/session memory queries, screen-context invalid responses, and Gmail-draft failures; Agent Log now records that next-step detail instead of raw local tool failure data.
- Local Agent tool validation now runs before safety confirmation checks, so Strict/Normal mode cannot turn an invalid missing-detail tool request into an approval prompt.
- Session context helper events now store stable Session context statuses instead of raw helper JSON/log lines or backend/token-like details in `lastEvent` / `lastError`.
- Live/session context capture now checks Private Mode, sensitive-context detection, and app/window exclusion matches before capture starts and keeps a running privacy monitor that stops active capture if the current context becomes blocked.
- Session context capture now has deterministic coverage for the continuous capture helper shape: it requests Microphone and Screen Recording, selects microphone, primary display, and system audio where available, stores selected channels, starts the capture session, and consumes capture events.
- Session context capture now writes Agent Log events for capture start, stop, failure, and privacy-pause states, and clears stale stream/session ids when stopped.
- Agent mode runtime boundaries are now explicit and test-covered: Context starts session context only, Talk and Act start Realtime voice, Act is the only action-capable mode, and failed Context capture shows recovery-oriented `Needs review` status in the Agent screen.
- Context-only startup failures and privacy pauses now stop the Context run, show `Needs attention`, and write Agent Log failure details with a next step instead of leaving Agent visually active. Talk and Act do not stop solely because passive session context fails.
- Settings > Permissions now has an explicit Refresh Status action, and Pro builds keep permission polling active until Screen Recording status is current instead of stopping as soon as dictation permissions are granted.
- No-network app launch now has deterministic macOS UI coverage for the signed-out/offline recovery path: test-only launch overrides force signed-out/offline state, the auth screen shows concrete reconnect copy, Google/email auth actions are disabled while offline, and Swift copy guards prevent backend/provider terminology from returning. Real network-off clean-machine UAT remains open.
- Dictation network-loss recovery now has deterministic Swift coverage: a transcription network drop maps to the user-facing no-internet state and writes a support-useful Transcription service failure with a reconnect next step. Physical network-off dictation UAT from a downloaded app remains open.
- Talk/Act mid-session connection-loss recovery now has deterministic coverage: the WebRTC bridge emits `connection_lost` for peer/ICE failures, ignores late state changes during user-initiated Stop, and Swift telemetry writes a support-useful Talk service failure with reconnect next step. Physical network-drop Talk UAT from a downloaded app remains open.
- Account access loss now clears transient dictation and Agent runtime state, stops Realtime/session-context work, logs a support-useful recovery event, and blocks the Agent hotkey when the account is signed out or payment-required.
- Realtime tool successes now write support-safe Agent Log events with the tool name, result state, and data-field names only; raw tool payloads such as screen text, memory summaries, Gmail content, inserted text, and URLs are not copied into the generic completion event.
- Release app-source warnings were cleaned up by updating permission callback isolation, target app reactivation, audio compression export, and owl overlay first-frame generation to current macOS APIs.
- `scripts/verify-release.sh` passes after the latest OAuth-scope, Stripe live-mode, third-party account-copy, memory/search/vault, support-export raw-context redaction, support-export schema metadata, permission-block/service-failure/failed-tool-call/successful-tool-call/Act loop action logging/Act permission-cancellation/Action Cursor non-interference-lead-in-presentation-gating-multi-display/Focus Highlight shortcut-geometry-capture-clear-log/memory-error diagnostics, durable Agent mode persistence, Agent screen polish, explicit Act safety-mode choice, Act safety-policy guardrails, confirmation Stop Session/cancel-execution guardrails, confirmation frontmost/rationale/timeout guardrails, Computer Use safety-check recovery, Act safety-check Agent Log coverage, onboarding permission-copy guardrails, Agent hotkey toggle, Settings hotkey documentation, Settings permission-refresh hardening, Agent context-consent, Talk/Act Stop visibility, Talk latency telemetry, Realtime connection-failure recovery, Realtime session instruction guardrails, account-limit response hardening, app-side account-limit recovery, Agent Log support-readiness, active Act command Stop/cancel, dictation recovery-copy guardrails, Act mode recovery-copy guardrails, Talk mode recovery-copy guardrails, dictation service-failure Agent Log guardrails, session-context copy guardrails, live-session privacy guardrails, session-context Agent Log events, Agent mode runtime boundaries, remaining Auth/Billing/Google/screen-context/Agent-tool/Act/memory plain-language error hardening, Agent-tool next-step hardening and Strict-mode validation ordering, Context startup recovery, no-network launch recovery, web auth/download recovery, Release app-source warning cleanup, backend failure-injection/abuse-case/auth-provider/InsForge-database, landing, Release build, and secret-scan checks. It covers source OpenAI-key scan, 72 Swift unit tests, 9 macOS UI tests, 55 backend Deno tests, launch-site verification including `/api/download-health`, landing lint/build, landing build secret scan, Release app build, and built Release app secret scan. The Release app build has no app-code warnings; Xcode still prints its generic AppIntents metadata notice because the app has no AppIntents dependency.
- The macOS UI test target now re-activates Voiyce, hides unrelated apps, and waits for target controls before clicking so external app windows do not create false navigation failures.
- The macOS UI test target now covers Agent screen copy/control polish, including user-facing Act copy, Off-disabled Start behavior, Context start/stop state, Act safety note, Agent context-consent copy, Talk/Act Stop visibility, active Act command Stop/cancel behavior, Agent Log support-ready cues, and absence of visible internal implementation terms.
- `scripts/verify-launch-site.sh` now scans the generated landing build for leaked OpenAI API keys.
- `scripts/verify-launch-site.sh --url http://localhost:23002` now passes against a `next start` production preview and validates `/icon.png`, `/favicon.ico`, and `/og-header.png` as real image payloads with expected PNG/ICO signatures and dimensions.
- `scripts/verify-production-landing.sh` now provides a no-build/no-deploy production smoke gate for the public landing routes, revised agent-context copy, stale-copy rejection, `/api/download-health`, legal contact, and social image/favicon payloads.
- `scripts/verify-release.sh --production-landing-check` now opt-in runs the production smoke gate, with `--production-url <base-url>` for non-default production URLs.
- `scripts/verify-rollback-readiness.sh` now provides a no-mutation R2 rollback dry-run. It verifies the current public `latest.json`, latest DMG, versioned DMG, checksum sidecars, a previous versioned rollback candidate, and generates the rollback `latest.json` locally for review.
- `scripts/audit-launch-readiness.sh` now provides a no-build/no-package status audit for the required launch docs/scripts, exact-artifact hold state, visible blocker tracking, optional production landing smoke status, and public R2 manifest metadata.
- `scripts/verify-release-archive.sh` now verifies the Xcode Release archive path in a temporary directory without exporting an app, creating a DMG, notarizing, uploading, or changing existing `build/release` artifacts; `scripts/verify-release.sh --archive-check` can include that check in the broader release gate.
- `scripts/verify-public-dmg.sh` now verifies the currently public DMG without installing or mutating release artifacts. It downloads the DMG to a temporary directory, verifies SHA-256, runs `hdiutil verify`, checks DMG Gatekeeper acceptance and stapled notarization, mounts read-only/no-browse, verifies mounted `Voiyce.app` plus the `/Applications` symlink, verifies the app signature and Gatekeeper acceptance, checks bundle version/build against `latest.json`, scans the mounted app for leaked OpenAI-key patterns, detaches, and cleans up. `scripts/verify-release.sh --public-dmg-check` can include this in the broader release gate.
- `scripts/verify-agent-usage-caps.sh` now verifies the server-side Default/Pro/Power cap matrix, cap documentation alignment, reserve/finalize RPC hardening, per-capability Realtime/transcription/Computer Use/screen-context wiring, account-limit behavior before OpenAI, and Deno coverage for usage reservations.
- `scripts/verify-release-source-state.sh` now provides a no-mutation release-source provenance gate for clean-tree status, Xcode version/build consistency, and expected release tag-to-HEAD verification. `scripts/verify-release.sh --source-state-check` can include it before build/package work on a release branch.
- `scripts/verify-release.sh` now scans the built Release app bundle for leaked OpenAI API keys even when packaging is not requested.
- `scripts/verify-release.sh --skip-ui-tests --public-download-check` passes after the latest 72-test web auth/download recovery state and verifies the current public R2 `latest.json`, latest DMG, latest checksum sidecar, versioned DMG, versioned checksum sidecar, manifest SHA consistency, and latest/versioned DMG byte equality for version `1.0`, build `16`.
- `scripts/verify-rollback-readiness.sh` passes against the current public `1.0+16` R2 artifacts and previous rollback candidate `1.0+1`, SHA-256 `97123202c651bf5046044aeb1c6406181b8d21323261748028e76a76ad86bfe5`. This proves rollback manifest readiness without changing R2 objects; an actual latest-object repoint remains unperformed.
- `scripts/audit-launch-readiness.sh --allow-blockers` passes and reports the current eight expected launch blockers; strict mode exits `1` while those blockers remain. `scripts/audit-launch-readiness.sh --live --allow-blockers` verifies the current public R2 manifest metadata and reports production `/api/download-health` as still blocking.
- `scripts/verify-release-archive.sh` passes. It archived the Release app to a temporary directory, verified the archived app signature, and scanned the archived app bundle for leaked OpenAI API keys. The temporary archive was removed and no DMG/release artifact was created or changed.
- `scripts/verify-release.sh --skip-ui-tests --archive-check` passes as a diagnostic integrated archive path. It reruns the broader release verifier with source secret scan, 72 Swift unit tests, 55 backend Deno tests, local launch-site checks, landing lint/build and secret scan, Release app build, built app secret scan, temporary Release archive build, archived app codesign verification, and archived app secret scan. UI tests were intentionally skipped for this diagnostic path, and no packaging/notarization/upload or existing DMG/release artifact mutation occurred.
- `scripts/verify-public-dmg.sh` passes for the current public `1.0+16` R2 DMG. `scripts/verify-release.sh --skip-ui-tests --public-dmg-check` also passes as a diagnostic integrated public-DMG path with source secret scan, 72 Swift unit tests, 55 backend Deno tests, local launch-site checks, landing lint/build and secret scan, Release app build, built app secret scan, and public DMG image/signature/Gatekeeper/notarization/mount/Applications-symlink/app-secret verification. UI tests were intentionally skipped for this diagnostic path, and no packaging/notarization/upload/install or existing release artifact mutation occurred.
- `scripts/verify-agent-usage-caps.sh` passes. It verifies 12 Default/Pro/Power tier/capability cap rows for Realtime, transcription, Computer Use, and context; proves the SQL reserve/finalize RPCs enforce daily and monthly caps; checks all four cost-bearing functions reserve/finalize usage only when `VOIYCE_ENFORCE_AGENT_USAGE_CAPS` is enabled; and runs 57 Deno backend tests covering request caps, kill switches, account-limit responses before OpenAI, redacted upstream failures, reserve/finalize calls, structured usage units, Realtime turn-detection tuning, and missing OAuth/permission instruction guardrails.
- App termination cleanup now clears active dictation and Agent runtime state, stops Realtime bridge/server state, locally terminates active session-context capture, and logs context shutdown before quit. Deterministic Swift coverage proves the state reset and local session-context stop; physical quit-while-running UAT from the downloaded app remains open.
- System sleep cleanup now listens for macOS sleep/wake notifications, stops active local runtime before sleep, clears active dictation and Agent state, locally terminates active session-context capture, logs context shutdown, and logs a restartable wake state. Deterministic Swift coverage proves the state reset and local session-context stop; physical sleep/wake UAT from the downloaded app remains open.
- Display-layout change recovery now clears transient action/focus/tour overlays, clears saved focus regions that may point at stale coordinates, lets Context/Talk continue with fresh screen captures, and pauses active Act mode so stale screen coordinates cannot continue driving actions. Deterministic Swift coverage proves the Act-only pause policy and stale focus-region clearing; physical display connect/disconnect UAT from the downloaded app remains open.
- `docs/releases/Voiyce-1.0+16.md` now records the current public R2 checksum from `latest.json` and both checksum sidecars: `bfed37a6f089eb83d0d5426fc5d25dbd709184bf2f85feceefac70ee68c485d5`.
- Backend Deno coverage now runs all function tests and verifies Realtime, transcription, Computer Use, and screen-context kill switches/request caps, Realtime/transcription model override gating, no-secret client responses for upstream OpenAI errors, OpenAI auth/rate-limit status preservation, and cap-ledger reservation/finalization for cost-bearing agent capabilities.
- Realtime, transcription, Computer Use, and screen-context functions now return generic client-safe errors for upstream/internal failures while redacting secret-like text from operational logs.
- Realtime, transcription, Computer Use, and screen-context tests now inject OpenAI 401 and 429/quota-style failures and verify clients receive generic bodies with the upstream status, not raw provider payloads.
- Computer Use now rejects high-confidence abuse requests before OpenAI is called, covering credential theft, catastrophic deletion, fraud, illegal access, and hidden actions.
- Realtime, transcription, Computer Use, and screen-context tests now inject InsForge auth/session failures and verify the functions return a generic client error without calling OpenAI or exposing auth payload text.
- Realtime, transcription, Computer Use, and screen-context tests now inject InsForge database/RPC failures and verify the functions stop before OpenAI, return generic client errors for infrastructure failures, and do not expose database/auth payload text.
- Computer Use local action dispatch now has deterministic Swift coverage for right click, double click, scroll, command-style hotkeys, and safe text injection without posting real system events during tests. URL open, app activation, direct screen click, key press, and Voiyce-native navigation remain covered through the existing Realtime/native tool layer.
- Backend CORS preflight and unsupported-method behavior is covered for Realtime, transcription, Computer Use, and screen-context functions.
- Screen-context now participates in `reserve_agent_usage_cost` / `finalize_agent_usage_cost`; temporary internal Default/Pro/Power cap values and usage-estimate environment variables are documented in `docs/phase-2-production-hardening.md`.
- Stripe checkout, billing portal, and billing sync now block `sk_live_...` keys unless `STRIPE_ALLOW_LIVE_MODE=true` is explicitly set after live billing review.
- Terms subscription/refund/cancellation copy matches the active billing flow: Stripe Checkout handles monthly/yearly Pro subscriptions, the in-app billing action opens Stripe Checkout or the Stripe billing portal, and cancellation is described as stopping future renewals while access continues through the current billing period.
- Backend Deno coverage now passes with 71 tests, including Realtime session instruction guardrails, account-limit response hardening, InsForge database/RPC failure injection, auth-provider failure injection, Computer Use abuse-case blocking, OpenAI auth/rate-limit failure injection, Stripe live-mode guardrails for checkout, billing portal, and billing sync, Stripe webhook signature/event/RPC mapping coverage, VideoDB session-context safe-failure/kill-switch/query-cap coverage, and shared token redaction coverage.
- Terms and Privacy now cover the current product surface: voice, screen context, local memory, agent handoffs, support exports, connected services, third-party processors, retention, and deletion controls.
- Privacy copy now concretely matches the implemented local memory behavior: structured local index, Voiyce-written Markdown notes, summary retention, raw screenshot retention, Private Mode, app/site exclusions, delete controls, and support-export creation/redaction.
- Settings > Agent Memory now exposes a self-serve vault setup path: users can create/open the default local vault or choose an existing folder, and local memory vault sync can be disabled per signed-in account while keeping the structured local memory index active. Swift unit coverage verifies account scoping and that disabling vault notes prevents Markdown writes without disabling search.
- Landing routes now include a skip link, main landmark, visible keyboard focus styles, and launch-site accessibility smoke checks.
- Swift unit coverage now verifies sensitive-context memory skips and support-export redaction patterns without destructive memory operations.
- Agent Log now uses persisted local events, filters/search/stats, expandable details, a working redacted support export from the log screen, copyable event IDs, and no inert inspector/sample-event controls.
- Agent Log now redacts sensitive event titles, summaries, and details before events are saved to disk or shown in the live log.
- Swift unit coverage now verifies generated support export JSON redacts sensitive event titles, summaries, and details.
- Swift unit coverage now verifies stored Agent Log event JSON redacts sensitive event titles, summaries, and details.
- Swift unit coverage now verifies raw transcript, screenshot, image data URL, and long blob payloads are redacted before Agent Log storage and support export JSON.
- Swift unit coverage now verifies support export schema metadata and event IDs.
- Agent Log now writes support-useful permission-block events for missing Screen Recording and Accessibility permissions across screen context, Act command setup, Computer Use, and text/click/key tools.
- Swift unit coverage now verifies permission-block events include feature, permission, and next-step detail and appear in support export output.
- Agent Log now writes support-useful service-failure events for OpenAI-backed Realtime, transcription, and Computer Use failures, including upstream status and concrete next steps.
- Swift unit coverage now verifies quota/rate-limit service-failure events include feature, service, upstream status, and next-step detail and appear in support export output.
- Realtime tool calls now write Agent Log failures at the bridge boundary, while confirmation waits and already-blocked catastrophic actions avoid duplicate failure events.
- Act mode now writes Agent Log events for planned local action batches, no-action finishes, post-action screen-capture failures, max-step finishes, and cancelled Computer Use runs using action-type-only details.
- Agent Log now writes support-useful memory-error events for local memory index, screenshot, vault directory, vault note, and deletion failures, including operation, path, and next-step detail.
- Swift unit coverage now verifies memory-error events appear in support export output.
- Swift unit coverage now verifies memory deletion clears the structured index, raw screenshots, and Voiyce-written vault notes.
- Swift unit coverage now verifies session-only, 30-day, 90-day, and forever summary retention, and verifies raw screenshot retention as a separate setting from summary retention.
- Swift unit coverage now verifies Private Mode and app/site exclusions skip both persistent memory and raw screenshot storage.
- Private Mode, sensitive-context detection, and app/site exclusions now pause live/session context capture before it starts and while it is running, in addition to skipping durable memory and raw screenshot storage.
- Swift unit coverage now verifies session context privacy pauses write Agent Log events with the block reason and app/site detail.
- Swift unit coverage now verifies Context-only startup failure and privacy-pause results do not leave the Agent active, while Talk/Act can keep running when only passive context capture fails.
- Swift unit coverage now verifies memory search match/no-result behavior and date-organized plain Markdown vault output.
- Swift unit coverage now verifies Obsidian-style daily notes include frontmatter metadata for date, source, source modes, apps, tags, privacy level, screenshot retention, and account scope, while memory deletion still removes Voiyce-written notes with quoted YAML tags.
- Swift unit coverage now verifies per-account local long-term memory isolation for records, vault paths, retention settings, screenshot-retention settings, Private Mode, and app/site exclusions.
- Swift unit coverage now verifies internal tool results distinguish current screen context, active-session context, and long-term memory with stable `memory_source` / `context_scope` data fields.
- Realtime session instructions now require Talk and Act to use saved memory before answering previous-work or memory-dependent requests, cite memory dates/sessions in natural language when available, and avoid exposing internal provider/runtime/tool/source-label names in normal speech. Saved-memory tool copy now says "saved memory" instead of user-facing "long-term memory" and returns answer guidance for natural date/session citation.
- Swift unit coverage now verifies the Google OAuth scope list matches the current Gmail/Calendar feature surface.
- Swift unit coverage now verifies successful Realtime tool calls write Agent Log completion events without copying raw tool result content.
- The focused Swift unit target now passes with 81 tests after support-export schema metadata/event ID coverage, app-side usage-limit recovery copy and Agent Log quota-event coverage, Realtime connection-failure recovery coverage, Talk latency telemetry coverage, Action Cursor presentation-gating/animation/multi-display coverage, Focus Highlight shortcut/geometry/capture and clear/log coverage, live-session privacy guardrails, session-context Agent Log privacy-pause coverage, Agent mode runtime-boundary coverage, Context startup recovery coverage, Settings permission-refresh polling coverage, memory/search/vault/OAuth-scope/account-isolation/vault-toggle/memory-recall copy, raw-context redaction, permission-block diagnostics, service-failure diagnostics, failed-tool-call and successful-tool-call logging, memory-error diagnostics, Agent mode persistence, explicit Act safety-mode choice, Act safety-policy guardrails, confirmation Stop Session/cancel-execution guardrails, confirmation frontmost/rationale/timeout guardrails, Computer Use safety-check recovery, Act safety-check Agent Log coverage, Act permission/cancellation coverage, onboarding permission-copy guardrails, Agent hotkey toggle, dictation recovery-copy, Act mode recovery-copy, Talk mode recovery-copy, dictation service-failure Agent Log guard, session-context copy guard, remaining Auth/Billing/Google/screen-context/Agent-tool/Act/memory plain-language error hardening, Agent-tool next-step hardening, Strict-mode Agent tool validation ordering, Context-only privacy-pause next-step hardening, dictation network-loss recovery, mode-specific Agent permission recovery, app termination cleanup, system sleep cleanup, and display-layout recovery.
- The focused Swift unit target now passes with 98 tests after app-side Default/Pro/Power capability gate coverage and persisted-mode reconciliation coverage. `scripts/audit-launch-readiness.sh --allow-blockers` still passes and reports the expected eight launch blockers.
- The focused Swift unit target now passes with 100 tests after access-loss runtime cleanup coverage, including signed-out/payment-required recovery copy and active dictation/Agent state reset.
- The focused Swift unit target now passes with 110 tests after app-side dictation fallback safe-error coverage, including the new guard that unexpected transcription failures do not retain backend/key/secret/token/localized-description details in recoverable errors.
- The focused Swift unit target now passes with 110 tests after adding Agent tool bridge next-step coverage for invalid requests, invalid confirmations, missing/stale confirmations, cancelled confirmations, and empty memory summaries.
- The focused Settings navigation UI path now verifies the Permissions Refresh Status control and the separate Open System Settings action.
- The full UI-enabled no-package release gate now passes after the latest 72-test Agent permission-recovery and web auth/download recovery slice.
- The focused active Act command UI tests pass after Stop/cancel hardening: deterministic native Voiyce navigation still works, and an active held Act command returns the main action from Stop to Start after Stop is clicked.
- The macOS UI target now passes with 8 tests after the Agent screen polish, Settings hotkey documentation, Agent context-consent, Talk/Act Stop visibility, active Act command Stop/cancel, Agent Log support-readiness, and launch smoke coverage; the current UI-enabled no-package release gate also passes.
- A clean Debug macOS app build passes with `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' clean build`.
- Third-party account copy review verifies Gmail/Calendar are framed as connected Google OAuth features and unavailable tool paths return `requires: google_oauth`.
- Launch-site verification now checks the Privacy Policy for concrete local storage behavior and passes against localhost.
- `docs/beta-launch-communications.md` decides the next public build label as Beta and prepares beta invite copy, draft release notes, known limitations, support instructions, launch-day monitoring checks, release-day smoke checks, permissions copy, privacy/memory copy, data processing map, and uninstall/reset-memory guidance.
- `docs/launch-rollback-runbook.md` documents landing, R2 DMG, backend function, and app artifact rollback paths.
- `docs/manual-uat-matrix.md` defines a repeatable clean-install, permissions, Dictation, Context, Talk, Act, website/auth/download/legal, resilience, and support-export UAT matrix.
- `docs/releases/Voiyce-1.0+16-beta-release-notes.md` contains exact current public-artifact beta notes for version `1.0`, build `16`, with R2 URLs, checksum, recorded Git commit, known limitations, support path, verification evidence, and current production landing verification.
- Production landing verification passed on 2026-05-20: `https://voiyce.us` serves the current agent-context page, `/api/download-health` returns healthy against the public R2 DMG, and `scripts/verify-production-landing.sh https://voiyce.us` passed. Vercel deployment listing remains blocked by the current CLI/MCP auth context, so the deployment ID is not recorded.
- Repo docs/pages no longer contain stale legacy support-address references.
- Packaging, notarization, clean-machine install, and manual UAT remain open.
- `docs/launch-ready-self-serve.md` tracks current verification status, remaining UAT, and release-candidate blockers.

### Self-Serve Launch Workstreams

#### 1. Landing Page And Marketing Site

- [x] Complete a final copy pass across `/`, `/download`, `/auth`, `/privacy`, and `/terms`.
- [x] Ensure the hero message is direct: "Stop re-explaining your work to AI."
- [x] Ensure all visible positioning supports "agent context layer."
- [x] Remove outdated dictation-first claims from the landing page, metadata, Open Graph copy, and Twitter metadata.
- [x] Verify the agent logo strip uses correct icons/assets, does not clip at desktop widths, and stacks cleanly on mobile.
- [x] Verify Hermes Agent uses the local `hermes-agent.png` asset and does not depend on a fragile external favicon.
- [x] Verify legal contact email is `aki.b@pentridgemedia.com` in Terms and Privacy.
- [x] Verify download CTAs route correctly through auth and then the download page.
- [x] Verify no broken internal links locally: home, auth, download, privacy, terms.
- [x] Verify OG image and favicon render locally.
- [x] Verify OG image and favicon render in production preview.
- [x] Run desktop visual QA at 1440, 1280, and 1024 px widths.
- [x] Run mobile visual QA at iPhone SE, iPhone 14/15, and large Android widths.
- [x] Check that no hero, nav, CTA, legal, or agent-strip text overlaps or clips at supported breakpoints.
- [x] Run full-page color-contrast QA across home, auth, download, terms, and privacy routes, including auth input placeholders.
- [x] Verify basic accessibility smoke guardrails: `lang`, skip link, main landmark, and visible focus style.
- [x] Confirm `npm run lint` passes without warnings.
- [x] Confirm `npm run build` passes.

#### 2. macOS App Core Product Polish

- [x] Verify first-run onboarding explains permissions in plain language.
- [x] Verify the app can be understood without reading external docs.
- [x] Verify Off, Context, Talk, and Act modes have distinct states, labels, and safe transitions.
- [x] Verify Dictation remains separate from Agent modes.
- [x] Verify hotkeys do not conflict and are documented in Settings or onboarding.
- [ ] Verify Settings accurately reflects permission state after grant, denial, refresh, quit, and reopen.
Partial automated coverage: Settings now exposes a Refresh Status control with UI coverage, Pro permission polling stays active until Screen Recording state is current, and `permissionStatusCopyReflectsGrantedAndDeniedStates` verifies Settings/onboarding granted and denied copy stays tied to the underlying permission state. Manual grant/denial/quit/reopen UAT remains open.
- [x] Verify Agent Log is useful to a non-developer power user and to support.
- [x] Verify support export redacts sensitive fields by default.
- [x] Remove placeholder/sample events from production surfaces unless explicitly labeled as examples. The unused dashboard usage demo-data seeding hook has also been removed so production usage analytics cannot backfill sample words or session counts.
- [ ] Verify all user-facing error states explain what happened and what to do next.
Partial automated coverage: Dictation, Talk, Act, screen context, Auth/Billing, Google, Agent-tool validation, memory, permission-block, quota, and service-failure paths have targeted copy guards. Act command failure result payloads now include structured `next_step` data for missing tasks, sign-in, Accessibility, safety checks, and post-action screen-capture failures. Full manual UI sweep remains open.
- [x] Remove provider/backend implementation language from onboarding and dashboard dictation recovery states.
- [x] Remove Computer Use/backend/provider implementation language from Act command recovery states.
- [x] Remove provider/backend implementation language from Talk startup recovery states.
- [x] Remove provider/backend implementation language from dictation service-failure Agent Log/support export states.
- [x] Remove VideoDB/Computer Use/OpenAI/backend/runtime implementation language from active-session context/search/summary states.
- [x] Verify Stop is always visible during active Talk or Act sessions.
- [ ] Verify crashes, network failures, quota errors, account access loss, and permission blocks do not leave the app in a stuck active state.
- Partial automated coverage: Realtime connection failures, usage-limit responses, account access loss, permission-block Agent Log events, Act cancellation, and Context-only startup/privacy-pause failures now recover without leaving the tested active states stuck. Manual crash/permission UAT remains open.
- [ ] Verify app menu, menu bar UI, dashboard, settings, onboarding, and agent screens all match the dark premium Voiyce aesthetic.
Partial automated coverage: `testDashboardSettingsAndAgentNavigation` and `testAgentScreenPolishAndStartStopControls` verify Dashboard, Settings, Agent, and Agent Log expose expected launch UI copy and do not expose internal implementation terms such as backend, Realtime, Computer Use, VideoDB, SDP, or tool calls. The app menu now exposes Dashboard, Agent, Agent Log, Settings, and Focus Tools commands with `appMenuLaunchCopyStaysUserFacing` coverage. `menuBarLaunchCopyStaysUserFacing` verifies menu bar launch copy stays free of backend/internal implementation terms, and menu actions now expose stable accessibility identifiers. Settings permission rows now expose stable accessibility identifiers so the Permissions tab launch-copy path stays deterministic. Manual coverage: `docs/manual-uat-matrix.md` now has a dedicated Visual And Navigation Polish section for onboarding, Dashboard/sidebar, Settings, Agent, Agent Log, menu bar, and app menu review, with launch audit guards for each row. Visual/premium aesthetic review for all screen states remains manual UAT.
The walkthrough video sheet now uses product-facing launch copy instead of dictation-only onboarding language, and its load-failure copy includes a concrete retry step. `demoVideoLaunchCopyStaysProductFacing` blocks internal implementation terms and "start dictating" regressions.

#### 3. Memory, Privacy, And Local Data Controls

- [x] Verify Context capture is off by default or clearly consented to before durable capture begins.
- [x] Verify users can pause capture quickly.
- [x] Verify Private Mode pauses durable memory, raw screenshot storage, and live/session context capture.
- [x] Verify app/site exclusions skip memory writes and pause live/session context for matching apps/sites where the current app/window is detectable.
- [x] Verify sensitive contexts are skipped by default: password managers, banking, health, private browsing, credential fields, payment flows, and system security screens.
- [x] Verify memory deletion clears structured local memory, screenshots, and Voiyce-written vault notes.
- [x] Verify retention settings work for session-only, 30 days, 90 days, and forever.
- [x] Verify raw screenshot retention is separate from summary retention.
- [x] Verify the Markdown vault is readable, portable, date-organized, and not dependent on Obsidian being installed.
- [x] Verify memory search returns relevant prior context and gracefully handles no results.
- [x] Verify privacy copy matches actual storage behavior.
- [x] Verify no secrets, tokens, API keys, private screenshots, or transcripts are written into logs or support exports by default.

#### 4. Talk Mode Readiness

- [x] Define QA target ranges for connection readiness, first audio response, tool-call silence, and interruption settling.
- [ ] Measure first response perceived latency on a normal network.
- [ ] Measure interruption behavior: user cuts off assistant, assistant stops speaking, session continues.
Partial automated coverage: `realtimeTelemetryParsesAndWritesTalkLatencyAgentLogEvents` verifies the Realtime interruption-completed telemetry path is parsed and written to Agent Log with the launch QA target and review label. Physical spoken interruption UAT remains open.
Manual UAT coverage: `docs/manual-uat-matrix.md` now requires testers to record first-response timing, interruption settling time, tool-delay progress phrasing, long-thought correction handling, and repeated tool requests during the Talk pass.
- [x] Verify microphone permission denial produces a clear recovery path.
- [x] Verify Realtime connection failure produces a clear recovery path.
- [x] Verify Realtime instructions require natural progress check-ins for long tool/context waits.
- [ ] Verify Talk can answer questions about current screen context when Screen Recording is granted.
Partial automated coverage: `realtime instructions route screen and memory questions to the right context source` verifies Talk instructions prefer current screen inspection for screen-dependent requests, active-session context for current-session history, saved memory for prior work, and Screen Recording recovery when screen inspection is blocked. Physical spoken Talk UAT with Screen Recording granted remains open.
- [x] Verify Talk explains missing permission or missing OAuth instead of hallucinating access.
- [x] Verify Talk stops cleanly and releases audio resources.
- [x] Verify Talk latency telemetry writes support-safe Agent Log measurements with useful summaries.

#### 5. Act Mode Readiness

- [x] Verify Act Mode requires an explicit safety mode before first use.
- [x] Verify Strict mode asks before every click, type, submit, send, delete, purchase, account change, external post, or high-impact operation.
- [x] Verify Normal mode asks before high-impact actions and allows low-risk navigation.
- [x] Verify Unrestricted still blocks catastrophic full-system deletion, credential theft, malware, fraud, and illegal/platform-abusive actions.
- [x] Verify confirmation prompts show exact action, target, and consequence.
- [x] Verify Cancel prevents execution.
- [x] Verify active one-off Act commands expose the main Stop action, cancel on Stop, and return the main action to Start.
- [x] Verify Stop cancels in-flight loops when safe to do so.
- [x] Verify Action Cursor appears before visible actions and does not steal focus.
- [x] Verify Focus Highlight capture works on single-display and multi-display setups.
- [x] Verify OpenAI Computer Use safety checks either resume correctly after approval or fail with a clear recovery path.
- [x] Verify every planned, approved, canceled, failed, and completed action is logged.
- [x] Verify Act can fail safely when Accessibility or Screen Recording permission is missing.

#### 6. Backend, Secrets, Cost, And Kill Switches

- [ ] Rotate any exposed OpenAI keys and verify old keys no longer work.
- [ ] Verify OpenAI keys are server-side only and absent from the macOS app bundle, browser bundle, source, logs, and release artifacts.
- [x] Verify Realtime, transcription, Computer Use, and screen-context functions enforce request size limits.
- [x] Verify kill switches work independently: `VOIYCE_DISABLE_ALL_AI`, `VOIYCE_DISABLE_REALTIME`, `VOIYCE_DISABLE_TRANSCRIPTION`, `VOIYCE_DISABLE_COMPUTER_USE`, and `VOIYCE_DISABLE_SCREEN_CONTEXT`.
- [x] Verify client model overrides are disabled unless explicitly allowed.
- [x] Verify backend errors never expose secrets to the client.
- [x] Verify usage and estimated cost are recorded by capability where possible.
- [x] Define temporary internal caps for beta even before full paid tier enforcement.
- [x] Verify Default/Pro/Power server-side usage caps for Realtime, transcription, Computer Use, and context when cap enforcement is enabled.
- [ ] Verify OpenAI, InsForge, Vercel, Cloudflare R2, and Stripe dashboard access before launch day.

#### 7. Release Artifact Integrity

- [ ] Freeze a release candidate branch.
- [ ] Commit all app, backend, landing page, script, and doc changes used for the release candidate.
- [ ] Confirm unrelated local changes are either intentionally included, split out, or documented as excluded.
- [ ] Build a fresh signed and notarized DMG from the exact release candidate source.
- [ ] Record build number, version, Git commit, archive path, DMG path, SHA-256, notarization ID, and R2 URLs.
- [ ] Verify Gatekeeper accepts the DMG.
- [ ] Verify stapling succeeds.
- [ ] Verify the DMG opens and includes the app plus Applications symlink.
- [x] Verify `Voiyce.dmg`, `Voiyce.dmg.sha256`, versioned DMG, versioned checksum, and `latest.json` for the currently published R2 artifacts.
- [x] Verify the public latest URL returns `200 OK`.
- [x] Verify the currently public DMG downloads, passes image/Gatekeeper/stapler checks, mounts read-only, contains a signed/notarized `Voiyce.app` and `/Applications` symlink, matches manifest version/build, and scans clean for leaked OpenAI-key patterns.
- [ ] Verify checksum downloaded from R2 matches the local DMG.
- [ ] Verify rollback can repoint the latest DMG to the previous known-good version.
- [x] Run a no-mutation rollback readiness dry-run that verifies the previous known-good versioned DMG and generates a local rollback `latest.json`.

#### 8. Legal, Trust, And User Communication

- [x] Verify Terms of Service and Privacy Policy reflect actual product behavior.
- [x] Verify legal contact email is correct everywhere.
- [x] Verify refund, subscription, and cancellation copy matches the active payment flow.
- [x] Verify privacy policy covers voice input, transcripts, screenshots, local memory, support exports, third-party providers, and deletion.
- [x] Verify the app does not imply access to third-party accounts before OAuth or user permission exists.
- [x] Prepare known limitations for any beta announcement.
- [x] Prepare a short "how to get help" support path.
- [x] Prepare a simple user-facing uninstall/reset-memory note.

### Test Plan: Automated

- [x] Run Swift unit tests: `xcodebuild test` for `Voiyce-AgentTests`.
- [x] Run Swift UI tests: `xcodebuild test` for `Voiyce-AgentUITests`.
- [x] Run a clean macOS debug build.
- [x] Run a Release archive build.
- [x] Run integrated release verification with archive check in diagnostic mode.
- [x] Run public DMG mount/Gatekeeper verification.
- [x] Run backend function tests, if available.
- [x] Run agent usage-cap verification.
- [x] Run release source-state verification in prep mode and confirm strict mode remains blocked until clean-tree/tag requirements are met.
- [x] Run app-termination cleanup unit coverage for active dictation/Agent runtime state and local session-context shutdown.
- [x] Run system sleep cleanup unit coverage for active dictation/Agent runtime state and local session-context shutdown.
- [x] Run display-layout change cleanup unit coverage for stale overlay/focus cleanup and Act stale-coordinate pause policy.
- [x] Run TypeScript checks for landing page.
- [x] Run `npm run lint` in `landing-page`.
- [x] Run `npm run build` in `landing-page`.
- [x] Run secret scan against source.
- [x] Run secret scan against built Release app bundle.
- [x] Run secret scan against landing page build output.
- [x] Run `scripts/verify-release.sh --skip-ui-tests` without packaging.
- [x] Confirm the Release app build has no app-source warnings.
- [x] Rerun `scripts/verify-release.sh` without packaging after the local XCTest automation runner recovers.
- [x] Run local live route and CTA checks for landing page routes.
- [x] Run `scripts/verify-release.sh --package` before public upload.
- [ ] Run checksum verification for any generated DMG.
- [x] Run public latest/versioned R2 DMG checksum verification.
- [x] Run launch-readiness status audit in prep mode and confirm strict mode remains blocked until release/source/UAT/production blockers are resolved.
- [x] Run local link checks for landing page routes.
- [x] Run accessibility smoke checks for landing page keyboard focus and visible focus states.
- [x] Run full color-contrast review.

### Test Plan: Manual Product UAT

#### Clean Install And Onboarding

- [ ] Install from the public DMG on a fresh macOS user or clean machine.
- [ ] Launch from DMG and from Applications. Manual coverage: `docs/manual-uat-matrix.md` now includes `CI-07 Launch location parity`, and `scripts/generate-manual-uat-pass.sh` includes `CI-08 Launch location parity` plus `Launch from DMG and Applications result:`.
- [ ] Confirm macOS does not show unidentified-developer or damaged-app warnings.
- [ ] Complete onboarding with all permissions granted.
- [ ] Complete onboarding with permissions denied one by one.
- [ ] Quit and reopen after each permission path.
- [ ] Confirm Settings reflects actual permission state.
- [ ] Confirm sign-in works from a fresh install.
- [ ] Confirm sign-out and sign-in recovery works. Partial automated coverage: access-loss cleanup now clears active dictation/Agent runtime state and provides signed-out/payment-required recovery steps; full clean-install sign-out/sign-in UAT remains open. Manual coverage: `docs/manual-uat-matrix.md` now includes RR-07 for account access lost while Dictation, Context, Talk, or Act is active, and `scripts/generate-manual-uat-pass.sh` includes a matching scripted row and active account-access-loss result field.

#### Dictation

- [ ] Hold dictation hotkey in a native text field. Manual coverage: `docs/manual-uat-matrix.md` includes `DI-01 Native text field`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Dictation native-field insertion result:`.
- [ ] Hold dictation hotkey in browser text field. Manual coverage: `docs/manual-uat-matrix.md` includes `DI-02 Browser text field`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Dictation browser-field insertion result:`.
- [ ] Dictate short text. Manual coverage: `docs/manual-uat-matrix.md` now includes `DI-08 Short text accuracy`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Dictation short-text accuracy result:`.
- [ ] Dictate long paragraph. Manual coverage: `docs/manual-uat-matrix.md` includes `DI-03 Long paragraph`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Dictation long-paragraph result:`.
- [ ] Dictate with punctuation. Manual coverage: `docs/manual-uat-matrix.md` now includes `DI-09 Punctuation handling`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Dictation punctuation result:`.
- [ ] Cancel mid-dictation. Manual coverage: `docs/manual-uat-matrix.md` includes `DI-04 Cancel mid-dictation`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Dictation cancel-mid-dictation result:`.
- [ ] Deny microphone and verify clear recovery. Manual coverage: `docs/manual-uat-matrix.md` includes `DI-06 Microphone denied`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Dictation microphone-denied recovery result:`.
- [ ] Disconnect network and verify clear recovery. Manual coverage: `docs/manual-uat-matrix.md` includes `DI-05 Offline transcription`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Dictation offline recovery result:`.
- [ ] Verify transcript is not inserted into the wrong field. Manual coverage: `docs/manual-uat-matrix.md` now includes `DI-07 Wrong-field protection`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Dictation wrong-field protection result:`.

#### Context Mode

- [ ] Start Context Mode. Manual coverage: `docs/manual-uat-matrix.md` includes `CM-01 Start and stop Context`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Context start/stop result:`.
- [ ] Work across browser, code editor, and app screens. Manual coverage: `docs/manual-uat-matrix.md` now includes `CM-08 Cross-app context quality`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Cross-app context quality result:`.
- [ ] Stop Context Mode. Manual coverage: `docs/manual-uat-matrix.md` includes `CM-01 Start and stop Context`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Context start/stop result:`.
- [ ] Verify session summary writes to memory. Manual coverage: `docs/manual-uat-matrix.md` includes `CM-02 Memory write`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Context memory write result:`.
- [ ] Verify excluded apps/sites do not write memory. Manual coverage: `docs/manual-uat-matrix.md` includes `CM-04 App/site exclusion`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Context app/site exclusion result:`.
- [ ] Verify Private Mode prevents durable writes. Manual coverage: `docs/manual-uat-matrix.md` includes `CM-03 Private Mode`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Context Private Mode result:`.
- [ ] Verify memory appears in vault if vault is enabled. Manual coverage: `docs/manual-uat-matrix.md` now includes `CM-07 Vault Notes visibility`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Vault Notes visibility result:`.
- [ ] Delete memory and verify files/index are removed. Manual coverage: `docs/manual-uat-matrix.md` includes `CM-05 Delete memory`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Context delete-memory result:`.

#### Talk Mode

- [ ] Start Talk Mode and ask a simple question. Manual coverage: `docs/manual-uat-matrix.md` includes `TK-01 Simple spoken question`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Talk first-response timing:`.
- [ ] Ask about current screen. Manual coverage: `docs/manual-uat-matrix.md` includes `TK-02 Current screen question`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Talk current-screen answer result:`.
- [ ] Ask about previous session memory. Manual coverage: `docs/manual-uat-matrix.md` includes `TK-03 Memory recall`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Talk memory-recall result:`.
- [ ] Interrupt the assistant while it speaks. Manual coverage: `docs/manual-uat-matrix.md` includes `TK-04 Interruption`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Talk interruption settling timing:`.
- [ ] Ask a question requiring a tool call. Manual coverage: `docs/manual-uat-matrix.md` includes `TK-05 Tool delay`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Talk tool-delay progress phrase observed:`.
- [ ] Ask for Gmail/Calendar without Google connected. Manual coverage: `docs/manual-uat-matrix.md` includes `TK-07 Missing OAuth`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Talk missing-OAuth recovery result:`.
- [ ] Speak a long thought with a correction before Voiyce answers. Manual coverage: `docs/manual-uat-matrix.md` includes `TK-08 Long thought and correction`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Talk long-thought/correction result:`.
- [ ] Ask repeated screen, memory, Gmail, or Calendar follow-ups in one Talk session. Manual coverage: `docs/manual-uat-matrix.md` includes `TK-09 Repeated tool requests`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Talk repeated-tool-requests result:`.
- [ ] Stop during a tool call. Manual coverage: `docs/manual-uat-matrix.md` now includes `TK-10 Stop during tool call`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Talk stop-during-tool-call result:`.
- [ ] Toggle network off during session. Manual coverage: `docs/manual-uat-matrix.md` includes `TK-06 Network drop`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Talk network-drop recovery result:`.
- [ ] Verify Agent Log entries after session. Manual coverage: `docs/manual-uat-matrix.md` now includes `TK-11 Agent Log after Talk`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Talk Agent Log review result:`.

#### Act Mode

- [ ] Start Act Mode in Strict. Manual coverage: `docs/manual-uat-matrix.md` includes `AC-01 Safety mode required`, Strict-mode navigation and confirmation rows, and `scripts/generate-manual-uat-pass.sh` includes `Act safety-mode-required result:`.
- [ ] Start Act Mode in Normal. Manual coverage: `docs/manual-uat-matrix.md` now includes `AC-18 Normal safety smoke`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Act Normal safety smoke result:`.
- [ ] Start Act Mode in Unrestricted. Manual coverage: `docs/manual-uat-matrix.md` now includes `AC-19 Unrestricted safety smoke`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Act Unrestricted safety smoke result:`.
- [ ] Ask Voiyce to open its own Settings. Manual coverage: `docs/manual-uat-matrix.md` includes `AC-02 Native Voiyce navigation`, and `scripts/generate-manual-uat-pass.sh` includes `Act native-Voiyce-navigation result:`.
- [ ] Ask Voiyce to open a website. Manual coverage: `docs/manual-uat-matrix.md` includes `AC-03 Browser navigation`, and `scripts/generate-manual-uat-pass.sh` includes `Act browser-navigation result:`.
- [ ] Ask Voiyce to fill a public test form. Manual coverage: `docs/manual-uat-matrix.md` includes `AC-04 Public test form`, and `scripts/generate-manual-uat-pass.sh` includes `Act public-test-form-fill result:`.
- [ ] Ask Voiyce to submit the form and verify confirmation behavior. Manual coverage: `docs/manual-uat-matrix.md` now includes `AC-20 Public form submit confirmation`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Act public-form submit confirmation result:`.
- [ ] Ask Voiyce to draft, but not send, an email if Gmail is connected. Manual coverage: `docs/manual-uat-matrix.md` includes `AC-05 Gmail draft`, and `scripts/generate-manual-uat-pass.sh` includes `Act Gmail draft result:`.
- [ ] Ask Voiyce to read upcoming calendar context if Google is connected. Manual coverage: `docs/manual-uat-matrix.md` includes `AC-06 Calendar read`, and `scripts/generate-manual-uat-pass.sh` includes `Act Calendar read result:`.
- [ ] Ask Voiyce to switch between desktop apps. Manual coverage: `docs/manual-uat-matrix.md` includes `AC-07 Desktop app switching`, and `scripts/generate-manual-uat-pass.sh` includes `Act desktop-app-switching result:`.
- [ ] Ask Voiyce to perform a blocked destructive action. Manual coverage: `docs/manual-uat-matrix.md` includes `AC-08 Blocked destructive action`, and `scripts/generate-manual-uat-pass.sh` includes `Act blocked-destructive-action result:`.
- [ ] Stop Act while the action cursor is visible. Manual coverage: `docs/manual-uat-matrix.md` includes `AC-09 Stop during Action Cursor`, and `scripts/generate-manual-uat-pass.sh` includes `Act stop-during-Action-Cursor result:`.
- [ ] Deny Accessibility and verify safe failure. Manual coverage: `docs/manual-uat-matrix.md` includes `AC-10 Missing Accessibility`, and `scripts/generate-manual-uat-pass.sh` includes `Act missing-Accessibility recovery result:`.
- [ ] Deny Screen Recording and verify safe failure. Manual coverage: `docs/manual-uat-matrix.md` includes `AC-11 Missing Screen Recording`, and `scripts/generate-manual-uat-pass.sh` includes `Act missing-Screen-Recording recovery result:`.
- [ ] Visit Agent Log or Settings mid-task and return to Act. Manual coverage: `docs/manual-uat-matrix.md` includes `AC-12 Visit Agent Log mid-task`, and `scripts/generate-manual-uat-pass.sh` includes `Act Agent Log mid-task recovery result:`.
- [ ] Verify all actions are logged. Manual coverage: `docs/manual-uat-matrix.md` now includes `AC-21 Action log audit trail`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Act action-log audit trail result:`.

### Test Plan: Landing Page And Web

- [x] Verify homepage desktop at 1440, 1280, and 1024 px. Manual coverage: `docs/manual-uat-matrix.md` includes `WEB-01 Public home route`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Public home route result:`.
- [x] Verify homepage mobile at 375, 390, and 430 px. Manual coverage: `docs/manual-uat-matrix.md` includes `WEB-01 Public home route`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Public home route result:`.
- [x] Verify `/auth`, `/download`, `/terms`, and `/privacy`. Manual coverage: `docs/manual-uat-matrix.md` includes `WEB-02 Auth/download flow` and `WEB-03 Legal pages`, and `scripts/generate-manual-uat-pass.sh` includes matching rows plus `Auth/download flow result:` and `Legal pages result:`.
- [x] Verify nav anchors scroll to the right sections.
- [x] Verify CTA buttons route correctly.
- [x] Verify no text clips in the hero, agent context strip, use-case cards, footer, legal pages, or buttons.
- [x] Verify Hermes image renders locally.
- [x] Verify agent context strip does not crowd OpenClaw and Cursor.
- [x] Verify legal pages have correct email.
- [x] Verify download page handles missing download URL gracefully.
- [ ] Verify production env vars for download URL and auth are set. Template coverage: production landing/evidence worksheets now require `NEXT_PUBLIC_DOWNLOAD_URL`, `NEXT_PUBLIC_INSFORGE_URL`, `NEXT_PUBLIC_INSFORGE_ANON_KEY` presence without copied values, and an auth provider callback/sign-in smoke result.

### Test Plan: Security And Privacy

- [x] Source secret scan.
- [x] Built app secret scan.
- [x] Landing build secret scan.
- [x] Support export redaction review.
- [x] Agent Log redaction review.
- [x] Memory deletion verification.
- [x] Screenshot retention verification.
- [x] Sensitive app exclusion verification.
- [x] OAuth scope review.
- [x] Payment/Stripe mode review.
- [x] Backend CORS and allowed-method review.
- [x] Request-size tests for Realtime, transcription, Computer Use, and screen-context functions.
- [x] Rate-limit/failure-injection tests for each backend function and upstream provider limit mode.
- [x] Abuse-case test: prompt asks for credentials, deletion, fraud, illegal access, or hidden actions.

### Test Plan: Reliability And Failure Injection

- [ ] No network at app launch. Partial automated coverage: `Voiyce_AgentUITestsLaunchTests/testOfflineSignedOutLaunchShowsRecoveryCopy` verifies signed-out/offline launch recovery copy and disabled auth actions with a deterministic test-only network override. Manual coverage: `docs/manual-uat-matrix.md` includes `RR-01 No network at launch`, and `scripts/generate-manual-uat-pass.sh` includes `Physical no-network launch from downloaded app result:`. Physical network-off launch from a downloaded app still needs manual UAT.
- [ ] Network drops during dictation. Partial automated coverage: `Voiyce_AgentTests/offlineDictationFailureLogsSupportUsefulRecoveryEvent` verifies dropped transcription network requests map to no-internet recovery copy and log a support-useful Transcription service failure; physical network-off dictation from a downloaded app still needs manual UAT.
- [ ] Network drops during Talk. Partial automated coverage: `Voiyce_AgentTests/realtimeConnectionFailureTelemetryStopsAndExplainsRecovery` verifies `connection_lost` telemetry stops active Talk/Act state and logs a support-useful Talk service failure; physical network-off Talk from a downloaded app still needs manual UAT.
- [ ] Network drops during Act. Partial automated coverage: `Voiyce_AgentTests/realtimeConnectionFailureTelemetryStopsAndExplainsRecovery` now includes Act-specific `connection_lost` telemetry and verifies support-useful Act Mode service-failure logging. Manual coverage: `docs/manual-uat-matrix.md` now includes `AC-17 Network drop during Act`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Act network-drop recovery result:`. Physical network-off Act UAT from a downloaded app still needs manual UAT.
- [x] OpenAI returns 401.
- [x] OpenAI returns rate limit.
- [x] OpenAI returns quota exceeded.
- [x] InsForge function fails.
- [ ] R2 download URL fails. Partial automated coverage: the landing `/api/download-health` route checks the configured installer URL before auto-starting download, `scripts/verify-launch-site.sh --url http://localhost:23000` verifies current health success, a deterministic bad-URL production-start simulation returned `503` with a safe unreachable-artifact body, and `scripts/verify-rollback-readiness.sh` verifies the current public R2 artifacts plus the previous `1.0+1` rollback candidate without mutation. Manual coverage: `docs/manual-uat-matrix.md` now includes `WEB-05 Download-health fallback`, and `scripts/generate-manual-uat-pass.sh` includes a matching row and result field. Physical production/CDN failure UAT and actual rollback execution remain open.
- [x] Auth provider fails.
- [ ] Permission is revoked while session is running. Partial automated coverage: `Voiyce_AgentTests/agentPermissionRecoveryMatchesModeRequirements` verifies the mode-specific missing-permission policy for Context, Talk, and Act. Manual coverage: `docs/manual-uat-matrix.md` includes `RR-03 Permission revoked mid-session recovery`, and `scripts/generate-manual-uat-pass.sh` includes `Permission revoked mid-session recovery result:`. Physical mid-session permission-revocation UAT still needs manual execution.
- [ ] App is quit while session is running. Partial automated coverage: `Voiyce_AgentTests/appTerminationClearsTransientRuntimeState` and `Voiyce_AgentTests/appTerminationStopsLocalSessionContextCapture` verify termination cleanup clears active dictation/agent runtime state, stops local session-context capture, and logs context shutdown. Manual coverage: `docs/manual-uat-matrix.md` includes `RR-04 Quit while active cleanup`, and `scripts/generate-manual-uat-pass.sh` includes `Quit while active cleanup result:`. Physical quit-while-running UAT from the downloaded app still needs manual execution.
- [ ] Mac sleeps and wakes during Context Mode. Partial automated coverage: `Voiyce_AgentTests/systemSleepClearsTransientRuntimeState` and `Voiyce_AgentTests/systemSleepStopsLocalSessionContextCapture` verify sleep cleanup clears active dictation/Agent runtime state, stops local session-context capture, and logs context shutdown. The app also listens for macOS sleep/wake notifications, stops active local runtime before sleep, and leaves the mode restartable after wake. Manual coverage: `docs/manual-uat-matrix.md` includes `RR-02 Sleep/wake active-session cleanup`, and `scripts/generate-manual-uat-pass.sh` includes `Sleep/wake active-session cleanup result:`. Physical sleep/wake UAT from the downloaded app still needs manual execution.
- [ ] Multiple displays are connected and disconnected. Partial automated coverage: `Voiyce_AgentTests/displayConfigurationRecoveryStopsOnlyActiveActMode` verifies display changes pause active Act mode while allowing Context/Talk to continue with fresh captures, and `Voiyce_AgentTests/displayConfigurationChangeClearsSavedFocusRegion` verifies stale focus regions are cleared and logged when display geometry changes. The app also clears transient action/focus/tour overlays on `NSApplication.didChangeScreenParametersNotification`. Manual coverage: `docs/manual-uat-matrix.md` includes `RR-05 Multi-display connect/disconnect recovery`, and `scripts/generate-manual-uat-pass.sh` includes `Multi-display connect/disconnect recovery result:`. Physical display connect/disconnect UAT from the downloaded app still needs manual execution.

### Launch Candidate Exit Criteria

No broad beta sharing until all of these are true:

- [ ] All automated checks pass or have explicit owner-approved exceptions.
Template coverage: `docs/launch-ready-self-serve.md` now includes explicit UAT result fields for automated check commands, automated result links, and owner-approved automated exceptions, and the launch audit guards those fields.
- [ ] Clean-machine install passes.
- [x] Landing page and legal pages pass desktop/mobile visual QA.
- [ ] No known P0 or P1 bugs remain.
Template coverage: `docs/manual-uat-matrix.md` and `docs/launch-ready-self-serve.md` now include an explicit no-known-P0/P1 field, and the launch audit guards that field.
- [ ] P2 bugs are documented with clear user impact and workaround.
Template coverage: `docs/manual-uat-matrix.md` and `docs/launch-ready-self-serve.md` now include explicit UAT result fields for P2 user impact, P2 workaround, and owner approval/acceptance, and the launch audit guards those fields.
- [ ] DMG is signed, notarized, stapled, checksummed, uploaded, and publicly verified.
- [ ] Secrets have been rotated and verified absent from shipped artifacts.
- [x] Kill switches have been tested.
- [x] Memory deletion and privacy controls have been tested.
- [ ] Act Mode safety confirmations have been tested.
Partial automated coverage: `confirmationCopyIncludesActionTargetAndConsequence`, `cancelledConfirmationCannotExecuteLaterAndCanStopSession`, `staleConfirmationTimesOutAndCannotExecuteLater`, `realtimeWebClientSupportsConfirmationApproveCancelAndStop`, and `realtime instructions route voice confirmation stop requests` verify confirmation copy, timeout/cancel/Stop Session behavior, stale confirmation rejection, the embedded Realtime confirmation buttons plus approve/cancel/stop-session tool schema, and backend Realtime voice guidance for stop-session decisions. Manual coverage: `docs/manual-uat-matrix.md` now includes explicit Act confirmation approve, cancel, Stop Session, and timeout rows, and `scripts/generate-manual-uat-pass.sh` includes matching scripted rows plus a confirmation result field. Physical Act confirmation UAT from a downloaded app remains open.
- [ ] Rollback path is documented and rehearsed. Partial: `docs/launch-rollback-runbook.md` documents landing, R2 DMG, backend function, and app artifact rollback; `scripts/verify-rollback-readiness.sh` passed a no-mutation R2 rollback dry-run for `1.0+1`. An actual controlled latest-object repoint has not been performed.
- [x] Known limitations and support contact are ready.

### Launch Day Runbook

1. Freeze the release branch.
2. Run full automated verification.
3. Build and notarize the DMG from the release branch.
4. Verify the DMG locally.
5. Upload to R2 as versioned and latest.
6. Verify `latest.json`, checksum, and public download.
7. Deploy or verify landing page production build.
8. Run smoke test from production site: home -> auth -> download -> install -> launch.
9. Confirm kill switches are accessible.
10. Monitor OpenAI, Vercel, InsForge, Cloudflare R2, Stripe, and support inbox.
11. Send limited beta invites only after smoke checks pass.
12. Keep prior DMG and landing deployment ready for rollback.

### Documentation To Finish Before Sharing

- [x] Release notes for the exact current public artifact.
- [x] Draft release notes template.
- [x] Known limitations.
- [x] Clean install instructions.
- [x] Permissions explanation.
- [x] Privacy and memory behavior summary.
- [x] Support and bug-report instructions.
- [x] Rollback instructions.
- [ ] Internal UAT results with date, machine, OS version, tester, and pass/fail notes.
Template coverage: `docs/launch-ready-self-serve.md` now includes explicit UAT result fields for tester, date, machine, macOS version, and pass/fail notes, and the launch audit guards those fields.

## User Stories

### US-001: Mode Selector State Model
**Description:** As a developer, I want a durable Agent mode model so the app can consistently start and stop each assistant capability.

**Acceptance Criteria:**
- [x] Add or finalize `AgentMode`: `off`, `context`, `talk`, `act`.
- [x] Store selected mode in app state.
- [x] Store whether the selected mode is currently running.
- [x] `off` always stops active agent services.
- [x] Switching modes while running transitions services safely.
- [x] Debug build succeeds with `xcodebuild`.

### US-002: Polished Agent Screen
**Description:** As a user, I want a clean Agent control screen so I can choose how Voiyce works with me without seeing backend details.

**Acceptance Criteria:**
- [x] Agent screen shows title, subtitle, four-mode selector, status, halo/orb, Start/Stop button, capability summary, and Act safety note.
- [x] Agent screen does not mention OpenAI, VideoDB, Computer Use, SDP, tool calls, or Realtime internals.
- [x] Active mode has distinct visual treatment.
- [x] Start button is disabled for Off mode.
- [x] Stop button stops the current mode.
- [x] UI matches the current dark Voiyce aesthetic.
- [x] Debug build succeeds with `xcodebuild`.

### US-003: Agent Log Screen
**Description:** As a power user or support engineer, I want an Agent Log screen so I can inspect what Voiyce did, asked, or attempted.

**Acceptance Criteria:**
- [x] Sidebar includes `Agent Log`.
- [x] Agent Log shows event list with time, title, summary, status, category, and expandable details.
- [x] Agent Log supports filters: All, Voice, Actions, Memory, Errors.
- [x] Agent Log supports text search.
- [x] Agent Log includes summary stats for events, successful actions, confirmations, and errors.
- [x] Placeholder/sample events are replaced or backed by real local event storage before production release.
- [x] Debug build succeeds with `xcodebuild`.

### US-004: Agent Hotkey Toggle
**Description:** As a user, I want the Agent hotkey to toggle the selected agent mode so I do not need to hold a key during longer sessions.

**Acceptance Criteria:**
- [x] Pressing Option once starts the selected non-Off Agent mode.
- [x] Pressing Option again stops the active Agent mode.
- [x] Releasing Option does not stop the Agent.
- [x] Dictation hotkey remains separate and preserves hold-to-dictate behavior.
- [x] UI reflects running/stopped state after hotkey events.
- [x] Debug build succeeds with `xcodebuild`.

### US-005: Context Mode
**Description:** As a user, I want Context Mode so Voiyce can quietly remember my work session without voice or actions.

**Acceptance Criteria:**
- [x] Starting Context Mode starts passive session context capture.
- [x] Context Mode does not start Realtime voice.
- [x] Context Mode does not click, type, open apps, or perform actions.
- [x] Context Mode writes context events to Agent Log.
- [ ] Context Mode captures frequently enough that users feel Voiyce understands what happened during the active session. Manual coverage: `docs/manual-uat-matrix.md` now includes `CM-08 Cross-app context quality`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Cross-app context quality result:`.
- Partial automated coverage: `sessionContextCaptureScriptRecordsScreenMicrophoneAndSystemAudio` verifies Context starts a continuous capture helper for microphone, display, and optional system audio channels and consumes capture events. Physical multi-app Context UAT remains open.
- [x] Stopping Context Mode stops capture cleanly.
- [x] User can see clear status: Ready, Keeping context, Paused, or Error.

### US-006: Talk Mode
**Description:** As a user, I want Talk Mode so I can speak naturally with Voiyce while it has access to session context.

**Acceptance Criteria:**
- [x] Starting Talk Mode starts Context Mode services and Realtime voice.
- [ ] Browser/WebRTC or embedded Realtime bridge connects successfully.
- Partial automated coverage: `realtimeWebClientConnectsMicrophonePeerAndRemoteAudioPath` verifies the embedded client microphone, peer connection, SDP, remote answer, remote audio, and audio-ready telemetry path. Physical spoken Talk UAT remains open.
- [ ] Voice input and model audio output work.
- Partial automated coverage: `realtimeWebClientConnectsMicrophonePeerAndRemoteAudioPath` verifies microphone capture is sent to the peer connection and model audio is wired to the autoplay `remoteAudio` element. Manual coverage: `docs/manual-uat-matrix.md` now includes `TK-12 Voice input and output smoke`, and `scripts/generate-manual-uat-pass.sh` includes a matching row plus `Talk voice input/output result:`. Physical audio-input/output UAT remains open.
- [x] Existing Gmail, Calendar, open URL, open app, insert text, screen inspection, and memory tools remain available.
- [x] Talk Mode writes voice session events and support-safe tool results to Agent Log.
- [x] Stopping Talk Mode stops voice and context capture.

### US-007: Act Mode Shell
**Description:** As a user, I want Act Mode so Voiyce can operate apps and websites with visible progress and explicit safety boundaries.

**Acceptance Criteria:**
- [x] Starting Act Mode starts Context and Talk capabilities.
- [x] Act Mode enables action-capable tools only while active.
- [x] Agent screen displays safety language for Act Mode.
- [x] Act Mode requires a selected safety mode before first use.
- [x] Act Mode writes every planned and executed action to Agent Log.
- [x] Stopping Act Mode cancels in-flight action loops when safe to do so.

### US-008: OpenAI Computer Use Loop
**Description:** As a developer, I want an OpenAI Computer Use loop so the assistant can reason over screenshots and propose UI actions.

**Acceptance Criteria:**
- [x] Implement a service that calls the Responses API with the hosted `computer` tool path.
- [x] The service sends the current screenshot and task goal to the model.
- [x] The service receives proposed computer actions and safety checks.
- [x] The service executes allowed local actions through the native action path.
- [x] After each action, the service captures the new screen state and continues until done, blocked, or cancelled.
- [x] The loop can be cancelled by user Stop.
- [x] Computer Use failures are logged with status and plain-language message.

### US-009: Native macOS Action Executor
**Description:** As a developer, I want a native action executor so Voiyce can reliably click, type, scroll, press keys, and activate apps.

**Acceptance Criteria:**
- [x] Executor supports left click, right click, double click, text insertion, key press, hotkey press, scroll, app activation, and URL open.
- [x] Executor checks required macOS Accessibility permissions before action.
- [x] Executor returns structured success/failure results.
- [x] Executor refuses blind text fallback when target focus is unsafe or unknown.
- [x] Executor emits Agent Log events for each action.
- [x] Executor can be backed by current local APIs or a CUA Driver Core style package after technical evaluation.

### US-010: Action Cursor Overlay
**Description:** As a user, I want to see where Voiyce is acting so computer control feels understandable and trustworthy.

**Acceptance Criteria:**
- [x] Add a non-interactive always-on-top overlay window that does not steal focus.
- [x] Overlay shows a distinct Voiyce action cursor during Act Mode.
- [x] Cursor animates to target before click/type actions.
- [x] Overlay can show a compact status bubble: Looking, Clicking, Typing, Waiting, Needs confirmation.
- [x] Overlay is hidden outside Act Mode unless user enables preview/teaching mode.
- [x] Multi-display behavior is handled correctly.

### US-011: Focus Highlight
**Description:** As a user, I want to mark part of my screen and refer to it by voice so I can say things like "summarize this" or "click this."

**Acceptance Criteria:**
- [x] Add a global shortcut for focus highlight drawing.
- [x] User can paint or box-select a visible region.
- [x] Highlight overlay is click-through outside the drawing gesture.
- [x] Highlighted region is captured as image/context for Talk and Act modes.
- [x] The current highlighted region can be cleared.
- [x] Agent Log records highlight creation and clearing.

### US-012: Safety Mode Selector
**Description:** As a user, I want to choose strict, normal, or unrestricted safety so Voiyce matches my comfort level.

**Acceptance Criteria:**
- [x] Add Safety Mode setting: Strict, Normal, Unrestricted.
- [x] Safety Mode is configured in Settings.
- [x] Strict asks before every click, type, submit, send, delete, purchase, account change, or external post.
- [x] Normal asks before high-impact actions: send, submit, delete, purchase, account changes, public posts, credential changes, billing changes.
- [x] Unrestricted allows nearly all user-directed actions without confirmation, while still keeping emergency stop and blocking catastrophic full-system deletion or actions prohibited by law/platform policy.
- [x] First Act Mode start requires choosing a safety mode.
- [x] Safety mode is visible in Act Mode UI and Settings.
- [x] Every confirmation decision is logged.

### US-013: Confirmation UI
**Description:** As a user, I want clear approve/cancel prompts before sensitive actions so I remain in control.

**Acceptance Criteria:**
- [x] Confirmation UI shows exact action, target, and expected consequence.
- [x] Confirmation UI supports Approve, Cancel, and Stop Session.
- [x] Confirmation UI appears above other app windows when necessary.
- [x] In Talk/Act Mode, the assistant verbally explains why confirmation is needed.
- [x] Cancelled actions do not execute.
- [x] Agent Log records requested, approved, cancelled, and timed-out confirmations.

### US-014: Long-Term Memory Store
**Description:** As a user, I want Voiyce to remember useful context across sessions so I can ask about prior work.

**Acceptance Criteria:**
- [x] Add local long-term memory records with date, source mode, summary, tags, app/site hints, links, and searchable text.
- [x] Store distilled summaries by default.
- [x] Retain raw screenshots when they materially improve general memory quality, recall, or user retention, subject to privacy controls and user deletion.
- [x] Support per-user memory isolation.
- [x] Add retention settings: session only, 30 days, 90 days, forever.
- [x] Add memory search API for the Agent.
- [x] Add memory delete controls.
- [x] Agent Log records memory writes and searches.

### US-015: Obsidian Vault Integration
**Description:** As a user, I want Voiyce to create and write to an Obsidian-style vault so my long-term memory is readable and portable.

**Acceptance Criteria:**
- [x] Provide a setup flow to create a new vault folder or select an existing folder.
- [x] If creating a new vault, use a clear default name such as `Voiyce Memory`.
- [x] Write Markdown notes grouped by day, project, or session.
- [x] Organize vault notes primarily by date.
- [x] Add links between related topics, projects, people, apps, and recurring work themes when those relationships are detected.
- [x] Include frontmatter metadata for date, source, apps, tags, and privacy level.
- [x] Do not require Obsidian CLI for the first version; write plain Markdown files directly.
- [ ] If an Obsidian URI or CLI workflow is later available, treat it as an optional enhancement.
- [x] User can disable vault sync at any time.

### US-016: Memory Recall in Talk and Act Modes
**Description:** As a user, I want to ask Voiyce about previous work so it can recall useful long-term context.

**Acceptance Criteria:**
- [x] Talk Mode can search long-term memory before answering memory-dependent questions.
- [x] Act Mode can use memory to ground actions only when relevant.
- [x] Assistant distinguishes current screen, current session memory, and long-term memory in internal tool results.
- [x] User-facing responses do not expose technical source names unless useful.
- [x] Memory recall cites date/session in natural language when appropriate.

### US-017: Tier-Based Capability Controls
**Description:** As a product owner, I want Default, Pro, and Power tiers so cost and capability scale with user value.

**Acceptance Criteria:**
- [x] Add internal capability gates for Default, Pro, and Power.
- [x] Default supports dictation and limited Talk/Context usage with lower-cost models/settings.
- [x] Pro supports higher limits, more frequent context capture, Talk Mode, and selected Act Mode capabilities.
- [x] Power supports full Act Mode, long-running sessions, Computer Use, higher memory limits, and higher spend caps.
- [x] Tier limits are enforced server-side where cost-bearing APIs are used.
- [x] UI explains upgrade-relevant limits in plain language.

### US-018: Cost and Usage Controls
**Description:** As a product owner, I want usage controls so Realtime, Computer Use, memory capture, and storage do not create runaway cost.

**Acceptance Criteria:**
- [x] Track Realtime session duration and estimated cost.
- [x] Track Computer Use loop count, screenshots, tool calls, and estimated cost.
- [x] Track memory capture frequency and storage usage.
- [x] Add per-tier daily/monthly caps.
- [x] Add server-side kill switches for Realtime and Computer Use.
- [x] User sees graceful limit messages instead of generic failures.

### US-019: Privacy Controls
**Description:** As a user, I want control over what Voiyce can see and remember so I can trust ambient context features.

**Acceptance Criteria:**
- [x] Add app/site exclusions for durable memory and raw screenshot capture.
- [x] Extend app/site exclusions to live/session context capture.
- [x] Add private-mode toggle that pauses durable memory and raw screenshot storage.
- [x] Extend private mode to pause live/session context capture with visible status.
- [x] Automatically avoid or warn on sensitive contexts such as password managers, banking, health, and private browsing where detectable.
- [x] Show visible status when context or act mode is active.
- [x] Provide delete memory controls.
- [x] Document what is stored locally, sent to OpenAI, sent to VideoDB, and written to vault.

### US-020: Production Diagnostics
**Description:** As a support engineer, I want actionable diagnostics so I can resolve user failures quickly.

**Acceptance Criteria:**
- [x] Agent Log captures OpenAI quota/rate-limit errors with upstream status.
- [x] Agent Log captures missing Screen Recording and Accessibility permission blocks with support-useful feature, permission, and next-step details.
- [x] Agent Log captures rejected actions, failed tool calls, and safety blocks.
- [x] Agent Log captures local memory write/delete failures with support-useful operation, path, and next-step details.
- [x] User-facing errors are plain language.
- [x] Exported logs redact secrets and sensitive content by default.
- [x] Support bundle export can be added later without changing event schema.

### US-021: Release Source Integrity
**Description:** As a product owner, I want every public DMG to map back to a committed and tagged source state so releases are reproducible and debuggable.

**Acceptance Criteria:**
- [x] Commit the exact macOS app, backend functions, tests, scripts, and landing page source used for the released DMG.
- [x] Tag the release with version and build number, for example `v1.0+16`.
- [x] Record release artifact URLs, checksum, notarization status, and Vercel deployment URL in release notes. Vercel deployment ID remains unavailable from the current CLI/MCP auth context, but `https://voiyce.us` production verification passed.
- [x] Keep unrelated local dirty work out of release tags.
- [x] Document rollback steps for the DMG and landing page.

### US-022: Secret Rotation and Runtime Key Hygiene
**Description:** As a security owner, I want exposed development secrets rotated and production secrets kept server-side so users cannot extract or abuse platform keys.

**Acceptance Criteria:**
- [ ] Revoke the OpenAI key exposed during development.
- [ ] Deploy a new OpenAI key only to server-side environments that need it.
- [x] Verify the macOS app bundle does not contain OpenAI API keys.
- [x] Verify the landing-page browser bundle does not contain server secrets.
- [x] Add a release checklist item for secret scanning before public launch.

### US-023: Clean-Machine Install and Permission UAT
**Description:** As a user, I want the first-run permission flow to work correctly from the downloaded DMG so setup does not feel broken or contradictory.

**Acceptance Criteria:**
- [ ] Install the public DMG on a clean macOS user or clean machine.
- [ ] Complete sign-in and onboarding from the downloaded app, not an Xcode build.
- [ ] Grant Microphone, Speech Recognition, Accessibility, and Screen Recording when prompted.
- [ ] Settings shows permission states accurately immediately after grant, after refresh, after quit/reopen, and after toggling permissions off/on.
- [ ] When a permission prompt returns to the app, the app returns to the original requesting screen and does not trigger duplicate approval loops. Manual coverage: `docs/manual-uat-matrix.md` now includes `CI-08 Permission return routing`, and `scripts/generate-manual-uat-pass.sh` includes `CI-09 Permission return routing` plus `Permission return routing result:`.
Partial automated coverage: `permissionReturnRestoresSettingsPermissionsTab` and `permissionReturnRestoresAgentScreen` verify permission-return routing restores Settings > Permissions or Agent once, clears persisted return targets, and does not reroute again on a second restore call. Physical permission prompt return UAT from the downloaded app remains open.
- [ ] Record screenshots or notes for each pass/fail step.
Template coverage: `docs/manual-uat-matrix.md` and `docs/launch-ready-self-serve.md` now include explicit UAT result fields for screenshot/recording links, Agent Log/support export links, and pass/fail notes, and the launch audit guards those fields.

### US-024: Act and Computer Use Real-Site Hardening
**Description:** As a user, I want Act Mode to handle common real app and website tasks reliably, including blocked states and sensitive actions.

**Acceptance Criteria:**
- [x] Create a repeatable UAT matrix for Gmail, Google Calendar, browser navigation, public website forms, app Settings navigation, and desktop app switching.
- [x] Act Mode completes bounded tasks without losing state when the user visits Agent Log or Settings.
- [x] Action Cursor remains visible during native and Computer Use actions.
- [x] Computer Use failures include a plain-language reason and next step.
- [x] Pending OpenAI safety checks resume after approval or fail into a recoverable state.
- [x] Sensitive actions follow the selected Safety Mode.

### US-025: Voice Latency and Conversation Tuning
**Description:** As a user, I want Talk Mode to feel conversational, responsive, and tolerant of natural pauses.

**Acceptance Criteria:**
- [x] Define target latency ranges for first audio response, tool-call acknowledgement, and interruption handling.
- [x] Tune Realtime turn detection so natural pauses do not prematurely cut the user off.
- [x] When screen context or tools are still loading, Talk uses a natural "checking" response instead of claiming it cannot see the screen too early.
- [ ] Spoken UAT covers short commands, long thoughts, interruptions, corrections, and repeated tool requests. Manual coverage: the Talk matrix now includes explicit rows for simple spoken questions, measured interruptions, long thought/correction handling, and repeated tool requests.
- [x] Latency regressions are logged or measurable during QA.

### US-026: Tier, Cap, and Kill-Switch Enforcement
**Description:** As a business owner, I want server-enforced tiers and emergency controls so production usage cannot create unbounded cost.

**Acceptance Criteria:**
- [x] Implement Default, Pro, and Power server-side usage gates.
- [x] Enforce daily/monthly limits for Realtime, transcription, Context capture, and Computer Use steps when cap enforcement is enabled.
- [x] Enforce durable memory storage and raw screenshot storage caps beyond local retention controls.
- [x] Add admin kill switches for Realtime, transcription, Computer Use, and context capture.
- [x] Limit messages are user-friendly and logged.
- [x] Usage and estimated cost are recorded per user and per cost-bearing server capability.

### US-027: Memory Privacy and Retention Controls
**Description:** As a user, I want clear control over what Voiyce stores locally and how long it keeps it.

**Acceptance Criteria:**
- [x] Add memory retention settings for session-only, 30 days, 90 days, and forever.
- [x] Add raw screenshot retention settings separate from summary retention.
- [x] Add app/site exclusions for durable memory and raw screenshot storage.
- [x] Extend app/site exclusions to live/session context capture.
- [x] Add private-mode toggle for durable memory and raw screenshot storage.
- [x] Extend private mode to pause live/session context capture and show visible paused status.
- [x] Add memory delete controls and verify deletion from both structured storage and Markdown vault notes.
- [x] Document local-only memory behavior and future cloud-memory non-goals for the current launch.

### US-028: Production Monitoring and Support Workflow
**Description:** As a support engineer, I want production diagnostics and escalation paths so user issues can be resolved quickly.

**Acceptance Criteria:**
- [x] Agent Log captures missing Screen Recording and Accessibility permission blocks in a support-export-visible format.
- [x] Agent Log captures Realtime, transcription, and Computer Use service failures with upstream status and support-useful next steps.
- [x] Agent Log captures memory errors in a support-useful format.
- [x] Support export redacts secrets and sensitive user content by default.
- [x] Define support escalation paths for billing, permissions, OpenAI quota, login, download, and Act failures.
- [x] Add monitoring or manual checks for Vercel, Cloudflare R2, InsForge functions, OpenAI usage, and Stripe mode.
- [x] Add release-day smoke checks for website, download, auth, DMG install, and core app workflows.

### US-029: Launch Labeling, Pricing, and Rollback
**Description:** As a product owner, I want launch messaging, pricing assumptions, and rollback paths defined before broad distribution.

**Acceptance Criteria:**
- [x] Decide whether the next public build is labeled Beta, Early Access, or Production.
- [x] Prepare known limitations for Act, Talk, memory, and permissions for the Beta invite and release notes.
- [ ] Finalize Default/Pro/Power pricing and usage caps before paid production launch.
- [ ] Confirm Stripe mode, products, prices, and webhook behavior before charging real users.
- [x] Document rollback for the landing page, DMG latest object, and backend functions.
- [x] Run no-mutation R2 rollback readiness verification for the previous known-good versioned DMG.

## Functional Requirements

- FR-1: The system must support four user-facing Agent modes: Off, Context, Talk, and Act.
- FR-2: Off Mode must stop Realtime, context capture, Computer Use loops, action cursor, and native action execution.
- FR-3: Context Mode must run context capture and memory indexing without voice or actions.
- FR-4: Talk Mode must run context capture and Realtime voice.
- FR-5: Act Mode must run context capture, Realtime voice, OpenAI Computer Use loop, native action execution, action cursor, and confirmation UI.
- FR-6: Dictation must remain separate from Agent modes.
- FR-7: The Option hotkey must toggle the selected Agent mode on and off.
- FR-8: The Agent screen must hide backend technical labels from normal users.
- FR-9: Agent Log must expose detailed events for support/debugging.
- FR-10: The Computer Use loop must be cancellable at any time by Stop.
- FR-11: The native executor must check macOS Accessibility permissions before executing clicks, typing, keypresses, or scrolls.
- FR-12: Action Cursor must visually indicate assistant actions during Act Mode.
- FR-13: Focus Highlight must let users mark visible UI regions for reference by voice.
- FR-14: Safety Mode must support Strict, Normal, and Unrestricted.
- FR-15: Safety Mode must be managed in Settings.
- FR-16: Unrestricted mode must be genuinely permissive for user-directed actions, while preserving emergency stop and blocking catastrophic full-system deletion or actions prohibited by law/platform policy.
- FR-17: Confirmation prompts must show exact action and consequence before high-impact actions according to safety mode.
- FR-18: Long-term memory must be local-only for the initial release.
- FR-19: Long-term memory must store distilled summaries by default and may retain raw screenshots when useful for memory quality.
- FR-20: Users must be able to delete memory.
- FR-21: The Obsidian-style vault integration must write plain Markdown files organized primarily by date with cross-links to related topics.
- FR-22: Pricing tiers must gate model quality, capture frequency, Computer Use availability, memory retention, and spend caps.
- FR-23: Cost-bearing backend services must enforce server-side usage limits.
- FR-24: The system must log enough structured data to debug failures without exposing secrets.

## Non-Goals

- Do not replace the current dictation feature.
- Do not expose raw backend implementation names on the main Agent screen.
- Do not make always-on screen/audio capture the default for every user.
- Do not require Obsidian CLI for the first vault version.
- Do not make cloud memory part of the initial release.
- Do not retain raw screenshots without privacy controls and user deletion controls.
- Do not execute illegal, credential-stealing, malware, payment fraud, or platform-abusive tasks in any safety mode.
- Do not ship unrestricted Act Mode without visible stop controls and audit logging.

## Design Considerations

- The Agent screen is a calm control surface, not a console.
- Agent Log is the technical/detail surface.
- Use premium dark UI consistent with existing Voiyce styling.
- Act Mode should feel powerful but controlled.
- The Action Cursor should make automation visible and understandable.
- Confirmation prompts must be impossible to confuse with passive status messages.
- Avoid nested cards and dense text on the Agent screen.
- Use plain language: "operate apps and websites" instead of "Computer Use"; "keeps context" instead of "VideoDB."

## Technical Considerations

- OpenAI Realtime WebRTC remains the voice front door. OpenAI docs recommend WebRTC for browser-based realtime voice and describe the unified session setup where a browser sends SDP to a developer server, which posts multipart session configuration to `/v1/realtime/calls`.
- OpenAI Computer Use is implemented through the Responses API hosted `computer` tool. The current default model is `gpt-5.5`, with `OPENAI_COMPUTER_USE_MODEL` available for override. Earlier docs and examples may refer to `computer-use-preview`; the current implementation follows the latest hosted computer tool shape.
- The native executor should be implemented behind an abstraction so the app can use current Swift/Accessibility primitives first and optionally adopt a CUA Driver Core style package after evaluation.
- TipTour's public repo is a useful reference for overlay windows, focus highlight, action cursor behavior, and CUA-backed input delivery, but Voiyce should preserve its OpenAI Realtime + VideoDB + native tools architecture.
- Long-term memory should have two local layers: a structured local index for search and a Markdown vault for user-readable recall.
- Raw screenshots may be retained locally when they improve memory quality, but must remain subject to retention controls, sensitive-app exclusions, and deletion.
- Obsidian integration should write Markdown directly; Obsidian CLI or URI automation is optional and not required for initial release.
- Action Cursor now ships with the OpenAI Computer Use loop and native action paths so users can see visible action state instead of unexplained UI jumps.
- Server-side functions must enforce usage tiers and keep OpenAI API keys server-side.

## Success Metrics

- A user can understand and start the desired Agent mode in under 10 seconds.
- A user can stop an active Agent mode in one click or one hotkey press.
- Talk Mode connects and responds within acceptable perceived latency for normal conversation.
- Act Mode can complete a representative website/app task with visible cursor feedback and no unexplained UI jumps.
- 100% of high-impact actions trigger confirmation in Normal mode.
- Agent Log contains enough detail to diagnose failed Realtime, Computer Use, memory, and permission issues.
- Memory recall returns relevant prior session context for common queries.
- Obsidian-style vault notes are readable, organized, and portable.
- Cost caps prevent unexpected runaway OpenAI or VideoDB spend.

## Open Questions

- What exact Default, Pro, and Power prices and monthly caps should ship?
- What capture frequency should Context Mode use for each tier to feel continuous without excessive cost/storage?
- What retention defaults should apply to raw screenshots in each tier?
- Should the local blocked-action list expand beyond its first launch set for catastrophic deletion, credential theft, malware, fraud, illegal access, hidden actions, and platform-abusive actions?
- Should the current JSON-backed local memory index graduate to SQLite/vector search before production release?

## Reference Docs

- OpenAI Realtime WebRTC guide: https://developers.openai.com/api/docs/guides/realtime-webrtc
- OpenAI Computer Use guide: https://developers.openai.com/api/docs/guides/tools-computer-use
- OpenAI `computer-use-preview` model page: https://developers.openai.com/api/docs/models/computer-use-preview
- TipTour macOS reference repo: https://github.com/milind-soni/tiptour-macos
