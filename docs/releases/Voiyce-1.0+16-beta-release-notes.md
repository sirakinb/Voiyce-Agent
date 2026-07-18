# Voiyce Beta Release Notes - 1.0+16

Status: ready for owner-controlled beta sharing.
Release label: Beta.
Prepared: 2026-05-20.

These notes are tied to the currently published Cloudflare R2 macOS artifact. They are suitable for owner-controlled beta sharing after final owner sign-off on the invite list and support coverage.

## Artifact

- Version: `1.0`
- Build: `16`
- Release source tag recorded with the published artifact: `v1.0+16`
- Git commit subject: `Close launch-ready release gate`
- Latest DMG: https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/Voiyce.dmg
- Versioned DMG: https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/releases/Voiyce-1.0+16.dmg
- Manifest: https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/latest.json
- SHA-256: `bfed37a6f089eb83d0d5426fc5d25dbd709184bf2f85feceefac70ee68c485d5`
- Notarization: accepted and stapled. Latest notary submission ID: `01ae2b02-449b-480c-95dc-095b02ba2877`.
- Signing origin: `Developer ID Application: Akinyemi Bajulaiye (R28KUQ4KQP)`
- Landing URL: https://voiyce.us
- Landing deployment status: verified on 2026-05-20. `voiyce.us` serves the agent-context landing page, and `/api/download-health` returns healthy against the public R2 DMG. Vercel deployment listing remains unavailable from the current CLI/MCP auth context, so the deployment ID is not recorded.

## What Voiyce Does

Voiyce is the agent context layer for people working across Claude Code, Codex, Hermes Agent, OpenClaw, Cursor, and related AI workflows.

It captures what you are doing, what you are saying, and what your agents have already learned, then turns that into reusable context for the tools you work with.

## What Is Included

- Agent modes: Off, Context, Talk, and Act.
- Separate dictation flow for quick text insertion.
- Local memory and session context for agent handoffs.
- Agent Log for inspecting what Voiyce tried, used, saved, or blocked.
- Focus Highlight and Action Cursor for screen-aware work.
- Safety modes for Act workflows: Strict, Normal, and Unrestricted.
- Local memory retention, raw screenshot retention, app/site exclusions, Private Mode, and delete controls.
- Connected Google Gmail/Calendar tool paths after OAuth connection.

## What To Test

- Install from the DMG and complete onboarding from a clean macOS user or clean machine.
- Grant and deny each permission path: Microphone, Speech Recognition, Accessibility, and Screen Recording.
- Try normal dictation in a native app and a browser field.
- Start Context Mode, work briefly, stop it, and inspect memory/log output.
- Start Talk Mode and ask about the current screen.
- Start Act Mode in Strict, ask it to open Voiyce Settings, then cancel a sensitive action.
- Export Agent Log support data and confirm sensitive content is redacted before sharing.

## Known Limitations

- The public landing deployment is the revised agent-context page and `/api/download-health` verifies the live R2 DMG.
- The public `1.0+16` DMG has been rebuilt from the current source candidate, notarized, stapled, uploaded to R2, and verified against the live manifest.
- Act Mode is bounded and permission-dependent.
- Computer Use may misread dense, hidden, fast-changing, inaccessible, CAPTCHA-protected, or unauthenticated UI.
- Some websites block automation or require additional user login steps.
- Memory retention, raw screenshot retention, app/site exclusions, Private Mode, and delete controls are local controls that should be spot-checked by the owner before larger invite batches.
- Gmail and Calendar features require connected Google OAuth.
- Voice latency and interruption behavior should be monitored during the first invite window.
- Production env, Stripe, support coverage, and dashboard checks should be reviewed by the owner before expanding beyond the first invite batch.

## Support

Send bugs, screenshots, screen recordings, and the exact steps that led to the issue to:

```text
aki.b@pentridgemedia.com
```

Please include:

- macOS version.
- Voiyce version and build.
- Install source: public DMG, local build, or Xcode.
- Active mode: Dictation, Context, Talk, or Act.
- Permission state for Microphone, Screen Recording, and Accessibility.
- Expected result.
- Actual result.
- Agent Log export only after reviewing it for sensitive content.

## Verification Evidence

Passed on 2026-05-20:

```bash
scripts/verify-release.sh --source-state-check --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --skip-ui-tests --public-download-check --production-landing-check
```

Coverage: source OpenAI-key scan, source-state verification, 114 Swift unit tests, agent usage-cap verification, 71 backend Deno tests, launch-site verification, landing lint/build, landing build secret scan, Release app build, built Release app secret scan, public `latest.json`, latest DMG checksum, versioned DMG checksum, manifest SHA consistency, latest/versioned DMG byte equality, public DMG verification, and production landing verification. UI tests were intentionally skipped in this post-upload integrated run.

Public DMG mount/signature verification on 2026-05-20:

```bash
scripts/verify-public-dmg.sh
scripts/verify-release.sh --skip-ui-tests --public-dmg-check
```

Result: passed. It verified the current public R2 DMG SHA-256, disk image integrity, DMG Gatekeeper acceptance, stapled notarization ticket, read-only mount, mounted `Voiyce.app` presence, `/Applications` symlink, mounted app signature, app Gatekeeper acceptance, bundle version/build match against `latest.json`, mounted app OpenAI-key scan, detach, and temp cleanup.

Current-branch usage-cap verification on 2026-05-18:

```bash
scripts/verify-agent-usage-caps.sh
```

Result: passed. It verified Default/Pro/Power cap rows and documentation alignment, server-side reserve/finalize RPC hardening, per-capability usage-cap wiring for Realtime, transcription, Computer Use, and screen-context, and 52 backend Deno tests. Production environment confirmation for enabling cap enforcement remains external.

Current-branch source-state verification on 2026-05-20:

```bash
scripts/verify-release-source-state.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --allow-blockers
```

Result: strict source-state verification passed. It confirmed Xcode version `1.0`, build `16`, current branch/HEAD, no merge conflicts, `v1.0+16` pointing at HEAD, and the current release-candidate source is clean and tagged.

Additional R2 spot checks on 2026-05-20:

```bash
curl -fsSL https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/latest.json
curl -fsSL https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/Voiyce.dmg.sha256
curl -fsSL https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/releases/Voiyce-1.0+16.dmg.sha256
```

All reported `bfed37a6f089eb83d0d5426fc5d25dbd709184bf2f85feceefac70ee68c485d5`.

Rollback readiness dry-run on 2026-05-18:

```bash
scripts/verify-rollback-readiness.sh
```

Result: passed. It verified the current public `1.0+16` R2 artifacts, verified the previous `1.0+1` rollback candidate with SHA-256 `97123202c651bf5046044aeb1c6406181b8d21323261748028e76a76ad86bfe5`, generated a local rollback `latest.json`, and changed no R2 objects.

Launch-readiness status audit on 2026-05-20:

```bash
scripts/audit-launch-readiness.sh --live --allow-blockers
```

Result: audit execution passed with no launch blockers. Public R2 manifest metadata matched the recorded `1.0+16` checksum, and production landing verification passed.

Launch-readiness blocker verification on 2026-05-20:

```bash
scripts/verify-launch-blockers.sh
scripts/audit-launch-readiness.sh --live
```

Result: launch blocker verification passed with zero expected blockers and zero unexpected blockers. The read-only live audit verified public R2 `latest.json` reports version `1.0`, build `16`, and checksum `bfed37a6f089eb83d0d5426fc5d25dbd709184bf2f85feceefac70ee68c485d5`; production landing verification passed.

Production landing check on 2026-05-18:

```bash
curl -fsSI https://voiyce.us
curl -fsSL https://voiyce.us
scripts/verify-production-landing.sh https://voiyce.us
```

Result: route returned `200` from Vercel, but the page still served the old "Write at the speed of thought" / dictation-first copy. The production smoke gate failed with exit status `1` because `https://voiyce.us/api/download-health` returned `404`.

Production landing recheck on 2026-05-20:

```bash
scripts/verify-production-landing.sh https://voiyce.us
scripts/verify-public-dmg.sh
```

Result: passed. `https://voiyce.us` served the current "Stop re-explaining your work to AI." landing page, `/api/download-health` returned `{"ok":true,"status":200,"downloadUrl":"https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/Voiyce.dmg"}`, and the public R2 DMG passed checksum, image, Gatekeeper, stapler, mount, signature, bundle version/build, and mounted-app secret-scan checks.
