# Voiyce Beta Launch Communications

Status: draft for internal launch readiness.
Last updated: 2026-05-18.

This document prepares the user-facing material needed before inviting beta users. It does not approve a release by itself. Exact current public-artifact notes for `1.0+16` now live in `docs/releases/Voiyce-1.0+16-beta-release-notes.md` and are ready for owner-controlled beta sharing after final owner sign-off on the invite list and support coverage.

## One-Line Positioning

Voiyce is the agent context layer for people working across Claude Code, Codex, Hermes Agent, OpenClaw, Cursor, and related AI workflows.

## Launch Label Decision

The next public build should be labeled **Beta**.

Use Beta language in the landing CTA, invite copy, release notes, and support replies until clean-machine install, manual UAT, payment/account checks, and release-artifact verification are complete. Do not describe the build as Production or generally available.

## Short Product Description

Voiyce captures what you are doing, what you are saying, and what your agents have already learned, then turns that into reusable context for the tools you work with.

## Beta Invite Copy

Subject:

```text
Try Voiyce: agent context for your AI coding workflow
```

Body:

```text
I am opening a small Voiyce beta for people who move between coding agents and AI tools all day.

Voiyce helps you stop re-explaining your work to AI. It keeps context from your screen, spoken notes, and previous agent sessions available for handoffs across tools like Claude Code, Codex, Hermes Agent, OpenClaw, and Cursor.

This beta is best for founders, builders, operators, and developers who are comfortable testing early macOS software and reporting rough edges.

Known limits:
- macOS permissions are required for microphone, screen context, and app control.
- Act Mode is still being hardened across real websites and desktop apps.
- Memory is local-first, with retention, raw screenshot, exclusion, Private Mode, and delete controls.

Support: aki.b@pentridgemedia.com
```

## Draft Release Notes

Use this only as a starting point for a future exact release candidate. For the currently published `1.0+16` artifact, use `docs/releases/Voiyce-1.0+16-beta-release-notes.md` instead. Do not send template notes.

```markdown
# Voiyce Beta Release Notes

Release date:
Version:
Build:
Git commit:
DMG:
SHA-256:
Notarization:
Landing deployment:

## What Voiyce Does

Voiyce is the agent context layer for people working across Claude Code, Codex, Hermes Agent, OpenClaw, Cursor, and related AI workflows.

## What Is Included

- Agent modes: Off, Context, Talk, and Act.
- Separate dictation flow for quick text insertion.
- Local memory and session context for agent handoffs.
- Agent Log for inspecting what Voiyce tried, used, saved, or blocked.
- Focus Highlight and Action Cursor for screen-aware work.
- Safety modes for Act workflows.

## What To Test

- Install from the DMG and complete onboarding.
- Grant and deny each permission path.
- Try normal dictation in a native app and a browser field.
- Start Context Mode, work briefly, stop it, and inspect memory/log output.
- Start Talk Mode and ask about the current screen.
- Start Act Mode in Strict, ask it to open Settings, then cancel a sensitive action.

## Known Limitations

- Act Mode is bounded and permission-dependent.
- Computer Use may misread dense, hidden, or fast-changing UI.
- Some websites block automation, CAPTCHAs, or unauthenticated workflows.
- OpenAI pending safety checks can require a blocked/retry path for complex tasks.
- Memory retention, raw screenshot retention, app/site exclusions, Private Mode, and delete controls are local controls and should still be exercised during manual UAT.
- Gmail and Calendar features require connected Google OAuth.
- Voice latency and interruption behavior still need more spoken UAT.

## Support

Send bugs, screenshots, screen recordings, and the exact steps that led to the issue to aki.b@pentridgemedia.com.
```

## Release Notes Send Gate

Before sending any beta release notes, confirm:

- The notes are tied to one exact artifact, not the generic draft template.
- Version, build, Git commit, release tag, DMG URL, SHA-256, notarization status, signing origin, landing deployment URL/id, and R2 manifest URL are filled.
- `docs/releases/Voiyce-1.0+16-beta-release-notes.md` is ready for owner-controlled beta sharing after final owner sign-off.
- Production landing verification passes against `https://voiyce.us`, including `/api/download-health` and current agent-context copy.
- Clean-machine install evidence and manual UAT evidence are linked from the pre-invite decision record.
- Production environment evidence is recorded without secret values.
- Accepted P2 limitations have user-facing workaround copy.
- Support contact, Terms, Privacy, invite copy, release notes, and the landing page all use `aki.b@pentridgemedia.com`.
- Support intake instructions tell users to review screenshots, recordings, and Agent Log exports before sharing.
- Final owner sign-off is recorded.

