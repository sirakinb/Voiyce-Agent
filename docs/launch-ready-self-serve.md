# Launch-Ready Self-Serve Build Tracker

Date started: 2026-05-17

This tracker records the practical launch-readiness work being done before sharing Voiyce with beta users. The source of truth for scope is `tasks/prd-voiyce-agent-full-vision.md`, section `Launch-Ready Self-Serve Revision - 2026-05-17`.

## Current Positioning

Voiyce is the agent context layer for people working across Claude Code, Codex, Hermes Agent, OpenClaw, Cursor, and related AI workflows.

Primary headline:

```text
Stop re-explaining your work to AI.
```

## Google OAuth Scope Review

Current verdict: the requested Google scopes match the app's Gmail and Calendar feature surface. The app does not request Drive, Contacts, broad Calendar write, Gmail modify/delete, or other unrelated Google account scopes.

| Scope | Used For | Local Code Path |
| --- | --- | --- |
| `openid`, `email`, `profile` | OAuth account identity and consent account selection. | `GoogleWorkspaceManager.connect()` and connected account display. |
| `https://www.googleapis.com/auth/gmail.readonly` | Read matching Gmail message summaries when the user asks. | `GoogleWorkspaceManager.readGmail()` and `fetchGmailMessage()`. |
| `https://www.googleapis.com/auth/gmail.compose` | Create Gmail drafts through the Gmail API path. | `GoogleWorkspaceManager.draftGmail()`. |
| `https://www.googleapis.com/auth/gmail.send` | Send Gmail only through the send tool; Normal and Strict safety modes require Voiyce confirmation first. | `requestSendGmailConfirmation()`, `confirm_pending_action`, and `GoogleWorkspaceManager.sendGmail()`. |
| `https://www.googleapis.com/auth/calendar.freebusy` | Check availability without reading full event details. | `GoogleWorkspaceManager.checkCalendar()`. |
| `https://www.googleapis.com/auth/calendar.events.readonly` | Read upcoming primary calendar events when the user asks. | `GoogleWorkspaceManager.readCalendar()`. |

Regression guardrail: `googleOAuthScopesMatchCurrentGmailCalendarFeatureSet` fails the Swift unit target if scopes change without an intentional review.

Third-party account copy review: app/docs copy consistently frames Gmail and Calendar as connected Google OAuth features. Tool paths return `requires: google_oauth` when Google is not connected, and user-facing copy says "when connected" / "requires Google OAuth" rather than implying default access.

## Completed In This Revision

