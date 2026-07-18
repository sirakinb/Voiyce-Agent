# Voiyce Agent Tier, Cost, Privacy, and TipTour Plan

Last updated: 2026-05-18

This document turns the current Agent build into a product and cost plan. It covers what still needs to ship, how Default/Pro/Power should work, how privacy/safety modes should be exposed, and how the TipTour-style action layer fits into Voiyce.

## Current Build Status

Shipped in the current macOS build:

- Agent modes: Off, Context, Talk, Act.
- Separate Agent Log screen.
- Talk mode with OpenAI Realtime voice, screen tools, Gmail/Calendar tools, native Voiyce navigation, local memory search, and simple actions.
- Act mode with native executor plus OpenAI Computer Use loop for bounded app and website actions.
- Action Cursor overlay and Focus Highlight overlay.
- Local long-term memory with an Obsidian-style Markdown vault at `~/Documents/Voiyce Memory`.
- Settings safety modes: Strict, Normal, Unrestricted.
- Voice-confirmable pending actions for Voiyce-managed confirmations.
- Permission status UI for Microphone, Accessibility, and Screen Recording.

Fixed in this pass:

- The hidden Realtime/Act browser bridge now lives at the app shell level instead of inside the Agent screen. Navigating from Agent to Agent Log no longer tears down the bridge or breaks Act.
- Server-side usage-cap primitives now exist behind `VOIYCE_ENFORCE_AGENT_USAGE_CAPS=true` for Realtime, transcription, Computer Use, and screen-context requests.
- Default/Pro/Power capability and memory quota policy exists in the macOS app; production tier mapping still needs Stripe/product confirmation before paid launch.

## Features Still Needed

Required before calling the product "finished":

- Production confirmation that `VOIYCE_ENFORCE_AGENT_USAGE_CAPS=true` is set and server-side tier mapping matches Stripe products.
- Tier-aware model selection, capture frequency, and Act step limits beyond the current beta caps.
- Better latency tuning for Talk and Act, especially shorter voice turn delay and better interruption handling.
- More real-site hardening for Gmail, Google Calendar, browser forms, settings pages, and auth-heavy workflows.
- Resume flow for OpenAI Computer Use pending safety checks.
- Additional user-facing privacy polish for vault export and any remaining memory-management edge cases.
- Full TipTour-style visual interaction layer beyond the current Action Cursor and Focus Highlight.
- UAT script with repeatable voice commands for Talk, Act, memory, permissions, and Agent Log.

Nice-to-have after core reliability:

- Obsidian CLI integration for opening the vault, creating daily notes, and linking related topics from the command line.
- Cloud memory option for users who opt in later.
- Team/enterprise admin controls.
- Workspace profiles, for example "sales", "writing", "coding", "ops".

## TipTour Fit

TipTour is not a replacement for Voiyce. It is a useful reference for the action interaction layer.

What Voiyce already has:

- Action Cursor: shows when Voiyce is looking, clicking, typing, pressing keys, or waiting.
- Focus Highlight: lets the user mark "this part" of the screen and ask Voiyce to act on it.
- Native macOS actions plus Computer Use for actual control.

What Voiyce does not have yet:

- Freeform paint/underline selection as a first-class interaction.
- "Tour Guide" mode where the assistant points and teaches without taking over.
- Rich cursor path, target preview, click confirmation marker, and step-by-step visual trail.
- Better "this over here" spatial commands using the painted region plus screen state.

Recommended roadmap:

1. Action Cursor reliability: keep cursor visible during every native and Computer Use action.
2. Freeform Focus Paint: hold a hotkey, draw over a region, then say "change this", "move this", or "explain this".
3. Guided Action mode: show where Voiyce will click/type before execution when safety mode requires confirmation.
4. Tour Guide mode: teach the user with highlights and arrows without executing clicks.
5. Spatial memory: save marked regions as local memory when useful, with screenshots only if the user permits retention.

