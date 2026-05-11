# Voiyce

**Speak. It types.**

Voiyce is an open-source macOS app that turns your voice into clean, formatted text — instantly injected into whatever app you're already using. No switching windows. No copying and pasting. Just hold a key, talk, and keep moving.

Built for people who think faster than they type.

---

## The Problem

You're mid-flow — drafting an email, writing code comments, filling out a form — and your fingers can't keep up with your brain. You know exactly what you want to say, but typing slows you down. Existing dictation tools feel clunky, live in separate windows, or produce messy output you have to clean up.

Voiyce was built to fix that.

## How It Works

1. **Hold Control** anywhere on your Mac
2. **Speak naturally** — no special commands, no "period" or "new line"
3. **Release** — your words appear as clean text in whatever app you're using

That's it. Voiyce lives in your menu bar, listens when you ask it to, transcribes your speech, cleans up filler words and punctuation, and injects the result directly into the active text field. It feels like a system-level superpower, not another app.

## What's Inside

This is the full source code for Voiyce — the same app available as a [signed download](https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/Voiyce.dmg). You can build it yourself or grab the ready-to-go version.

### Core (open source)
- **Hold-to-dictate** — system-wide hotkey that works in any app
- **Smart transcription** — cleans up filler words, adds punctuation, formats naturally
- **Text injection** — output goes straight into the active text field
- **Menu bar presence** — always accessible, never in the way
- **Onboarding & permissions** — guides you through macOS microphone and accessibility setup
- **Usage tracking** — see your words per day, sessions, and streaks
- **Subscription billing** — Stripe-powered plans with free trial

### Pro (included in paid download)
- **Realtime AI Agent** — a voice-controlled desktop agent powered by OpenAI's Realtime API via WebRTC. Hold Option, speak naturally, and it takes action: opens apps, clicks buttons, types text, runs scripts. This isn't a chatbot — it's an agent that operates your Mac.
- **Google Workspace** — connect Gmail and Google Calendar. The agent can check your schedule, read emails, draft responses, and send messages — all by voice.

## Why Open Source?

We believe the best tools are the ones people can trust, inspect, and learn from. Open-sourcing Voiyce means:

- **Transparency** — you can see exactly what the app does with your microphone and your data
- **Community** — if you have ideas for making voice input better, you can contribute
- **Learning** — this is a real, shipping macOS app built with Swift, SwiftUI, WebRTC, and native system APIs. If you're building something similar, take what you need.

If you just want a polished app that works out of the box — with the AI agent, Google integrations, code signing, automatic updates, and no setup required — [download Voiyce](https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/Voiyce.dmg) and subscribe to a plan.

## Build It Yourself

### Requirements
- macOS 15.0+
- Xcode 16+
- An Apple Developer account (for code signing, or run unsigned locally)

### Steps

```bash
git clone https://github.com/sirakinb/Voiyce-Agent.git
cd Voiyce-Agent
open Voiyce-Agent.xcodeproj
```

Hit **Run** in Xcode. The app will ask for microphone and accessibility permissions on first launch.

> **Note:** When you build from source, Pro features (Realtime Agent, Google Workspace) are included by default. The `VOIYCE_PRO` compilation flag controls this — remove it from the target's Swift compilation conditions in Xcode Build Settings if you want the open-source-only build.

### Landing Page

The marketing site lives in `landing-page/` and is a Next.js app:

```bash
cd landing-page
npm install
npm run dev
```

## Project Structure

```
Voiyce-Agent/              # macOS Swift app
  App/                     # App entry point, state, constants
  Core/                    # Hotkeys, text injection, system integration
  Features/                # Dashboard, settings, onboarding, realtime agent
  Services/                # Google Workspace, realtime agent server
  UI/                      # Sidebar, menu bar, visual components

landing-page/              # Next.js marketing & download site
backend/                   # FastAPI backend for agent workflows
insforge/                  # Edge functions (auth, billing, Stripe webhooks)
scripts/                   # Release & publish automation
docs/                      # Internal documentation
```

## The Tech

- **Swift + SwiftUI** — native macOS, no Electron
- **Apple Speech Recognition** — on-device transcription
- **CGEvent + Accessibility APIs** — system-wide text injection
- **WebRTC + OpenAI Realtime API** — low-latency voice agent (Pro)
- **InsForge** — authentication and backend services
- **Stripe** — subscription billing
- **Cloudflare R2** — DMG hosting and distribution
- **Next.js on Vercel** — landing page

## Contributing

Pull requests are welcome. If you're fixing a bug or improving the core dictation experience, go for it. For larger changes, open an issue first so we can discuss the approach.

## License

MIT — use it, learn from it, build on it.

## About

Voiyce is built by [Pentridge Media](https://pentridgemedia.com). We make tools that help people work faster with AI.

Questions? Ideas? [Open an issue](https://github.com/sirakinb/Voiyce-Agent/issues) or reach out at aki.b@pentridgemedia.com.
