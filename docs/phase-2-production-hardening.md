# Phase 2 Production Hardening

This file tracks what Phase 2 adds on top of the current Agent build and what still requires external verification.

## Implemented In This Pass

- Local memory privacy settings:
  - Private Mode pauses durable memory and raw screenshot storage.
  - Summary retention supports Session only, 30 days, 90 days, and Forever.
  - Raw screenshot retention supports Off, 30 days, 90 days, and Forever.
  - App/site exclusions skip matching memory writes.
  - Sensitive contexts such as password managers, banking, health, private browsing, and credentials are skipped by default.
- Memory delete now clears the structured memory index, saved screenshots, and Voiyce-written daily vault notes.
- Local memory is scoped by signed-in account: account changes switch the structured index, screenshot directory, vault path setting, retention settings, Private Mode, and app/site exclusions. Swift unit coverage verifies records and privacy settings do not bleed across accounts.
- Agent tool results now distinguish current screen capture, active-session context, and long-term memory with stable source labels in structured result data.
- Realtime instructions now route previous-work questions and memory-dependent Act requests through saved memory before answering or acting, require natural date/session citation when memory results include it, and keep internal provider/runtime/tool/source-label names out of normal speech.
- Realtime instructions now explicitly route screen-dependent Talk questions through current-screen inspection, active-session history questions through session context, and prior-work questions through saved memory, with deterministic Deno coverage for that ordering.
- Realtime turn detection uses semantic VAD with low eagerness to reduce premature Talk responses during natural pauses; spoken UAT still needs to validate short commands, long thoughts, interruptions, and corrections.
- Realtime instructions require Talk to report missing Google OAuth or missing Screen Recording/Microphone/Accessibility permission as the blocker with a next step, and not infer inbox, calendar, screen, account, or app access without tool confirmation.
- Realtime instructions now route pending-confirmation voice decisions through approve, cancel, and stop-session paths so spoken stop requests do not fall back to a plain cancellation.
- Talk Stop now invalidates pending browser-side Realtime connection attempts, releases late microphone streams, clears the hidden audio element, and keeps peer-connection callbacks tied to the local connection object during teardown.
- Embedded Realtime client coverage verifies the Talk/WebRTC setup path captures microphone audio, attaches tracks to the peer connection, posts SDP to the local Realtime session endpoint, applies the remote answer, wires model audio to the autoplay audio element, and emits audio-ready telemetry. Physical spoken Talk UAT still needs to validate real audio input/output.
- Realtime telemetry coverage verifies first response, tool-call delay, and interruption-completed measurements are written to Agent Log with launch QA targets; physical spoken interruption UAT remains open.
- Talk/Act Stop now ends local session-context capture before summary generation while preserving session identifiers long enough to summarize and close the backend session.
- The embedded Realtime client has regression coverage for the expected Talk tool surface: Gmail, Calendar, app/site opening, text insertion, screen inspection, active-session context, and local memory tools.
- Agent mode capability coverage now verifies Talk starts session context plus Realtime voice, Act starts session context plus Realtime voice plus action capability, and direct-control tools such as click, keypress, and `act_with_computer` are rejected outside Act mode.
- Local memory vault daily notes now include frontmatter for date, source modes, app hints, tags, privacy level, screenshot retention, and account scope.
- Local memory usage snapshots now track record count, captures today, screenshot count/bytes, vault note count/bytes, index bytes, and total storage bytes, and expose those fields through memory tool results plus Memory saved Agent Log details.
- Settings now exposes the local memory vault setup path: create/open the default vault or choose an existing folder.
- Vault Notes can be disabled per signed-in account from Settings without disabling the structured local memory index or search.
- Active Agent modes now show visible status in the sidebar and menu bar, including Context and Act, so ambient context/action state is not hidden when the Agent screen is not selected.
- Agent screen includes a self-contained mode map for Off, Context, Talk, and Act so users can understand what starts, what stays inactive, and which permission/privacy/safety controls apply without reading external docs.
- Agent support export now writes a local redacted JSON bundle from Agent Log.
- Dictation/audio debug logs now record transcript word counts and safe operation states instead of raw transcript text, thrown error payloads, or temporary recording filenames.
- The launch-readiness audit now statically checks the touched dictation/audio paths for raw transcript, thrown-error, and temporary recording-path debug print regressions.
- The launch-readiness audit now also checks app/landing support-contact constants and verifier contact values against `aki.b@pentridgemedia.com`, and blocks legacy Voiyce support-address regressions.
- The launch-readiness audit now verifies the landing-site verifier still includes the zero-warning lint gate, raw image regression guard, landing build secret scan, accessibility smoke checks, and download-health route checks.
- The launch-readiness audit now verifies the production landing smoke verifier still includes stale-copy rejection, download-health, legal contact, social image/favicon payload checks, and current agent-context positioning.
- The launch-readiness audit now verifies the rollback readiness dry-run still checks current public R2 artifacts, a previous rollback candidate, local rollback manifest generation, and the no-R2-mutation guarantee.
- The launch-readiness audit now verifies the main release verifier still includes source and built-app secret scans, usage-cap verification, launch-site verification, archive/public-DMG hooks, and the production landing hook.
- The launch-readiness audit now verifies the main release verifier still includes the source-state hook, package command, public-download manifest hook, and `--skip-ui-tests` diagnostic-only warning.
- The launch-readiness audit now verifies the release source-state verifier still includes clean-tree status, version/build consistency, tag-to-HEAD verification, and prep-stage blocker reporting.
- The launch-readiness audit now verifies the public DMG verifier still includes checksum, image verification, Gatekeeper/notarization, read-only mounting, Applications symlink, app signature, bundle version/build, and mounted app secret scanning.
- The launch-readiness audit now verifies the release archive verifier still includes temporary archive output, archived app presence/codesign checks, and archived app OpenAI-key scanning without export/DMG mutation.
- The launch-readiness audit now verifies exact-artifact release records keep version/build, commit, R2 URLs, checksum, notarization/signing, source-state warning, a dirty-tree blocker count matching the current Git status, and full release-candidate gate notes.
- The tier/cost plan now matches the current usage-cap implementation: server-side caps exist behind `VOIYCE_ENFORCE_AGENT_USAGE_CAPS=true`, while production env confirmation and Stripe tier mapping remain launch blockers.
- The launch-readiness audit now verifies the tier/cost plan keeps current server-side cap status, production env/tier-mapping blockers, per-tier hard-cap scope, AI kill-switch scope, and paid-production confirmation steps.
- The launch-readiness audit now verifies this production hardening doc keeps server-side-only environment guidance, OpenAI key requirement, AI kill switches, request caps, usage-cap enforcement env, an AI usage/quota monitoring record, and the remaining external blocker list.
- The launch-readiness audit now verifies the Stripe billing connection doc keeps live-mode and pricing configuration warnings, and that checkout, portal, and billing-sync functions/tests continue blocking `sk_live_...` unless `STRIPE_ALLOW_LIVE_MODE=true`.
- The launch-readiness audit now verifies the Stripe webhook path keeps signature verification, subscription created/updated/deleted handling, `apply_stripe_subscription_update` wiring, cancel-at-period-end handling, active-plan mapping, and SQL RPC grant/update behavior.
- Stripe webhook tests now cover missing-signature rejection before database calls, ignored signed events with no billing update, and signed subscription updates mapping customer/subscription/status/price/cancel/plan values into the billing RPC payload.
- VideoDB/session-context backend failures now use generic client-safe errors for auth/provider failures and shared redaction for bearer and `x-access-token` strings, with Deno coverage for preflight/method handling, validation, auth-provider failures, and upstream provider failures.
- VideoDB/session-context now has a server-side `VOIYCE_DISABLE_SESSION_CONTEXT` kill switch and a `VOIYCE_SESSION_CONTEXT_MAX_QUERY_CHARS` search-query cap so the active-session memory path can be paused or bounded without shipping a new app build.
- The launch-readiness audit now verifies the VideoDB/session-context function and shared safe-error helpers keep those client-safe failure, redaction, kill-switch, and query-cap guardrails.
- The launch-readiness audit now verifies the manual UAT matrix still includes required evidence, exit rules, clean install/permissions, Dictation, Context, Talk, Act, website/legal/download, resilience, blocked action, and support export coverage.
- The launch-readiness audit now verifies beta communications remain internally held, Beta-labeled, agent-context positioned, support-contact aligned, and complete across limitations, permissions, privacy/memory, data processing, support escalation, monitoring, and clean-install instructions.
- The launch-readiness audit now verifies beta uninstall/reset-memory guidance remains present, prefers in-app memory deletion, identifies the current build's Voiyce-owned local memory paths, and keeps manual local reset support-guided.
- The launch-readiness audit now verifies the rollback runbook keeps smallest-surface rollback guidance, dirty-tree DMG warnings, support contact, severity/triage sections, landing/R2/backend/app rollback paths, post-rollback verification, and incident notes.
- The unused dashboard usage demo-data seeding hook was removed so production analytics cannot accidentally show sample words or dictation sessions.
- Context capture coverage verifies the helper requests Microphone and Screen Recording, selects microphone, display, and system audio channels where available, stores selected channels, starts the capture session, and consumes capture events. Physical Context UAT still needs to validate whether the resulting memory feels complete across real apps.
- Backend function kill switches:
  - `VOIYCE_DISABLE_ALL_AI`
  - `VOIYCE_DISABLE_REALTIME`
  - `VOIYCE_DISABLE_TRANSCRIPTION`
  - `VOIYCE_DISABLE_COMPUTER_USE`
  - `VOIYCE_DISABLE_SCREEN_CONTEXT`
  - `VOIYCE_DISABLE_SESSION_CONTEXT`
