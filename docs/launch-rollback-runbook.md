# Voiyce Launch Rollback Runbook

Status: internal runbook.
Last updated: 2026-05-19.

Use this when a beta or public launch needs to be stopped, reverted, or narrowed. Do not improvise a rollback during an incident; identify the failing surface, roll back only that surface when possible, and verify the user path afterward.

## Rollback Principles

- Stop new exposure first.
- Preserve evidence: logs, build IDs, DMG checksum, manifest, deployment URL, and issue reports.
- Prefer reverting the smallest failing surface: landing, download object, backend function, or app artifact.
- Do not upload a replacement DMG from a dirty tree.
- Do not point users at an artifact without a recorded version, build, checksum, and notarization status.
- Keep the support contact active: `aki.b@pentridgemedia.com`.

## Severity Triggers

### P0: Stop Sharing Immediately

- Public DMG is unsigned, unstapled, damaged, or Gatekeeper-rejected.
- Public DMG checksum does not match `latest.json` or `Voiyce.dmg.sha256`.
- App ships an OpenAI API key or other secret.
- App can perform a destructive or sensitive action without expected confirmation.
- Memory deletion, privacy, or support export behavior exposes sensitive data.
- Auth/download flow sends users to the wrong artifact.

### P1: Narrow Or Pause Invites

- Clean install fails for multiple users.
- Permission recovery blocks core app use.
- Talk or Act mode fails for common launch workflows.
- Backend quota, rate limit, or kill-switch behavior is not understood.
- Landing page copy makes a materially inaccurate product claim.

## Immediate Triage

1. Identify the failing surface:
   - landing site
   - auth/download route
   - R2 public DMG or manifest
   - macOS app behavior
   - backend function
   - billing/auth/provider configuration
2. Record the current state:
   - Git branch and commit
   - Vercel deployment URL
   - DMG URL
   - `latest.json`
   - SHA-256
   - app version/build
   - relevant logs or screenshots
3. Decide action:
   - pause invites
   - revert landing deployment
   - repoint R2 latest object
   - disable an AI capability with kill switches
   - pull the download link from the landing page

## Landing Rollback

Use when copy, UI, auth routing, or download routing is wrong.

1. Identify the last known-good Vercel deployment.
2. Promote or redeploy that version from Vercel.
3. Confirm required env vars still point at the intended download URL.
4. Run:

```bash
scripts/verify-launch-site.sh --url https://voiyce.us
```

5. Manually smoke:
   - home
   - auth
   - download
   - privacy
   - terms
6. Confirm the legal contact remains `aki.b@pentridgemedia.com`.

If production cannot be verified quickly, remove or disable broad download CTAs until the site is known-good.

## R2 DMG Rollback

Use when the public latest DMG is bad but a previous versioned DMG is known-good.

Known object layout:

- latest DMG: `Voiyce.dmg`
- latest checksum: `Voiyce.dmg.sha256`
- manifest: `latest.json`
- versioned archive: `releases/Voiyce-x.y+z.dmg`
- versioned checksum: `releases/Voiyce-x.y+z.dmg.sha256`

No-mutation dry run before any R2 write:

```bash
scripts/verify-rollback-readiness.sh
```

By default this checks the current public `latest.json`, current latest/versioned DMGs, their checksum sidecars, and the previous `releases/Voiyce-1.0+1.dmg` rollback candidate. It then prints a local rollback `latest.json` without changing R2.

To test a different known-good candidate:

```bash
scripts/verify-rollback-readiness.sh --rollback-url https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/releases/Voiyce-<version>+<build>.dmg
```

Rollback steps:

1. Pick the previous known-good versioned DMG.
2. Run the no-mutation dry run above and confirm the generated manifest is correct.
3. Verify its checksum locally after download.
4. Copy the versioned DMG back to the stable latest key:

```bash
npx wrangler r2 object get voiyce-downloads/releases/Voiyce-<version>+<build>.dmg --remote --file /tmp/Voiyce-rollback.dmg
npx wrangler r2 object get voiyce-downloads/releases/Voiyce-<version>+<build>.dmg.sha256 --remote --file /tmp/Voiyce-rollback.dmg.sha256
(cd /tmp && shasum -a 256 -c Voiyce-rollback.dmg.sha256)
npx wrangler r2 object put voiyce-downloads/Voiyce.dmg --remote --file /tmp/Voiyce-rollback.dmg
npx wrangler r2 object put voiyce-downloads/Voiyce.dmg.sha256 --remote --file /tmp/Voiyce-rollback.dmg.sha256
```

