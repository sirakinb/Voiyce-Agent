# Voiyce 1.0+16 Release Record

Date recorded: 2026-05-14
Last public artifact verification: 2026-05-20

This records the public macOS artifact currently served from Cloudflare R2.

## Artifact

- Version: `1.0`
- Build: `16`
- Latest DMG: https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/Voiyce.dmg
- Versioned DMG: https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/releases/Voiyce-1.0+16.dmg
- Checksum: `bfed37a6f089eb83d0d5426fc5d25dbd709184bf2f85feceefac70ee68c485d5`
- Manifest: https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/latest.json
- Notarization: accepted and stapled. Latest notary submission ID: `01ae2b02-449b-480c-95dc-095b02ba2877`.
- Signing origin: `Developer ID Application: Akinyemi Bajulaiye (R28KUQ4KQP)`

## Source State

- Release source state: tag `v1.0+16` points at the clean release commit.
- Commit subject: `Close launch-ready release gate`
- Release-candidate source tag status: `v1.0+16` points at the current clean source candidate.

The public `1.0+16` DMG has been rebuilt from the current source candidate, notarized, stapled, uploaded to R2, and verified against the live manifest.

## Verification Commands

Latest non-packaging public artifact check:

```bash
scripts/verify-release.sh --skip-ui-tests --public-download-check
```

Result on 2026-05-18: passed. This verified the current public `latest.json`, latest DMG checksum sidecar, versioned DMG checksum sidecar, manifest SHA consistency, and latest/versioned DMG byte equality for version `1.0`, build `16`. The same diagnostic run also passed source OpenAI-key scan, 72 Swift unit tests, 55 backend Deno tests, launch-site verification including `/api/download-health`, landing lint/build, landing build secret scan, Release app build, and built Release app secret scan. UI tests were intentionally skipped in this diagnostic public-download run.

Latest no-mutation public DMG mount/signature check:

```bash
scripts/verify-public-dmg.sh
scripts/verify-release.sh --skip-ui-tests --public-dmg-check
```

Result on 2026-05-20: passed. This downloaded the current public R2 DMG, verified SHA-256 `bfed37a6f089eb83d0d5426fc5d25dbd709184bf2f85feceefac70ee68c485d5`, ran `hdiutil verify`, confirmed Gatekeeper accepts the DMG as Notarized Developer ID, validated the stapled ticket, mounted read-only/no-browse, verified mounted `Voiyce.app` plus the `/Applications` symlink, verified the app signature and Gatekeeper acceptance, confirmed bundle version `1.0` and build `16` match `latest.json`, scanned the mounted app for leaked OpenAI-key patterns, detached the image, and removed temporary files. The integrated release gate also passed source OpenAI-key scan, source-state verification, 114 Swift unit tests, 71 backend Deno tests, agent usage-cap verification, launch-site verification, landing lint/build, landing build secret scan, Release app build, built Release app secret scan, public artifact verification, and production landing verification. UI tests were intentionally skipped in this post-upload integrated run.

Current-branch usage-cap check:

```bash
scripts/verify-agent-usage-caps.sh
```

Result on 2026-05-18: passed. This verified the Default/Pro/Power cap matrix for Realtime, transcription, Computer Use, and context; checked SQL cap documentation alignment; checked reserve/finalize RPC hardening; checked per-capability function wiring; and ran 52 backend Deno tests.

Current-branch source-state prep check:

```bash
scripts/verify-release-source-state.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16' --allow-blockers
```

Result on 2026-05-19: strict source-state verification passed. It confirmed Xcode version `1.0`, build `16`, current branch/HEAD, no merge conflicts, `v1.0+16` pointing at HEAD, and the working tree has 0 tracked or untracked paths. The broader `scripts/verify-release.sh --source-state-check --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'` gate also passed through non-packaging release verification.

Latest no-mutation rollback readiness check:

```bash
scripts/verify-rollback-readiness.sh
```

Result on 2026-05-18: passed. This verified the current public `1.0+16` manifest/latest/versioned R2 artifacts and checksum sidecars, verified rollback candidate `https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/releases/Voiyce-1.0+1.dmg` with SHA-256 `97123202c651bf5046044aeb1c6406181b8d21323261748028e76a76ad86bfe5`, generated a local rollback `latest.json` for version `1.0`, build `1`, and changed no R2 objects.

Full release-candidate gate:

```bash
scripts/verify-release.sh --package --public-download-check
```

For notarized public release packaging:

```bash
scripts/release-macos-dmg.sh --clean --notary-profile "voiyce-notary"
UPLOAD_CLIENT=wrangler \
CF_R2_BUCKET="voiyce-downloads" \
R2_PUBLIC_BASE_URL="https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev" \
scripts/publish-dmg-to-r2.sh
```

## Required Before Broad Launch

- Package verification passed with `Developer ID Application: Akinyemi Bajulaiye (R28KUQ4KQP)`.
- Production landing verification passed against `https://voiyce.us`, including `/api/download-health`.
- Confirm production account, billing, OAuth, support owner, monitoring, and final launch-decision evidence without copying secrets.
- Confirm Vercel production deployment identity when project access is available; R2 `latest.json` and the public DMG currently verify against the recorded artifact.