- Backend request limits:
  - `VOIYCE_REALTIME_MAX_SDP_CHARS`
  - `VOIYCE_TRANSCRIPTION_MAX_AUDIO_BYTES`
  - `VOIYCE_COMPUTER_USE_MAX_TASK_CHARS`
  - `VOIYCE_COMPUTER_USE_MAX_SCREENSHOT_BASE64_CHARS`
  - `VOIYCE_SCREEN_CONTEXT_MAX_IMAGE_BASE64_CHARS`
  - `VOIYCE_SESSION_CONTEXT_MAX_QUERY_CHARS`
- Client model override is now opt-in:
  - `VOIYCE_ALLOW_CLIENT_REALTIME_MODEL`
  - `VOIYCE_ALLOW_CLIENT_TRANSCRIPTION_MODEL`
- Backend usage/cost discipline:
  - Realtime, transcription, Computer Use, and screen-context can reserve and finalize estimated usage when `VOIYCE_ENFORCE_AGENT_USAGE_CAPS` is enabled.
  - Usage events are written by capability through `reserve_agent_usage_cost` and `finalize_agent_usage_cost`.
  - Usage events now store structured usage units alongside estimated cost: Realtime session count, estimated session seconds, and SDP size; transcription request count, audio seconds, and audio bytes; Computer Use step count, screenshot count/size, task length, continuation count, output action count, pending safety-check count, and output item count; screen-context request count, screenshot count, image size, and prompt length.
  - Temporary Default/Pro/Power daily and monthly caps are defined in `insforge/sql/billing_schema.sql`.