- Added `scripts/verify-launch-site.sh`.
- Wired `scripts/verify-release.sh` to run `scripts/verify-launch-site.sh` as the landing-page release gate.
- Updated landing metadata and hero copy to use the exact `agent context layer` positioning.
- Added a local Hermes Agent image asset at `landing-page/public/hermes-agent.png`.
- Updated Terms and Privacy contact email to `aki.b@pentridgemedia.com`.
- Updated Terms and Privacy from dictation-first language to cover voice, screen context, local memory, agent handoffs, support exports, connected services, third-party processors, retention, and deletion controls.
- Replaced the generic landing-page README with Voiyce-specific launch verification instructions.
- Hardened the landing download URL fallback so missing or blank `NEXT_PUBLIC_DOWNLOAD_URL` values use the default public R2 DMG URL.
- Added a landing download-health route so the site checks the configured DMG URL before auto-starting the hidden download request; the download page now shows a plain recovery state and support email if the installer link is unreachable.
- Hardened web auth failures so the signup/sign-in route maps SDK/provider/network errors to plain, support-safe recovery copy instead of echoing raw error messages.
- Split `scripts/verify-release.sh` into explicit macOS unit-test and UI-test phases.
- Added `scripts/verify-release.sh --skip-ui-tests` as a diagnostic-only path so local build/backend/site failures can be separated from XCTest automation permission failures.
- Hardened the macOS UI tests to re-activate Voiyce, hide unrelated apps, and wait for target controls before clicking so external app windows do not create false navigation failures.
- Added landing build-output and built Release app-bundle secret scans to the normal verification path.
- Hardened `scripts/verify-release.sh --public-download-check` so it validates `latest.json`, absolute HTTPS latest/versioned DMG URLs, latest and versioned checksum sidecars, manifest SHA consistency, and latest/versioned DMG byte equality.
- Reran the non-packaging public artifact gate after the latest 72-test web auth/download state; the current R2 `latest.json`, latest DMG, versioned DMG, checksum sidecars, manifest SHA, and latest/versioned byte equality all verify for version `1.0`, build `16`.
- Added `scripts/verify-public-dmg.sh` and wired `scripts/verify-release.sh --public-dmg-check` so the currently public DMG can be downloaded, image-verified, Gatekeeper/notarization-checked, mounted read-only, checked for `Voiyce.app` plus the `/Applications` symlink, app-signature-checked, bundle-version-checked, secret-scanned, and detached without installing or mutating release artifacts.
- Corrected `docs/releases/Voiyce-1.0+16.md` to match the current public R2 manifest checksum `bfed37a6f089eb83d0d5426fc5d25dbd709184bf2f85feceefac70ee68c485d5` and recorded the 2026-05-18 public artifact verification result.
- Hardened `scripts/verify-launch-site.sh --url` so live checks fetch `/`, `/auth?intent=download`, `/download?intent=download`, `/privacy`, and `/terms`, then verify key CTAs, rendered positioning copy, agent labels, and legal contact content.
- Added legal product-coverage guardrails to `scripts/verify-launch-site.sh`.
- Added download URL fallback guardrails to `scripts/verify-launch-site.sh`.
- Added launch-site checks for required icon/favicon/OG assets, social metadata, and production-preview `/icon.png`, `/favicon.ico`, and `/og-header.png` payload validation, including PNG/ICO signatures and expected image dimensions.
- Expanded backend function tests across Computer Use, Realtime, transcription, and screen-context functions.
- Verified server-side kill switches for `VOIYCE_DISABLE_ALL_AI`, `VOIYCE_DISABLE_REALTIME`, `VOIYCE_DISABLE_TRANSCRIPTION`, `VOIYCE_DISABLE_COMPUTER_USE`, and `VOIYCE_DISABLE_SCREEN_CONTEXT`.
- Verified server-side request caps for Realtime SDP, transcription audio, Computer Use task/screenshot payloads, and screen-context images.
- Verified client model overrides for Realtime and transcription stay disabled unless the matching allow flag is set.
- Added `scripts/verify-agent-usage-caps.sh` and wired `scripts/verify-release.sh` to statically verify the Default/Pro/Power usage-cap matrix, cap documentation alignment, reserve/finalize RPC hardening, and Realtime/transcription/Computer Use/screen-context usage-cap wiring before the backend Deno test suite runs.
- Added app-termination cleanup for active dictation and Agent sessions: quitting Voiyce now tears down hotkeys, cancels local dictation recording state, stops the Realtime bridge/server, clears active Agent runtime state, locally stops session-context capture, and logs context shutdown.
- Added system sleep/wake cleanup for active dictation and Agent sessions: before macOS sleeps, Voiyce tears down local runtime, stops Realtime bridge/server state, clears active Agent state, locally stops session-context capture, and records a restartable wake state after the Mac wakes.
- Added display-layout change recovery: Voiyce clears transient action/focus/tour overlays when macOS display geometry changes, clears saved focus regions that may point at stale coordinates, lets Context/Talk continue with fresh screen captures, and pauses active Act mode so stale screen coordinates cannot keep driving actions.
- Added account access-loss cleanup: signed-out or payment-required transitions clear active dictation/Agent runtime state, stop Realtime/session-context work, log a recovery event, and prevent Agent hotkey starts until access is active again.
- Added per-account local memory isolation so signed-in account changes re-scope the long-term memory index, screenshot directory, vault path setting, retention settings, Private Mode, and app/site exclusions.
- Added stable source labels to Agent tool results so current screen inspection returns `memory_source=current_screen`, active session context returns `memory_source=session_context`, and long-term memory returns `memory_source=long_term`.
- Added richer Obsidian-style daily-note frontmatter for local memory vault notes: date, Voiyce source, source modes, app hints, tags, privacy level, screenshot retention, and account scope.
- Added local memory usage tracking for record count, captures today, screenshot count/bytes, vault note count/bytes, index bytes, and total storage bytes; memory tool results and Memory saved Agent Log events now expose the current usage state.
- Added `scripts/verify-release-source-state.sh`, a no-mutation source provenance gate for clean-tree status, Xcode version/build consistency, and release tag-to-HEAD verification. `scripts/verify-release.sh --source-state-check` can include it before build/package work on a release branch.
- Added a `--dirty-summary` prep option to `scripts/verify-release-source-state.sh` so release-source reviews can include a non-mutating breakdown by Git status and top-level surface before deciding what to include, split, remove, or defer.
- Added `scripts/generate-release-source-disposition.sh`, a no-write markdown generator that pre-fills the release-source inclusion review with branch, HEAD, dirty-path count, status/surface summary, and every dirty path grouped for include/split/remove/generated/owner disposition.
- Added `scripts/generate-launch-evidence-package.sh`, a no-write markdown generator that pre-fills the launch evidence package with current source facts plus required command, artifact, production/account, manual UAT, privacy/security, and final decision evidence fields.
- Added `scripts/generate-manual-uat-pass.sh`, a no-write markdown generator that pre-fills the manual UAT execution sheet with current source facts, surface assignments, scripted row results, required timing/checksum/permission measurements, bug severity fields, and hold rules.
- Added `scripts/generate-production-evidence-packet.sh`, a no-read-secret/no-write markdown generator that pre-fills production/account evidence for OpenAI key rotation, AI usage/quota monitoring, InsForge env/database, Vercel landing, R2 artifacts, Stripe billing, support ownership, monitoring, and launch hold rules.
- Added `scripts/verify-evidence-generators.sh`, a no-write verifier that executes the release-source, launch evidence, manual UAT, and production evidence generators, checks required rendered sections/current dirty count/support contact, and scans output for OpenAI-style secret patterns.
- `scripts/generate-production-evidence-packet.sh` now includes the AI usage/quota monitoring section, and `scripts/verify-evidence-generators.sh` verifies the rendered production packet includes OpenAI usage dashboard and pause/narrow/continue decision fields.
- Added `scripts/verify-launch-blockers.sh`, a no-write verifier that runs the prep audit and fails if the blocker set differs from the eight known launch gates.
- Reran `scripts/verify-launch-site.sh --url http://localhost:23000` on 2026-05-19 against the local dev server; lint, production build, landing build secret scan, live routes, social/favicons, home CTAs, auth/download, and legal content all passed with zero lint warnings.
- Fixed the landing Agent Context logo strip so Hermes Agent and OpenClaw render as real Next image elements with local assets, then reran `scripts/verify-launch-site.sh --url http://localhost:23000 --visual`; desktop/mobile visual QA passed and captured home/auth/download/privacy/terms screenshots.
- Added shared backend safe-error helpers for client-facing failures and redacted operational logs.
- Hardened Realtime, transcription, Computer Use, and screen-context functions so upstream OpenAI failures return generic client-safe errors instead of raw upstream bodies.
- Added backend regression tests proving upstream secret-like error payloads are not exposed to clients across Realtime, transcription, Computer Use, and screen-context.
- Added backend failure-injection tests proving Realtime, transcription, Computer Use, and screen-context preserve OpenAI 401 and 429/quota-style statuses while returning generic, scrubbed client bodies.
- Added a Computer Use abuse guard that rejects high-confidence credential-theft, catastrophic-deletion, fraud, illegal-access, and hidden-action requests before OpenAI is called.
- Added backend auth-provider failure tests proving Realtime, transcription, Computer Use, and screen-context stop before OpenAI and return generic, scrubbed client errors when InsForge session lookup fails.
- Added backend InsForge database/RPC failure tests proving Realtime, transcription, Computer Use, and screen-context stop before OpenAI and return generic, scrubbed client errors for infrastructure failures.
- Added screen-context usage reservation/finalization so Context requests participate in the internal cap ledger when cap enforcement is enabled.
- Added backend regression tests proving Realtime, transcription, Computer Use, and screen-context reserve and finalize estimated usage by capability when `VOIYCE_ENFORCE_AGENT_USAGE_CAPS` is enabled.
- Added structured usage units to the server-side agent usage ledger so cost-bearing events record the quantities behind estimated spend: Realtime estimated session seconds, transcription audio seconds/bytes, Computer Use step/screenshot/task/action/safety-check counts, and screen-context screenshot/image/prompt units.
- Added backend account-limit response hardening so Realtime, transcription, Computer Use, and screen-context cap hits return clear `402` / `usage_limit_reached` responses before OpenAI is called, while auth/database/provider failures remain generic and redacted.
- Added app-side account-limit recovery so Dictation, Talk, Act, and screen context map `usage_limit_reached` / HTTP 402 responses to plain user-facing copy and quota-style Agent Log events instead of transport/provider details.
- Added upgrade-limit copy to Settings and the checkout plan picker: Pro keeps dictation active after trial, Context/Talk/Act use beta budgets, and Power-level Act limits are not sold in this build.
- Added app-side Default/Pro/Power capability gates: Default exposes Context and Talk but not Act, paid/beta/Pentridge access maps to Pro for the current beta surface, and the future Power tier maps to full Agent modes plus Power memory storage.
- Verified the capability-gate slice with the focused Swift test target: 98 tests passed, including tier matrix and unsupported persisted-mode reconciliation coverage.
- Verified access-loss cleanup with the focused Swift test target: 100 tests passed, including active state reset and signed-out/payment-required recovery copy coverage.
- Added backend CORS preflight and unsupported-method tests for Realtime, transcription, Computer Use, and screen-context functions.
- Documented temporary internal daily/monthly cap values and usage-estimate environment variables in `docs/phase-2-production-hardening.md`.
- Added Swift unit coverage for sensitive-context memory skips and support-export redaction without clearing local user memory or creating a support export.
- Made the long-term memory store testable with isolated storage/defaults and tightened session-only memory so it does not leave durable screenshot files behind.
- Added Swift unit coverage for memory deletion, summary retention modes, raw screenshot retention, private mode/exclusions with screenshots enabled, memory search, and plain Markdown vault output.
- Tightened Privacy Policy and beta communications so local memory, raw screenshot retention, Private Mode, exclusions, support exports, and delete behavior match the app’s implemented storage controls.
- Added launch-site guardrails that verify the Privacy Policy includes concrete local storage behavior, not only broad product keywords.
- Added a Google OAuth scope review table and Swift guardrail test so new scopes require an explicit review.
- Verified third-party account copy does not imply Gmail/Calendar access before Google OAuth is connected.
- Added Stripe live-mode guardrails so checkout, billing portal, and billing sync reject `sk_live_...` unless `STRIPE_ALLOW_LIVE_MODE=true` is explicitly set.
- Verified Terms subscription/refund/cancellation copy against the active Stripe flow: monthly/yearly Pro checkout, in-app billing portal management, and cancellation stopping future renewals while access remains through the current billing period.
- Wired the Agent Log screen export button to create the existing redacted support bundle.
- Removed the inert Agent Log inspector control and made event IDs copyable from expanded log rows.
- Added Swift unit coverage proving a generated support export JSON file redacts sensitive event titles, summaries, and details.
- Hardened Agent Log storage so sensitive event titles, summaries, and details are redacted before events are saved to disk or shown in the log.
- Hardened Agent Log storage and support exports so detail fields named transcript, dictation, screenshot, image, base64, or raw screen/context redact their values before disk write or export.
- Added redaction for screenshot-style image data URLs and long base64-like blobs in support-facing text.
- Added Swift unit coverage proving raw transcript, screenshot, image data URL, and long blob payloads are redacted from stored Agent Log JSON and support export JSON.
- Removed raw transcript text, raw thrown errors, and temporary recording filenames from dictation/audio debug logs; transcription logs now record word counts only, with Swift coverage preventing transcript phrases from returning to debug output.
- Added a launch audit guard so `scripts/audit-launch-readiness.sh --allow-blockers` fails if the touched dictation/audio paths regain raw transcript, thrown-error, or temporary recording-path debug prints.
- Added a launch audit guard for the support contact so the macOS app, landing config, launch-site verifier, and production verifier stay pinned to `aki.b@pentridgemedia.com`, while legacy Voiyce support-address contacts fail the audit.
- Added a launch audit guard that verifies `scripts/verify-launch-site.sh` still enforces zero-warning landing lint, raw image regression checks, landing build secret scanning, accessibility smoke checks, and `/api/download-health`.
- Added a launch audit guard that verifies `scripts/verify-launch-visuals.mjs` keeps the Hermes Agent and OpenClaw image-load assertions after the Agent Context logo strip fix.
- Tightened the landing source and visual verifiers so OpenClaw must use the local `/openclaw.svg` asset instead of a remote favicon URL.
- Added a launch audit guard that fails if stale docs or tasks reintroduce accepted Next.js landing image-warning language after the raw image cleanup.
- Added a launch audit guard that verifies `scripts/verify-production-landing.sh` still enforces stale-copy rejection, `/api/download-health`, legal contact, social image/favicon payload checks, and current agent-context positioning.
- Added a launch audit guard that verifies `scripts/verify-rollback-readiness.sh` still checks the current public manifest/artifacts, previous rollback candidate, local rollback manifest generation, and the no-R2-mutation guarantee.
- Added a launch audit guard that verifies `scripts/verify-release.sh` still includes source and built-app secret scans, usage-cap verification, launch-site verification, archive/public-DMG hooks, and the production landing hook.
- Extended the release verifier audit guard to require the source-state hook, signed local package command, public-download manifest hook, and the `--skip-ui-tests` diagnostic-only warning.
- Added a launch audit guard that verifies `scripts/verify-release-source-state.sh` still checks clean-tree state, version/build values, tag-to-HEAD alignment, and prep-stage blocker reporting.
- Added a launch audit guard that verifies `scripts/verify-public-dmg.sh` still checks checksum, image verification, Gatekeeper/notarization, read-only mounting, Applications symlink, app signature, bundle version/build, and mounted app secret scanning.
- Added a launch audit guard that verifies `scripts/verify-release-archive.sh` still archives to a temporary path, checks archived app presence, verifies codesign, and scans the archived app for OpenAI keys without export/DMG mutation.
- Added a launch audit guard that verifies exact-artifact release records keep version/build, commit, R2 URLs, checksum, notarization/signing, source-state warning, a dirty-tree blocker count matching the current Git status, and the full release-candidate gate note.
- Reconciled `docs/agent-tier-cost-plan.md` with the current usage-cap implementation: server-side Realtime/transcription/Computer Use/screen-context caps now exist behind `VOIYCE_ENFORCE_AGENT_USAGE_CAPS=true`, while production env and Stripe tier mapping confirmation remain open.
- Added a launch audit guard that verifies the tier/cost plan keeps the current server-side cap status, production env/tier-mapping blocker, per-tier hard-cap scope, AI kill-switch scope, and paid-production confirmation steps.
- Added a launch audit guard that verifies `docs/phase-2-production-hardening.md` keeps server-side-only environment guidance, OpenAI key requirement, AI kill switches, request caps, usage-cap enforcement env, and the remaining external blocker list.
- Added a launch audit guard that verifies `docs/stripe-billing-connection.md` keeps Stripe live-mode and pricing configuration warnings, and that checkout, portal, and billing-sync functions/tests continue blocking `sk_live_...` unless `STRIPE_ALLOW_LIVE_MODE=true`.
- Extended the Stripe billing audit guard to verify the webhook handler keeps `Stripe-Signature` verification, subscription created/updated/deleted handling, `apply_stripe_subscription_update` wiring, cancel-at-period-end handling, active-plan mapping, and the SQL RPC grant/update behavior.
- Added focused Stripe webhook Deno tests for missing-signature rejection before database calls, ignored signed events with no billing update, and signed subscription updates mapping customer/subscription/status/price/cancel/plan fields into the billing RPC payload.
- Added a Stripe live billing review template so paid launch cannot proceed without recorded live-mode decision, product/price ids, checkout and portal evidence, webhook endpoint/signing-secret presence, subscription mapping, refund/cancellation copy, support owner, no-secret handling, and final sign-off.
- Hardened the VideoDB-backed session-context function so auth/provider failures return generic client-safe errors, request validation stays explicit, and provider errors are logged through the shared redactor instead of being returned to the app.
- Added a `VOIYCE_DISABLE_SESSION_CONTEXT` kill switch and `VOIYCE_SESSION_CONTEXT_MAX_QUERY_CHARS` search-query cap to bound VideoDB-backed session context without shipping a new app build.
- Added shared safe-error tests for bearer and `x-access-token` redaction, plus VideoDB session Deno tests for preflight/method handling, kill-switch behavior before env lookup, auth-provider failure before VideoDB calls, validation before upstream calls, query-cap enforcement, and generic upstream failure responses.
- Added a launch audit guard that verifies the VideoDB/session-context function and shared safe-error helpers keep the new client-safe failure, redaction, kill-switch, and query-cap coverage.
- Hardened app-side dictation fallback errors so unexpected transcription failures no longer retain raw provider/backend localized descriptions in `WhisperError` associated values, with Swift coverage proving backend/key/token terms are not carried into the recoverable error object.
- Extended the launch audit guard so Whisper fallback errors cannot regress to storing raw `localizedDescription`, upstream messages, or provider/backend details in recoverable transcription errors.
- Removed raw `localizedDescription` payloads from remaining local debug prints in billing, overlay first-frame generation, and permission diagnostics, then added a launch audit guard against those prints returning.
- Added a launch audit guard that verifies the manual UAT matrix still covers required evidence, ship/hold exit rules, clean install/permissions, Dictation, Context, Talk, Act, visual/navigation polish, website/legal/download, resilience, blocked action, and support export rows.
- Added a pre-invite decision record template so the final self-serve launch decision has one place for artifact identity, source-state proof, automated gates, production evidence, clean-machine UAT, manual UAT, environment evidence, rollback ownership, support ownership, blockers, accepted limitations, and owner sign-off.
- Added a launch audit guard that verifies beta communications remain internally held, Beta-labeled, agent-context positioned, support-contact aligned, and complete across known limitations, permissions, privacy/memory, data processing, support escalation, monitoring, and clean-install instructions.
- Added a support intake template for beta reports covering severity, owner, environment, mode, permissions, account state, reproduction, reviewed screenshots/exports, event IDs, user-facing replies, and privacy boundaries for transcripts, screenshots, secrets, OAuth tokens, and payment details.
- Added an invite-resume checklist so invites cannot restart after a pause, incident, failed verification, backend change, landing deployment, billing change, or artifact change without current blocker status, support queue status, production verification, exact-artifact identity, clean-machine/manual UAT evidence, environment evidence, rollback readiness, support-copy alignment, and owner sign-off.
- Added a final privacy and security review template so source/bundle secret scans, support export redaction, local memory paths, legal/privacy copy, production env evidence, OpenAI key rotation, Stripe mode, and no-secret handling are reviewed in one place before invites resume.
- Reconciled the top-level PRD implementation status so it no longer lists raw screenshot retention, app/site exclusions, and memory deletion UX as open after those controls received deterministic coverage and launch audit guardrails; the open list now focuses on pricing/tier mapping, production usage-cap confirmation, Context tuning, Computer Use pending-safety resume behavior, Act hardening, spoken UAT, clean-machine UAT, billing, and production landing verification.
- Added a release-notes send gate that distinguishes generic draft notes from exact-artifact notes and requires artifact identity, production landing verification, clean-machine/manual UAT evidence, production environment evidence, accepted limitation workarounds, support/privacy copy alignment, reviewed-support-export instructions, and owner sign-off before sending.
- Added a launch evidence package template so automated gates, clean-machine proof, manual UAT, privacy/security review, production environment evidence, Stripe/account evidence, support readiness, rollback readiness, accepted limitations, and owner sign-off are linked in one place before invites or release notes go out.
- Added evidence naming and privacy-review rules for command logs, screenshots, recordings, dashboard captures, support exports, redactions, and missing-evidence substitutions so each item maps back to an exact gate, UAT row, risk, or decision.
- Added a final self-serve preflight sequence that separates non-mutating prep checks, exact-candidate checks, manual/account evidence, and artifact-changing release commands so launch work cannot accidentally skip source-state, public download, public DMG, production landing, clean-machine, or UAT proof.
- Added a release source inclusion/exclusion review template so every dirty tracked or untracked path is either intentionally included in the release candidate, split out, removed, or documented as generated output before any clean-tree tag or fresh DMG.
- Tightened the release source review with a dirty-tree disposition summary, including include/defer/remove/generated/needs-owner counts, high-risk surface review, matching evidence, and unresolved-path count before source freeze.
- Added a manual UAT execution assignment section so clean install, Dictation, Context, Talk, Act, web/legal/download, accessibility, billing/account, resilience, and exploratory QA each need an owner, target environment, evidence link, and pass/hold status before the final launch decision.
- Expanded the manual UAT audit guard so permission denial/revocation, sign-in recovery, offline dictation, current-screen Talk, Talk network drop, Act stop/permission/mid-task behavior, checkout/portal access, public artifact verification, and resilience rows cannot disappear from the launch matrix.
- Extended the beta communications audit guard to verify uninstall/reset-memory guidance remains present, prefers in-app memory deletion, identifies the current build's Voiyce-owned local memory paths, and keeps manual local reset support-guided.
- Added a launch audit guard that verifies the rollback runbook keeps the smallest-surface rollback principle, dirty-tree DMG warning, support contact, severity/triage sections, landing/R2/backend/app rollback paths, post-rollback verification, and incident note template.
- Expanded the rollback incident note template with owners, pause decision, rollback surface, user/data/billing impact, support-report links, kill-switch changes, rollback command evidence, clean-machine verification, invite-resume criteria, and final owner sign-off, with audit guards for the required fields.
- Added a rollback resume checklist so invites cannot restart after rollback until incident notes, production landing, R2 artifacts, public-download verification, clean-machine evidence, manual smoke, kill-switch/limitations copy, support ownership, exact version/build copy, blocker status, workarounds, and owner sign-off are recorded.
- Added stable support export schema metadata (`schemaVersion`, `bundleKind`) and event IDs so future support tooling can extend exports without changing the stored Agent Log event model.
- Added a production evidence packet template so OpenAI key rotation, InsForge env/database state, Vercel deployment, R2 artifacts, Stripe mode, support ownership, no-secret handling, open blockers, and final sign-off can be recorded consistently without exposing secret values.
- Added an OpenAI key rotation evidence checklist so exposed-key revocation, replacement-key server-side storage, source/bundle secret scans, post-rotation smoke, optional old-key negative check, usage/quota alerts, and security owner sign-off can be recorded without copying secret values.
- Added a production landing cutover evidence checklist so the Vercel deployment id, deployed commit, download env, auth env, auth callback/sign-in smoke, production smoke checks, stale-copy rejection, R2 artifact identity, rollback deployment, monitoring window, blockers, and final sign-off are captured before invites or release notes resume.
- Added exploratory QA charters to the manual UAT matrix so real founder work sessions, permission chaos, privacy edge cases, Agent stress loops, account/billing edges, visual polish, and public web/artifact sweeps are tested beyond scripted happy paths.
- Added a launch test strategy document that maps automated gates, manual UAT, exploratory testing, privacy/security testing, production account testing, and final evidence packaging to concrete commands, evidence, and launch hold rules.
- Added a beta support response playbook for install/download, permissions, Dictation/Talk, Act safety/Stop, billing/account, and privacy/memory reports, including privacy-safe data requests and pause conditions.
- Added a launch monitoring evidence template so first-hour, first-day, weekly expansion, and after-change monitoring records capture owners, surface checks, signal counts, command/dashboard evidence, invite decisions, and pause rules without copying private data or secrets.
- Added a launch risk and exception register template so accepted P2 limitations, skipped diagnostics, external/account blockers, support workarounds, escalation triggers, and owner sign-off are tracked in one place before any invite or release-note decision.
- Added an invite batch control template so every beta expansion records owner coverage, target persona/count, exact artifact identity, linked evidence, known limitations, monitoring window, pause criteria, and final sign-off before a batch is sent.
- Added severity response targets for beta support so P0/P1/P2/P3 reports have first-response expectations, owner expectations, invite decisions, evidence requirements, escalation rules, and launch-hold behavior.
- Added a clean-install evidence checklist so the physical clean-machine blocker has one pass/hold/rerun record covering DMG identity, Gatekeeper, sign-in, permissions after quit/reopen, Dictation, Context, Talk, Act Strict, Agent Log, Settings, memory reset, legal/download, P0/P1/P2 findings, privacy-safe evidence review, and owner sign-off.
- Added explicit manual accessibility UAT rows for keyboard-only navigation, VoiceOver labels/roles, and reduced-motion/increased-contrast comfort across onboarding, Dashboard, Settings, Agent, Agent Log, dialogs, overlays, Action Cursor, Focus Highlight, and active-mode status.
- Added a support inbox readiness record so invite batches require a primary owner, backup owner, engineering/billing/rollback escalation owners, first-hour/first-day coverage, intake/playbook readiness, privacy-safe support-export instructions, pause authority, and owner sign-off.
- Added a known-limitation workaround register so permission-dependent modes, dense/blocked Act UI, pending safety checks, local-first memory, Talk latency, and Google-connected features each have user impact, workaround copy, support action, owner, and ship/hold decision.
- Added an Act safety incident checklist for unexpected actions, missing confirmations, blocked-action reports, sensitive workflows, Stop failures, and app-control concerns, including safety mode, visible action, Stop state, sensitive surface, Agent Log IDs, invite decision, kill-switch consideration, and hold rules.
- Prep verification update: `scripts/verify-release-source-state.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --allow-blockers` passes version/build/branch checks and still reports the expected dirty-tree and missing-tag blockers; `scripts/verify-rollback-readiness.sh` could not resolve the public R2 host inside the sandbox, so rollback evidence still needs a networked read-only rerun before invites.
- Added support-useful Agent Log permission-block events for missing Screen Recording and Accessibility permissions across screen context, Act command setup, Computer Use, and text/click/key tools.
- Added Swift unit coverage proving permission-block events are stored with feature, permission, and next-step detail and appear in the redacted support export.
- Added support-useful Agent Log service-failure events for OpenAI-backed Realtime, transcription, and Computer Use failures, including upstream status and concrete next steps.
- Added Swift unit coverage proving quota/rate-limit service-failure events are stored with feature, service, upstream status, and next-step detail and appear in the redacted support export.
- Added bridge-level Agent Log events for failed Realtime tool calls while avoiding duplicate logs for confirmation waits and already-blocked catastrophic actions.
- Removed the unused demo usage-data seeding hook so dashboard usage analytics cannot accidentally populate sample words/sessions in production.
- Added bridge-level Agent Log events for successful Realtime tool calls using support-safe summaries, tool names, result state, and data-field names only.
- Added Act loop Agent Log events for planned action batches, no-action finishes, post-action screen-capture failures, max-step finishes, and cancelled Computer Use runs using action-type-only details.
- Added injected Swift coverage proving Act mode fails safely and writes support-useful permission events when Accessibility or Screen Recording is missing, and that cancellation can stop before the action loop while writing a cancelled Agent Log event.
- Added Action Cursor guardrails so local Act actions show a visible animated cursor/status lead-in before posting local events, cancellation can stop during that lead-in, the cursor is gated to active Act/action presentation or preview mode, multi-display Computer Use coordinates map from the captured display frame, and the cursor overlay is test-covered as non-activating, mouse-transparent, all-spaces/full-screen friendly UI.
- Added Focus Highlight guardrails so rectangle, paint, and underline marks use test-covered screen-coordinate geometry, the global focus shortcuts dispatch the expected mark modes, passive post-selection guides remain mouse-transparent, focused-region capture selects/crops the correct display region including Retina scaling and off-edge clipping, and create/clear events are written to Agent Log.
- Added support-useful Agent Log memory-error events for local memory index, screenshot, vault directory, vault note, and deletion failures, including operation, path, and next-step detail.
- Added Swift unit coverage proving memory-error events appear in the redacted support export.
- Added durable Agent mode selection persistence so the selected Agent mode and safety mode survive fresh `AppState` instances.
- Polished the Agent screen so Act copy uses user-facing action language instead of exposing Computer Use internals.
- Added macOS UI coverage for the Agent screen title, subtitle, four-mode selector, status, Off-disabled Start button, Context start/stop state, Act safety note, and absence of internal implementation terms.
- Expanded macOS UI copy guardrails so Dashboard, Settings, Agent, and Agent Log stay user-facing and do not expose backend/internal implementation terms, with stable Settings permission-row identifiers to keep the navigation test deterministic.
- Added menu bar launch-copy guardrails and stable menu action identifiers so the menu bar stays user-facing and test-addressable without exposing backend/internal implementation terms.
- Added app menu commands for Dashboard, Agent, Agent Log, Settings, and Focus Tools, with launch-copy guardrails so the app menu stays user-facing and avoids backend/internal implementation terms.
- Changed Agent hotkey wiring to an explicit Option toggle callback so pressing Option toggles the selected Agent mode and releasing Option does not stop it.
- Documented the Agent Mode hotkey in Settings > Hotkeys with concise start/stop copy separate from hold-to-dictate.
- Added Swift unit coverage for Agent hotkey press/release semantics and UI coverage for the Settings hotkey documentation.
- Added an explicit Agent context-consent panel: context capture starts only after Start or Option, Stop pauses capture, and Private Mode pauses live context and skips saved memory/screenshots.
- Extended live session context privacy controls so Private Mode, sensitive-context detection, and app/window exclusion matches block capture before it starts and stop an already-running session context capture.
- Added first-class Agent Log events for session context capture start, stop, failure, and privacy-pause states, and cleared stale session/stream ids when capture stops.
- Added deterministic coverage for the continuous Context capture helper: Microphone and Screen Recording permission requests, microphone/display/system-audio channel selection, selected-channel storage, capture session start, and event consumption.
- Made Agent mode runtime boundaries explicit: Context starts session context only, Talk and Act start Realtime voice, Act is the only action-capable mode, and failed Context capture shows recovery-oriented `Needs review` status in the Agent screen.
- Context-only startup failures and privacy pauses now recover to a non-running `Needs attention` state instead of leaving Agent visually active; Talk and Act keep the voice session active when only session context fails.
- Added an explicit Settings > Permissions `Refresh Status` control, updated Pro permission refresh polling so it does not stop before Screen Recording state is current, and centralized Settings/onboarding permission-state copy with unit coverage for granted and denied states.
- Strengthened permission-return coverage so returning from macOS permission prompts restores the original Voiyce surface once, clears the saved return target, and cannot trigger a duplicate reroute loop on a second restore pass.
- Hardened local Agent tool validation ordering so missing required details are reported before Strict/Normal safety confirmation logic can ask for approval.
- Added deterministic no-network launch coverage for the signed-out auth path: UI tests can force signed-out/offline state, the auth screen shows concrete reconnect copy, Google/email sign-in buttons are disabled while offline, and Swift copy guardrails keep backend/provider terms out of the launch/auth recovery strings. Physical network-off launch from a downloaded app still needs manual UAT.
- Added deterministic dictation network-loss recovery coverage: a dropped transcription request maps to the user-facing no-internet state and writes a support-useful Transcription service failure with reconnect next step. Physical network-off dictation UAT still needs to be run from the downloaded app.
- Added Talk/Act WebRTC connection-loss recovery telemetry: mid-session peer or ICE failure now emits `connection_lost`, stops the browser bridge cleanly, and writes the same support-useful Talk service failure used for startup network failures. Physical network-drop Talk UAT still needs to be run from the downloaded app.
- Added mode-specific Agent permission recovery: Context blocks/stops when Microphone or Screen Recording is missing, Talk blocks/stops when Microphone is missing, and Act blocks/stops when Microphone, Screen Recording, or Accessibility is missing, with support-useful Agent Log permission events.
- Added web auth/download resilience guardrails: `scripts/verify-launch-site.sh` now verifies support-safe auth recovery copy, the download-health API route, current live `/api/download-health` success, and degraded download recovery copy.
- Added macOS UI coverage for the Agent context-consent copy and for visible Stop controls during active Talk and Act sessions.
- Added shared active Agent status for the sidebar and menu bar, with coverage proving active Context and Act modes stay visible outside the Agent screen.
- Added an Agent mode map on the Agent screen so Off, Context, Talk, and Act explain their behavior, permission needs, and control boundaries in-app without relying on external docs.
- Improved the Agent Log screen with support-ready timeline/action/export cues, detail-aware search, clearer empty states, and macOS UI coverage.
- Hardened the active Act command lifecycle so a running one-off Act command exposes the main Stop action, cancels the active command task, returns the main action to Start, and writes Agent Log start/cancel events.
- Added an explicit Act safety-mode choice before first use: Act Start and one-off Act commands stay disabled until the user chooses Strict, Normal, or Unrestricted, the choice persists, and unconfirmed bridge actions fall back to Strict behavior.
- Added a testable Act action safety policy for Strict, Normal, and Unrestricted confirmation behavior, explicit action/target/consequence confirmation copy, and local blocks for catastrophic deletion, credential theft, malware, fraud, illegal access, hidden actions, and platform-abusive actions.
- Added Agent Log entries for approved confirmations so requested, approved, and cancelled confirmation decisions are visible in support review.
- Added Stop Session as a first-class confirmation decision, wired it to the existing Agent stop request, and added Swift unit coverage proving stopped/cancelled confirmations cannot be approved or executed later.
- Added embedded Realtime client confirmation coverage so pending confirmations keep visible Confirm, Cancel, and Stop Session paths plus voice-driven `confirm_pending_action` wiring. The Realtime tool schema now advertises `approve`, `cancel`, and `stop_session` decisions so spoken stop requests can route to the existing stop path.
- Added backend Realtime instruction coverage so pending-confirmation voice guidance routes approve, cancel, and stop-session decisions to `confirm_pending_action`.
- Hardened confirmations so the native prompt orders front across spaces, stays visible after app deactivation, tool results include a spoken safety reason, and stale pending confirmations time out with support-visible Agent Log events and no later execution path.
- Changed OpenAI Computer Use pending safety checks to fail with a clear Act recovery path instead of returning a non-resumable confirmation id.
- Added support-export-covered Agent Log events for Act safety-check stops so pending safety checks include a plain-language reason and next step.
- Removed remaining app-source Release build warnings by updating permission callback isolation, target-app reactivation, audio compression export, and owl overlay first-frame generation to current macOS APIs. The Release build now has no app-code warnings; Xcode still prints its generic AppIntents metadata notice because the app has no AppIntents dependency.
- Centralized first-run onboarding permission copy and added Swift unit coverage proving it explains Microphone, Speech Recognition, Accessibility, and Screen Recording access in plain language without provider/backend/API terms.
- Replaced onboarding and dashboard dictation service-limit/transcription-failure recovery copy with plain beta-support next steps, and added a Swift unit guard against provider keys, backend billing details, server-function language, and raw secret-management terms in that recovery copy.
- Replaced Act command runtime recovery copy with plain Act mode next steps for empty commands, sign-in, permissions, confirmations, rate limits, invalid responses, and service failures, with a Swift unit guard against Computer Use/backend/provider terminology returning to those user-facing strings.
- Replaced Talk startup recovery copy with plain Talk mode next steps for sign-in, local audio setup, invalid responses, rate limits, and connection failures, with a Swift unit guard against provider/backend terminology returning to those user-facing strings.
- Added Talk latency QA targets and support-safe Agent Log telemetry for connection readiness, first response, tool-call duration, and interruption settling.
- Added Realtime connection-failure recovery so microphone denial and connection failure stop the active Talk/Act state, show a clear Agent-screen recovery message, and write support-useful Agent Log events.
- Added embedded Realtime client coverage for the Talk/WebRTC setup path: microphone capture, peer audio tracks, SDP session creation, remote answer application, remote audio playback, and audio-ready telemetry.
- Centralized Realtime session instructions and added Deno coverage requiring natural progress check-ins for long tool/context waits plus explicit Talk/Act mode boundaries.
- Added Realtime instruction coverage for Talk context routing: screen-dependent questions use current-screen inspection, current-session history uses active-session context, previous-work questions use saved memory, and missing Screen Recording routes to recovery instead of guessing.
- Added Swift telemetry coverage proving Talk interruption-completed events write Agent Log QA measurements with the launch interruption target and review label.
- Tuned Realtime turn detection to semantic VAD with low eagerness so Talk waits longer through natural pauses before responding.
- Added Realtime instruction coverage requiring Talk to state missing Google OAuth or missing macOS permissions as the blocker with a next step, instead of inferring inbox, calendar, screen, account, or app access.
- Replaced dictation transcription Agent Log service-failure copy with plain Transcription service recovery steps, with a Swift unit guard against provider/backend/server-function terminology in stored Agent Log and support export events.
- Replaced active-session context/search/summary copy with provider-neutral Session context language, and added a Swift unit guard against VideoDB/Computer Use/OpenAI/backend/runtime terms returning to those user-facing strings.
- Hardened remaining visible Auth, Billing, Google connection/OAuth callback, screen context, Agent tool bridge, Act unexpected-failure, support-export write, session-context helper, and memory-error paths so raw SDK/OAuth/API/backend/token/localized failure text is not shown to users or copied into support-facing summaries.
- Added Swift unit coverage proving Auth/Billing recovery copy, Google recovery copy, Agent tool bridge failures, Act unexpected failures, session-context raw helper/backend text, and memory-error support export summaries stay plain and actionable.
- Added `docs/beta-launch-communications.md` with the Beta label decision, beta invite copy, draft release notes, known limitations, permissions explanation, privacy/memory summary, data processing map, support path, launch-day monitoring checklist, and uninstall/reset-memory note.
- Added `docs/releases/Voiyce-1.0+16-beta-release-notes.md` with exact current public-artifact release notes for version `1.0`, build `16`, including R2 URLs, checksum, recorded Git commit, known limitations, support path, verification evidence, and owner-controlled beta sharing status.
- Added `scripts/verify-production-landing.sh`, a no-build/no-deploy production smoke gate that fetches the public landing routes, verifies the revised agent-context positioning, rejects stale dictation-first launch copy, checks legal contact, checks `/api/download-health`, and validates icon/favicon/OG payloads.
- Wired `scripts/verify-release.sh --production-landing-check` and `--production-url <base-url>` as opt-in production landing verification, so release candidates can include the public landing smoke gate without changing the default local/no-deploy gate.
- Added `docs/launch-rollback-runbook.md` with landing, R2 DMG, backend function, and app artifact rollback steps.
- Added `scripts/verify-rollback-readiness.sh`, a no-mutation R2 rollback dry-run that verifies the current public manifest/artifacts, verifies a previous versioned DMG rollback candidate, and generates the rollback `latest.json` locally for review.
- Added `scripts/audit-launch-readiness.sh`, a no-build/no-package launch status audit that verifies the required readiness docs/scripts, exact-artifact hold state, visible PRD/tracker blockers, optional live production landing status, and public R2 manifest metadata.
- Added `scripts/verify-release-archive.sh` and wired `scripts/verify-release.sh --archive-check` so the Release archive path can be verified in a temporary directory without creating a DMG, notarizing, uploading, or changing existing release artifacts.
- Ran the integrated diagnostic release gate with `scripts/verify-release.sh --skip-ui-tests --archive-check`, proving the broader release verifier can include the temporary archive check without packaging, notarizing, uploading, or mutating existing release artifacts.
- Added clean-install instructions and support escalation paths to `docs/beta-launch-communications.md`.
- Replaced remaining legacy support-address references in repo docs/pages with `aki.b@pentridgemedia.com`.
- Centralized the macOS app support email in `AppConstants.supportEmail` and added `launchSupportEmailStaysConsistentAcrossAppCopy` so usage-limit and dictation recovery copy cannot drift from the launch/legal contact.
- Centralized the landing-page support email in `voiyce-config.ts`, routed auth/download/legal copy through that constant, and updated the launch-site verifier to guard the shared web contact source instead of page-local literals.
- Replaced remaining landing raw `<img>` elements in the app/auth/download surfaces with Next image handling or non-image icon presentation, removing the final landing ESLint image warnings.
- Added a launch-site guardrail that fails if raw `<img>` elements return to launch-critical landing surfaces.
- Added a global skip link, main landmark, and visible keyboard focus styles for the landing/auth/download/legal routes.
- Added accessibility smoke guardrails to `scripts/verify-launch-site.sh` for `lang`, skip link, main landmark, and focus styling.
- Added `scripts/verify-launch-visuals.mjs` and a `scripts/verify-launch-site.sh --visual` option for Chrome-backed desktop/mobile screenshots and layout assertions.
- Added full-page color-contrast checks to the Chrome visual QA gate and raised low-contrast muted landing/auth/legal text tokens, including auth input placeholders.
- Added `docs/manual-uat-matrix.md` with a repeatable clean-install, permissions, Dictation, Context, Talk, Act, website/auth/download/legal, resilience, and support-export UAT matrix.
- Tightened the Talk manual UAT rows so the launch pass records first-response timing, interruption settling, tool-delay progress phrasing, long-thought correction handling, and repeated tool requests instead of relying only on subjective feel.
- Reran the UI-enabled no-package release gate after support-export schema metadata; that checkpoint passed with 64 Swift unit tests, 8 macOS UI tests, 55 backend Deno tests, launch-site verification, landing lint/build, Release app build, and secret scans. Later release-gate runs superseded this with the current 70-test Swift target.
- Ran the launch-site gate against local development:

```bash
scripts/verify-launch-site.sh --url http://localhost:23000
```

Result: passed. This older checkpoint reported Next.js `<img>` lint warnings that have since been removed; the current launch-site gate now requires zero lint warnings and fails if raw image elements return to launch-critical surfaces.

- Reran the launch-site gate against the restarted local development server:

```bash
scripts/verify-launch-site.sh --url http://localhost:23000
```

Result: passed with live route checks for `/`, `/auth`, `/download`, `/privacy`, and `/terms`.

- Ran the diagnostic release gate:

```bash
scripts/verify-release.sh --skip-ui-tests
```

Result: passed. This covered the source secret scan, macOS unit tests, backend function tests, launch-site verification, and Release app build.

- Ran the full release gate with UI tests enabled:

```bash
scripts/verify-release.sh
```

Result: passed after the live-session privacy guardrails and session-context copy guard were added. This covered the source secret scan, 39 Swift unit tests, 8 macOS UI tests, 49 backend Deno tests, launch-site verification, landing lint/build, landing build secret scan, Release app build, and built Release app secret scan.

- Ran the diagnostic release gate with public R2 download verification:

```bash
scripts/verify-release.sh --skip-ui-tests --public-download-check
```

Result: passed. This verified `latest.json`, the public latest DMG, latest checksum sidecar, public versioned DMG, versioned checksum sidecar, manifest SHA consistency, and latest/versioned DMG byte equality for version `1.0`, build `16`.

- Reran the hardened launch-site gate against localhost:

```bash
scripts/verify-launch-site.sh --url http://localhost:23000
```

Result: passed. This covered required files/assets, copy guardrails, legal email, lint, production build, landing build secret scan, live route fetches, home CTA/link assertions, removed-agent label guardrails, auth page assertions, download loading-state assertion, and legal page assertions.

- Ran all backend function tests:

```bash
deno test --allow-env insforge/functions/*/*.test.ts
```

Result: passed, 20 tests. This covered Computer Use payload shape and caps, Realtime/transcription model override gating, Realtime/transcription/screen-context request caps, and AI capability kill switches.

- Reran all backend function tests after backend error-safety hardening:

```bash
deno test --allow-env insforge/functions/*/*.test.ts
```

Result: passed, 24 tests. This covered the prior backend guardrails plus no-secret client-response regressions for Realtime, transcription, Computer Use, and screen-context upstream errors.

- Reran all backend function tests after adding usage reservation coverage:

```bash
deno test --allow-env insforge/functions/*/*.test.ts
```

Result: passed, 28 tests. This covered the prior backend guardrails plus cap-ledger reservation/finalization for Realtime, transcription, Computer Use, and screen-context.

- Reran all backend function tests after adding CORS/allowed-method coverage:

```bash
deno test --allow-env insforge/functions/*/*.test.ts
```

Result: passed, 32 tests. This covered the prior backend guardrails plus CORS preflight and unsupported-method behavior for Realtime, transcription, Computer Use, and screen-context.

- Reran the diagnostic release gate after expanding backend coverage:

```bash
scripts/verify-release.sh --skip-ui-tests
```

Result: passed. This covered source secret scan, macOS unit tests, all backend function tests, launch-site verification, Release app build, and built Release app secret scan.

- Reran the launch-site gate after the legal/trust copy update:

```bash
scripts/verify-launch-site.sh --url http://localhost:23000
```

Result: passed. This included the new Terms/Privacy product-coverage guardrails.

- Reran the launch-site gate after adding metadata and share-asset checks:

```bash
scripts/verify-launch-site.sh --url http://localhost:23000
```

Result: passed. This confirmed the local icon and OG image routes respond and required social metadata is present.

- Ran the Swift unit test target after adding memory/privacy coverage:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests
```

Result: passed, 8 tests.

- Reran the diagnostic release gate after the app-side memory/privacy test additions:

```bash
scripts/verify-release.sh --skip-ui-tests
```

Result: passed. This covered source secret scan, Swift unit tests, all backend function tests, launch-site verification, Release app build, and built Release app secret scan.

- Reran the full no-package release gate after the app-side memory/privacy additions and legal/backend hardening:

```bash
scripts/verify-release.sh
```

Result: passed. This covered source secret scan, Swift unit tests, macOS UI tests, all backend function tests, launch-site verification, landing build secret scan, Release app build, and built Release app secret scan.

- Reran the launch-site gate after adding the accessibility smoke guardrails:

```bash
scripts/verify-launch-site.sh --url http://localhost:23000
```

Result: passed. This covered the new accessibility smoke checks, landing lint/build, landing build secret scan, live routes, home CTA assertions, agent-label guardrails, and legal page assertions.

- Reran the diagnostic release gate after backend client-response error hardening:

```bash
scripts/verify-release.sh --skip-ui-tests
```

Result: passed. This covered source secret scan, Swift unit tests, all backend function tests, launch-site verification, landing build secret scan, Release app build, and built Release app secret scan.

- Reran the full no-package release gate after backend client-response error hardening:

```bash
scripts/verify-release.sh
```

Result: passed. This covered source secret scan, Swift unit tests, macOS UI tests, all backend function tests, launch-site verification, landing build secret scan, Release app build, and built Release app secret scan.

- Reran the diagnostic release gate after adding cap-ledger coverage:

```bash
scripts/verify-release.sh --skip-ui-tests
```

Result: passed. This covered source secret scan, Swift unit tests, 28 backend function tests, launch-site verification, landing build secret scan, Release app build, and built Release app secret scan.

- Reran the full no-package release gate after adding cap-ledger coverage:

```bash
scripts/verify-release.sh
```

Result: passed. This covered source secret scan, Swift unit tests, macOS UI tests, 28 backend function tests, launch-site verification, landing build secret scan, Release app build, and built Release app secret scan.

- Reran the diagnostic release gate after adding CORS/allowed-method coverage:

```bash
scripts/verify-release.sh --skip-ui-tests
```

Result: passed. This covered source secret scan, Swift unit tests, 32 backend function tests, launch-site verification, landing build secret scan, Release app build, and built Release app secret scan.

- Ran the Swift unit test target after wiring Agent Log export/copy controls, support export file redaction coverage, and stored Agent Log event redaction:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests
```

Result: passed, 10 tests. This covered permission return routing, agent mode/safety copy, private-mode memory skips, app/site memory exclusions, sensitive-context memory skips, support redaction patterns, generated support export JSON redaction, and stored Agent Log event redaction for titles, summaries, details, and on-disk JSON.

- Ran the Swift unit test target after tightening memory deletion, retention, search, and vault behavior:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests
```

Result: passed, 17 tests. This covered the prior Swift checks plus clear-memory deletion of the structured index, raw screenshots, and Voiyce-written vault notes; session-only memory without durable screenshot writes; 30-day, 90-day, and forever summary retention; raw screenshot retention as a separate control from summary retention; private mode and app/site exclusions with screenshots enabled; search matches and no-result responses; and plain Markdown vault notes organized by date.

- Reran the Swift unit test target after adding the Google OAuth scope guardrail:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests
```

Result: passed, 18 tests. This covered the prior Swift checks plus `googleOAuthScopesMatchCurrentGmailCalendarFeatureSet`, which fails if the requested Google OAuth scopes drift beyond the current Gmail/Calendar feature set without review.

- Reran all backend function tests after adding Stripe live-mode guardrails:

```bash
deno test --allow-env insforge/functions/*/*.test.ts
```

Result: passed, 35 tests. This covered the prior backend checks plus checkout, billing portal, and billing sync blocking Stripe live secret keys before any network request unless `STRIPE_ALLOW_LIVE_MODE=true` is set.

- Reran focused OpenAI-backed backend function tests after adding auth/rate-limit failure injection:

```bash
deno test --allow-env insforge/functions/realtime-session/index.test.ts insforge/functions/transcribe-audio/index.test.ts insforge/functions/computer-use-step/index.test.ts insforge/functions/screen-context/index.test.ts
```

Result: passed, 36 tests. This covered Realtime, transcription, Computer Use, and screen-context OpenAI 401 and 429/quota-style failures, generic client-safe bodies, upstream status preservation, and secret-like payload scrubbing.

- Reran all backend function tests after adding auth/rate-limit failure injection:

```bash
deno test --allow-env insforge/functions/*/*.test.ts
```

Result: passed, 39 tests. This covered the prior backend checks plus OpenAI 401 and 429/quota-style failure injection across the four OpenAI-backed functions.

- Reran Computer Use tests after adding the abuse-case guard:

```bash
deno test --allow-env insforge/functions/computer-use-step/index.test.ts
```

Result: passed, 13 tests. This covered safety instructions, high-confidence abuse classification, and rejecting a credential-theft request before the OpenAI call.

- Reran all backend function tests after adding the abuse-case guard:

```bash
deno test --allow-env insforge/functions/*/*.test.ts
```

Result: passed, 41 tests. This covered the prior backend checks plus Computer Use abuse-case blocking.

- Reran focused OpenAI-backed backend function tests after adding auth-provider failure injection:

```bash
deno test --allow-env insforge/functions/realtime-session/index.test.ts insforge/functions/transcribe-audio/index.test.ts insforge/functions/computer-use-step/index.test.ts insforge/functions/screen-context/index.test.ts
```

Result: passed, 42 tests. This covered auth/session-provider failures returning generic client errors without calling OpenAI or leaking bearer-token-like upstream text.

- Reran all backend function tests after adding auth-provider failure injection:

```bash
deno test --allow-env insforge/functions/*/*.test.ts
```

Result: passed, 45 tests. This covered the prior backend checks plus auth-provider failure injection across the four OpenAI-backed functions.

- Reran focused OpenAI-backed backend function tests after adding InsForge database/RPC failure injection:

```bash
deno test --allow-env insforge/functions/realtime-session/index.test.ts insforge/functions/transcribe-audio/index.test.ts insforge/functions/computer-use-step/index.test.ts insforge/functions/screen-context/index.test.ts
```

Result: passed, 46 tests. This covered InsForge profile/RPC failures returning generic client errors without calling OpenAI or leaking bearer-token-like database payload text.

- Reran all backend function tests after adding InsForge database/RPC failure injection:

```bash
deno test --allow-env insforge/functions/*/*.test.ts
```

Result: passed, 49 tests. This covered the prior backend checks plus InsForge database/RPC failure injection across the four OpenAI-backed functions.

- Reran the diagnostic no-UI release gate after tightening memory deletion and retention behavior:

```bash
scripts/verify-release.sh --skip-ui-tests
```

Result: passed. This covered source secret scan, 17 Swift unit tests, 32 backend function tests, launch-site verification, landing lint/build, landing build secret scan, Release app build, and built Release app secret scan.

- Reran the diagnostic no-UI release gate after the InsForge database/RPC failure-injection slice:

```bash
scripts/verify-release.sh --skip-ui-tests
```

Result: passed. This covered source OpenAI-key scan, 18 Swift unit tests, 49 backend Deno tests, launch-site verification, landing lint/build, landing build secret scan, Release app build, and built Release app secret scan. UI tests were intentionally skipped for this diagnostic run.

- Reran the diagnostic no-UI release gate after hardening raw transcript/screenshot redaction in Agent Log and support export paths:

```bash
scripts/verify-release.sh --skip-ui-tests
```

Result: passed. This covered source OpenAI-key scan, 19 Swift unit tests, 49 backend Deno tests, launch-site verification, landing lint/build, landing build secret scan, Release app build, and built Release app secret scan. UI tests were intentionally skipped for this diagnostic run.

- Ran the Swift unit test target after adding support-useful permission-block Agent Log events:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests
```

Result: passed, 20 tests. This covered the prior Swift guardrails plus support-export-visible permission-block events for Screen Recording and Accessibility failures.

- Ran the Swift unit test target after adding support-useful service-failure Agent Log events:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests
```

Result: passed, 21 tests. This covered the prior Swift guardrails plus support-export-visible quota/rate-limit service-failure events with feature, service, upstream status, and next-step detail.