## Known Limitations

These should be visible in beta notes and support replies.

- Voiyce is macOS-first and depends on macOS permission grants.
- Dictation is separate from Agent modes; turning Agent Off does not disable dictation.
- Context Mode is useful but not yet a fully tuned always-on capture system.
- Talk can answer from screen context only after Screen Recording is granted and a fresh screen read runs.
- Talk may take longer when it needs a screen read, memory search, Gmail lookup, Calendar lookup, or tool call.
- Act Mode should be treated as assisted operation, not autonomous control.
- Strict and Normal safety modes should still be used for anything that submits, sends, deletes, purchases, changes account state, or exposes private data.
- Unrestricted mode is broader, but must still refuse catastrophic deletion, credential theft, malware, fraud, and prohibited actions.
- Computer Use can fail on dense UI, hidden menus, fast-changing pages, inaccessible controls, CAPTCHAs, and unauthenticated workflows.
- Memory is local-first for the current launch. Cloud memory is not part of this release.
- Memory retention, app/site exclusions, raw screenshot retention, and deletion must be tested before broad sharing.
- Agent Log is a support surface, not a guarantee that every low-level operating-system event was recorded.

### Known Limitation Workaround Register

Use this before release notes, support replies, invite batches, or owner-approved narrow invites. Every accepted limitation needs a plain user-facing workaround and a support owner. If a limitation has no workaround, treat it as a hold.

| Limitation | User impact | User-facing workaround | Support action | Owner | Ship decision |
| --- | --- | --- | --- | --- | --- |
| Permission-dependent modes | Dictation, screen context, Talk, or Act may be blocked until macOS permissions are granted. | Open Voiyce Settings > Permissions, grant the missing macOS permission, then quit and reopen if the state does not refresh. | Ask for macOS version, Voiyce build, permission state, and whether refresh/reopen was tried. | Support owner | Continue only with recovery copy in notes. |
| Act on dense or blocked UI | Act may fail on hidden menus, CAPTCHAs, inaccessible controls, or fast-changing screens. | Use Strict mode, keep actions low-risk, stop when UI looks wrong, and handle CAPTCHA/login/protected flows manually. | Preserve Agent Log event IDs and exact action request; pause repeated failing workflow. | Support owner | Continue only for bounded beta workflows. |
| Pending safety checks | Complex Act tasks may stop with a blocked/retry path instead of resuming automatically. | Rephrase the task into a smaller low-risk step or finish the blocked step manually. | Record task wording, safety mode, and Agent Log event IDs. | Engineering owner | Continue only if clear recovery copy remains. |
| Local-first memory | Memory is stored locally and is not a cloud sync guarantee. | Use the local vault/export paths for review, and use Settings > Memory > Delete Memory before manual reset. | Guide users through in-app deletion first; manual file cleanup stays support-guided. | Support owner | Continue with privacy/reset-memory copy. |
| Talk latency and interruption tuning | Talk may be slower when reading the screen, searching memory, or waiting on tools. | Wait for the progress phrase, stop/retry if it feels stuck, and use shorter requests for urgent tasks. | Capture timing notes from the Talk UAT fields and any repeated slow path. | Engineering owner | Continue only while latency is disclosed as beta. |
| Google-connected features | Gmail and Calendar answers require the user to connect Google. | Connect Google before asking Gmail/Calendar questions, or treat missing connection as a blocker. | Confirm OAuth state and do not infer inbox/calendar access from user text alone. | Support owner | Continue with missing-OAuth copy. |

Limitations hold rule: hold release notes or the next invite batch if any accepted limitation lacks user-facing workaround copy, support owner, support action, or a matching known-limitation entry in release notes/support replies.

## Permissions Explanation

Use this plain-language explanation in onboarding, support replies, or beta docs.