- Settings and the checkout plan picker explain the current user-facing limit boundary: Pro keeps dictation active, Context/Talk/Act use beta budgets, and Power-level Act limits are not sold in this build.
- The macOS app has an internal Default/Pro/Power capability policy. Default keeps Act unavailable while allowing Context and Talk under conservative limits, paid/beta/Pentridge access maps to Pro for the current beta surface, and an explicit Power mapping exists for future full Act/Computer Use and Power memory limits.
- `scripts/verify-agent-usage-caps.sh` verifies the Default/Pro/Power cap matrix, server-side RPC reserve/finalize logic, per-capability function wiring, account-limit responses before OpenAI, and backend tests for Realtime, transcription, Computer Use, and screen-context.
- Durable memory storage and raw screenshot storage now have local Default/Pro/Power quotas in addition to retention, private mode, exclusions, and deletion controls. Raw screenshots are skipped when screenshot storage is exhausted, while the distilled memory can still save; durable memory writes are skipped once the local record or total-storage cap is reached.
- App termination cleanup clears active dictation and Agent runtime state, stops Realtime bridge/server state, locally stops session-context capture, and logs context shutdown before quit. Swift unit coverage verifies the deterministic cleanup path; physical quit-while-running UAT from the downloaded app remains open.
- System sleep cleanup handles macOS sleep/wake notifications by stopping active local runtime before sleep, clearing dictation and Agent active state, locally stopping session-context capture, and logging a restartable wake state. Swift unit coverage verifies deterministic sleep cleanup; physical sleep/wake UAT from the downloaded app remains open.
- Display-layout change recovery handles macOS screen-parameter notifications by clearing transient action/focus/tour overlays, clearing saved focus regions with stale coordinates, letting Context/Talk continue with fresh captures, and pausing active Act mode before stale coordinates can continue. Swift unit coverage verifies the Act-only pause policy and stale focus-region clearing; physical display connect/disconnect UAT from the downloaded app remains open.
- Account access-loss cleanup clears active dictation and Agent runtime state, stops Realtime/session-context work, writes a support-useful recovery event, and blocks Agent hotkey starts while the account is signed out or payment-required. Swift unit coverage verifies the state reset and signed-out/payment-required recovery copy; physical sign-out/sign-in UAT from the downloaded app remains open.
- Native Act text entry now refuses blind paste/type fallback unless macOS reports a focused text-like target. Direct text insertion and hosted Computer Use typing return structured failures with a concrete next step when focus is unsafe or unknown.
- Computer Use now has app-side loop coverage for sending the initial task and screenshot, receiving hosted computer actions, executing an allowed local action, capturing the next screen, continuing with `previousResponseId` and `callId`, and finishing with structured Agent Log evidence. Backend Deno coverage verifies the current hosted Responses API `computer` tool payload shape, follow-up screenshot output, safety instructions, abuse blocks, kill switches, account-limit handling, and redacted upstream failures.
- The local Act action surface now has deterministic coverage for right click, double click, scroll, command-style hotkeys, and safe text insertion without posting real system events during tests. URL open, app activation, direct screen click, key press, and Voiyce-native navigation remain covered through the existing Realtime/native tool layer.
- `scripts/verify-release-source-state.sh` verifies source provenance before a public release by checking clean-tree status, Xcode version/build consistency, and the expected release tag pointing at HEAD without building, packaging, tagging, or mutating files.
- Release verification now includes source secret scanning, usage-cap verification, optional exported app secret scanning, all backend function tests, landing-page build, macOS build, optional local package, and optional public R2 download/checksum verification.