- Reran the macOS UI target after hardening focus handling against external window interference:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentUITests
```

Result: passed, 5 tests. This covered app launch/window creation, Dashboard/Settings/Agent/Agent Log navigation, permission-screen return routing, agent-mode selection, and Act command navigation.

- Reran the full no-package release gate after the UI-test focus hardening and raw-context redaction work:

```bash
scripts/verify-release.sh
```

Result: passed. This covered source OpenAI-key scan, 19 Swift unit tests, 5 macOS UI tests, 49 backend Deno tests, launch-site verification, landing lint/build, landing build secret scan, Release app build, and built Release app secret scan.

- Reran the diagnostic no-UI release gate after adding support-useful permission-block diagnostics:

```bash
scripts/verify-release.sh --skip-ui-tests
```

Result: passed. This covered source OpenAI-key scan, 20 Swift unit tests, 49 backend Deno tests, launch-site verification, landing lint/build, landing build secret scan, Release app build, and built Release app secret scan. UI tests were intentionally skipped for this diagnostic run.

- Reran the diagnostic no-UI release gate after adding support-useful service-failure diagnostics:

```bash
scripts/verify-release.sh --skip-ui-tests
```

Result: passed. This covered source OpenAI-key scan, 21 Swift unit tests, 49 backend Deno tests, launch-site verification, landing lint/build, landing build secret scan, Release app build, and built Release app secret scan. UI tests were intentionally skipped for this diagnostic run.

- Reran the diagnostic no-UI release gate after adding the failed-tool-call Agent Log hook:

```bash
scripts/verify-release.sh --skip-ui-tests
```

Result: passed. This covered source OpenAI-key scan, 21 Swift unit tests, 49 backend Deno tests, launch-site verification, landing lint/build, landing build secret scan, Release app build, and built Release app secret scan. UI tests were intentionally skipped for this diagnostic run.

- Reran the full no-package release gate after the permission-block, service-failure, and failed-tool-call diagnostics slices:

```bash
scripts/verify-release.sh
```

Result: passed. This covered source OpenAI-key scan, 21 Swift unit tests, 5 macOS UI tests, 49 backend Deno tests, launch-site verification, landing lint/build, landing build secret scan, Release app build, and built Release app secret scan.

- Ran the Swift unit target after adding support-useful memory-error Agent Log events:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests
```

Result: passed, 22 tests. This covered the prior Swift guardrails plus support-export-visible memory-error events with operation, path, and next-step detail.

- Reran the full no-package release gate after the memory-error diagnostics slice:

```bash
scripts/verify-release.sh
```

Result: passed. This covered source OpenAI-key scan, 22 Swift unit tests, 5 macOS UI tests, 49 backend Deno tests, launch-site verification, landing lint/build, landing build secret scan, Release app build, and built Release app secret scan.

- Ran the Swift unit target after adding durable Agent mode selection persistence:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests
```

Result: passed, 23 tests. This covered the prior Swift guardrails plus selected Agent mode and Agent safety mode persistence across fresh app state instances.

- Reran the full no-package release gate after adding durable Agent mode selection persistence:

```bash
scripts/verify-release.sh
```

Result: passed. This covered source OpenAI-key scan, 23 Swift unit tests, 5 macOS UI tests, 49 backend Deno tests, launch-site verification, landing lint/build, landing build secret scan, Release app build, and built Release app secret scan.

- Ran the macOS UI test target after the Agent screen polish pass:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentUITests
```

Result: passed, 6 tests. This covered the prior UI flows plus Agent screen copy/control polish, Off-disabled Start behavior, Context start/stop state, Act safety note, and absence of visible internal implementation terms.

- Reran the full no-package release gate after the Agent screen polish pass:

```bash
scripts/verify-release.sh
```

Result: passed. This covered source OpenAI-key scan, 23 Swift unit tests, 6 macOS UI tests, 49 backend Deno tests, launch-site verification, landing lint/build, landing build secret scan, Release app build, and built Release app secret scan.

- Ran the Swift unit target after the Agent hotkey toggle cleanup:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests
```

Result: passed, 24 tests. This covered the prior Swift guardrails plus Option hotkey press/release toggle semantics.

- Reran the macOS UI target after documenting the Agent Mode hotkey in Settings:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentUITests
```

Result: passed, 6 tests. This covered the prior UI flows plus Settings > Hotkeys copy for the Agent Mode Option toggle.

- Reran the full no-package release gate after the Agent hotkey toggle cleanup and Settings hotkey documentation:

```bash
scripts/verify-release.sh
```

Result: passed. This covered source OpenAI-key scan, 24 Swift unit tests, 6 macOS UI tests, 49 backend Deno tests, launch-site verification, landing lint/build, landing build secret scan, Release app build, and built Release app secret scan.

- Ran the affected macOS UI tests after adding Agent context consent and Talk/Act Stop coverage:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentUITests/Voiyce_AgentUITests/testAgentScreenPolishAndStartStopControls -only-testing:Voiyce-AgentUITests/Voiyce_AgentUITests/testStopVisibleForTalkAndActSessions
```

Result: passed, 2 tests. This covered the new Agent context-consent copy, Context start/stop behavior, and visible Stop actions during active Talk and Act sessions.

- Reran the macOS UI target after adding Agent context consent and Talk/Act Stop coverage:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentUITests
```

Result: passed, 7 tests. This covered the prior UI flows plus Agent context-consent copy and visible Stop controls for active Talk and Act sessions.

- Reran the full no-package release gate after adding Agent context consent and Talk/Act Stop coverage:

```bash
scripts/verify-release.sh
```

Result: passed. This covered source OpenAI-key scan, 24 Swift unit tests, 7 macOS UI tests, 49 backend Deno tests, launch-site verification, landing lint/build, landing build secret scan, Release app build, and built Release app secret scan.

- Ran the Agent Log navigation UI smoke after adding support-ready cues:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentUITests/Voiyce_AgentUITests/testDashboardSettingsAndAgentNavigation
```

Result: passed, 1 test. This covered the Agent Log support-ready header, session timeline cue, action detail cue, and redacted support export cue.

- Reran the full no-package release gate after the Agent Log support-readiness pass:

```bash
scripts/verify-release.sh
```

Result: passed. This covered source OpenAI-key scan, 24 Swift unit tests, 7 macOS UI tests, 49 backend Deno tests, launch-site verification, landing lint/build, landing build secret scan, Release app build, and built Release app secret scan.

- Ran the affected macOS UI tests after hardening active Act command Stop/cancel behavior:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentUITests/Voiyce_AgentUITests/testActCommandCanUseNativeVoiyceNavigation -only-testing:Voiyce-AgentUITests/Voiyce_AgentUITests/testActCommandShowsMainStopWhileRunning
```

Result: passed, 2 tests. This covered deterministic native Act navigation and the active Act command Stop path returning the main action to Start. Broader live Computer Use loop cancellation remains part of manual UAT.

- Reran the macOS UI target after active Act command Stop/cancel hardening:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentUITests
```

Result: passed, 8 tests. This covered the prior UI flows plus deterministic native Act navigation, active Act command Stop/cancel behavior, and the launch smoke test.

- Reran the full no-package release gate after active Act command Stop/cancel hardening:

```bash
scripts/verify-release.sh
```

Result: passed. This covered source OpenAI-key scan, 24 Swift unit tests, 8 macOS UI tests, 49 backend Deno tests, launch-site verification, landing lint/build, landing build secret scan, Release app build, and built Release app secret scan.

- Ran a clean Debug macOS app build:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' clean build
```

Result: passed. This verified a clean Debug build without creating a DMG, package, notarized artifact, upload, or deployment.

- Reran the launch-site gate after tightening Privacy Policy local-storage copy and guardrails:

```bash
scripts/verify-launch-site.sh --url http://localhost:23000
```

Result: passed. This covered source checks for concrete local storage privacy copy, landing lint/build, landing build secret scan, live route fetches, CTA assertions, and rendered Privacy/Terms checks. This older checkpoint reported Next.js `<img>` lint warnings that have since been removed; the current launch-site gate requires zero lint warnings.

- Ran the launch-site gate with Chrome-backed visual QA:

```bash
scripts/verify-launch-site.sh --url http://localhost:23000 --visual
```

Result: passed. This covered the normal launch-site checks plus the download URL fallback guardrail, desktop screenshots at 1440, 1280, and 1024 px, mobile screenshots at 375, 390, and 430 px, auth/download/privacy/terms screenshots at desktop and mobile widths, horizontal-overflow checks, full-page color-contrast checks including input placeholders, text-clipping checks, hero/nav overlap checks, agent-label visibility/overlap checks, Hermes/OpenClaw image loading, OpenClaw/Cursor spacing, key link presence, and nav-anchor scroll behavior. Screenshots were written outside the repo to `/var/folders/df/28vzzx2170q_lb8ggs50dl680000gn/T/voiyce-launch-visuals-1779063061941`.

- Ran the Swift unit target after remaining plain-language error hardening:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests
```

Result: passed, 68 tests. This covered the prior Swift guardrails plus Auth/Billing recovery copy, Google connection/OAuth callback recovery copy, Agent tool bridge failures, Act unexpected failures, session-context raw helper/backend text, support-export write failure copy, and memory-error support export summaries.

- Hardened remaining local Agent tool validation failures so missing app names, URLs, recipients, text, screen coordinates, key names, native Act commands, long-term/session memory queries, screen-context invalid responses, and Gmail-draft failures carry concrete `next_step` data into Agent Log instead of raw local tool details. Billing beta-code and free-word-count recovery copy now also tells the user what to do next.
- Hardened the remaining core Agent tool bridge failures so invalid tool payloads, invalid confirmation payloads, missing/stale confirmations, cancelled confirmations, confirmed-action failures, and empty memory summaries carry concrete `next_step` recovery data instead of bare failed results.
- Hardened remaining OAuth/permission requirement failures so Google Workspace read/draft/send/calendar failures, direct/unrestricted Gmail send paths, and local Accessibility-required insert/click/key actions carry concrete `next_step` data alongside `requires`.
- Added a launch audit guard that verifies those core Agent tool failure paths do not regress to `data: nil` and that Swift coverage keeps the invalid-request next-step assertion.
- Added a launch audit guard that verifies OAuth/Accessibility requirement failures do not regress to bare `requires` payloads, plus Swift coverage for the disconnected-Google next-step path.
- Repositioned onboarding first-run copy around Voiyce as a reusable memory/context layer for Dictation, Context, Talk, Act, and handoffs to tools like Codex, Claude Code, Cursor, and Hermes, rather than presenting the product primarily as dictation.
- Added Swift and launch-audit guardrails that keep onboarding copy concrete, agent-context positioned, and free of vague launch phrases or internal implementation terms.

- Reran the Swift unit target after Agent tool next-step hardening:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests
```

Result: passed, 68 tests. This added coverage that Agent tool validation failures remain plain and write `Next step` detail into Agent Log/support export paths.

- Hardened Context-only startup recovery so a failed session-context start or privacy pause stops the Context run, shows a clear recovery message, and writes an Agent Log failure with `Next step` detail. Talk and Act do not stop solely because the passive session-context helper failed.

- Reran the Swift unit target after Context startup recovery hardening:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests
```

Result: passed, 69 tests. This added coverage that failed Context-only startup does not leave Agent active, Talk/Act are not stopped by passive context failure, and privacy-pause results include actionable next-step data.

- Added Settings permission-refresh hardening and Strict-mode tool validation ordering:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentUITests/Voiyce_AgentUITests/testDashboardSettingsAndAgentNavigation
scripts/verify-release.sh
```

Result: passed. The focused Swift target now has 70 tests, including Pro permission-refresh polling coverage and the Strict-mode missing-detail validation guard. The focused Settings UI path covers the new Permissions `Refresh Status` control and confirmation copy. The full release gate passed with source OpenAI-key scan, 70 Swift unit tests, 8 macOS UI tests, 55 backend Deno tests, launch-site verification, landing lint/build, landing build secret scan, Release app build, and built Release app secret scan.

- Added signed-out/offline launch recovery coverage:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -destination 'platform=macOS' test -only-testing:Voiyce-AgentUITests/Voiyce_AgentUITestsLaunchTests
scripts/verify-release.sh
```

Result: passed. The signed-out/offline UI path now shows concrete reconnect copy and disables Google/email sign-in actions while offline. The current full release gate passed with source OpenAI-key scan, 70 Swift unit tests, 9 macOS UI tests, 55 backend Deno tests, launch-site verification, landing lint/build, landing build secret scan, Release app build, and built Release app secret scan.

- Added dictation network-loss Agent Log recovery coverage:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests
```

Result: passed, 71 tests. This covered the new `offlineDictationFailureLogsSupportUsefulRecoveryEvent` guard: a transcription network drop maps to `noInternet`, writes plain reconnect copy, and records a Transcription service failure event without upstream/provider details. Physical network-drop dictation UAT remains open for a downloaded app.

- Added app-side dictation fallback safe-error coverage:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests
```

Result: passed, 110 tests. This covered the new `dictationFallbackErrorsDoNotRetainProviderDetails` guard: unexpected transcription failures map to generic Voiyce copy and do not retain raw backend, key, secret, token, or localized-description details in the `WhisperError` value. Physical downloaded-app dictation failure-injection remains open.

- Added Talk/Act connection-loss telemetry coverage:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests
```

Result: passed, 71 tests. This extended `realtimeConnectionFailureTelemetryStopsAndExplainsRecovery` so `connection_lost` events from the WebRTC bridge stop the active Talk/Act state and write support-useful Talk service failure events with the same recovery copy as startup connection failures. Physical network-drop Talk UAT remains open for a downloaded app.

- Added Agent permission-recovery policy coverage:

```bash
git diff --check
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests
```

Result: passed, 72 tests. This added `agentPermissionRecoveryMatchesModeRequirements` and extended Realtime connection-loss coverage so Act-specific `connection_lost` events log support-useful service failures. Physical permission-revocation and network-drop UAT from a downloaded app remain open.

- Added landing auth/download recovery coverage:

```bash
git diff --check -- landing-page/src/app/api/download-health/route.ts landing-page/src/components/AuthPageClient.tsx landing-page/src/components/DownloadPageClient.tsx scripts/verify-launch-site.sh
npm run lint
npm run build
scripts/verify-launch-site.sh --url http://localhost:23000
NEXT_PUBLIC_DOWNLOAD_URL=http://127.0.0.1:9/Voiyce.dmg npm run start -- -p 23001
curl -i -sS http://localhost:23001/api/download-health
scripts/verify-release.sh
```

The launch-site verifier now runs landing lint with `--max-warnings=0`, so future warnings fail the gate instead of passing as accepted noise.

Result: passed. The bad-download simulation returned `503` with `{"ok":false,"status":"unreachable","downloadUrl":"http://127.0.0.1:9/Voiyce.dmg"}` from `/api/download-health`, proving the unreachable-artifact path. The full no-package release gate passed afterward with source OpenAI-key scan, 72 Swift unit tests, 9 macOS UI tests, 55 backend Deno tests, launch-site verification including the new auth/download guardrails, landing lint/build, landing build secret scan, Release app build, and built Release app secret scan.

- Reran the diagnostic public artifact gate after the latest web auth/download recovery state:

```bash
scripts/verify-release.sh --skip-ui-tests --public-download-check
```

Result: passed. This covered source OpenAI-key scan, 72 Swift unit tests, 55 backend Deno tests, launch-site verification including `/api/download-health`, landing lint/build, landing build secret scan, Release app build, built Release app secret scan, public `latest.json`, latest DMG checksum, versioned DMG checksum, manifest SHA consistency, and latest/versioned DMG byte equality for version `1.0`, build `16`. UI tests were intentionally skipped for this diagnostic public-download run; the current UI-enabled no-package release gate above remains the broader RC gate.

- Added and ran the server-side usage-cap verifier:

```bash
chmod +x scripts/verify-agent-usage-caps.sh
bash -n scripts/verify-agent-usage-caps.sh
scripts/verify-agent-usage-caps.sh
```

Result: passed. The verifier checked 12 Default/Pro/Power tier/capability cap rows for Realtime, transcription, Computer Use, and context; confirmed the cap rows align with `docs/phase-2-production-hardening.md`; verified the SQL reserve/finalize RPCs use per-user advisory locks, daily and monthly sums, cap failures, `reserved`/`succeeded` accounting, authenticated grants, and finalize status updates; checked all four cost-bearing functions reserve/finalize usage when `VOIYCE_ENFORCE_AGENT_USAGE_CAPS=true`; and ran 52 backend Deno tests covering request caps, kill switches, account-limit responses before OpenAI, redacted upstream failures, and usage reserve/finalize calls. Production environment confirmation for `VOIYCE_ENFORCE_AGENT_USAGE_CAPS=true` remains an external/account-level step.

- Added and ran the public DMG mount/signature verifier:

```bash
chmod +x scripts/verify-public-dmg.sh
bash -n scripts/verify-public-dmg.sh
bash -n scripts/verify-release.sh
scripts/verify-public-dmg.sh
scripts/verify-release.sh --skip-ui-tests --public-dmg-check
```

Result: passed. The standalone verifier downloaded the current public R2 DMG for version `1.0`, build `16`, verified SHA-256 `bfed37a6f089eb83d0d5426fc5d25dbd709184bf2f85feceefac70ee68c485d5`, verified the disk image with `hdiutil`, confirmed Gatekeeper accepts the DMG as Notarized Developer ID, validated the stapled ticket, mounted the DMG read-only/no-browse, verified mounted `Voiyce.app` and the `/Applications` symlink, verified the app with `codesign`, confirmed Gatekeeper accepts the app, checked bundle version/build against `latest.json`, scanned the mounted app for leaked OpenAI-key patterns, detached the image, and removed temporary files. The integrated diagnostic gate also passed with source OpenAI-key scan, 72 Swift unit tests, UI tests intentionally skipped, 55 backend Deno tests, launch-site verification including `/api/download-health`, landing lint/build, landing build secret scan, Release app build, built Release app secret scan, and the public DMG verifier. No package, notarization, upload, install, or existing release-artifact mutation occurred.

- Updated the public `1.0+16` release record after fetching the live R2 manifest and checksum sidecars:

```bash
curl -fsSL https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/latest.json
curl -fsSL https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/Voiyce.dmg.sha256
curl -fsSL https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/releases/Voiyce-1.0+16.dmg.sha256
```

Result: manifest and both checksum sidecars report `bfed37a6f089eb83d0d5426fc5d25dbd709184bf2f85feceefac70ee68c485d5`; `docs/releases/Voiyce-1.0+16.md` now records that current public checksum instead of the stale earlier checksum.

- Added exact-artifact beta release notes and checked the current production landing URL:

```bash
curl -fsSI https://voiyce.us
curl -fsSL https://voiyce.us
```

Result: `https://voiyce.us` initially returned `200` from Vercel while still serving the older "Write at the speed of thought" / dictation-first copy. This was a temporary production blocker that was resolved on 2026-05-20 when production served the current agent-context landing page.

- Added and ran the no-build production landing smoke gate:

```bash
bash -n scripts/verify-production-landing.sh
scripts/verify-production-landing.sh --help
scripts/verify-production-landing.sh https://voiyce.us
```

Result: script syntax/help passed. The production run initially failed with exit status `1` because `https://voiyce.us/api/download-health` returned `404`. This confirmed production had not yet been updated to the revised landing build; the issue was resolved on 2026-05-20.

- Added the opt-in production smoke check to the release verifier:

```bash
bash -n scripts/verify-release.sh
scripts/verify-release.sh --help
scripts/verify-production-landing.sh https://voiyce.us
```

Result: release verifier syntax/help passed and now documents `--production-landing-check` plus `--production-url <base-url>`. The production smoke run now passes against `https://voiyce.us`.

- Hardened and reran the production-preview landing asset gate:

```bash
npm run build
npm run start -- -p 23002
bash -n scripts/verify-launch-site.sh
scripts/verify-launch-site.sh --url http://localhost:23002
```

Result: passed. This covered the normal launch-site source/copy/legal/download/auth/accessibility guardrails, landing lint/build, landing build secret scan, live route fetches, and production-preview payload validation for `/icon.png` as a 256x256 PNG, `/og-header.png` as a 1200x630 PNG, and `/favicon.ico` as a valid ICO payload. The route checks now account for the Auth and Download pages being client-rendered behind production Suspense shells by verifying source-level UI copy plus live route metadata.