- Microphone: needed for dictation and Talk Mode.
- Speech Recognition or transcription access: needed to turn speech into text.
- Screen Recording: needed when Voiyce answers questions about the current screen or uses screen context.
- Accessibility: needed for Act Mode to click, type, press keys, scroll, and navigate apps.
- Notifications: useful for status and permission prompts, but not a substitute for explicit Act confirmations.

If a user denies a permission, Voiyce should keep the rest of the app usable and explain what feature is blocked.

## Privacy And Memory Summary

Current launch behavior to explain carefully:

- Long-term memory is local-first.
- Voiyce stores structured local records for search and user-readable Markdown notes for recall.
- Summary retention can be Session only, 30 days, 90 days, or Forever.
- Raw screenshots have a separate retention setting and can be Off, 30 days, 90 days, or Forever.
- Local memory is intended for context handoffs, not surveillance.
- Screen context should be captured only after clear consent and permission grants.
- Private Mode pauses durable memory and raw screenshot storage.
- App/site exclusions skip matching memory writes.
- Sensitive contexts are skipped by default for long-term memory.
- The in-app memory delete control clears the local structured index, raw screenshots, and Voiyce-written vault notes.
- Support exports must redact secrets and sensitive fields by default before they are shared.

## Data Processing Map

Use this wording when a beta user asks what Voiyce stores or sends.

| Data or context | Where it goes | Why | User control |
| --- | --- | --- | --- |
| Local memory summaries, searchable text, tags, app/site hints, and retention settings | Stored locally by Voiyce. | Lets Voiyce recall useful prior context across sessions. | Memory retention, app/site exclusions, Private Mode, and delete controls. |
| Voiyce-written Markdown memory notes | Written to the local Voiyce memory vault as plain Markdown. | Gives the user readable, portable memory notes. | Delete memory control; support-guided manual cleanup if needed. |
| Raw screenshots saved for long-term memory | Stored locally only when screenshot retention allows it. | Helps preserve visual context for later recall. | Separate raw screenshot retention setting, Private Mode, exclusions, and delete controls. |
| Current screen image for one-shot screen understanding | Sent to the server-side screen-context function and then to OpenAI for model processing. | Lets Talk/Act answer questions about the current screen. | Requires Screen Recording; user can avoid screen tools, revoke permission, or use Private Mode for durable memory protection. |
| Realtime voice and tool-session content | Sent through server-side OpenAI-backed functions. | Powers Talk Mode, transcription, and agent tool calls. | Stop the mode/session; revoke microphone permission; use Agent Off when not working with Voiyce. |
| Computer Use screenshots and task goals | Sent through the server-side Computer Use function and OpenAI Computer Use path. | Lets Act Mode reason about and operate the visible UI. | Use Strict/Normal safety modes, Stop, permission controls, and avoid Act on sensitive workflows. |
| Active-session VideoDB capture, if enabled | Sent to VideoDB session memory for temporary screen/audio indexing. | Supports searching or summarizing the current agent session. | Stop the agent/session; verify current VideoDB behavior during manual UAT before broad sharing. |
| Google Gmail/Calendar data | Requested from Google only after OAuth connection and only for the selected tool path. | Lets Voiyce read, draft, send, or check calendar context when the user asks. | Do not connect Google; revoke OAuth; use confirmation for sensitive sends. |
| Billing and payment data | Processed by Stripe; Voiyce stores only subscription/customer status needed for access. | Enables paid plan checkout, portal, and subscription access. | Use Stripe checkout/portal or support for billing issues. |
| Support exports | Created locally when the user exports support data. | Helps diagnose failures. | Exports redact sensitive content by default; user should review before sharing. |

## Support And Bug Report Path

Primary support contact:

```text
aki.b@pentridgemedia.com
```

Ask beta users to include:

- macOS version.
- Voiyce version and build number.
- Whether the app was installed from DMG or run from a local build.
- Which mode was active: Dictation, Context, Talk, or Act.
- Permission state for Microphone, Screen Recording, and Accessibility.
- Exact steps to reproduce.
- Expected result.
- Actual result.
- Screenshot or screen recording if safe to share.
- Agent Log export only if it has been reviewed for sensitive content.

Initial triage:

- P0: data loss, unsafe action, secret exposure, crash loop, or public download broken.
- P1: install/sign-in blocked, permissions cannot recover, Talk/Act unusable, or billing/auth mismatch.
- P2: confusing copy, isolated workflow failure, slow response, or non-critical UI defect.
- P3: polish, copy, visual alignment, or wishlist.