## Production Environment Variables

Set these in the server-side function environment, not in the macOS app bundle or browser bundle.

| Variable | Purpose | Default |
| --- | --- | --- |
| `OPENAI_API_KEY` | Server-side OpenAI calls | Required |
| `OPENAI_REALTIME_MODEL` | Realtime model | `gpt-realtime-2` |
| `OPENAI_TRANSCRIPTION_MODEL` | Transcription model | `whisper-1` |
| `OPENAI_COMPUTER_USE_MODEL` | Computer Use model | `gpt-5.5` |
| `OPENAI_SCREEN_CONTEXT_MODEL` | Screen-context model | `gpt-4.1-mini` |
| `VOIYCE_DISABLE_ALL_AI` | Emergency stop for all OpenAI-backed AI calls | Off |
| `VOIYCE_DISABLE_REALTIME` | Disable Realtime voice only | Off |
| `VOIYCE_DISABLE_TRANSCRIPTION` | Disable transcription only | Off |
| `VOIYCE_DISABLE_COMPUTER_USE` | Disable Act Computer Use only | Off |
| `VOIYCE_DISABLE_SCREEN_CONTEXT` | Disable screen-context analysis only | Off |
| `VOIYCE_DISABLE_SESSION_CONTEXT` | Disable VideoDB-backed session context capture/search | Off |
| `VOIYCE_ENFORCE_AGENT_USAGE_CAPS` | Enable server-side usage reservation/finalization for agent capabilities | Off |
| `VOIYCE_REALTIME_MAX_SDP_CHARS` | Realtime SDP request cap | `25000` |
| `VOIYCE_TRANSCRIPTION_MAX_AUDIO_BYTES` | Audio upload cap | `10485760` |
| `VOIYCE_COMPUTER_USE_MAX_TASK_CHARS` | Act task prompt cap | `2000` |
| `VOIYCE_COMPUTER_USE_MAX_SCREENSHOT_BASE64_CHARS` | Computer Use screenshot cap | `8000000` |
| `VOIYCE_SCREEN_CONTEXT_MAX_IMAGE_BASE64_CHARS` | Screen-context image cap | `8000000` |
| `VOIYCE_SESSION_CONTEXT_MAX_QUERY_CHARS` | Session-context search query cap | `1000` |
| `VOIYCE_REALTIME_ESTIMATED_SESSION_COST_USD` | Estimated usage reservation per Realtime session | `0.05` |
| `VOIYCE_REALTIME_ESTIMATED_SESSION_SECONDS` | Estimated Realtime session duration recorded in the usage ledger | `300` |
| `OPENAI_TRANSCRIPTION_COST_CENTS_PER_MINUTE` | Transcription cost estimate used for reservations | `0.6` |
| `VOIYCE_COMPUTER_USE_ESTIMATED_STEP_COST_USD` | Estimated usage reservation per Computer Use step | `0.02` |
| `VOIYCE_SCREEN_CONTEXT_ESTIMATED_REQUEST_COST_USD` | Estimated usage reservation per screen-context request | `0.003` |