Reference: [TipTour macOS repository](https://github.com/milind-soni/tiptour-macos).

## Tier Design

### Default

Target user:

- Wants fast dictation, light agent help, and occasional context.

Included:

- Dictation.
- Context mode with conservative capture frequency.
- Talk mode on the lower-cost realtime model.
- Light screen reads and local memory summaries.
- Limited simple actions: open app, open URL, insert text, navigate Voiyce tabs.
- No broad Computer Use by default, or a very small monthly allowance.

Recommended limits:

- 300 dictation minutes per month.
- 90 Talk minutes per month.
- 15 Context hours per month.
- 10 Act/Computer Use tasks per month.
- 30-day local memory summaries.
- Raw screenshots off by default.

Recommended price:

- $19/month.

### Pro

Target user:

- Uses Voiyce during real work sessions and wants Talk plus frequent Act.

Included:

- Everything in Default.
- Higher Context capture frequency.
- Talk with model routing: default to realtime-mini, upgrade selected turns to GPT-Realtime-2 when screen/action complexity is high.
- Act mode enabled with native executor and OpenAI Computer Use.
- More local memory, topic linking, and Obsidian vault support.
- Normal safety mode by default.

Recommended limits:

- 900 dictation minutes per month.
- 300 Talk minutes per month.
- 60 Context hours per month.
- 150 Act/Computer Use tasks per month.
- 90-day local memory summaries.
- Optional raw screenshot retention with short default retention.

Recommended price:

- $69/month.

### Power

Target user:

- Wants a high-agency assistant running alongside them for serious daily work.

Included:

- Everything in Pro.
- GPT-Realtime-2 used more often for higher-quality voice/action planning.
- Higher Context capture frequency.
- Larger Act budget and higher action step limits.
- More aggressive memory capture, search, and Obsidian linking.
- Unrestricted safety mode available after explicit opt-in.

Recommended limits:

- 2,400 dictation minutes per month.
- 1,000 Talk minutes per month.
- 160 Context hours per month.
- 600 Act/Computer Use tasks per month.
- 180-day local memory summaries.
- Optional raw screenshot retention with explicit retention controls.

Recommended price:

- $199/month.

## Privacy And Safety Controls

These should be separate concepts in Settings.

Safety mode controls what Voiyce is allowed to do:

- Strict: confirm most app, browser, email, file, and account actions.
- Normal: confirm sensitive actions while routine navigation can run faster.
- Unrestricted: broad computer control with explicit opt-in. Still block full system deletion, credential exfiltration, illegal actions, and platform-prohibited actions.

Privacy mode controls what Voiyce is allowed to remember:

- Private: no durable memory, no raw screenshot retention, current-session only.
- Local Memory: local summaries and Obsidian vault notes, raw screenshots off by default.
- Local Memory Plus Screenshots: local summaries plus raw screenshots retained for a user-selected period.
- Unrestricted Local Recall: aggressive local capture and retention, app exclusions still respected.

Privacy controls that need to ship:

- App and website exclusion list.
- Pause memory for 15 minutes, 1 hour, or until tomorrow.
- Delete today, delete current session, delete all local memory.
- Toggle raw screenshot retention.
- Retention duration for raw screenshots.
- Open Obsidian vault.
- Export memory bundle.

## Cost Basis

Provider pricing used for this draft:

- OpenAI GPT-Realtime-2: audio input $32 / 1M tokens, cached audio input $0.40 / 1M tokens, audio output $64 / 1M tokens. Text input $4 / 1M tokens, cached text input $0.40 / 1M tokens, text output $24 / 1M tokens.
- OpenAI gpt-realtime-mini: audio input $10 / 1M tokens, cached audio input $0.30 / 1M tokens, audio output $20 / 1M tokens. Text input $0.60 / 1M tokens, cached text input $0.06 / 1M tokens, text output $2.40 / 1M tokens.
- OpenAI transcription: gpt-4o-mini-transcribe estimated at $0.003/minute; gpt-4o-transcribe estimated at $0.006/minute.
- OpenAI computer-use-preview: $1.50 / 1M input tokens and $6.00 / 1M output tokens.
- VideoDB: realtime signal input $0.084/hour, transcription $0.01/minute, search $1.50 / 1k queries, media storage $0.03/GB/month, index storage $0.0005/minute/month.

Sources:

- [OpenAI API pricing](https://openai.com/api/pricing/)
- [OpenAI detailed pricing docs](https://developers.openai.com/api/docs/pricing)
- [OpenAI Realtime cost guide](https://developers.openai.com/api/docs/guides/realtime-costs)
- [VideoDB pricing](https://videodb.io/pricing)

Important cost model notes:

- Realtime cost is not just "minutes connected". OpenAI bills Realtime responses by input/output tokens across audio, text, and image.
- OpenAI documents user audio as roughly 1 audio token per 100 ms and assistant audio as roughly 1 audio token per 50 ms.
- Later turns can get more expensive because the conversation grows, but prompt caching can reduce repeated input costs.
- VideoDB Context cost depends heavily on how often Voiyce samples, indexes, searches, and retains session context.
- Computer Use cost depends on screenshot/token size and action loop steps, so Act needs caps.

## Monthly COGS Assumptions

These are planning estimates, not billing guarantees.

| Tier | Assumed usage | Estimated provider COGS / active user / month |
| --- | --- | --- |
| Default | 300 dictation min, 90 Talk min, 15 Context hr, 10 Act tasks | $4.50 |
| Pro | 900 dictation min, 300 Talk min, 60 Context hr, 150 Act tasks | $24.00 |
| Power | 2,400 dictation min, 1,000 Talk min, 160 Context hr, 600 Act tasks | $103.00 |

Blended assumption:

- 70% Default.
- 25% Pro.
- 5% Power.
- Blended provider COGS: about $14.30 per active user per month.
- Blended revenue at $19/$69/$199: about $40.50 per active user per month.

## Scale Projection

This table estimates monthly provider COGS. It excludes payroll, support, taxes, chargebacks, customer acquisition, and large enterprise infrastructure. Add 15-25% operating overhead once cloud sync, analytics, support tooling, and deployment infrastructure are included.

| Active users | All Default COGS | All Pro COGS | All Power COGS | Blended COGS | Blended MRR |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 10 | $45 | $240 | $1,030 | $143 | $405 |
| 100 | $450 | $2,400 | $10,300 | $1,430 | $4,050 |
| 1,000 | $4,500 | $24,000 | $103,000 | $14,300 | $40,500 |
| 10,000 | $45,000 | $240,000 | $1,030,000 | $143,000 | $405,000 |
| 100,000 | $450,000 | $2,400,000 | $10,300,000 | $1,430,000 | $4,050,000 |
| 1,000,000 | $4,500,000 | $24,000,000 | $103,000,000 | $14,300,000 | $40,500,000 |

Loaded cost estimate with 20% operating overhead:

| Active users | Blended provider COGS | Loaded COGS estimate |
| ---: | ---: | ---: |
| 10 | $143 | $172 |
| 100 | $1,430 | $1,716 |
| 1,000 | $14,300 | $17,160 |
| 10,000 | $143,000 | $171,600 |
| 100,000 | $1,430,000 | $1,716,000 |
| 1,000,000 | $14,300,000 | $17,160,000 |

## Cost Control Requirements

Must ship with tiers:

- Per-user cost ledger for Realtime, transcription, Computer Use, and screen-context requests. Implemented server-side behind `VOIYCE_ENFORCE_AGENT_USAGE_CAPS=true`; production env confirmation remains open.
- Per-tier hard caps for Realtime, transcription, Context, Computer Use, and local memory/raw screenshot retention.
- Soft warning at 70%, 90%, and 100% of included usage.
- Graceful downgrade path when a user hits limits.
- Per-session max duration.
- Per-Act max step count.
- Model router that defaults to cheaper models and escalates only when needed.
- Cache-friendly Realtime session updates: avoid changing tools/instructions mid-session unless required.
- App/site exclusions to avoid wasting context budget on private or irrelevant apps.
- Admin kill switches for all AI, Realtime, transcription, Computer Use, screen context, and VideoDB-backed session context.

## Recommended Implementation Order

1. Stabilize lifecycle: keep the Realtime/Act bridge alive across navigation and app state changes.
2. Confirm production usage-cap env values and Stripe-to-tier mapping before charging.
3. Tune tier config in code: model routing, capture frequency, Act steps, and retention.
4. Finish any remaining Settings privacy polish and vault export behavior.
5. Add full TipTour-style Focus Paint and guided action visuals.
6. Finalize billing enforcement and plan upgrade UI for paid production.

Stop before step 6 if the current goal is to finish product capability before payment structure.
