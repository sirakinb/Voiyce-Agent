# Voiyce Mac App

Voiyce is a native macOS voice workflow for people who want to write without slowing down to type. The premise is simple: speak naturally, and Voiyce turns that speech into clean, formatted text that can be inserted into whatever app you are already using.

The product is built around the idea that dictation should feel ambient, fast, and reliable. Instead of asking users to switch into a separate writing tool, Voiyce lives on the Mac, listens when invoked, transcribes short voice sessions, cleans up the result, and places the final text back into the active workflow. The goal is to make voice input feel like a system-level productivity layer rather than another destination app.

## What This Repository Contains

This repository contains the full Voiyce product surface:

- `Voiyce-Agent/` - the native macOS Swift app, including onboarding, authentication, billing state, dictation, transcript persistence, menu bar UI, and text injection.
- `landing-page/` - the Next.js marketing, auth, download, pricing, privacy, and terms site.
- `backend/` - a FastAPI backend intended for local or hosted agent workflows.
- `insforge/` - InsForge edge functions and SQL for authentication, billing, checkout, portal sessions, Stripe webhook handling, and transcription support.
- `docs/` - release, billing, Cloudflare R2, and user-flow documentation.
- `scripts/` - release and publishing helpers for the macOS app.

## Product Premise

Typing is still the bottleneck in many knowledge-work flows. People often know what they want to say before they can get it into an email, document, prompt, note, or chat. Voiyce aims to close that gap by making speech-to-text feel polished enough for real work:

- Capture voice quickly from the Mac.
- Transcribe and format the spoken thought.
- Remove friction like filler words and manual punctuation.
- Insert the result into the current app.
- Track usage and subscription state without disrupting the workflow.

The landing page positions this as "write at the speed of thought": a Mac-first dictation product for turning natural speech into ready-to-use text.

## Core Components

### macOS App

The Swift app is the primary product experience. It handles the local user interface, permission onboarding, microphone capture, hotkeys, transcript storage, usage limits, billing awareness, and system text insertion.

### Landing Page

The Next.js site is the public funnel for the product. It introduces Voiyce, routes users through authentication, presents pricing, and provides the Mac download flow.

For Vercel, import this repository and set the project root directory to:

```text
landing-page
```

### Backend And Services

The backend and InsForge functions support account, billing, checkout, webhook, portal, and transcription-related flows. Secrets should be configured in the relevant hosting provider and never committed to the repository.

## Local Development

Run the landing page:

```bash
cd landing-page
npm install
npm run dev -- -p 9201
```

Open:

```text
http://localhost:9201
```

Run the macOS app from Xcode by opening:

```text
Voiyce-Agent.xcodeproj
```

## Deployment Notes

The easiest web deployment path is:

1. Push this repository to GitHub.
2. Import it into Vercel.
3. Set the Vercel root directory to `landing-page`.
4. Configure any required public environment variables for the landing page.
5. Deploy.

The macOS app release flow is documented in `docs/` and supported by the release scripts in `scripts/`.

## Security Notes

Do not commit `.env`, `.env.*`, Vercel local state, Cloudflare local cache, `node_modules`, build artifacts, or generated Xcode derived data. Runtime secrets for InsForge, Stripe, Anthropic, Cloudflare, and other integrations should live in the provider dashboards or local environment files.