### Support Intake Template

Use this for every user report before asking for more data. Keep raw transcripts, screenshots, secrets, OAuth tokens, and payment details out of the ticket unless the user has reviewed and intentionally shared them.

```markdown
#### Support Report - YYYY-MM-DD

- Reporter:
- Contact:
- Severity: P0 / P1 / P2 / P3
- Owner:
- Status: new / investigating / waiting on user / fixed / closed
- Voiyce version/build:
- macOS version:
- Install source: public DMG / candidate DMG / local build
- Active mode: Dictation / Context / Talk / Act / Settings / Website / Billing
- Permission state: Microphone / Screen Recording / Accessibility / Speech Recognition / Notifications
- Account state: signed out / signed in / Pro / free / unknown
- Network state: online / offline / flaky / unknown
- Exact steps:
- Expected result:
- Actual result:
- First failure time:
- Reproducible: yes / no / unknown
- Screenshot/recording reviewed for sensitive content:
- Agent Log/support export reviewed for sensitive content:
- Support export event IDs:
- Related command/dashboard evidence:
- User-facing reply sent:
- Next action:
- Resolution:
```

## Support Escalation Matrix

| Issue type | First check | Escalate when | Owner/action |
| --- | --- | --- | --- |
| Billing | Confirm Stripe mode, product, price, checkout URL, and webhook logs | User was charged incorrectly or cannot access paid features after payment | Pause payment links if needed; verify Stripe dashboard before replying |
| Permissions | Check Microphone, Screen Recording, Accessibility, and Notifications in macOS Settings | Permission appears granted but Voiyce still reports blocked after restart | Capture macOS version, Voiyce build, and permission diagnostics |
| OpenAI quota/rate limit | Check server-side function logs and OpenAI usage dashboard | Multiple users see Talk, transcription, or Computer Use failures | Use kill switches or temporary caps before inviting more users |
| Login/auth | Confirm auth route, provider status, and user account state | User cannot reach the download page after successful sign-in | Verify landing `/auth` and `/download`; collect browser console errors if available |
| Download | Check `latest.json`, `Voiyce.dmg`, checksum, and CDN response | DMG download fails, checksum mismatches, or Gatekeeper rejects the app | Stop invites; run public download verification; rollback R2 latest object if needed |
| Act Mode | Confirm Screen Recording, Accessibility, safety mode, and exact requested action | Act attempts a sensitive operation without expected confirmation or cannot stop | Stop sharing that workflow; preserve Agent Log; consider disabling Computer Use |

### Support Inbox Readiness Record

Use this before the first invite batch, after any support-owner change, and before resuming invites after an incident. Do not paste private user messages, transcripts, screenshots, OAuth tokens, payment details, or secret values.

```markdown
#### Support Inbox Readiness - YYYY-MM-DD

- Primary inbox:
- Primary support owner:
- Backup support owner:
- Engineering escalation owner:
- Billing escalation owner:
- Rollback owner:
- Monitoring cadence:
- First-hour coverage window:
- First-day coverage window:
- P0/P1 escalation path:
- P2 triage path:
- Support intake template ready:
- Support response playbook ready:
- Known limitations link:
- Clean-install evidence link:
- Launch monitoring record link:
- Risk/exception register link:
- Support export privacy review instructions ready:
- User-facing first reply template ready:
- Invite pause authority:
- Final owner sign-off:
```

Support inbox hold rules:

- Hold invites if no primary owner, backup owner, or P0/P1 escalation owner is assigned.
- Hold invites if the inbox will not be monitored during the first-hour and first-day windows.
- Hold invites if support replies still ask for raw transcripts, unreviewed screenshots, OAuth tokens, payment details, or secrets.
- Hold invites if support cannot pause invite expansion when a P0/P1 report arrives.

### Severity Response Targets

Use these targets during the first private beta window and any later invite expansion. They are operational targets, not public promises.