- Added and ran the no-mutation R2 rollback readiness dry-run:

```bash
scripts/verify-rollback-readiness.sh
```

Result: passed. The dry-run verified the current public `latest.json`, latest DMG, versioned `1.0+16` DMG, and checksum sidecars, then verified the previous rollback candidate `https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/releases/Voiyce-1.0+1.dmg` with SHA-256 `97123202c651bf5046044aeb1c6406181b8d21323261748028e76a76ad86bfe5`. It generated a local rollback `latest.json` for version `1.0`, build `1`, kept the stable latest URL as `https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/Voiyce.dmg`, and made no R2 object changes.

- Added and ran the launch-readiness status audit:

```bash
bash -n scripts/audit-launch-readiness.sh
scripts/audit-launch-readiness.sh --help
scripts/audit-launch-readiness.sh --allow-blockers
scripts/audit-launch-readiness.sh
scripts/audit-launch-readiness.sh --live --allow-blockers
```

Result: syntax/help passed. Prep mode initially reported expected blockers while source/tag/package/production/manual gates were still open. Those engineering blockers were closed on 2026-05-20 after source-state verification, package verification, notarized public DMG upload, production landing verification, and launch-blocker verification passed.

Reran on 2026-05-19 after adding the support response playbook:

```bash
scripts/audit-launch-readiness.sh --allow-blockers
scripts/audit-launch-readiness.sh --live --allow-blockers
```

Result: prep mode passed with 664 checks while the remaining blockers were still expected. On 2026-05-20, the live audit verified public R2 `latest.json` for version `1.0`, build `16`, checksum `bfed37a6f089eb83d0d5426fc5d25dbd709184bf2f85feceefac70ee68c485d5`, and production landing/download verification passed.

- Added and ran the temporary Release archive verification path:

```bash
chmod +x scripts/verify-release-archive.sh
bash -n scripts/verify-release-archive.sh
scripts/verify-release-archive.sh --help
bash -n scripts/verify-release.sh
scripts/verify-release.sh --help
scripts/verify-release-archive.sh
```

Result: syntax/help passed. `scripts/verify-release-archive.sh` passed: Xcode archive succeeded for the Release app in a temporary directory, the archived `Voiyce.app` signature verified with `codesign --verify --deep --strict`, and the archived app bundle scan found no leaked OpenAI API key pattern. The temporary archive was removed at exit, and no DMG/package/notarization/upload or existing `build/release` artifact mutation occurred. Xcode still printed the known generic AppIntents metadata notice because the app has no AppIntents dependency.

- Ran the integrated diagnostic release gate with archive verification:

```bash
scripts/verify-release.sh --skip-ui-tests --archive-check
```

Result: passed. Coverage: source OpenAI-key scan, 72 Swift unit tests, UI tests intentionally skipped for this diagnostic path, 55 backend Deno tests, launch-site verification including `/api/download-health`, landing lint/build, landing build secret scan, Release app build, built Release app OpenAI-key scan, temporary Release archive verification, archived app codesign verification, and archived app OpenAI-key scan. It did not package, notarize, upload, or mutate existing DMG/release artifacts. The generic AppIntents metadata notice remained accepted; the older Next.js `<img>` warnings have since been removed and are now guarded against by the launch-site verifier.

- Ran formatting and residual raw-error scans after the plain-language hardening:

```bash
git diff --check
rg -n "localizedDescription|errorMessage\\s*=|lastError\\s*=|lastStatus\\s*=|AgentToolResult\\(ok: false|Text\\(.*error|feedbackPill\\(.*error" Voiyce-Agent --glob '*.swift'
rg -n '[ \t]+$' Voiyce-Agent/Services/Google/GoogleWorkspaceManager.swift Voiyce-Agent/Services/Auth/AuthenticationManager.swift Voiyce-Agent/Services/Billing/BillingManager.swift Voiyce-Agent/Services/RealtimeAgent/ComputerUseAgent.swift Voiyce-Agent/Services/RealtimeAgent/RealtimeAgentServer.swift Voiyce-Agent/Services/Whisper/WhisperService.swift Voiyce-Agent/Services/RealtimeAgent/ScreenContextProvider.swift Voiyce-Agent/Services/RealtimeAgent/AgentLongTermMemoryStore.swift Voiyce-Agent/Services/RealtimeAgent/VideoDBAgentMemory.swift Voiyce-Agent/Services/RealtimeAgent/AgentEventStore.swift Voiyce-AgentTests/Voiyce_AgentTests.swift
```

Result: formatting passed. The residual `localizedDescription` scan is limited to sanitized recovery-copy funnels, debug `print` statements, or already user-facing local tool validation messages; the broad manual item for proving every error state explains what happened and what to do next remains open.

