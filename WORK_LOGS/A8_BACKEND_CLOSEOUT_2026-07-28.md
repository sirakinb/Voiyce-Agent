# A8 Backend Closeout — obsolete agent function removal

**Lane:** Luna backend + landing closeout
**Base:** integration `61f46ed8eb8d4acdf85f26c5953d78f60aecf0bb`
**Branch:** `luna/backend-landing-closeout` (worktree `/root/luna/REPOS/voiyce-closeout`)
**Date:** 2026-07-28

## Scope (recreated from reviewed Drone `29fae836`, never pushed)

Removed four obsolete agent-era InsForge functions from the repo:

| Slug | Status |
|------|--------|
| `realtime-session` | Deleted from repo |
| `screen-context` | Deleted from repo |
| `computer-use-step` | Deleted from repo |
| `videodb-session` | Deleted from repo |

**Preserved:** `transcribe-audio`, all billing functions (`check-pentridge-subscription`, `stripe-webhook`, etc.), `_shared/safe-errors.ts`.

## Verification

- `deno test --allow-env insforge/functions/` → **22 passed / 0 failed**
- `scripts/verify-launch-site.sh` → **passed** (lint, build, dictation copy guards)

### Production function inventory (OPTIONS preflight, 2026-07-28)

Base: `https://25565ha3.us-east.insforge.app/functions/<slug>`

| Slug | OPTIONS | Notes |
|------|---------|-------|
| `realtime-session` | 204 | Obsolete — still deployed |
| `screen-context` | 204 | Obsolete — still deployed |
| `computer-use-step` | 204 | Obsolete — still deployed |
| `videodb-session` | 204 | Obsolete — still deployed |
| `transcribe-audio` | 204 | Preserved |
| `check-pentridge-subscription` | 204 | Preserved |
| `stripe-webhook` | 204 | Preserved |

## Undeploy status: BLOCKED on VPS

`npx @insforge/cli current` reports **not logged in** on `srv1675098`. No `.insforge` credentials on this host.

**Action for Adzo (or credentialed host):** after merging checkpoint, undeploy only the four obsolete slugs:

```bash
npx @insforge/cli functions delete realtime-session
npx @insforge/cli functions delete screen-context
npx @insforge/cli functions delete computer-use-step
npx @insforge/cli functions delete videodb-session
```

Re-smoke preserved targets (`transcribe-audio`, `check-pentridge-subscription`, `stripe-webhook`) — expect OPTIONS 204.

## Rollback (re-deploy obsolete functions)

If a slug must be restored, redeploy from the pre-A8 integration tree (`61f46ed` parent) using InsForge CLI from a machine with project auth:

```bash
git checkout 61f46ed -- insforge/functions/<slug>
cd insforge/functions/<slug>
npx @insforge/cli functions deploy <slug>
```

Source for all four slugs exists at `61f46ed` (integration HEAD before this checkpoint). Rollback is **re-deploy from git**, not undeploy of preserved functions.

## Landing / C3 / C1 (same checkpoint)

- **C3:** `AuthPageClient.tsx` — dictation-first auth copy aligned with Swift `AuthView` (headline, CTAs, connection/credential errors, browser vs app sign-in separation).
- **C1 (landing):** Hero subcopy dictation-first; `<img>` → `next/image`; verify scripts updated for dictation-only guards.
- **Production gap:** `scripts/verify-production-landing.sh` still fails on stale hero subcopy `Accelerate your productivity` at voiyce.us until landing deploy.

**Handoff:** Adzo final gate. Do not mark Aligno cards Complete from this lane.
