# Voiyce Landing Page

Next.js landing, auth handoff, download, and legal pages for `voiyce.us`.

## Local Development

```bash
npm install
npm run dev
```

The current local development URL used during launch QA is:

```text
http://localhost:23000
```

If that port is unavailable, use the URL printed by Next.js and pass it to the launch verifier.

## Launch Verification

Run the fast marketing-site gate from the repo root:

```bash
scripts/verify-launch-site.sh
```

When the local server is running, include live route checks:

```bash
scripts/verify-launch-site.sh --url http://localhost:23000
```

This verifies:

- required routes and launch assets exist
- Terms and Privacy use `aki.b@pentridgemedia.com`
- forbidden/outdated copy is absent
- required agent-context positioning is present
- `npm run lint` passes
- `npm run build` passes
- optional live routes respond: `/`, `/auth`, `/download`, `/privacy`, `/terms`

## Environment Variables

The app has safe defaults for local development, but production should set:

```bash
NEXT_PUBLIC_INSFORGE_URL=
NEXT_PUBLIC_INSFORGE_ANON_KEY=
NEXT_PUBLIC_DOWNLOAD_URL=
```

`NEXT_PUBLIC_DOWNLOAD_URL` should point to the latest public DMG, currently the Cloudflare R2 `Voiyce.dmg` object until `downloads.voiyce.us` is attached.

## Positioning Rules

The homepage should position Voiyce as:

```text
The agent context layer for your AI workflow.
```

Keep the primary headline:

```text
Stop re-explaining your work to AI.
```

Do not make the landing page dictation-first. Dictation can remain in app/download/onboarding copy, but the marketing page should emphasize:

- reusable agent context
- memory across work sessions
- handoff between Claude Code, Codex, Hermes Agent, OpenClaw, and Cursor
- concrete pain from repeated explanations and lost context

Avoid these phrases:

- boost productivity
- revolutionize
- unlock your potential
- AI-powered
- seamless experience

## Important Files

- `src/app/page.tsx` - homepage
- `src/app/layout.tsx` - metadata
- `src/app/auth/page.tsx` - auth route
- `src/app/download/page.tsx` - download route
- `src/app/privacy/page.tsx` - Privacy Policy
- `src/app/terms/page.tsx` - Terms of Service
- `src/components/HeroAnimation.tsx` - context handoff animation
- `src/lib/voiyce-config.ts` - public env defaults and route helpers
- `public/hermes-agent.png` - local Hermes Agent logo used in the agent context strip