- Added and ran app-termination, system sleep, and display-layout cleanup unit coverage:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests
```

Result: passed with 78 tests. New coverage: `appTerminationClearsTransientRuntimeState` verifies quit cleanup clears active dictation/Agent runtime state without changing the selected Agent mode, and `appTerminationStopsLocalSessionContextCapture` verifies local session-context capture is stopped and logged when Voiyce quits. `systemSleepClearsTransientRuntimeState` and `systemSleepStopsLocalSessionContextCapture` verify the same deterministic state reset and local context shutdown for macOS sleep. `displayConfigurationRecoveryStopsOnlyActiveActMode` verifies display changes pause only active Act mode, and `displayConfigurationChangeClearsSavedFocusRegion` verifies saved focus regions are cleared and logged when display geometry changes. Physical quit-while-running, sleep/wake, and display connect/disconnect UAT from the downloaded app remain open.

- Added and ran per-account long-term memory isolation coverage:

```bash
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests
```

Result: passed with 81 tests. New coverage: `longTermMemoryRecordsAreIsolatedByAccount` verifies account changes switch to separate memory indexes, filesystem-safe account storage paths, and scoped vault paths without showing another account's records. `memoryPrivacySettingsAreScopedPerAccount` verifies retention, screenshot retention, Vault Notes, Private Mode, and app/site exclusions are account-scoped. `vaultSyncCanBeDisabledWithoutDisablingStructuredMemory` verifies disabling Vault Notes keeps structured memory searchable without writing Markdown notes. Existing screen/session/memory copy tests now also verify structured `memory_source` / `context_scope` labels for current screen, active-session context, and long-term memory tool results. `vaultNotesArePlainMarkdownAndDateOrganized` now verifies daily-note frontmatter includes date, source modes, apps, tags, privacy level, screenshot retention, and account scope. `memoryClearRemovesStructuredStorageScreenshotsAndVaultNotes` verifies quoted YAML tags still allow Voiyce-written notes to be deleted. `git diff --check` and trailing-whitespace scans passed for the touched app/test/docs files. The only warning in the test log was Xcode's generic AppIntents metadata notice; WebContent sandbox noise came from the embedded test app process.

- Added and ran memory-recall instruction/copy hardening coverage:

```bash
deno test --allow-env insforge/functions/realtime-session/index.test.ts
xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests
```

Result: Deno passed with 15 tests and now verifies Realtime instructions require saved-memory grounding before previous-work answers, Act-mode saved-memory grounding before memory-dependent actions, natural date/session citations, and no normal-speech exposure of internal provider/runtime/tool/source-label names. Swift passed with 81 tests and now verifies saved-memory search results return natural citation guidance while no-result copy says "saved memory" instead of exposing long-term-memory terminology.

- Added and ran the release source-state verifier in prep mode:

```bash
chmod +x scripts/verify-release-source-state.sh
bash -n scripts/verify-release-source-state.sh
scripts/verify-release-source-state.sh --help
scripts/verify-release-source-state.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --allow-blockers
```

Result: syntax/help passed. Prep mode now reports the expected source blockers: the working tree has 123 tracked or untracked paths and `v1.0+16` is not yet tagged at HEAD. It confirmed the branch, HEAD SHA, no merge conflicts, and Xcode `MARKETING_VERSION=1.0` / `CURRENT_PROJECT_VERSION=16`. Strict mode should remain blocked until the release candidate source is committed, unrelated work is split or intentionally included, and the release tag points at the exact committed source.

Also verified the broader release gate stops before tests/build/package work when the strict source-state hook is enabled:

```bash
scripts/verify-release.sh --source-state-check --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --skip-ui-tests
```

Result: exited `1` as expected during source-state verification because the working tree is dirty and `v1.0+16` does not exist at HEAD. No packaging, notarization, upload, or release artifact mutation occurred.

## Current Release Gate Status

The current UI-enabled no-package release gate is clean after the permission-block, service-failure, failed-tool-call, successful-tool-call, Act loop action logging, Act permission/cancellation coverage, Action Cursor non-interference/lead-in/presentation-gating/multi-display coverage, Focus Highlight shortcut/geometry/capture and clear/log coverage, memory-error diagnostics, durable Agent mode persistence, Agent screen polish, Agent hotkey toggle, Settings hotkey documentation, Settings permission-refresh hardening, Agent context-consent, Talk/Act Stop visibility, Talk latency telemetry, Realtime connection-failure recovery, Realtime session instruction guardrails, account-limit response hardening, app-side account-limit recovery, support-export schema metadata, Agent Log support-readiness, active Act command Stop/cancel, explicit Act safety-mode choice, Act safety-policy guardrails, confirmation Stop Session/cancel-execution guardrails, confirmation frontmost/rationale/timeout guardrails, Computer Use safety-check recovery, Act safety-check Agent Log coverage, onboarding permission-copy guardrails, dictation recovery-copy, Act mode recovery-copy, Talk mode recovery-copy, dictation service-failure Agent Log guardrail, session-context copy guard, live-session privacy guardrail, session-context Agent Log event, Agent mode runtime-boundary, remaining plain-language error hardening, Agent-tool next-step hardening and Strict-mode validation ordering, Context startup recovery, no-network launch recovery, web auth/download recovery hardening, and Release app-source warning cleanup. Packaging, notarization, clean-machine install, and release-artifact upload remain intentionally separate.

- `scripts/verify-release.sh`: passed on 2026-05-18 after the web auth/download recovery slice. Coverage: source OpenAI-key scan, 72 Swift unit tests, 9 macOS UI tests, 55 backend Deno tests, launch-site verification including `/api/download-health`, landing lint/build, landing build secret scan, Release app build, and built Release app secret scan. The Release app build has no app-code warnings; Xcode still prints its generic AppIntents metadata notice because the app has no AppIntents dependency.
- `scripts/verify-release.sh --skip-ui-tests`: last passed on 2026-05-18 before the support-export schema metadata test was added. It remains a diagnostic-only path superseded by the current UI-enabled full gate. The Release app build had no app-code warnings; Xcode still printed its generic AppIntents metadata notice because the app has no AppIntents dependency.
- `scripts/verify-release.sh --skip-ui-tests --public-download-check`: passed on 2026-05-18 after the 72-test web auth/download recovery state. Coverage: source OpenAI-key scan, 72 Swift unit tests, 55 backend Deno tests, launch-site verification including `/api/download-health`, landing lint/build, landing build secret scan, Release app build, built Release app secret scan, public `latest.json`, latest DMG checksum, versioned DMG checksum, manifest SHA consistency, and latest/versioned DMG byte equality for version `1.0`, build `16`.
- `scripts/verify-agent-usage-caps.sh`: passed on 2026-05-18 after adding missing OAuth/permission instruction guardrails and was rerun during the launch-ready PRD reconciliation slice. Coverage: 12 Default/Pro/Power tier/capability cap rows, SQL cap documentation alignment, usage-unit JSON storage, reserve/finalize RPC hardening, Realtime/transcription/Computer Use/screen-context usage-cap wiring, account-limit behavior before OpenAI, and 57 backend Deno tests for cost-bearing functions.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 84 tests on 2026-05-18 after adding memory usage snapshot coverage for capture frequency, screenshot/vault/index storage bytes, tool-result usage fields, and Agent Log storage totals.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 84 tests on 2026-05-18 after adding Agent mode-map copy coverage for Off, Context, Talk, and Act self-serve explanations and control boundaries.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 85 tests on 2026-05-18 after adding Talk Stop teardown coverage for pending Realtime connection invalidation, late microphone stream release, hidden audio cleanup, and local peer-connection callback binding.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 86 tests on 2026-05-18 after adding user Stop coverage that ends local session-context capture before summary generation while preserving session identifiers for summary/backend close.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 87 tests on 2026-05-18 after adding embedded Realtime client coverage for the Talk tool surface: Gmail, Calendar, app/site opening, text insertion, screen inspection, active-session context, and local memory tools.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 88 tests on 2026-05-18 after adding Act/Talk capability-boundary coverage for context plus voice mode composition, Act safety copy, Realtime tool-call mode forwarding, and direct-control tool rejection outside Act mode.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 89 tests on 2026-05-18 after adding native Act text-target safety coverage. Voiyce now refuses direct text insertion and Computer Use typing when macOS cannot confirm a focused text-like target, returning structured recovery data instead of typing blindly.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 90 tests on 2026-05-18 after adding app-side Computer Use loop coverage for initial task/screenshot submission, hosted computer action handling, allowed local action execution, post-action screenshot capture, continuation IDs, structured result data, and Agent Log evidence.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 91 tests on 2026-05-18 after adding local memory storage quota enforcement for durable records, total local memory storage, and raw screenshot bytes.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 92 tests on 2026-05-18 after adding deterministic local Act action-surface coverage for right click, double click, scroll, command-style hotkeys, and safe text insertion without posting real system events during tests.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 93 tests on 2026-05-18 after adding deterministic Action Cursor lifecycle coverage for native Voiyce navigation and Computer Use action loops, including Act cursor start, visible statuses, and delayed completion hide.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 95 tests on 2026-05-18 after adding active-Agent return banners in Agent Log and Settings plus deterministic Act recoverability coverage across Agent Log/Settings navigation and native Voiyce navigation from those surfaces.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 96 tests on 2026-05-18 after adding structured `next_step` recovery payloads for Act command failures covering missing task details, signed-out state, missing Accessibility, pending safety checks, and post-action Screen Recording loss.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 104 tests on 2026-05-18 after updating the embedded Realtime confirmation tool schema so voice decisions explicitly support `approve`, `cancel`, and `stop_session`.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 104 tests on 2026-05-18 after extending Realtime telemetry coverage to assert interruption-completed events write Agent Log QA measurements with the launch interruption target and review label.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 104 tests on 2026-05-18 after strengthening permission-return coverage to prove return targets are cleared after restoring Settings > Permissions or Agent and cannot trigger duplicate reroutes.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 105 tests on 2026-05-18 after centralizing menu bar launch copy, adding stable menu action identifiers, and adding `menuBarLaunchCopyStaysUserFacing`.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 106 tests on 2026-05-18 after adding app menu navigation commands and `appMenuLaunchCopyStaysUserFacing`.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 107 tests on 2026-05-18 after changing the walkthrough video sheet from dictation-only onboarding copy to product-facing launch copy, making its load-failure copy actionable, and adding `demoVideoLaunchCopyStaysProductFacing`.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 108 tests on 2026-05-18 after centralizing the macOS support email in `AppConstants.supportEmail` and adding `launchSupportEmailStaysConsistentAcrossAppCopy`.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 109 tests on 2026-05-18 after replacing raw dictation transcript/error and temp-recording debug prints with word-count-only/safe operation log messages and adding `dictationDebugLogsDoNotIncludeRawTranscriptText`.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 after adding the dictation/audio debug-log privacy guard; the audit now checks the touched dictation/audio paths for raw transcript, thrown-error, and temp recording-path print regressions.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 after adding the support-contact guard; the audit now checks the app/landing constants, launch-site and production verifiers, and legacy Voiyce support-address regressions.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 after adding the launch-site verifier meta-guard; the audit now confirms the verifier still covers zero-warning lint, raw image regressions, landing build secret scan, accessibility smoke checks, and `/api/download-health`.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 after adding the production-landing verifier meta-guard; the audit now confirms the production smoke verifier still checks stale-copy rejection, `/api/download-health`, legal contact, social image/favicon payloads, and current agent-context positioning.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 after adding the rollback verifier meta-guard; the audit now confirms the rollback dry-run verifier still checks current public R2 artifacts, the previous rollback candidate, local rollback manifest generation, and no R2 mutation.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 after adding the release verifier meta-guard; the audit now confirms the main release verifier still includes source and built-app secret scans, usage-cap verification, launch-site verification, archive/public-DMG hooks, and the production landing hook.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 after extending the release verifier meta-guard; the audit now also confirms the source-state hook, package command, public-download manifest hook, and `--skip-ui-tests` diagnostic-only warning stay in the release verifier.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 after adding the release source-state verifier meta-guard; the audit now confirms the source-state verifier still checks clean-tree state, version/build values, tag-to-HEAD alignment, and prep-stage blocker reporting.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 after adding the public DMG verifier meta-guard; the audit now confirms the public DMG verifier still checks checksum, image verification, Gatekeeper/notarization, read-only mounting, Applications symlink, app signature, bundle version/build, and mounted app secret scanning.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 after adding the release archive verifier meta-guard; the audit now confirms the archive verifier still uses a temporary archive path, invokes Xcode archive output, checks archived app presence, verifies codesign, and scans the archived app for OpenAI keys.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 after adding the exact-artifact release-record guard and updating stale source-state wording to the current dirty-tree blocker count; the audit now confirms release records keep version/build, commit, R2 URLs, checksum, notarization/signing, source-state warning, and full release-candidate gate notes.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 after reconciling the tier/cost plan with the current usage-cap implementation; the audit now confirms the plan records server-side cap status, production env/tier-mapping blockers, per-tier hard-cap scope, kill-switch scope, and paid-production confirmation steps.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 after adding the production-hardening environment guard; the audit now confirms server-side-only environment guidance, OpenAI key requirement, AI kill switches, request caps, usage-cap enforcement env, and remaining external blockers stay documented.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 after adding the Stripe billing guard; the audit now confirms Stripe live-mode/pricing warnings stay documented and checkout, portal, and billing-sync functions/tests continue blocking `sk_live_...` unless `STRIPE_ALLOW_LIVE_MODE=true`.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 after extending the Stripe billing guard for subscription webhooks; the audit now confirms signature verification, subscription created/updated/deleted handling, `apply_stripe_subscription_update` wiring, cancel-at-period-end handling, active-plan mapping, and SQL RPC grant/update behavior stay present.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 after adding the manual UAT matrix coverage guard; the audit now confirms the matrix still covers required evidence, exit rules, clean install/permissions, Dictation, Context, Talk, Act, website/legal/download, resilience, blocked action, and support export rows.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 after adding the beta communications guard; the audit now confirms beta copy remains internally held, Beta-labeled, agent-context positioned, support-contact aligned, and complete across known limitations, permissions, privacy/memory, data processing, support escalation, monitoring, and clean-install instructions.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 after extending the beta communications guard for uninstall/reset-memory guidance; the audit now confirms the note remains present, prefers in-app memory deletion, identifies the current build's Voiyce-owned local memory paths, and keeps manual local reset support-guided.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 after adding the rollback runbook guard; the audit now confirms the runbook keeps the smallest-surface rollback principle, dirty-tree DMG warning, support contact, severity/triage sections, landing/R2/backend/app rollback paths, post-rollback verification, and incident note template.
- `deno test --allow-env insforge/functions/computer-use-step/index.test.ts`: passed with 16 tests on 2026-05-18. Coverage includes the current hosted Responses API `computer` tool payload, first-step task input, follow-up screenshot output, safety instructions, prohibited request blocking before OpenAI, kill switches, CORS/method handling, auth/database/upstream failure redaction, preserved upstream auth/rate-limit statuses, and usage reserve/finalize behavior.
- `scripts/verify-release-archive.sh`: passed on 2026-05-18. Coverage: temporary Xcode Release archive build, archived app presence check, archived app codesign verification, and archived app OpenAI-key secret scan. It did not export an app, create a DMG, notarize, upload, or change existing `build/release` artifacts.
- `scripts/verify-release.sh --skip-ui-tests --archive-check`: passed on 2026-05-18 as a diagnostic integrated archive path. Coverage: source OpenAI-key scan, 72 Swift unit tests, UI tests intentionally skipped, 55 backend Deno tests, launch-site verification including `/api/download-health`, landing lint/build, landing build secret scan, Release app build, built Release app secret scan, temporary Release archive build, archived app codesign verification, and archived app secret scan. It did not package, notarize, upload, or change existing DMG/release artifacts.
- `scripts/verify-public-dmg.sh`: passed on 2026-05-18 for the current public `1.0+16` R2 DMG. Coverage: `latest.json`, SHA-256, `hdiutil verify`, DMG Gatekeeper acceptance, stapled notarization ticket, read-only mount, mounted `Voiyce.app` presence, `/Applications` symlink, app signature verification, app Gatekeeper acceptance, bundle version/build match, mounted app OpenAI-key scan, detach, and temp cleanup.
- `scripts/verify-release.sh --skip-ui-tests --public-dmg-check`: passed on 2026-05-18 as a diagnostic integrated public-DMG path. Coverage: source OpenAI-key scan, 72 Swift unit tests, UI tests intentionally skipped, 55 backend Deno tests, launch-site verification including `/api/download-health`, landing lint/build, landing build secret scan, Release app build, built Release app secret scan, and `scripts/verify-public-dmg.sh`.
- `scripts/verify-release-source-state.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'`: passed on 2026-05-20; it confirmed `MARKETING_VERSION=1.0`, `CURRENT_PROJECT_VERSION=16`, no merge conflicts, clean source state, and tag `v1.0+16` at HEAD.
- `scripts/verify-agent-usage-caps.sh`: passed on 2026-05-19. It verified 12 tier/capability cap rows, 4 cost-bearing function/test pairs, and 57 backend usage-cap tests across Computer Use, Realtime, transcription, and screen-context.
- `scripts/verify-release.sh --source-state-check --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --skip-ui-tests`: exited `1` as expected on 2026-05-18 before tests/build/package work because strict source-state verification is blocked by the dirty tree and missing release tag.
- `scripts/verify-launch-site.sh --url http://localhost:23002`: passed on 2026-05-18 against `next start` production preview after adding byte-level icon/favicon/OG payload checks.
- `scripts/verify-rollback-readiness.sh`: passed on 2026-05-18. It verified the current public `1.0+16` latest/versioned R2 artifacts, verified the previous known-good `1.0+1` rollback candidate and sidecar, generated a local rollback `latest.json`, and made no R2 changes.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 and reported eight expected readiness blockers. `scripts/audit-launch-readiness.sh` exited `1` as intended while those blockers remain. `scripts/audit-launch-readiness.sh --live --allow-blockers` verified the public R2 manifest metadata and reported production `/api/download-health` as still blocking.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 after adding the OAuth/Accessibility requirement guard; the audit now confirms local Agent requirement failures and Google Workspace OAuth failures keep concrete `next_step` recovery data alongside `requires`.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 110 tests on 2026-05-18 after adding disconnected-Google next-step coverage and hardening Google Workspace OAuth-required results.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 after adding the onboarding launch-copy guard; the audit now confirms first-run onboarding keeps agent-context positioning.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 111 tests on 2026-05-18 after adding `onboardingLaunchCopyStaysAgentContextPositioned`.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 after adding the Act cancellation next-step guard; the audit now confirms stopped Act commands do not regress to status-only failed results.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 111 tests on 2026-05-18 after extending `actModeCancellationStopsBeforeActionLoopAndWritesCancelledEvent` to assert the cancelled tool result and Agent Log entry include recovery next-step data.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 after adding the dashboard/tier-copy implementation-language guard; the audit now confirms dashboard offline copy and tier-limit copy avoid server/Computer Use terms.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 111 tests on 2026-05-18 after extending `dictationRecoveryCopyStaysUserFacing` and `agentCapabilityTierGatesModesAndStorage` to cover dashboard offline and tier-limit copy.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 after adding the onboarding/settings rough-term copy guard; the audit now confirms onboarding permission recovery and Settings support-export copy avoid authorization/debugging language.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 112 tests on 2026-05-18 after adding `settingsLaunchCopyStaysSupportFacing` and extending onboarding permission-copy coverage.
- Settings support-export status copy now calls the generated bundle a redacted support log in success and failure states, so the Settings path stays aligned with Agent Log privacy expectations.
- `scripts/audit-launch-readiness.sh --allow-blockers` now directly guards the Settings support-export success and failure copy so it continues to name the generated bundle as a redacted support log.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test -only-testing:Voiyce-AgentTests`: passed with 114 tests on 2026-05-19 after tightening Settings support-export success/failure copy to explicitly say redacted support log.
- `scripts/verify-release-source-state.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --allow-blockers --dirty-summary`: passed as a prep-stage audit on 2026-05-19 and confirmed the canonical dirty-tree blocker remains 123 paths plus the missing `v1.0+16` tag.
- `scripts/verify-launch-blockers.sh`: passed on 2026-05-19 with eight expected blockers and zero unexpected blockers.
- `scripts/verify-evidence-generators.sh`: passed on 2026-05-19 and confirmed the evidence generators still reflect version `1.0`, build `16`, tag `v1.0+16`, and the 123-path dirty-tree blocker.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-19 with 1643 checks and the same eight allowed launch blockers after adding the Talk voice input/output UAT guard, production landing auth-env evidence guards, explicit billing/account UAT generator rows, the cross-app Context quality UAT guard, Talk Agent Log review UAT guard, dictation short-text and punctuation UAT guards, launch-location parity and permission-return routing UAT guards, dictation wrong-field protection and Vault Notes visibility UAT guards, public-form submit confirmation and action-log audit UAT guards, Normal/Unrestricted Act safety smoke UAT guards, Talk stop-during-tool-call UAT guard, Act network-drop UAT guard, download-health fallback UAT guard, explicit Act confirmation UAT guards, the active account-access-loss UAT guard, risk/exception register generator guard, Google Workspace OAuth review generator guard, Stripe live billing review generator guard, production landing cutover generator guard, OpenAI key rotation generator guard, Act safety incident generator guard, support inbox generator guard, invite-resume generator guard, invite-batch generator guard, launch monitoring generator guard, exploratory QA generator guard, clean-install UAT generator guard, pre-invite decision generator guard, privacy/security review generator guard, app/landing vague-copy guard, AI usage/quota monitoring record guard, production evidence packet AI usage/quota fields, launch evidence package risk/exception guard, manual UAT clean-user/no-network evidence guard, release source disposition include/split/remove guard, production support-path proof guard, launch evidence support-path index guard, launch evidence rollback-readiness index guard, core Dictation launch-evidence result fields, core Context launch-evidence result fields, core Talk launch-evidence result fields, core Act Phase 2 launch-evidence result fields, release source-freeze review-order/command guardrails, row-level website/legal/UI polish launch-evidence fields, and row-level resilience/recovery launch-evidence fields.
- `scripts/generate-privacy-security-review.sh` now prints a no-read-secret/no-write privacy and security review worksheet with current source facts, secret/bundle scan slots, support export and Agent Log redaction checks, local memory/screenshot/vault/delete review, user-facing disclosure checks, no-secret handling, blockers, and final owner sign-off.
- `scripts/generate-pre-invite-decision.sh` now prints a no-read-secret/no-write pre-invite launch/no-launch decision worksheet with current source facts, required evidence links, explicit blocker checks, exact-artifact fields, support/rollback/privacy evidence, no-secret/private-data handling, and final owner sign-off.
- `scripts/generate-clean-install-uat.sh` now prints a no-read-secret/no-write clean-install UAT worksheet for downloaded-DMG install, first launch, sign-in, permission prompt state after refresh/quit/reopen/revoke, core Dictation/Context/Talk/Act smoke, physical offline launch, support export redaction, privacy-safe evidence review, and final owner sign-off.
- `scripts/generate-exploratory-qa-pass.sh` now prints a no-read-secret/no-write exploratory QA worksheet for founder-work, permission-chaos, privacy-edge, Agent-stress, account/billing, visual-polish, and public web/artifact charters, with required observations, finding severity, privacy-safe evidence review, workaround decisions, and final owner sign-off.
- `scripts/generate-launch-monitoring-record.sh` now prints a no-read-secret/no-write launch monitoring worksheet for first-hour, first-day, weekly expansion, and after-change checks across website/Vercel, R2, InsForge, OpenAI usage/quota, Stripe, support inbox, signals, pause/resume decisions, and privacy-safe evidence handling.
- `scripts/generate-invite-batch-record.sh` now prints a no-read-secret/no-write invite batch worksheet for exact artifact identity, batch ownership, support/monitoring/rollback coverage, known limitations, launch evidence links, pause criteria, and privacy-safe invite evidence handling.
- `scripts/generate-invite-resume-checklist.sh` now prints a no-read-secret/no-write invite-resume worksheet for restarting invites after a pause, incident, failed verification, backend change, landing deployment, billing change, or artifact change with required verification, resume safety checks, pause authority, and privacy-safe evidence handling.
- `scripts/generate-support-inbox-readiness.sh` now prints a no-read-secret/no-write support inbox readiness record for owner coverage, first-hour and first-day monitoring, escalation paths, support-path proof, pause authority, and privacy-safe support evidence.
- `scripts/generate-act-safety-incident.sh` now prints a no-read-secret/no-write Act safety incident record for unexpected actions, missing confirmations, blocked actions, sensitive workflows, Stop failures, kill-switch review, capability narrowing, invite decisions, and privacy-safe evidence handling.
- `scripts/generate-openai-key-rotation.sh` now prints a no-read-secret/no-write OpenAI key rotation worksheet for exposed-key revocation, server-side replacement, source/app/landing/DMG secret scans, post-rotation smoke, old-key negative checks, usage/quota alerts, and no-secret evidence handling.
- `scripts/generate-production-landing-cutover.sh` now prints a no-read-secret/no-write production landing cutover worksheet for Vercel deployment identity, deployed commit, download and auth env review, auth callback/sign-in smoke, production smoke, stale-copy rejection, R2 artifact identity, rollback deployment, monitoring, resume decision, and no-secret evidence handling.
- `scripts/generate-stripe-live-billing-review.sh` now prints a no-read-secret/no-write Stripe live billing review worksheet for live-mode decision, product/price ids, checkout and portal evidence, webhook endpoint and signing-secret presence, subscription mapping, refund/cancellation copy, support ownership, monitoring, and no-payment-data evidence handling.
- `scripts/generate-google-workspace-oauth-review.sh` now prints a no-read-secret/no-write Google Workspace OAuth worksheet for OAuth app identity, redirect URIs, Gmail/Calendar scopes, consent copy, test-account connection, missing/revoked OAuth recovery, token/privacy handling, support evidence, and launch decision handling.
- `scripts/generate-risk-exception-register.sh` now prints a no-read-secret/no-write risk and exception register for accepted P2s, skipped diagnostics, manual UAT gaps, external/account blockers, support exceptions, workaround copy, owner assignment, hold triggers, no-secret/private-data handling, and invite/release decisions.
- `scripts/generate-release-source-disposition.sh` now includes Include In Release Candidate, Split Out Before Release, and Remove Or Regenerate sections so the 123-path dirty-tree blocker can be resolved with explicit source inclusion decisions before a release tag or fresh DMG.
- `scripts/generate-launch-evidence-package.sh` now includes support-path proof fields, rollback-readiness evidence fields, and a Risk And Exception Register so inbox test-message evidence, first-reply evidence, P0/P1 escalation evidence, landing/R2/backend/app rollback proof, accepted limitations, skipped diagnostics, external blockers, P0/P1 holds, P2 workarounds, secret/private-data/payment/unsafe-Act risks, and release-note/support-copy alignment are reviewed before invite or release decisions.
- `scripts/generate-manual-uat-pass.sh` now makes clean-user permission sync and physical no-network launch from the downloaded app explicit scripted rows and required measurements, with generator/audit checks to keep the remaining physical UAT evidence visible.
- `scripts/generate-manual-uat-pass.sh` now includes an explicit Act network-drop row and required result field, with generator/audit checks so physical Act connection-loss recovery must be recorded before launch.
- `scripts/generate-manual-uat-pass.sh` now includes an explicit Talk stop-during-tool-call row and required result field, with generator/audit checks so stopping a slow tool lookup is recorded before launch.
- `scripts/generate-manual-uat-pass.sh` now includes explicit Normal and Unrestricted Act safety smoke rows and result fields, with generator/audit checks so all Act safety modes have bounded physical UAT coverage.
- `scripts/generate-manual-uat-pass.sh` now includes explicit Act public-form submit confirmation and action-log audit rows, with generator/audit checks so submit confirmation behavior and support-useful logs are recorded before launch.
- `scripts/generate-manual-uat-pass.sh` now includes explicit dictation wrong-field protection and Vault Notes visibility rows, with generator/audit checks so focus safety and vault output are recorded before launch.
- `scripts/generate-manual-uat-pass.sh` now includes explicit launch-location parity and permission-return routing rows, with generator/audit checks so mounted-DMG/Application launch behavior and macOS permission-return loops are recorded before launch.
- `scripts/generate-manual-uat-pass.sh` now includes explicit dictation short-text and punctuation rows, with generator/audit checks so baseline text quality is recorded separately from native/browser insertion and long-paragraph coverage.
- `scripts/generate-manual-uat-pass.sh` now includes explicit dictation native-field, browser-field, long-paragraph, cancel, offline, and microphone-denied result fields, with generator/audit checks so core Dictation launch evidence is recorded row by row.
- `scripts/generate-manual-uat-pass.sh` now includes explicit Context start/stop, memory write, Private Mode, app/site exclusion, delete-memory, and multi-display result fields, with generator/audit checks so core Context launch evidence is recorded row by row.
- `scripts/generate-manual-uat-pass.sh` now includes explicit Talk current-screen, memory-recall, network-drop, missing-OAuth, long-thought/correction, and repeated-tool-request result fields, with generator/audit checks so spoken-agent launch evidence is recorded row by row.
- `scripts/generate-manual-uat-pass.sh` now includes explicit Act safety-mode, navigation, form-fill, Gmail draft, Calendar read, desktop switching, blocked-action, Stop-during-cursor, permission-recovery, and mid-task Agent Log result fields, with generator/audit checks so Act Phase 2 launch evidence is recorded row by row.
- `scripts/generate-manual-uat-pass.sh` now splits website, auth/download, legal, and UI polish UAT into explicit rows and result fields, with generator/audit checks so public web, visual, keyboard, VoiceOver, motion, and contrast evidence is recorded row by row.
- `scripts/generate-manual-uat-pass.sh` now includes explicit resilience result fields for no-network launch, sleep/wake, mid-session permission revocation, quit while active, multi-display changes, and support-export privacy review, with generator/audit checks so recovery evidence is recorded row by row.
- `scripts/generate-manual-uat-pass.sh` now includes an explicit Talk Agent Log review row, with generator/audit checks so spoken-session logs are reviewed separately from Act logs.
- `scripts/generate-manual-uat-pass.sh` now includes an explicit Talk voice input/output smoke row, with generator/audit checks so physical microphone input, model audio output, and Stop audio cleanup are recorded before launch.
- `scripts/generate-manual-uat-pass.sh` now includes an explicit cross-app Context quality row, with generator/audit checks so real browser/code-editor/app coverage is recorded separately from basic start/stop.
- `scripts/generate-manual-uat-pass.sh` now includes explicit billing mode, checkout/portal, account-access transition, and usage-limit recovery rows, with generator/audit checks so billing/account UAT is recorded item by item instead of collapsed into one aggregate pass.
- `scripts/generate-production-evidence-packet.sh` now requires support inbox test-message, first-reply, and P0/P1 escalation evidence so support ownership is proven before invite expansion instead of only assigned.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 after adding the Agent Log support-copy guard; the audit now confirms Agent Log avoids the old error/investigate/search-copy labels.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 113 tests on 2026-05-18 after adding `agentLogLaunchCopyStaysSupportFacing`.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 after adding the Agent runtime failure-status guard; the audit now confirms Context startup failure does not regress to the blunt `Error` status label.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 114 tests on 2026-05-18 after adding `agentRuntimeLaunchCopyStaysRecoveryOriented`.
- Agent Off-mode summary now tells users to start Context, Talk, or Act when they want Voiyce to help, replacing softer companion-style copy with concrete mode language.
- `scripts/audit-launch-readiness.sh --allow-blockers`: passed on 2026-05-18 after adding the Agent Off-mode wording guard; the audit now confirms the Off summary keeps concrete Context/Talk/Act language and does not regress to companion-style copy.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 114 tests on 2026-05-18 after extending `agentModeCopyMatchesExpectedCapabilities` to guard the Agent Off summary.
- `scripts/audit-launch-readiness.sh --allow-blockers` now scans app and landing source for vague launch phrases like "boost productivity," "revolutionize," "unlock your potential," "AI-powered," and "seamless experience" so the PRD copy rule is enforced outside the PRD itself.
- `docs/manual-uat-matrix.md` now includes explicit Billing, Account Limits, and Access rows for Stripe mode sanity, checkout/portal access, account access transitions, and usage-limit recovery.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that the manual UAT matrix keeps the billing/account section plus account-access and usage-limit recovery rows.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that the manual UAT matrix keeps measured Talk first-response, interruption-settling, and tool-delay progress-phrase rows.
- Added matching Talk measurement fields to the UAT result template so completed passes preserve the exact first-response, interruption, and tool-delay notes.
- `scripts/audit-launch-readiness.sh --allow-blockers` now also checks that spoken Talk UAT keeps explicit long-thought/correction and repeated-tool-request rows.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that Talk UAT keeps an explicit stop-during-tool-call row and generated result field.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that Act UAT keeps explicit Normal and Unrestricted safety smoke rows and generated result fields.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that Act UAT keeps explicit public-form submit confirmation and action-log audit rows plus generated result fields.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that manual UAT keeps explicit dictation wrong-field protection and Vault Notes visibility rows plus generated result fields.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that manual UAT keeps explicit launch-location parity and permission-return routing rows plus generated result fields.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that manual UAT keeps explicit dictation short-text and punctuation rows plus generated result fields.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that manual UAT keeps an explicit Talk Agent Log review row plus generated result field.
- `scripts/audit-launch-readiness.sh --allow-blockers` now checks that manual UAT keeps an explicit cross-app Context quality row plus generated result field.
- Added explicit date and pass/fail note fields to the UAT result template, with launch audit guards for tester, date, machine, macOS version, and pass/fail notes.
- Added explicit P2 user-impact, workaround, and owner-acceptance fields to the UAT result template, with launch audit guards so exit decisions can support the documented workaround requirement.
- Added screenshot/recording and Agent Log/support export link fields to the UAT result template, with launch audit guards so pass/fail evidence has a stable place to be recorded.
- Mirrored the screenshot/support-export/P2-impact/P2-workaround/owner-approval fields into the canonical manual UAT final-decision block and added launch audit guards for them.
- Added automated-check command, result-link, and owner-approved exception fields to the UAT result template, with launch audit guards so the automated-gate exit criterion has reviewable evidence.
- Added explicit no-known-P0/P1 and support/contact/release-notes-match fields to the UAT decision templates, with launch audit guards for both.
- Added a dedicated Visual And Navigation Polish section to the manual UAT matrix for onboarding, Dashboard/sidebar, Settings, Agent, Agent Log, menu bar, and app menu review, with launch audit guards for each row.
- Added an explicit active account-access-loss resilience row to the manual UAT matrix and generated UAT worksheet, with launch audit guards so sign-out or payment-required transitions while Dictation, Context, Talk, or Act is active stay part of the physical launch pass.
- Added explicit Act confirmation approve, cancel, Stop Session, and timeout rows to the manual UAT matrix and generated UAT worksheet, with launch audit guards so physical confirmation behavior is exercised instead of inferred from generic Act rows.
- Added an explicit Act network-drop row to the manual UAT matrix and generated UAT worksheet, with launch audit guards so connection-loss behavior during Act is recorded instead of inferred from Talk or automated telemetry.
- Added an explicit Talk stop-during-tool-call row to the manual UAT matrix and generated UAT worksheet, with launch audit guards so slow tool lookup cancellation is tested as its own launch behavior.
- Added explicit Normal and Unrestricted Act safety smoke rows to the manual UAT matrix and generated UAT worksheet, with launch audit guards so launch testing covers every Act safety mode with harmless bounded tasks.
- Added explicit Act public-form submit confirmation and action-log audit rows to the manual UAT matrix and generated UAT worksheet, with launch audit guards so submit confirmation behavior and support-safe action logs are reviewed separately from generic form filling.
- Added explicit dictation wrong-field protection and Vault Notes visibility rows to the manual UAT matrix and generated UAT worksheet, with launch audit guards so active-field safety and Obsidian-style vault output are reviewed separately from generic dictation and memory-write rows.
- Added explicit launch-location parity and permission-return routing rows to the manual UAT matrix and generated UAT worksheet, with launch audit guards so mounted-DMG/Application launch behavior and duplicate permission-return loops are reviewed separately from generic install and permission rows.
- Added explicit dictation short-text and punctuation rows to the manual UAT matrix and generated UAT worksheet, with launch audit guards so basic text quality is reviewed separately from insertion-target and long-paragraph checks.
- Added an explicit Talk Agent Log review row to the manual UAT matrix and generated UAT worksheet, with launch audit guards so spoken-session events are checked for usefulness and privacy separately from Act action logs.
- Added an explicit cross-app Context quality row to the manual UAT matrix and generated UAT worksheet, with launch audit guards so browser/code-editor/app-screen capture quality is reviewed separately from basic Context start/stop and memory-write checks.
- Added an explicit download-health fallback row to the manual UAT matrix and generated UAT worksheet, with launch audit guards so healthy public downloads and unreachable-artifact recovery are both recorded before launch.
- Added a production environment verification template to `docs/phase-2-production-hardening.md` covering OpenAI, InsForge functions/database, Vercel, Cloudflare R2, Stripe, and support inbox evidence, with launch audit guards so account-level checks stay concrete without copying secrets.
- Added explicit production landing auth-env evidence fields for `NEXT_PUBLIC_INSFORGE_URL`, `NEXT_PUBLIC_INSFORGE_ANON_KEY` presence, and auth callback/sign-in smoke, with generator/verifier/audit guards so the PRD's download/auth env check cannot be satisfied by download URL evidence alone.
- Added an AI usage and quota monitoring record to `docs/phase-2-production-hardening.md` so invite decisions have concrete OpenAI usage, alert-threshold, per-capability trend, usage-cap, kill-switch, spike, and support-report evidence without copying secrets or private request data.
- Hardened Act unexpected-failure recovery so generic thrown errors use the standard Act recovery message instead of raw localized descriptions; Swift and launch-audit guards now cover that path.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 83 tests on 2026-05-18 after adding `agentActivityStatusOnlyAppearsWhileRunning` coverage for hidden/off state plus visible active Context and Act labels, and `billingLimitCopyExplainsAgentCapsPlainly` coverage for Pro, beta-budgeted Context/Talk/Act, unavailable Power-level Act limits, and vague-copy regressions.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentUITests/Voiyce_AgentUITests/testAgentScreenPolishAndStartStopControls`: passed on 2026-05-18 after adding sidebar active-status assertions for Context and Act.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentUITests/Voiyce_AgentUITests/testAgentScreenPolishAndStartStopControls`: passed on 2026-05-18 after adding the self-contained Agent mode map. An initial parallel run failed from an Xcode build database lock while unit tests were still running; the sequential rerun passed.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 81 tests after adding per-account memory isolation, structured memory-source labels, vault frontmatter, account-scoped Vault Notes toggle coverage, Settings vault setup controls, and saved-memory recall copy/citation guidance. Earlier in the same launch-readiness pass it also covered app-termination, system sleep, and display-layout cleanup for active runtime state reset, local session-context shutdown, Act display-change pause policy, and stale focus-region clearing.
- `deno test --allow-env insforge/functions/realtime-session/index.test.ts`: passed with 19 tests after adding screen/active-session/saved-memory context-routing coverage, saved-memory grounding, technical-source-name instruction guards, semantic VAD low-eagerness turn-detection coverage, missing OAuth/permission anti-hallucination instruction coverage, and pending-confirmation approve/cancel/stop-session voice-routing coverage.
- `curl -i -sS http://localhost:23001/api/download-health` under `NEXT_PUBLIC_DOWNLOAD_URL=http://127.0.0.1:9/Voiyce.dmg`: returned `503` with a safe unreachable-artifact JSON body.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -destination 'platform=macOS' test -only-testing:Voiyce-AgentUITests/Voiyce_AgentUITestsLaunchTests`: passed with 2 tests after adding signed-out/offline launch recovery coverage.
- `scripts/verify-launch-site.sh --url http://localhost:23000 --visual`: passed on 2026-05-17.
- `scripts/verify-launch-site.sh`: passed on 2026-05-18 after changing landing lint to run with `--max-warnings=0`, verifying the launch-site gate now fails on future lint warnings while still passing the current source and build.
- `scripts/verify-launch-site.sh`: passed on 2026-05-18 after centralizing landing support email through `voiyce-config.ts`, updating source guardrails for auth/download/legal support copy, and replacing remaining landing raw `<img>` usages. The script required running outside the sandbox because Turbopack attempted local port binding during `next build`; lint passed with zero warnings.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentUITests/Voiyce_AgentUITests/testActCommandCanUseNativeVoiyceNavigation -only-testing:Voiyce-AgentUITests/Voiyce_AgentUITests/testActCommandShowsMainStopWhileRunning`: passed with 2 tests after active Act command Stop/cancel hardening.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentTests`: passed with 70 tests after support-export schema metadata/event ID coverage, app-side account-limit recovery copy/logging, Realtime connection-failure recovery coverage, Talk latency telemetry coverage, Action Cursor presentation-gating/animation/multi-display coverage, Focus Highlight shortcut/geometry/capture and clear/log coverage, live-session privacy guardrails, session-context Agent Log privacy-pause coverage, Agent mode runtime-boundary coverage, Context startup recovery coverage, Settings permission-refresh polling coverage, memory/search/vault/OAuth-scope, raw-context redaction, permission-block diagnostics, service-failure diagnostics, failed-tool-call and successful-tool-call logging, memory-error diagnostics, Agent mode persistence, explicit Act safety-mode choice, Act safety-policy guardrails, confirmation Stop Session/cancel-execution guardrails, confirmation frontmost/rationale/timeout guardrails, Computer Use safety-check recovery, Act safety-check Agent Log coverage, Act permission/cancellation coverage, onboarding permission-copy guardrails, Agent hotkey toggle, dictation recovery-copy guard, Act mode recovery-copy guard, Talk mode recovery-copy guard, dictation service-failure Agent Log guard, session-context copy guard, Auth/Billing/Google recovery-copy guards, Agent tool bridge plain-failure/next-step/Strict-mode ordering guards, Act unexpected-failure guard, and memory/session-context raw-error hardening.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentUITests/Voiyce_AgentUITests/testDashboardSettingsAndAgentNavigation`: passed on 2026-05-18 after the Settings usage-limit row assertion was added. Earlier in the same launch-readiness pass, this test also covered the Settings Permissions refresh control.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentUITests/Voiyce_AgentUITests/testDashboardSettingsAndAgentNavigation`: passed on 2026-05-18 after expanding Dashboard, Settings, Agent, and Agent Log internal implementation-term guardrails and adding stable Settings permission-row identifiers for the Permissions tab checks.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentUITests/Voiyce_AgentUITests/testAgentModeSelectorShowsExpectedModes -only-testing:Voiyce-AgentUITests/Voiyce_AgentUITests/testAgentScreenPolishAndStartStopControls -only-testing:Voiyce-AgentUITests/Voiyce_AgentUITests/testStopVisibleForTalkAndActSessions -only-testing:Voiyce-AgentUITests/Voiyce_AgentUITests/testActCommandCanUseNativeVoiyceNavigation -only-testing:Voiyce-AgentUITests/Voiyce_AgentUITests/testActCommandShowsMainStopWhileRunning`: passed with 5 tests after explicit Act safety-mode choice.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' test -only-testing:Voiyce-AgentUITests`: passed with 8 tests after focus hardening, Agent screen polish coverage, Settings hotkey documentation coverage, Agent context-consent copy, Talk/Act Stop visibility coverage, active Act command Stop/cancel coverage, Agent Log support-readiness coverage, and launch smoke coverage.
- `xcodebuild -project Voiyce-Agent.xcodeproj -scheme Voiyce-Agent -configuration Debug -destination 'platform=macOS' clean build`: passed on 2026-05-17.
- `deno test --allow-env insforge/functions/*/*.test.ts`: passed with 71 tests after the latest Realtime instruction guardrails, backend request-size, usage-cap, account-limit response, no-secret-error, OpenAI auth/rate-limit failure-injection, auth-provider failure-injection, InsForge database/RPC failure-injection, Computer Use abuse-case, Stripe live-mode guardrails, Stripe webhook signature/event/RPC mapping coverage, VideoDB session-context safe-failure/kill-switch/query-cap coverage, and shared token redaction coverage.
- Note: earlier full-gate attempts exposed an external-window focus flake and then a local XCTest automation-mode timeout. The UI target now re-activates Voiyce and hides other apps before navigation/clicks; both the isolated UI target and the current full no-package release gate passed afterward.