| Severity | First response target | Owner expectation | Invite decision | Required evidence |
| --- | --- | --- | --- | --- |
| P0 | Same day, immediately when seen | Support owner and engineering owner assigned before more invites | Pause all new invites until fixed, rolled back, or explicitly held | Incident note, support report, monitoring record, affected artifact/build, and owner sign-off |
| P1 | Same business day | Single owner assigned and next action recorded | Pause the affected workflow or narrow the next batch | Support report, reproduction status, workaround or hold decision, and owner sign-off |
| P2 | Within 2 business days | Owner or backlog destination recorded | Continue only if user-facing workaround exists | Support report, known-limitation or workaround copy, and risk-register link |
| P3 | Before the next planned invite expansion | Track as polish or wishlist | Continue if it is polish-only and does not confuse launch positioning | Support report or tracker link |

Escalation rules:

- Any secret exposure, private-data leak, unsafe Act behavior, broken public download, unexpected live charge, or crash loop is P0 until reviewed.
- Two users in one invite batch reporting the same install, auth, Dictation, Talk, Act, billing, or privacy issue escalate the issue at least one severity level.
- A P2 without a clear workaround becomes a launch hold for broader invites.
- Every P0/P1 needs a user-facing reply, owner, next action, and invite decision before another batch is sent.

## Support Response Playbook

Use these reply patterns during beta so support stays concrete and privacy-safe. Do not ask users to send raw transcripts, full screenshots, OAuth tokens, payment details, or secrets. Ask them to review screenshots, recordings, and Agent Log exports before sharing.

### Install Or Download Blocked

```text
Thanks for flagging this. Please send your macOS version, the Voiyce version/build if you can see it, the download URL you used, and the exact step where the install failed. If macOS showed a warning, a screenshot is helpful after you confirm it does not include private data.

We are checking the public DMG, checksum, and download route before sending more invites.
```

Pause condition: any checksum mismatch, broken public download, Gatekeeper rejection, or damaged-app warning from the intended DMG.

### Permission Recovery

```text
Voiyce depends on separate macOS permissions for microphone, screen context, and app control. Please open Settings > Permissions in Voiyce and macOS System Settings, then confirm which of Microphone, Speech Recognition, Screen Recording, Accessibility, and Notifications are granted.

If you are comfortable sharing it, include a reviewed screenshot of those permission states and the mode you were trying to use.
```

Pause condition: a granted permission still blocks the same feature after refresh, quit, and reopen.

### Dictation Or Talk Failure

```text
Please send the Voiyce version/build, whether Dictation or Talk was active, your network state, and the short steps that led to the failure. If an Agent Log entry exists, export it and review it before sharing.

Do not include the spoken transcript unless you intentionally want us to see it.
```

Pause condition: repeated failures across multiple users, quota/rate-limit spikes, or provider errors that leave Dictation/Talk stuck active.

### Act Mode Safety Or Stop Failure

```text
Please stop using that Act workflow for now. Send the requested action, selected safety mode, visible app/site, permission state, and whether Stop was available. A reviewed Agent Log export is more useful than a full screen recording.

We will treat any unexpected action, missing confirmation, or Stop failure as a launch-blocking report until reviewed.
```

Pause condition: unsafe action, missing expected confirmation, hidden/destructive action attempt, or Stop failing to cancel visible work.

#### Act Safety Incident Checklist

Use this for any Act report involving an unexpected action, missing confirmation, blocked action, sensitive workflow, Stop failure, or user concern about app control. Do not ask for raw screenshots, credentials, private page contents, payment details, or secrets.

```markdown
##### Act Safety Incident - YYYY-MM-DD

- Severity:
- Reporter:
- Owner:
- Voiyce version/build:
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
```

Act safety hold rules:

- Hold invites if Act performs a hidden, destructive, credential, payment, private-data, or account-changing action without expected confirmation.
- Hold invites if Stop is not visible or does not cancel visible work.
- Hold invites if a blocked catastrophic, fraud, illegal-access, credential-theft, malware, hidden-action, or platform-abusive request executes any local action.
- Hold invites if the same Act safety report appears from two users in one invite batch.

### Billing Or Account Access

```text
Please send the account email, Voiyce version/build, whether you were signing in, checking out, opening the billing portal, or using a gated feature, and the exact message you saw.

Do not send card numbers, payment screenshots with private details, Stripe secrets, or bank information.
```

Pause condition: unexpected live charge, wrong price, paid access not unlocking, or multiple users blocked after payment/sign-in.

### Privacy Or Memory Concern