5. Regenerate or restore `latest.json` so `version`, `build`, `sha256`, `download_url`, and versioned URL fields match the rollback artifact.
6. Upload the corrected manifest.
7. Verify public objects:

```bash
scripts/verify-release.sh --public-download-check --skip-ui-tests
```

8. Download from the public URL and verify Gatekeeper on a clean machine or clean macOS user.

Do not use a locally rebuilt DMG as a rollback target unless it has been signed, notarized, stapled, checksummed, and recorded.

## Backend Function Rollback

Use when Realtime, transcription, Computer Use, auth, billing, or kill-switch behavior is broken.

1. Prefer kill switches first if the capability is risky:
   - `VOIYCE_DISABLE_ALL_AI`
   - `VOIYCE_DISABLE_REALTIME`
   - `VOIYCE_DISABLE_TRANSCRIPTION`
   - `VOIYCE_DISABLE_COMPUTER_USE`
2. Record the current function deployment and env values.
3. Redeploy the last known-good function version from a clean source state.
4. Run available function tests:

```bash
deno test --allow-env insforge/functions/computer-use-step/index.test.ts
```

5. Smoke the affected app mode.
6. Update known limitations or support replies if the capability remains disabled.

## App Artifact Rollback

Use when a new macOS app artifact is bad after users have downloaded it.

1. Stop sending users to the bad artifact.
2. Repoint R2 latest objects to the previous known-good versioned DMG.
3. Update release notes and support replies with the version/build users should install.
4. If users already installed the bad app, provide a simple remediation:
   - quit Voiyce
   - download the corrected DMG
   - replace the app in Applications
   - relaunch and confirm version/build
5. If local data could be affected, pause broad use until the data path is understood.

## Verification After Any Rollback

Run the strongest applicable checks:

```bash
scripts/verify-release.sh
scripts/verify-launch-site.sh --url https://voiyce.us
scripts/verify-release.sh --public-download-check --skip-ui-tests
```

Manual smoke:

- home -> auth -> download
- download DMG
- checksum matches manifest
- Gatekeeper accepts DMG
- install and launch
- permissions screen opens
- Dictation still works
- Agent screen opens
- support contact is visible in docs/legal paths

## Resume After Rollback Checklist

Use this before restarting invites, sending release notes, or repointing users after any rollback or incident mitigation.

- Incident note is complete, with support owner, engineering owner, severity, affected surface, and rollback surface recorded.
- New-user exposure is paused or intentionally narrowed until verification passes.
- Current public landing passes `scripts/verify-launch-site.sh --url https://voiyce.us` or the production landing verifier for the intended deployment.
- Public R2 `latest.json`, latest DMG, versioned DMG, and checksum sidecars match the artifact users should receive.
- `scripts/verify-release.sh --public-download-check --skip-ui-tests` passes against the intended public artifact.
- Clean-machine or clean-user install evidence exists for the artifact users should receive after rollback.
- Manual smoke covers home, auth, download, install, launch, permissions, Dictation, Agent screen, and support contact.
- Any disabled kill switch or narrowed capability is reflected in beta notes, support replies, and known limitations.
- Support inbox has an owner and user-facing reply ready for affected users.
- Release notes and invite copy identify the exact version/build now being served.
- Open P0/P1 blockers are zero or the launch remains paused.
- Accepted P2 limitations have user-facing workaround copy.
- Final owner sign-off is recorded before invites resume.

## Incident Note Template

```markdown
# Launch Incident

- Date/time opened:
- Date/time closed:
- Reporter:
- Support owner:
- Engineering owner:
- Surface: landing / auth / download / DMG / app / backend / billing / account
- Severity: P0 / P1 / P2 / P3
- Pause decision: pause invites / narrow invites / keep monitoring
- Rollback surface: none / landing / R2 DMG / backend function / app artifact / billing config

## Impact

- Users affected:
- Workflows affected:
- Data/privacy risk:
- Billing/payment risk:

## Trigger

- First failing signal:
- Reproduction steps:
- Related support report IDs:

## Current Artifact/Deployment

- Git commit:
- Release tag:
- Vercel deployment:
- DMG URL:
- SHA-256:
- App version/build:
- R2 manifest:
- Backend function/version:
- Stripe mode/config:

## Action Taken

- Kill switches changed:
- Rollback command/result:
- Manual mitigation:
- User-facing support reply:

## Verification

- Automated commands/results:
- Manual smoke result:
- Clean-machine or clean-user result:
- Support/contact/release notes still match:

## User Communication

- Internal owner notified:
- Affected users notified:
- Public/invite copy changed:

## Follow-up Fixes

- Required source fix:
- Required doc/support update:
- Required verification before resuming invites:
- Final owner sign-off:
```
