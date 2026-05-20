# Voiyce Agent Modes - Current Build

This describes what the Agent modes do in the current macOS build. It is a product behavior map for users, designers, support, and engineering.

## Quick Read

| Mode | What it is for | Voice | Screen context | Tools/actions | Current limits |
| --- | --- | --- | --- | --- | --- |
| Off | Keep the Agent quiet | No | No | No | Dictation still works separately with Control |
| Context | Passive work-session awareness | No Realtime voice | Session context plus local memory writes | No direct actions | Context is useful but not true always-on semantic memory yet |
| Talk | Natural voice conversation plus lightweight actions | OpenAI Realtime | Current screen, focus region, session memory, local long-term memory | Gmail/Calendar, drafts, simple native actions, app/URL open, text insertion | Heavy multi-step UI workflows belong in Act |
| Act | Operate apps and websites with approval | OpenAI Realtime plus typed Act command | Current screen, focus region, session memory, local long-term memory | Native executor, OpenAI Computer Use loop, Action Cursor, confirmations | Bounded, permission-dependent, still needs more real-site hardening |

## What Shipped In This Build

- A non-technical Agent screen with Off, Context, Talk, and Act modes.
- A separate Agent Log screen with mode, action, memory, confirmation, and error events.
- Local long-term memory with searchable records and an Obsidian Markdown vault inside the active Obsidian vault, for example `~/Adzo's Brain/Voiyce Memory`.
- Focus Tools bar via `Control+Command+A`, the menu bar item, or the Agent screen. It contains Focus, Paint, and Underline tools for screen-region inspection.
- Focus Highlight via the Agent button and `Command+Shift+F`, with focus-region screen inspection.
- Action Cursor overlay for Act/native/Computer Use action states such as Looking, Clicking, Typing, Waiting, and Pressing keys.
- Safety modes in Settings: Strict, Normal, and Unrestricted.
- Confirmation UI and voice-confirmable pending actions for Voiyce-managed sensitive actions.
- OpenAI Computer Use through the Responses API using the hosted `computer` tool, routed through the deployed `computer-use-step` function.

## Dictation Is Separate

The normal Voiyce dictation flow is not one of the Agent modes. Holding Control records speech, transcribes it, and inserts text into the current app. Agent mode uses the Agent screen and the Agent hotkey. Dictation should keep working even when Agent mode is Off.

## Off

Off means the Agent is not actively listening, capturing session memory, or operating apps.

What should still work:

- Standard Control-key dictation.
- Dashboard, Settings, Agent Log, and billing UI.

Limitations:

- No Realtime voice session.
- No session context capture.
- No screen-aware answers.
- No app or website actions.

## Context

Context mode is the quiet “work with me in the background” mode. It keeps session context active and records useful local memory without opening a Realtime voice conversation.

What it should do:

- Keep a session timeline of recent work context.
- Save useful memory summaries locally when context/screen tools produce durable information.
- Write user-readable Markdown notes into the local memory vault, organized by date with topic links.
- Avoid speaking or taking action.

Limitations:

- No voice conversation.
- No direct Gmail, Calendar, browser, click, type, or Computer Use actions.
- It is not yet a fully tuned always-on capture system. Capture frequency, retention policy, private app exclusions, and raw screenshot retention controls still need product hardening.

## Talk

Talk mode is for conversational help while you work, and it is intentionally more capable than pure chat. It starts OpenAI Realtime voice and can use tools when the user asks for help.

What it should do:

- Answer questions out loud.
- Inspect the current screen when you ask about “this,” “what I’m looking at,” or visible content.
- Inspect only the marked focus region after you use Focus Highlight.
- Search session memory for things that happened earlier in the active session.
- Search local long-term memory across previous sessions.
- Read connected Gmail and Calendar when Google OAuth is connected.
- Check calendar availability.
- Draft text, replies, and email copy.
- Open low-risk apps or URLs.
- Navigate Voiyce’s own tabs directly, such as Agent, Agent Log, Dashboard, or Settings.
- Handle simple explicit actions such as clicking a visible button, typing short text, or opening a visible page when the task is bounded and low-risk.