## Production Environment Verification Template

Complete this before broad beta sharing and again before any paid production launch. Record only presence/status and dashboard links or screenshots; do not copy secret values into docs, support exports, or chat.

| Surface | Required check | Evidence to record |
| --- | --- | --- |
| OpenAI dashboard | Exposed development keys are revoked, the active server-side key is current, and usage/quota alerts are visible. | Rotation date, last-four/key label only, usage dashboard screenshot, owner. |
| InsForge functions | `OPENAI_API_KEY`, model overrides, AI kill switches, request caps, `VOIYCE_DISABLE_SESSION_CONTEXT`, and `VOIYCE_ENFORCE_AGENT_USAGE_CAPS` match the launch decision. | Function environment screenshot or connector output with values redacted, owner, timestamp. |
| InsForge database/RPC | Usage-cap SQL, billing RPCs, Stripe subscription RPC, and tier mapping are deployed to the intended project. | Migration/RPC version, project id/name, owner, timestamp. |
| Vercel landing | `NEXT_PUBLIC_DOWNLOAD_URL`, `NEXT_PUBLIC_INSFORGE_URL`, auth anon-key presence, auth/download configuration, and production deployment point at the intended build, intended auth project, and public DMG. | Deployment URL/id, env-var presence with values redacted except public URLs, auth sign-in smoke, owner. |
| Cloudflare R2 | `latest.json`, latest DMG, versioned DMG, and checksum sidecars point to the intended version/build. | `scripts/verify-release.sh --public-download-check` output link or pasted summary. |
| Stripe | Mode, products, prices, checkout, billing portal, webhook endpoint, and webhook secret match the beta/paid launch decision. | Test/live mode, product/price IDs, webhook endpoint id, owner, timestamp. |
| Support inbox | `aki.b@pentridgemedia.com` is monitored and escalation owners are assigned for P0/P1 reports. | Inbox owner, backup owner, monitoring cadence. |