```text
Please describe which mode was active, whether Private Mode or app/site exclusions were enabled, and what data you expected Voiyce not to save. If you share screenshots, vault notes, memory files, or support exports, review them first and remove anything private.

We will verify local memory, raw screenshot retention, vault notes, Agent Log, and support export behavior before expanding invites.
```

Pause condition: raw transcript, private screenshot, credential, payment data, OAuth token, OpenAI-style key, or excluded/private context appears in memory, Agent Log, support export, or shared docs.

## Launch-Day Monitoring Checklist

Use this during the first private beta invite window and after any artifact or backend change.

Cadence:

- First hour after invites: check every 15 minutes.
- First day: check at least hourly while users are active.
- First week: check daily before inviting more users.

Manual checks:

| Surface | Check | Healthy signal | Pause condition |
| --- | --- | --- | --- |
| Website/Vercel | Home, auth, download, privacy, and terms routes load. | Routes return 2xx and CTAs point to auth/download. | Any public route fails, loops, or shows stale legal/contact copy. |
| Cloudflare R2 | `latest.json`, latest DMG, versioned DMG, and checksum sidecars are reachable. | Manifest SHA matches the checksum sidecar and latest/versioned DMGs match the intended build. | Download fails, checksum mismatch, wrong build, or Gatekeeper rejection. |
| InsForge functions | `realtime-session`, `transcribe-audio`, `screen-context`, `computer-use-step`, billing, and auth functions show normal success/error mix. | No sustained 5xx spike; expected 401/403s are tied to unauthenticated requests. | Repeated 5xxs, auth/session lookup failures, or generic errors across multiple users. |
| OpenAI usage | Realtime, transcription, screen-context, and Computer Use spend/errors stay within expected beta volume. | No quota exhaustion; 401/429s are rare and logged with generic client responses. | Quota errors affect multiple users, spend jumps unexpectedly, or provider errors persist. |
| Stripe | Account mode, products/prices, checkout sessions, portal sessions, and webhook deliveries match the intended beta mode. | Test/live mode matches the launch decision; webhook deliveries succeed. | Unexpected live charges, wrong prices, failed webhooks, or access not unlocking after payment. |
| Support inbox | New reports include build, OS, mode, permissions, and steps. | P0/P1 queue is empty or actively owned. | Any data loss, unsafe action, secret exposure, crash loop, install block, or broken download report. |

Local commands to run before inviting more users:

```bash
scripts/audit-launch-readiness.sh --live
scripts/verify-launch-site.sh --url http://localhost:23000
scripts/verify-production-landing.sh https://voiyce.us
scripts/verify-agent-usage-caps.sh
scripts/verify-release-source-state.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
scripts/verify-rollback-readiness.sh
scripts/verify-public-dmg.sh
scripts/verify-release.sh --skip-ui-tests --public-download-check --public-dmg-check --production-landing-check
```

Do not continue broad sharing if any command fails or if a pause condition is hit. During prep, `scripts/audit-launch-readiness.sh --live --allow-blockers` can be used to print the current blocker list without treating the prep audit itself as failed.

### Monitoring Evidence Template

Use one record for the first-hour window, one for the first-day window, and one for each weekly invite expansion. Link dashboards or command outputs where possible. Do not paste secret values, raw transcripts, private screenshots, OAuth tokens, payment details, or customer private data.

```markdown
#### Launch Monitoring Record - YYYY-MM-DD HH:MM

- Monitor owner:
- Window: first hour / first day / weekly expansion / after change
- Release version/build:
- Git commit:
- Landing deployment URL/id:
- DMG URL/checksum:
- Invite batch size:
- Decision: continue / pause / rollback / narrow invite

##### Surface Checks

- Website/Vercel status:
- Cloudflare R2 status:
- InsForge functions status:
- OpenAI usage/quota status:
- Stripe mode/webhook status:
- Support inbox status:

##### Signals

- P0 count:
- P1 count:
- P2 count:
- New support reports:
- Repeated failure pattern:
- Spend or quota anomaly:
- Download or checksum anomaly:
- Privacy/security concern:

##### Actions

- Commands run:
- Dashboard evidence links:
- User-facing reply sent:
- Invite pause or resume decision:
- Owner-approved exception:
- Next review time:
- Final owner sign-off:
```