What should usually move to Act:

- Broad computer operation.
- Multi-step clicking and typing across websites.
- Website workflows with changing visual state.
- Sending email, deleting, purchasing, submitting payments, or changing accounts.

Talk can still start useful work. The line is not “chat versus action.” The line is “lightweight conversational action versus heavier computer-control workflow.”

Limitations:

- Screen awareness is snapshot-based. Voiyce captures a fresh screen or focus-region image when a tool runs.
- Earlier-session recall depends on what was saved into local memory.
- Gmail and Calendar require Google OAuth.
- Tool calls add latency. A screen read, Gmail lookup, or memory search can take longer than a normal voice answer.
- If a tool returns stale, missing, or permission-limited data, Talk should say it is checking or blocked instead of pretending it knows.

## Act

Act mode is for telling Voiyce to operate apps and websites. It includes the same voice foundation as Talk, plus explicit action paths.

What it should do:

- Use native executor actions first for deterministic low-risk tasks.
- Navigate Voiyce’s own UI directly, such as “click the Settings tab.”
- Use OpenAI Computer Use for bounded multi-step UI tasks.
- Click, type, navigate, press keys, scroll, and fill forms when the task is clear.
- Show the Action Cursor while it is looking or acting.
- Ask for confirmation before sensitive actions according to the selected safety mode.
- Log actions and failures in Agent Log.

Current action layers:

- Native executor: fastest path for known Voiyce actions and simple app commands.
- Screen inspect: snapshot-based context for “what is on my screen?”
- Focus Highlight: user-marked region for “this part” requests.
- OpenAI Computer Use: visual UI operation loop for broader app and website tasks.
- Gmail/Calendar APIs: structured tools for connected Google data.
- Local memory: searchable prior context and daily Markdown notes.

Limitations:

- Screen Recording permission must be granted for screen-aware Act tasks.
- Accessibility permission must be granted for reliable clicking, typing, hotkeys, scrolling, and text insertion.
- OpenAI Computer Use is bounded to a small number of steps per request.
- It can misread dense, hidden, or fast-changing UI.
- It cannot bypass app permissions, website auth, CAPTCHAs, or missing Google OAuth.
- Confirmation is required for sensitive actions in Strict and Normal safety modes.
- Unrestricted mode is broader, but still blocks catastrophic full-system deletion and prohibited actions.
- OpenAI pending safety checks are surfaced as a blocked/confirmation state; deeper resume-after-safety continuation still needs hardening for complex workflows.

## Agent Log

Agent Log is not a mode. It is the audit surface for what Voiyce tried, which tools ran, what succeeded, what failed, and where confirmation was required.

It should show:

- Mode changes.
- Realtime voice starts/stops.
- Screen and focus-region inspect events.
- Gmail and Calendar tool calls.
- Native actions.
- Computer Use actions.
- Memory writes/searches.
- Permission, quota, and safety failures.

## Local Memory

Local long-term memory is stored in two places:

- Structured app index: used by Voiyce for search and recent summaries.
- Markdown vault: `~/Documents/Voiyce Memory/Daily/YYYY-MM-DD.md`, with frontmatter and `[[topic]]` links.

The first version is local-only. Cloud memory, vector search, app/site exclusions, and retention controls are future work.

## What Still Needs Product Work

- More voice latency and interruption tuning.
- More natural spoken recovery language when tools are slow or temporarily missing data.
- Broader real-site Act hardening across Gmail, browser forms, settings, and desktop apps.
- Resume flow for OpenAI Computer Use pending safety checks.
- Raw screenshot retention policy, private app exclusions, and delete controls.
- Tier/pricing gates for Default, Pro, and Power.