## Fast Site Gate

Use this during every landing/legal copy pass:

```bash
scripts/verify-launch-site.sh --url http://localhost:23000
```

It checks:

- required route files
- required launch assets
- required agent-context positioning
- forbidden/outdated copy phrases
- Terms and Privacy contact email
- basic accessibility guardrails
- download URL fallback guardrails
- download-health API and auth recovery-copy guardrails
- landing lint
- landing production build
- landing build output for leaked OpenAI API keys
- optional live route health
- optional live icon/favicon/OG payload validation
- optional live rendered-copy and CTA/link assertions
- optional Chrome visual QA across desktop/mobile breakpoints, including full-page color contrast

Latest result:

```bash
scripts/verify-launch-site.sh --url http://localhost:23000
```

Result on 2026-05-19: passed after starting a temporary local landing dev server on port `23000`. The gate covered required files/assets, launch-copy guardrails, agent-context positioning, legal contact/product coverage, download fallback, auth recovery copy, accessibility smoke checks, zero-warning landing lint, production build, landing build secret scan, live route checks, social image/favicon payloads, rendered home/CTA checks, and live auth/download/legal content. The temporary dev server was stopped after verification.

## Production Landing Gate

Use this after deploying the revised landing page and before sending beta invites:

```bash
scripts/verify-production-landing.sh https://voiyce.us
```

It does not build or deploy anything. It only fetches the public site and verifies the deployed home/auth/download/legal routes, the `/api/download-health` route, current agent-context copy, absence of stale dictation-first copy, legal contact, and social image/favicon payloads.

## Heavy Release Gate

Use this before a real release candidate:

```bash
scripts/verify-release.sh
```

Before uploading or sharing a public artifact:

```bash
scripts/verify-release.sh --package --public-download-check
```

This is intentionally heavier because it includes macOS tests/builds, backend tests, app packaging, and optional public R2 verification.

After deploying the revised public landing page, include the production smoke check before inviting users:

```bash
scripts/verify-release.sh --skip-ui-tests --public-download-check --production-landing-check
```

Use the full UI-enabled variant for a final release candidate when local UI automation is healthy:

```bash
scripts/verify-release.sh --public-download-check --production-landing-check
```

## Final Self-Serve Preflight Sequence

Run this sequence before any broader beta invite, release-note send, public DMG upload, or production launch announcement. Keep command output links in the launch evidence package. Do not paste secrets, raw transcripts, private screenshots, OAuth tokens, or payment details into the record.

### Non-Mutating Prep Checks

These commands should not build a new DMG, deploy, upload, tag, or change release artifacts:

```bash
scripts/audit-launch-readiness.sh --allow-blockers
scripts/verify-release-source-state.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --allow-blockers
scripts/generate-release-source-disposition.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-launch-evidence-package.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-manual-uat-pass.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-clean-install-uat.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-exploratory-qa-pass.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-launch-monitoring-record.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-invite-batch-record.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-invite-resume-checklist.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-support-inbox-readiness.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-act-safety-incident.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-openai-key-rotation.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-production-evidence-packet.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-production-landing-cutover.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-stripe-live-billing-review.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-google-workspace-oauth-review.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-risk-exception-register.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-privacy-security-review.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/generate-pre-invite-decision.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/verify-evidence-generators.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/verify-launch-blockers.sh
scripts/verify-launch-site.sh --url http://localhost:23000 --visual
scripts/verify-production-landing.sh https://voiyce.us
scripts/verify-rollback-readiness.sh
```

### Exact Candidate Checks

Run these only when the candidate source tree, public artifact, and production landing target are the ones users will receive:

```bash
scripts/verify-release.sh --source-state-check --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --archive-check --public-download-check --public-dmg-check --production-landing-check
```

If local UI automation is temporarily unhealthy, the diagnostic fallback is:

```bash
scripts/verify-release.sh --source-state-check --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --archive-check --public-download-check --public-dmg-check --production-landing-check --skip-ui-tests
```

Do not treat the `--skip-ui-tests` fallback as release-candidate proof unless the owner records an explicit exception and the manual UAT pass covers the missing UI automation surface.

### Manual And Account Evidence

Before invites resume, complete and link:

- Clean-machine or clean-user install from the exact DMG.
- Manual UAT result for onboarding, permissions, Dictation, Context, Talk, Act, Agent Log, Settings, billing/account access, legal/download routes, and support export.
- Final privacy and security review.
- Production environment verification for OpenAI key rotation, InsForge function env, Vercel, Cloudflare R2, Stripe mode/products/webhooks, and support inbox ownership.
- Rollback readiness evidence for landing, R2, backend functions, and app artifact.
- Release notes tied to the exact artifact, not the draft template.

### Artifact-Changing Commands

Run artifact-changing commands only after the source tree is clean, tagged, and the exact-candidate checks above pass. Keep these out of prep-stage audits:

```bash
scripts/verify-release.sh --source-state-check --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --package --public-download-check --public-dmg-check --production-landing-check
```

## Remaining Before Beta Sharing

### Must Finish Internally