Launch hold rule: if any row is missing, stale, or cannot be verified without exposing secrets, keep the release notes on internal hold.

## OpenAI Key Rotation Evidence Checklist

Use this when rotating the exposed development key and before marking the key blocker complete. Record labels, last-four characters, timestamps, dashboard links, and screenshots only. Do not paste full keys, environment values, request bodies, support exports, or logs containing bearer tokens.

```markdown
### OpenAI Key Rotation - YYYY-MM-DD

- Security owner:
- Exposed key label/last-four, if safely known:
- Exposed key revoked in OpenAI dashboard:
- Replacement key created:
- Replacement key stored only in server-side function environment:
- macOS app bundle does not contain `OPENAI_API_KEY` or `sk-` values:
- Landing/browser bundle does not contain `OPENAI_API_KEY` or `sk-` values:
- Source secret scan result:
- Built app secret scan result:
- Landing build secret scan result:
- Production function smoke result after rotation:
- Old-key negative check, if available without exposing the key:
- Usage/quota alerts reviewed:
- Evidence reviewed for secret values before sharing:
- Remaining key/security blockers:
- Final security owner sign-off:
```

Launch hold rule: if the exposed key is not revoked, the replacement key is not server-side only, any bundle/source scan finds an OpenAI-style key, or the evidence requires copying a full secret value, keep release notes and invites paused.

## AI Usage And Quota Monitoring Record

Use this before the first invite batch, during the first-hour monitoring window, and before resuming invites after any quota, rate-limit, or cost anomaly. Record dashboard links, screenshots, owners, and short summaries only. Do not paste API keys, bearer tokens, request bodies, raw transcripts, private screenshots, or full support exports.

```markdown
### AI Usage And Quota Monitoring - YYYY-MM-DD

- Monitoring owner:
- Invite batch or release candidate:
- Window start/end:
- OpenAI usage dashboard reviewed:
- OpenAI hard spend/quota limit visible:
- OpenAI usage alert threshold reviewed:
- Realtime usage trend normal / elevated / hold:
- Transcription usage trend normal / elevated / hold:
- Computer Use usage trend normal / elevated / hold:
- Screen-context usage trend normal / elevated / hold:
- InsForge usage-cap events reviewed:
- `VOIYCE_ENFORCE_AGENT_USAGE_CAPS` production value reviewed:
- AI kill-switch values reviewed:
- Any 401, 402, 429, or quota spikes:
- Support reports linked:
- Pause/narrow/continue decision:
- Next monitoring checkpoint:
- Evidence reviewed for secret/private data before sharing:
```

Launch hold rule: pause or narrow invites if OpenAI spend/quota limits are not visible, usage alerts are not reviewed, usage-cap enforcement is off without an owner-approved exception, any AI capability shows unexplained spikes, or support reports indicate quota/rate-limit failures leave Dictation, Context, Talk, or Act stuck active.

## Production Landing Cutover Evidence Checklist

Use this after the revised agent-context landing page is deployed and before release notes, invite batches, or public artifact updates resume. Record public URLs, deployment ids, command outputs, dashboard links, timestamps, and screenshots only. Do not deploy from this checklist, and do not paste private env values or secrets.

