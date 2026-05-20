# Voiyce Launch Test Strategy

Status: launch-readiness reference.
Last updated: 2026-05-19.

This document defines the full self-serve test surface before Voiyce is shared beyond controlled beta. It does not authorize a release by itself; it tells the owner what evidence must exist and which checks block launch.

## Test Principles

- Test the exact artifact users will receive, not a nearby local build.
- Keep production, billing, and account evidence free of secret values.
- Treat skipped UI automation as an exception that needs owner approval and manual coverage.
- Keep P0/P1 issues at zero before wider invites.
- Record accepted P2 limitations with user-facing workaround copy.
- Do not package, notarize, upload, tag, deploy, or mutate public artifacts during prep-only checks.

## Automated Gates

| Area | Required evidence | Command or source | Launch hold rule |
| --- | --- | --- | --- |
| Launch audit | Current launch docs, blockers, support contact, legal/contact alignment, release notes, and verifier coverage. | `scripts/audit-launch-readiness.sh --allow-blockers` | Strict mode must fail while blockers are open; prep mode must pass before continuing. |
| Source state | Clean tree, expected version/build, expected tag, and no dirty artifact mismatch. | `scripts/verify-release-source-state.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'` | Hold if HEAD, tag, version, build, or dirty-tree status cannot reproduce the artifact. |
| macOS tests | Unit and UI coverage for Dictation, Context, Talk, Act, permissions, recovery copy, Agent Log, support export, billing/account gates, and app navigation. | `scripts/verify-release.sh --source-state-check --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'` | Hold if any required test fails; owner-approved skip must be paired with manual evidence. |
| Backend functions | InsForge function tests for Realtime, transcription, screen context, VideoDB session context, billing, portal, checkout, webhook, and usage caps. | Function test output plus `scripts/verify-agent-usage-caps.sh` | Hold if billing/access/cap behavior cannot be proven server-side. |
| Landing site | Lint, build, secret scan, route checks, accessibility smoke, social assets, auth/download/legal copy, agent-context positioning, and support contact. | `scripts/verify-launch-site.sh --url http://localhost:23000 --visual` | Hold if copy, route, accessibility, social asset, or download-health checks fail. |
| Production landing | Production route, auth/download health, support/legal contact, current copy, social assets, and download configuration. | `scripts/verify-production-landing.sh https://voiyce.us` | Hold if production differs from the approved launch source or download health fails. |
| Release artifact | App archive, signing, built app secret scan, public download, public DMG, notarization, checksum, and R2 manifest checks. | `scripts/verify-release.sh --archive-check --public-download-check --public-dmg-check --production-landing-check` | Hold if checksum, signature, notarization, manifest, or mounted app scan fails. |
| Rollback readiness | Landing, R2 latest/versioned objects, previous candidate, backend/app rollback notes, and non-mutating verification. | `scripts/verify-rollback-readiness.sh` | Hold if there is no known rollback target or owner. |

## Manual UAT

Use `docs/manual-uat-matrix.md` for the canonical manual pass. Required coverage:

- clean install, onboarding, permissions, denial, revocation, refresh, quit, reopen, sign-in, and sign-out
- Dictation in native/browser fields, long input, cancellation, offline recovery, and microphone-denied recovery
- Context, memory writes, Private Mode, exclusions, delete memory, and multi-display capture
- Talk current-screen answers, memory recall, interruption, tool-delay progress, network drop, missing OAuth, and repeated follow-ups
- Act safety mode, safe native navigation, browser navigation, public form filling, Gmail draft, calendar read, app switching, blocked destructive actions, Stop, missing permissions, and Agent Log mid-task behavior
- website, auth, download, legal, public artifact, visual/navigation, keyboard navigation, VoiceOver labels, motion/contrast comfort, billing/account, resilience, and support export paths

Launch hold rule: manual UAT is not passable until P0/P1 are zero, P2s have owner-approved workaround copy, and evidence links are recorded in the final decision block.

## Exploratory Testing

Run the exploratory QA charters in `docs/manual-uat-matrix.md` after scripted rows pass:

- founder work session
- permission chaos
- privacy edge sweep
- Agent stress loop
- account and billing edge sweep
- visual polish sweep
- public web and artifact sweep

Launch hold rule: any exploratory P0/P1 blocks launch; any P2 needs a user-facing workaround or an owner-approved narrow invite.

## Privacy And Security Testing

Use the final privacy and security review in `docs/launch-ready-self-serve.md`. Required coverage:

- source, landing build, built app, mounted DMG, support export, and Agent Log secret/redaction checks
- OpenAI key rotation and server-side-only key evidence
- local memory path, raw screenshot retention, vault note, delete-memory, and manual reset review
- privacy policy, terms, support intake, beta limitation, and production environment no-secret handling review

Launch hold rule: any copied secret, raw transcript, private screenshot, payment detail, OAuth token, or unresolved OpenAI key exposure blocks launch.

## Production Account Testing

Use `docs/phase-2-production-hardening.md` and `docs/stripe-billing-connection.md`. Required coverage:

- OpenAI dashboard key rotation, active key label, and usage/quota alerts
- InsForge function env, usage-cap env, billing SQL/RPC evidence, and kill-switch values
- Vercel deployment, download env, and `/api/download-health`
- Cloudflare R2 `latest.json`, latest DMG, versioned DMG, and checksum evidence
- Stripe mode, products, prices, checkout, portal, webhook endpoint/events, and signing-secret presence
- support inbox owner, backup owner, cadence, escalation path, and first reply readiness

Launch hold rule: if a production account check requires copying a secret value to prove it, capture safer dashboard evidence instead; if that is impossible, keep launch on hold.

## Evidence Package

Before invites resume or release notes are sent, attach links or short summaries for:

- launch audit result
- source-state result
- package/archive result
- launch-site and production landing results
- public download and public DMG results
- backend function and usage-cap results
- macOS unit/UI results
- landing lint/build/visual result
- secret scan result
- clean-machine install evidence
- manual UAT evidence
- exploratory QA evidence
- privacy/security review evidence
- production evidence packet
- Stripe/account evidence
- support inbox readiness
- rollback readiness
- owner-approved exceptions
- final owner sign-off