Pause rule: pause new invites if any P0/P1 appears, production download health fails, public DMG checksum changes unexpectedly, multiple users hit the same Talk/Act/billing failure, spend/quota jumps unexpectedly, or any support report suggests secret exposure, private data leakage, unsafe action, crash loop, or broken install.

## Invite Batch Control

Use this before sending each private beta batch, including founder/friendlies, design partners, or any post-fix re-invite. Keep batches small until the exact public artifact, production landing page, clean-machine install, manual UAT, support inbox, and monitoring evidence are current.

```markdown
### Invite Batch Record - YYYY-MM-DD

- Batch owner:
- Support owner:
- Monitoring owner:
- Rollback owner:
- Batch number:
- Target user count:
- Target persona:
- Invite source: founder list / design partner / waitlist / internal referral
- Release version/build:
- Git commit:
- Landing deployment URL/id:
- DMG URL/checksum:
- Known limitations linked:
- Pre-invite decision link:
- Launch evidence package link:
- Risk and exception register link:
- Support response owner confirmed:
- Monitoring window scheduled:
- Pause criteria sent to owners:
- Decision: send / hold / narrow
- Final owner sign-off:
```

Batch rules:

- Start with 3-5 high-trust users before any larger batch.
- Do not invite a new batch while a P0/P1 is open, a repeated P2 has no workaround, production download health is failing, checksum identity is unclear, or support inbox ownership is missing.
- Each batch must use exact artifact copy: version/build, DMG checksum, known limitations, support email, and privacy/reset-memory guidance.
- Wait through the first-hour monitoring window before sending another batch.
- Pause expansion if two users in the same batch hit the same install, auth, Dictation, Talk, Act, billing, or privacy concern.

## Invite Resume Checklist

Use this before resuming invites after any pause condition, incident, failed verification command, backend change, landing deployment, billing configuration change, or DMG/artifact change.

- Current P0/P1 queue is empty or each item has an owner, mitigation, and explicit hold decision.
- Any accepted P2 limitation has a user-facing workaround in beta notes or support replies.
- `scripts/audit-launch-readiness.sh --live --allow-blockers` shows only known prep-stage blockers, or strict mode passes for a release candidate.
- `scripts/verify-production-landing.sh https://voiyce.us` passes for the deployed landing page.
- `scripts/verify-release.sh --skip-ui-tests --public-download-check --public-dmg-check --production-landing-check` passes for the intended public artifact.
- The pre-invite decision record is updated with release version/build, Git commit, DMG checksum, landing deployment, R2 manifest, support owner, and rollback owner.
- Clean-machine or clean-user install evidence is current for the exact DMG users will receive.
- Manual UAT evidence covers onboarding, Dictation, Context, Talk, Act in Strict, Agent Log, Settings, billing/account access, and legal/download paths.
- Production environment evidence covers OpenAI key rotation, InsForge function env, usage-cap decision, Vercel env, R2 objects, Stripe mode, and support inbox ownership without copying secret values.
- Rollback readiness evidence identifies the previous known-good landing deployment, R2 latest object, backend function version, app artifact, and owner.
- Support/contact/release notes match the exact artifact and still use `aki.b@pentridgemedia.com`.
- Final owner sign-off is recorded before sending the next invite batch.

Release-day smoke checks:

- Website: home route loads, hero/CTA copy says Beta, Terms and Privacy use `aki.b@pentridgemedia.com`.
- Auth: `/auth?intent=download` loads, sign-in works, sign-out/sign-in recovery works, and failed auth has a clear next step.
- Download: `/download?intent=download` loads, download starts, `latest.json` points to the intended DMG, and checksum sidecars match.
- DMG: install from the intended public DMG on a clean macOS user, launch from Applications, and confirm Gatekeeper does not show damaged/unidentified warnings.
- Core app: onboarding, Dictation, Context Mode, Talk Mode, Act Mode in Strict, Agent Log, Settings permissions, memory deletion, and support export all complete their smoke path.
- Rollback: rollback owner can identify the previous known-good landing deployment, R2 latest object, backend function version, and app artifact before invites continue; `scripts/verify-rollback-readiness.sh` passes without changing R2.

## Clean Install Instructions

Use this for internal clean-machine or clean-user validation before beta sharing.