- [x] Rerun `scripts/verify-release.sh` from the current branch with UI tests enabled after the local XCTest automation runner recovers.
- [x] Resolve the current XCTest UI automation-mode timeout.
- [x] Resolve external-window UI automation focus failures in the macOS UI test target.
- [x] Resolve any failing macOS, backend, or landing checks.
- [x] Run a temporary Release archive build without creating or mutating DMG/release artifacts.
- [x] Run no-mutation public DMG mount/signature/Gatekeeper/notarization verification.
- [ ] Run a clean-machine install from the public DMG.
- [ ] Complete onboarding permission UAT.
- [ ] Complete Dictation, Context, Talk, and Act manual UAT.
- [x] Verify memory deletion and retention controls.
- [x] Verify Private Mode pauses durable memory, raw screenshot storage, and live session context capture.
- [x] Verify app/site exclusions skip memory writes, raw screenshot storage, and live session context capture when the current app/window matches an exclusion.
- [x] Verify sensitive contexts pause live session context capture where detectable.
- [x] Verify memory search returns relevant prior context and handles no results.
- [x] Verify the Markdown vault writes readable, date-organized Markdown without requiring Obsidian.
- [x] Verify Default/Pro/Power usage caps are implemented server-side for Realtime, transcription, Computer Use, and context when cap enforcement is enabled.
- [x] Verify durable memory storage and raw screenshot storage have tier-based quotas beyond local retention controls.
- [x] Verify privacy copy matches actual local memory, raw screenshot, Private Mode, exclusion, support export, and delete behavior.
- [x] Verify Google OAuth scopes match the current Gmail/Calendar feature surface.
- [x] Verify app copy does not imply Gmail/Calendar access before Google OAuth is connected.
- [x] Verify refund, subscription, and cancellation copy matches the active Stripe Checkout and billing portal flow.
- [x] Verify Agent Log and support export redaction.
- [x] Verify support export redaction patterns for emails, bearer tokens, and OpenAI-style keys.
- [x] Verify stored Agent Log event JSON redacts sensitive event titles, summaries, and details.
- [x] Verify generated support export JSON redacts sensitive event titles, summaries, and details.
- [x] Verify stored Agent Log JSON and support export JSON redact raw transcript, screenshot, image data URL, and long blob payloads.
- [x] Verify support export schema has stable version/kind metadata and event IDs for future support tooling.
- [x] Verify Agent Log is useful to a non-developer power user and to support.
- [x] Verify missing Screen Recording and Accessibility permission blocks write support-useful Agent Log/support export events.
- [x] Verify Act can fail safely when Accessibility or Screen Recording permission is missing.
- [x] Verify OpenAI-backed Realtime, transcription, and Computer Use failures write support-useful Agent Log/support export events with upstream status and next-step detail.
- [x] Verify Act requires an explicit Strict, Normal, or Unrestricted safety-mode choice before first start or one-off command.
- [x] Verify Strict safety policy asks before click, type, keypress, send, submit, delete, purchase, account change, external post, and other high-impact operations.
- [x] Verify Normal safety policy asks before high-impact operations while allowing low-risk app/URL navigation.
- [x] Verify Unrestricted safety policy skips confirmations while still blocking catastrophic deletion, credential theft, malware, fraud, illegal access, hidden actions, and platform-abusive actions.
- [x] Verify confirmation copy includes the exact action, target, and expected consequence.
- [x] Verify confirmation Stop Session cancels the pending action, stops the Agent session, logs the decision, and prevents later approval/execution.
- [x] Verify native confirmation prompts order front across spaces, stay visible after app deactivation, and avoid hiding a newer confirmation by stale id.
- [x] Verify Talk/Act confirmation results include a short spoken reason for why approval is needed.
- [x] Verify stale confirmations time out, write support-visible Agent Log events, and cannot be approved/executed later.
- [x] Verify OpenAI Computer Use pending safety checks fail with a clear recovery path instead of exposing a dead approval flow.
- [x] Verify onboarding/dashboard dictation recovery copy does not expose provider keys, backend billing details, server-function language, or raw secret-management terms.
- [x] Verify Act command recovery copy does not expose Computer Use, provider keys, backend billing details, server-function language, or raw secret-management terms.
- [x] Verify Talk startup recovery copy does not expose provider keys, backend billing details, server-function language, or raw secret-management terms.
- [x] Verify dictation service-failure Agent Log/support export copy does not expose provider keys, backend billing details, server-function language, or raw secret-management terms.
- [x] Verify active-session context/search/summary copy does not expose VideoDB, Computer Use, OpenAI, backend, runtime, or raw capture-package terms.
- [x] Verify Auth, Billing, Google connection/OAuth callback, screen context, Agent tool bridge, Act unexpected-failure, support-export write, session-context helper, and memory-error paths do not expose raw SDK/OAuth/API/backend/token/localized failure text.
- [x] Verify rejected actions, confirmation waits, and failed Realtime tool calls write Agent Log events without duplicating confirmation waits as failures.
- [x] Verify successful Realtime/Talk tool calls write support-safe Agent Log completion events without copying raw tool result payloads.
- [x] Verify planned, approved, cancelled, failed, and completed Act actions write Agent Log events.
- [x] Verify local memory errors write support-useful Agent Log/support export events with operation, path, and next-step detail without copying raw filesystem error text into summaries.
- [x] Verify Agent hotkey toggle semantics and Settings hotkey documentation.
- [x] Verify Agent context capture is explicit before durable session memory starts.
- [x] Verify Stop is visible during active Context, Talk, and Act sessions.
- [x] Verify active Context and Act modes expose visible status outside the Agent screen.
- [x] Verify Stop cancels in-flight Act loops before continuing local Computer Use work when safe to do so.
- [x] Verify Act command failure results include structured next-step recovery data for missing task details, signed-out state, missing Accessibility, pending safety checks, and post-action Screen Recording loss.
- [x] Verify Action Cursor overlay is non-activating, mouse-transparent, all-spaces/full-screen friendly, gives local Act actions an animated visible lead-in before event posting, stays hidden outside active Act/action presentation unless preview mode is enabled, maps Computer Use coordinates from the captured display frame for multi-display setups, and remains visible with status lifecycle events during native Voiyce and Computer Use action paths.
- [x] Verify active Act remains recoverable while the user visits Agent Log or Settings, including visible return affordances and native Voiyce navigation from those surfaces without clearing `Act active` state.
- [x] Verify Focus Highlight rectangle/freeform geometry, passive click-through guide overlay policy, display selection, and focused-region crop math for single-display and multi-display coordinates.
- [x] Verify Focus Highlight global shortcut callbacks dispatch rectangle, paint, and underline mark modes.
- [x] Verify Focus Highlight create/clear state and Agent Log events.
- [x] Verify backend upstream errors do not expose secret-like upstream text to clients.
- [x] Verify Realtime, transcription, Computer Use, and screen-context preserve OpenAI 401/rate-limit statuses without exposing upstream payload text.
- [x] Verify Computer Use rejects high-confidence credential-theft, catastrophic-deletion, fraud, illegal-access, and hidden-action requests before calling OpenAI.
- [x] Verify Realtime, transcription, Computer Use, and screen-context stop before OpenAI and return generic errors when InsForge auth/session lookup fails.
- [x] Verify Realtime, transcription, Computer Use, and screen-context stop before OpenAI and return generic errors when InsForge database/RPC calls fail.
- [x] Verify Realtime, transcription, Computer Use, and screen-context can reserve and finalize estimated usage by capability when cap enforcement is enabled.
- [x] Verify Realtime, transcription, Computer Use, and screen-context return clear account-limit responses before OpenAI when usage caps are reached.
- [x] Verify app-side usage-limit responses are user-facing for Dictation, Talk, Act, and Screen context and logged as quota events.
- [x] Verify Settings and checkout explain upgrade-relevant limits for Pro, beta-budgeted Context/Talk/Act, and unavailable Power-level Act limits in plain language.
- [x] Verify signed-out/offline app launch shows concrete reconnect recovery copy and disables sign-in actions in deterministic UI automation.
- [ ] Verify physical no-network app launch from the downloaded app on a clean macOS user or clean machine.
- [x] Verify dictation network-loss mapping writes a support-useful Transcription service failure with reconnect next step.
- [x] Verify Talk/Act connection-loss telemetry writes a support-useful Talk service failure with reconnect next step.
- [x] Verify app termination clears active dictation/agent runtime state and stops local session-context capture.
- [x] Verify system sleep cleanup clears active dictation/agent runtime state and stops local session-context capture before wake.
- [x] Verify display-layout changes clear transient overlays/focus regions and pause active Act mode before stale coordinates can continue.
- [x] Verify Agent modes block or stop with support-useful permission recovery when required permissions are missing in deterministic policy coverage.
- [x] Verify the landing download route detects an unreachable configured installer URL and exposes a plain support recovery path before auto-starting the hidden download request.
- [x] Verify CORS preflight and unsupported-method behavior for Realtime, transcription, Computer Use, and screen-context functions.
- [x] Define temporary internal daily/monthly cap values for Default, Pro, and Power tiers.
- [x] Verify checkout, billing portal, and billing sync block Stripe live-mode keys without explicit `STRIPE_ALLOW_LIVE_MODE=true`.
- [x] Run desktop/mobile landing visual QA against localhost.
- [x] Run full-page landing/auth/download/legal color-contrast QA against localhost.
- [x] Verify OG image and favicon render in production preview.
- [x] Verify sensitive contexts are skipped by long-term memory.
- [x] Verify long-term memory records, vault path settings, and privacy settings are isolated by signed-in account.
- [x] Verify current screen, active-session context, and long-term memory tool results include distinct structured source labels.
- [x] Verify local memory vault notes include Obsidian-style frontmatter metadata for date, source, apps, tags, and privacy level.
- [x] Add self-serve Settings controls to create/open the default memory vault or choose an existing vault folder.
- [x] Verify the Vault Notes toggle is account-scoped and disabling it keeps structured memory searchable without writing Markdown vault notes.
- [x] Verify Talk/Act Realtime instructions require saved-memory grounding for previous-work or memory-dependent requests.
- [x] Verify saved-memory recall guidance asks the assistant to cite dates/sessions naturally and avoid internal source/tool names in normal speech.
- [x] Verify the app-side Computer Use loop sends screenshots/tasks, handles hosted computer actions, captures the next screen after local actions, and continues with response/call IDs.
- [x] Verify kill switches in the server-side function environment.
- [x] Verify no OpenAI API keys or secrets are present in source, app bundle, landing bundle, logs, or support exports.
- [x] Verify source, landing build output, and built Release app bundle contain no leaked OpenAI API keys.
- [x] Verify no stale legacy support-address references remain in source/docs.
- [x] Verify native Act text entry refuses blind paste/type fallback when the focused target is unsafe or unknown.
- [x] Decide launch label for the next public build: Beta.
- [x] Document known limitations for the Beta invite/release notes.
- [x] Add launch-day manual monitoring checks for Vercel, Cloudflare R2, InsForge functions, OpenAI usage, Stripe mode, and support triage.
- [x] Add release-day smoke checks for website, auth, download, DMG install, rollback ownership, and core app workflows.
- [x] Create release notes for the exact current public artifact intended for beta review.
- [x] Prepare draft release notes template.
- [x] Add a launch-readiness status audit that fails strict mode until the release/source/UAT/production blockers are resolved.
- [x] Add a release source-state verifier that fails strict mode until the tree is clean, version/build match, and the expected release tag points at HEAD.
- [x] Add a release source inclusion/exclusion review template so unrelated dirty work cannot accidentally enter a release tag or fresh DMG.
- [x] Record build number, Git commit, DMG checksum, notarization status, R2 URLs, and landing deployment status. Partial: the production Vercel deployment ID is still unavailable from the current CLI/MCP auth context, but the production landing page and download-health route pass verification.
- [x] Verify currently published R2 `latest.json`, latest DMG, versioned DMG, and checksum sidecars.
- [x] Run a no-mutation R2 rollback readiness dry-run against the previous known-good `1.0+1` versioned DMG and generated rollback manifest.
- [x] Verify the currently public DMG downloads, passes image/Gatekeeper/stapler checks, mounts read-only, contains the signed Voiyce app and `/Applications` symlink, matches manifest version/build, and scans clean for leaked OpenAI-key patterns.
- [x] Verify Terms and Privacy cover current product behavior at a launch-copy level.
- [x] Document what is stored locally, sent to OpenAI, sent to VideoDB, written to the vault, and shared with connected services.
- [x] Prepare known limitations and support instructions.
- [x] Prepare clean-install instructions.
- [x] Prepare uninstall/reset-memory instructions.
- [x] Prepare rollback instructions.

### Requires External Or Account-Level Action

- [ ] Rotate any exposed OpenAI API keys in the OpenAI dashboard or connected platform tooling.
- [ ] Confirm production server-side env vars are set in InsForge/Vercel as appropriate.
- [x] Deploy or verify the revised agent-context landing page in production. On 2026-05-20, both `origin/main` and `voiyce-mac-app/main` were fast-forwarded to `28519d7173b06f2cfe05ba2c4962138a10bf1aaa`; `https://voiyce.us` served the current agent-context page; `/api/download-health` returned healthy; and `scripts/verify-production-landing.sh https://voiyce.us` passed. Vercel deployment listing still returns an auth/scope failure, so the deployment ID is not recorded.
- [ ] Confirm Stripe mode, products, prices, and webhooks before charging real users.
- [ ] Upload a fresh notarized DMG only after the source tree is clean and committed.

## Release Source Inclusion Review Template

Use this before freezing a release branch, tagging a release, building a fresh DMG, or running artifact-changing package/upload commands. The goal is to make the clean-tree blocker actionable: every tracked or untracked path in `git status --porcelain=v1 --untracked-files=all` must be intentionally included, split out, removed, or documented as generated output before release tagging.

```markdown
### Release Source Inclusion Review - YYYY-MM-DD

- Reviewer:
- Target release version/build:
- Target release branch:
- Intended release tag:
- Starting branch:
- Starting HEAD:
- `git status --porcelain=v1 --untracked-files=all` path count:
- `scripts/verify-release-source-state.sh --expected-version <version> --expected-build <build> --expected-tag <tag> --allow-blockers --dirty-summary` result:
- Dirty summary by git status:
- Dirty summary by top-level surface:

#### Dirty-Tree Disposition Summary

- Include-in-release path count:
- Split-out/defer path count:
- Remove/regenerate path count:
- Generated/local-only path count:
- Needs-owner-decision path count:
- High-risk surfaces touched: macOS app / backend functions / landing / release scripts / legal docs / billing / auth / memory / Act mode / other
- Every included path has matching test or manual evidence:
- Unresolved path count before source freeze:

#### Recommended Review Order

1. Release-critical scripts, launch docs, and exact-artifact records.
2. macOS app source, tests, project files, and entitlements.
3. Backend functions, shared helpers, SQL, and backend tests.
4. Landing page source, public assets, legal pages, and landing tests.
5. Generated files, local-only folders, caches, and temporary artifacts.

#### Include In Release Candidate

- Paths/features intentionally included:
- Reason they belong in this release:
- Required tests/gates:

#### Split Out Before Release

- Paths/features to move to a later branch:
- Reason excluded from this release:
- Owner/action:

#### Remove Or Regenerate

- Generated files to remove:
- Local-only files to remove:
- Regeneration command, if applicable:

#### Final Source-State Decision

- Unresolved merge conflicts: yes / no
- All unrelated local changes split, removed, or documented as excluded:
- Xcode version/build match target:
- Release tag will be created only after clean-tree verification:
- No package, notarize, upload, or R2 mutation before strict source-state passes:
- Source freeze verification commands:
  - `git status --porcelain=v1 --untracked-files=all`
  - `scripts/verify-release-source-state.sh --expected-version <version> --expected-build <build> --expected-tag <tag>`
  - `scripts/verify-launch-blockers.sh`
  - `scripts/verify-release.sh --source-state-check --expected-version <version> --expected-build <build> --expected-tag <tag>`
- Owner-approved exceptions:
- Final owner sign-off:
```

## Pre-Invite Decision Record Template

Use this immediately before any broader beta invite, paid launch, release-note send, or public artifact update. Attach links to logs, screenshots, dashboards, and command output where available. Do not paste secret values.

```markdown
### Pre-Invite Decision - YYYY-MM-DD

- Decision: ship / hold
- Decision owner:
- Release version/build:
- Release Git commit:
- Release tag:
- DMG URL:
- DMG checksum:
- Landing deployment URL/id:
- R2 manifest URL:
- Support owner:
- Rollback owner:

#### Required Evidence

- Source-state command/result:
- Package/archive command/result:
- Launch-site command/result:
- Production-landing command/result:
- Public-download command/result:
- Public-DMG command/result:
- Clean-machine install evidence:
- Manual UAT evidence:
- Production environment evidence:
- Stripe/account evidence:
- Support inbox evidence:
- Rollback readiness evidence:

#### Launch Decision

- Open P0/P1 blockers:
- Accepted P2 limitations:
- User-facing workaround copy:
- Release notes match exact artifact:
- Support/contact copy match exact artifact:
- No secrets copied into docs/support/chat:
- Owner-approved exceptions:
- Final owner sign-off:
```

## Launch Evidence Package Template

Use this as the index for the final self-serve launch folder. Link to command output, screenshots, dashboard captures, UAT notes, and support records. Do not paste secret values, raw transcripts, screenshots containing private data, OAuth tokens, payment details, or private user content.

```markdown
### Launch Evidence Package - YYYY-MM-DD

- Evidence owner:
- Release version/build:
- Git commit:
- Release tag:
- DMG URL/checksum:
- Landing deployment URL/id:
- R2 manifest URL:
- Support inbox owner:
- Rollback owner:

#### Evidence Naming And Privacy Review

- Evidence folder/link:
- Naming pattern: `YYYY-MM-DD_voiyce-<version>+<build>_<surface>_<check-or-uat-id>_<pass-or-hold>`
- Command-output filenames include command name, timestamp, exit status, and whether the command was prep-only or exact-candidate:
- Screenshot/recording filenames include surface, viewport or macOS version, UAT/check ID, and reviewed/private-data status:
- Dashboard captures are redacted for secret values, tokens, payment details, private user content, and full API keys:
- Support exports are reviewed before linking and never pasted inline:
- Every evidence link maps to one automated gate, UAT row, production-account check, risk-register item, or launch decision:
- Missing or redacted evidence is marked with owner, reason, and replacement proof:

#### Automated Gates

- Launch audit result:
- Release source-state result:
- Package/archive result:
- Launch-site result:
- Production landing result:
- Public download result:
- Public DMG result:
- Agent usage-cap result:
- Backend function test result:
- macOS unit/UI result:
- Landing lint/build/visual result:
- Secret scan result:

#### Manual And Account Evidence

- Clean-machine install evidence:
- Permission grant/deny evidence:
- Dictation evidence:
- Context evidence:
- Talk evidence:
- Act evidence:
- Agent Log/support export evidence:
- Privacy/security review evidence:
- Production environment evidence:
- Stripe/account evidence:
- Support inbox readiness evidence:
- Rollback readiness evidence:

#### Launch Decision Evidence

- Open P0/P1 blockers:
- Accepted P2 limitations:
- User-facing workaround links:
- Release notes link:
- Terms/Privacy/support contact alignment:
- Invite/resume decision link:
- Owner-approved exceptions:
- Final owner sign-off:
```

## Launch Risk And Exception Register Template

Use this before any broader beta invite, paid launch, release-note send, artifact update, or invite resume after a pause. Every accepted limitation, skipped diagnostic gate, manual UAT gap, production/account blocker, and owner-approved exception must have a user-facing workaround or an explicit hold decision. Do not paste secrets, raw transcripts, private screenshots, OAuth tokens, payment details, or customer private data.

```markdown
### Launch Risk And Exception Register - YYYY-MM-DD

- Register owner:
- Release version/build:
- Git commit:
- DMG URL/checksum:
- Landing deployment URL/id:
- Decision: continue / hold / narrow invite

| ID | Type | Severity | Surface | Description | User impact | Workaround or mitigation | Escalates to hold when | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RISK-001 | accepted P2 / skipped diagnostic / manual UAT gap / external blocker / support exception | P0 / P1 / P2 / P3 | landing / auth / download / DMG / app / backend / billing / account / support |  |  |  |  |  | open / accepted / fixed / hold |

#### Required Checks

- No accepted P0/P1 exceptions:
- Every accepted P2 has user-facing workaround copy:
- Every skipped diagnostic has owner-approved manual coverage:
- Every external/account blocker has owner and next action:
- Release notes and support replies include accepted limitations:
- Support intake and monitoring templates cover the risk:
- Rollback or kill-switch path exists where applicable:
- Final owner sign-off:
```

Launch hold rule: if any P0/P1 is accepted without a fix, any P2 lacks a workaround, any skipped diagnostic lacks manual replacement evidence, any external blocker lacks an owner/next action, or any risk could expose secrets/private data/payment issues/unsafe Act behavior, keep invites and release notes paused.

## Final Privacy And Security Review Template

Use this before sending beta invites, resuming invites after a pause, or publishing a new public artifact. Record command output links, dashboard screenshot links, or short summaries only. Do not paste secret values, raw transcripts, screenshots, OAuth tokens, payment details, or private user content into this record.

```markdown
### Privacy And Security Review - YYYY-MM-DD

- Reviewer:
- Release version/build:
- Git commit:
- DMG checksum:
- Landing deployment:
- Review decision: pass / hold

#### Secret And Bundle Checks

- Source secret scan result:
- Landing build secret scan result:
- Built app secret scan result:
- Mounted DMG secret scan result:
- OpenAI key rotation evidence:
- Server-side-only key evidence:
- Stripe live-mode decision:

#### Data And Export Checks

- Support export redaction evidence:
- Agent Log redaction evidence:
- Local memory path review:
- Raw screenshot retention review:
- Vault note/frontmatter review:
- Delete-memory control review:
- Manual reset path review:

#### User-Facing Disclosure Checks

- Privacy policy matches current storage and processors:
- Terms contact and support contact match:
- Beta limitations disclose current manual UAT gaps:
- Support intake avoids raw transcripts, screenshots, secrets, OAuth tokens, and payment details:
- Production environment evidence avoids secret values:

#### Decision

- Open privacy/security blockers:
- Accepted limitations and workaround:
- Required fix before invites:
- Final owner sign-off:
```

## Manual UAT Result Template

Use one entry per test pass.

```markdown
### UAT Pass - YYYY-MM-DD

- Tester:
- Date:
- Machine:
- macOS version:
- Build version:
- Build number:
- Git commit:
- DMG URL/checksum:
- Screenshot/recording links:
- Agent Log/support export links:
- Automated check commands:
- Automated check result links:
- Owner-approved automated exceptions:

#### Results

- Clean install:
- Onboarding:
- Permissions:
- Dictation:
- Context Mode:
- Talk Mode:
- Talk first-response timing:
- Talk interruption settling:
- Talk tool-delay progress phrase:
- Act Mode:
- Memory deletion:
- Agent Log/support export:
- Landing/auth/download:
- Pass/fail notes:

#### Bugs Found

- P0:
- P1:
- P2:
- P3:
- No known P0/P1 remain:
- P2 user impact:
- P2 workaround:

#### Decision

- Ship / hold:
- Required fixes before sharing:
- Support/contact/release notes match exact build:
- Owner acceptance:
```