```markdown
### Production Landing Cutover - YYYY-MM-DD

- Cutover owner:
- Production URL:
- Vercel project/team:
- Deployment URL/id:
- Git commit deployed:
- Landing source branch:
- `NEXT_PUBLIC_DOWNLOAD_URL` points at intended public DMG:
- `NEXT_PUBLIC_INSFORGE_URL` points at intended auth project:
- `NEXT_PUBLIC_INSFORGE_ANON_KEY` presence reviewed without copied value:
- Auth provider callback/sign-in smoke:
- Auth/download env presence reviewed without copied secrets:
- `scripts/verify-production-landing.sh https://voiyce.us` result:
- `scripts/verify-launch-site.sh --url https://voiyce.us` result, if used:
- `/api/download-health` result:
- Home/auth/download/privacy/terms route check:
- Stale dictation-first copy absent:
- Agent-context headline and support contact present:
- Social image/favicon payloads verified:
- R2 `latest.json` version/build/checksum:
- Latest and versioned DMG byte/checksum identity:
- Previous known-good landing deployment identified:
- Rollback owner:
- First-hour monitoring window:
- Open production landing blockers:
- Final cutover sign-off:
```

Launch hold rule: if production serves stale copy, `/api/download-health` fails, the download URL points at the wrong artifact, R2 identity does not match the release record, or no rollback deployment is identified, keep invites and release notes paused.

## Production Evidence Packet Template

Use this as the account-level evidence packet for the final launch folder. Record presence, ids, timestamps, dashboard links, screenshots, and short summaries only. Never paste secret values, full API keys, webhook signing secrets, OAuth tokens, customer payment details, raw transcripts, private screenshots, or support-export contents.

```markdown
### Production Evidence Packet - YYYY-MM-DD

- Evidence owner:
- Release version/build:
- Git commit:
- Landing deployment URL/id:
- DMG URL/checksum:
- Evidence decision: pass / hold

#### OpenAI

- Exposed development keys revoked:
- Active server-side key label/last-four only:
- Usage/quota alerts visible:
- Dashboard evidence link:
- Owner/timestamp:

#### InsForge Functions And Database

- `OPENAI_API_KEY` present without copied value:
- Model override env values reviewed:
- AI kill-switch env values reviewed:
- Request-cap env values reviewed:
- `VOIYCE_DISABLE_SESSION_CONTEXT` reviewed:
- `VOIYCE_ENFORCE_AGENT_USAGE_CAPS` reviewed:
- Usage-cap SQL/RPC deployment evidence:
- Billing RPC and Stripe subscription RPC evidence:
- Owner/timestamp:

#### Vercel Landing

- Production deployment URL/id:
- `NEXT_PUBLIC_DOWNLOAD_URL` points at intended public DMG:
- `NEXT_PUBLIC_INSFORGE_URL` points at intended auth project:
- `NEXT_PUBLIC_INSFORGE_ANON_KEY` presence reviewed without copied value:
- Auth provider callback/sign-in smoke:
- Auth/download env values present without copied secrets:
- `/api/download-health` result:
- Owner/timestamp:

#### Cloudflare R2

- `latest.json` URL:
- Latest DMG URL/checksum:
- Versioned DMG URL/checksum:
- `scripts/verify-release.sh --public-download-check` evidence:
- Owner/timestamp:

#### Stripe

- Stripe mode:
- Products/prices reviewed:
- Checkout evidence:
- Billing portal evidence:
- Webhook endpoint and event evidence:
- Webhook signing secret present without copied value:
- Owner/timestamp:

#### Support Inbox

- Primary support owner:
- Backup support owner:
- Monitoring cadence:
- P0/P1 escalation path:
- First user-facing reply template ready:

#### No-Secret Handling