1. Create or use a macOS user that has not installed Voiyce.
2. Download the intended DMG from the public or candidate URL.
3. Verify the checksum against the recorded SHA-256.
4. Open the DMG.
5. Confirm macOS does not report the app as damaged or unidentified.
6. Drag Voiyce into Applications.
7. Launch Voiyce from Applications, not from the mounted DMG.
8. Sign in with the intended beta account path.
9. Complete onboarding once with all permissions granted.
10. Quit and reopen Voiyce.
11. Confirm Settings still shows the correct permission state.
12. Sign out and sign back in if the build under test includes sign-out recovery.
13. Repeat the permission path with one permission denied at a time on a fresh user if possible.
14. Run smoke checks:
    - Dictation in a native text field.
    - Dictation in a browser field.
    - Context Mode start and stop.
    - Talk Mode start, simple question, and stop.
    - Act Mode in Strict with a low-risk Voiyce Settings navigation.
    - Agent Log opens and records useful events.
15. Record macOS version, app version/build, Git commit, DMG URL, checksum, and result in `docs/launch-ready-self-serve.md`.

### Clean Install Evidence Checklist

Use this immediately after the clean-machine or clean-user pass. Do not paste private screenshots, transcripts, OAuth tokens, payment details, or secret values.

```markdown
#### Clean Install Evidence - YYYY-MM-DD

- Tester:
- Machine type:
- macOS version:
- New macOS user or clean machine:
- Voiyce version/build:
- Git commit:
- DMG URL:
- DMG SHA-256:
- Manifest URL:
- Notarization/Gatekeeper result:
- Installed from Applications:
- Sign-in path tested:
- Account/billing state:
- Permission path: all granted / one denied at a time / revoked after grant
- Microphone state after quit/reopen:
- Speech Recognition state after quit/reopen:
- Screen Recording state after quit/reopen:
- Accessibility state after quit/reopen:
- Dictation native-field result:
- Dictation browser-field result:
- Context start/stop result:
- Talk simple-question result:
- Act Strict low-risk action result:
- Agent Log/support export result:
- Settings permission refresh result:
- Memory delete/reset result:
- Legal/download route result:
- P0/P1 found:
- P2 found and workaround:
- Screenshots/recordings reviewed before sharing:
- Final decision: pass / hold / rerun
- Final owner sign-off:
```

Clean-install hold rules:

- Hold if the DMG checksum, manifest, version/build, notarization, or Gatekeeper result does not match release notes.
- Hold if any permission remains stale after refresh, quit, and reopen.
- Hold if Dictation, Context, Talk, Act Strict, Agent Log, Settings, sign-in, or legal/download paths cannot complete their smoke path.
- Hold if evidence includes unreviewed private screenshots, transcripts, tokens, payment details, or secrets.

## Uninstall And Reset-Memory Note

Draft user note:

```markdown
## Uninstall Voiyce

1. Quit Voiyce from the menu bar.
2. Delete Voiyce from Applications.
3. Remove Login Items for Voiyce if macOS still shows one.

## Reset Local Memory

Before broad beta sharing, confirm the in-app memory delete control works and prefer that path.

If support asks for a manual reset, quit Voiyce first, then remove only the Voiyce-owned local memory locations that support identifies. Do not delete an entire user vault or unrelated app data.
```

Manual reset should stay support-guided, but the current build's Voiyce-owned memory paths are now identified:

- Structured memory index: `~/Library/Application Support/Voiyce-Agent/Memory/SignedOut/long-term-memory.json` for signed-out use, or `~/Library/Application Support/Voiyce-Agent/Memory/Accounts/user-<hex-encoded-account-id>/long-term-memory.json` after sign-in.
- Raw memory screenshots: `~/Library/Application Support/Voiyce-Agent/Memory/SignedOut/Screenshots/` for signed-out use, or `~/Library/Application Support/Voiyce-Agent/Memory/Accounts/user-<hex-encoded-account-id>/Screenshots/` after sign-in.
- Voiyce-written vault notes: `Daily/*.md` files inside the selected Voiyce memory vault, only when those notes contain Voiyce frontmatter. Do not delete the whole vault.

Prefer Settings > Memory > Delete Memory first. Manual deletion should only remove these Voiyce-owned locations after quitting Voiyce.