- Evidence reviewed for secret values before sharing:
- Screenshots reviewed for private data:
- Support exports reviewed instead of pasted:
- Open production blockers:
- Final owner sign-off:
```

Launch hold rule: if any production evidence packet field is missing, stale, or requires copying a secret value to prove, keep the release on internal hold until safer evidence is captured.

## Temporary Internal Usage Caps

These are not final pricing limits. They are conservative internal cap values that can be enforced by setting `VOIYCE_ENFORCE_AGENT_USAGE_CAPS=true` after the SQL functions are deployed.

| Tier | Capability | Daily Cap | Monthly Cap |
| --- | --- | ---: | ---: |
| Default | Computer Use | `$0.60` | `$3.00` |
| Default | Realtime | `$1.60` | `$8.00` |
| Default | Transcription | `$1.20` | `$6.00` |
| Default | Context | `$0.40` | `$2.00` |
| Pro | Computer Use | `$7.00` | `$35.00` |
| Pro | Realtime | `$9.00` | `$45.00` |
| Pro | Transcription | `$3.60` | `$18.00` |
| Pro | Context | `$2.00` | `$10.00` |
| Power | Computer Use | `$24.00` | `$120.00` |
| Power | Realtime | `$24.00` | `$120.00` |
| Power | Transcription | `$8.00` | `$40.00` |
| Power | Context | `$5.00` | `$25.00` |

## Clean-Machine Permission UAT

Run this from the public DMG, not Xcode.

| Step | Expected Result |
| --- | --- |
| Install from `https://voiyce.us` or the public R2 DMG | App opens without LaunchServices error |
| Sign in | Dashboard loads signed-in account |
| Grant Microphone | Settings shows Microphone on immediately and after refresh |
| Grant Speech Recognition | Settings shows Speech Recognition on immediately and after refresh |
| Grant Accessibility | Settings shows Accessibility on after quit/reopen |
| Grant Screen Recording | Settings shows Screen Recording on after quit/reopen |
| Start dictation | Control hold records, transcribes, and inserts text |
| Start Talk | Voice connects, hears mic, and speaks back |
| Ask Talk to inspect screen | It reads current screen or gives a clear permission blocker |
| Start Act | Action Cursor appears and bounded native actions work |
| Visit Agent Log and return to Act | Active-Agent banner is visible, Return to Agent works, and Act state remains recoverable |
| Toggle permissions off/on | Settings follows actual macOS state after refresh and relaunch |

Deterministic Swift coverage now verifies Action Cursor lifecycle for native Voiyce navigation and Computer Use action loops. Physical downloaded-app Act UAT still needs to confirm the same behavior across real apps and sites.
Deterministic Swift coverage also verifies active Act state survives Agent Log and Settings navigation, and native Voiyce navigation from those surfaces preserves `Act active` state.
Act command failure results now include structured next-step recovery data for missing task details, signed-out state, missing Accessibility, pending safety checks, and post-action Screen Recording loss.
Embedded Realtime confirmation coverage verifies visible Confirm, Cancel, and Stop Session paths plus voice-driven pending-confirmation approval/cancel/stop-session wiring.
Settings and onboarding now share permission-state copy for granted and denied states, with deterministic coverage for Microphone, Speech Recognition, Accessibility, and Screen Recording descriptions.
Permission-return coverage verifies macOS permission prompts route back to the original Voiyce screen once and clear the saved return target so repeated app activation does not create duplicate approval loops.
UI copy guardrails now cover Dashboard, Settings, Agent, Agent Log, onboarding launch copy, app menu commands, menu bar launch copy, and the walkthrough video sheet for user-facing language and absence of backend/internal implementation terms; Settings permission rows and menu bar actions have stable accessibility identifiers for deterministic coverage. Full visual polish still needs manual UAT.

## Act Mode UAT Matrix

| Task | Mode | Expected Result |
| --- | --- | --- |
| “Open Settings in Voiyce” | Talk or Act | Uses native Voiyce navigation, no visual mis-click |
| “Open Gmail and draft an email to myself” | Talk | Opens visible Gmail draft, does not send |
| “Read my next calendar event” | Talk | Uses Google Calendar integration or reports OAuth requirement |
| “Fill this public contact form with test data” | Act | Shows Action Cursor, fills fields, asks before submit in Normal |
| “Click the Settings tab” from another app | Act | Uses global action flow without requiring Voiyce frontmost first |
| “Delete all files on this Mac” | Any | Blocked even in Unrestricted |
| Computer Use pending safety check | Act | Fails into a clear recoverable confirmation state unless resume support is implemented |

## Remaining External Blockers

- OpenAI key rotation must be done in the OpenAI dashboard or the connected OpenAI Platform tooling.
- Clean-machine UAT requires a fresh macOS user or separate machine with the public DMG.
- Real production tier enforcement still needs Stripe product/price IDs, `VOIYCE_ENFORCE_AGENT_USAGE_CAPS=true` in production, and server-side tier mapping confirmation.
- Broad release should wait until the source tree is committed, tagged, and a fresh notarized DMG is built from that exact source.
