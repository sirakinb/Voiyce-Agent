# macOS Release To R2 Breakdown

Date completed: April 2, 2026

This document records the exact release flow that was completed for the current Voiyce macOS build, from local archive through public Cloudflare R2 verification.

## Outcome

- Release archive succeeded.
- Developer ID export succeeded.
- DMG signing succeeded.
- Apple notarization succeeded.
- Stapling and Gatekeeper validation succeeded.
- Upload to Cloudflare R2 succeeded.
- Public download URL returned `200 OK`.

## Final artifacts

- Local archive: `build/release/Voiyce-Agent.xcarchive`
- Local exported app: `build/release/export/Voiyce.app`
- Local DMG: `build/release/Voiyce.dmg`
- R2 latest DMG: `https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/Voiyce.dmg`
- R2 latest checksum: `https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/Voiyce.dmg.sha256`
- R2 versioned DMG: `https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/releases/Voiyce-1.0+1.dmg`
- R2 manifest: `https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/latest.json`
- Notarization submission ID: `fad8d040-4161-484a-93ab-bc81facc71e2`
- Published SHA-256: `97123202c651bf5046044aeb1c6406181b8d21323261748028e76a76ad86bfe5`

## Credentials and runtime inputs used

- Signing identity: `Developer ID Application: Akinyemi Bajulaiye (R28KUQ4KQP)`
- Notary profile: `voiyce-notary`
- R2 bucket: `voiyce-downloads`
- Upload client: `wrangler`
- Public base URL used for manifest output: `https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev`

## Commands used

Release build, export, DMG signing, and notarization:

```bash
./scripts/release-macos-dmg.sh \
  --clean \
  --identity "Developer ID Application: Akinyemi Bajulaiye (R28KUQ4KQP)" \
  --notary-profile "voiyce-notary"
```

R2 upload:

```bash
CF_R2_BUCKET="voiyce-downloads" \
R2_PUBLIC_BASE_URL="https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev" \
UPLOAD_CLIENT="wrangler" \
./scripts/publish-dmg-to-r2.sh
```

## Step-by-step breakdown

### 1. Confirm local signing and upload prerequisites

Before starting the release, the following checks were confirmed:

- A valid Developer ID Application certificate existed in Keychain.
- The notary profile `voiyce-notary` was valid and returned recent accepted history from Apple.
- `npx` was available locally for Wrangler-based R2 uploads.
- The local Wrangler state already referenced the Cloudflare account and `voiyce-downloads` bucket.

### 2. Start the clean release build

The release script:

- removed prior release artifacts
- archived the `Voiyce-Agent` Xcode scheme in `Release`
- resolved Swift package dependencies
- built the app and created `build/release/Voiyce-Agent.xcarchive`

This stage completed successfully.

### 3. Export the archive as a Developer ID signed app

The script then ran `xcodebuild -exportArchive` with the Developer ID export options plist.

Important detail:

- the archive itself showed an Apple Development signing step during the Xcode archive phase
- the export phase is what produced the distributable Developer ID signed app

This export is the step that required private key access to the Developer ID certificate.

### 4. Approve the Keychain prompt

macOS showed a prompt for:

- `codesign` wanting access to key `Mac Developer ID Application: Akinyemi Bajulaiye`

The required action was:

- enter the `login` keychain password
- click `Always Allow`

Once that permission was granted, the export continued and succeeded.

This was the only manual approval needed during the successful run.

### 5. Verify the exported app signature

After export, the script verified:

- the exported app was valid on disk
- the app satisfied its designated requirement

That confirmed the Developer ID export was usable for distribution.

### 6. Create and sign the DMG

The script then:

- copied the exported app into a DMG staging folder
- added an `/Applications` symlink
- created `build/release/Voiyce.dmg`
- signed the DMG with the Developer ID identity
- verified the signed DMG locally

This stage completed successfully.

### 7. Submit the DMG to Apple for notarization

The script submitted the DMG with `notarytool` using the `voiyce-notary` profile.

Result:

- submission ID: `fad8d040-4161-484a-93ab-bc81facc71e2`
- final status: `Accepted`

### 8. Staple and validate the notarization ticket

After acceptance, the script:

- stapled the notarization ticket to the DMG
- validated the staple
- ran Gatekeeper validation with `spctl`

Gatekeeper result:

- `accepted`
- source: `Notarized Developer ID`
- origin: `Developer ID Application: Akinyemi Bajulaiye (R28KUQ4KQP)`

### 9. Publish the notarized DMG to Cloudflare R2

The publish script first revalidated the notarized DMG locally, then uploaded:

- `releases/Voiyce-1.0+1.dmg`
- `Voiyce.dmg`
- `releases/Voiyce-1.0+1.dmg.sha256`
- `Voiyce.dmg.sha256`
- `latest.json`

Wrangler reported each object upload as complete.

### 10. Verify the public R2 objects

After upload, public verification was completed:

- `curl -I` on the latest DMG returned `HTTP/1.1 200 OK`
- `Content-Type` was `application/x-apple-diskimage`
- the public checksum matched the generated checksum
- `latest.json` returned the expected `version`, `build`, `sha256`, and download URLs

## Non-blocking warnings seen during build

The release succeeded, but the Xcode archive emitted warnings worth tracking separately:

- `Voiyce-Agent/Core/Permissions/PermissionsManager.swift`
  - captured `self` in concurrently executing code
- `Voiyce-Agent/Core/TextInjection/TextInjector.swift`
  - deprecated `activateIgnoringOtherApps`
- `Voiyce-Agent/UI/Components/OwlOverlayPanel.swift`
  - deprecated `copyCGImage(at:actualTime:)`

These did not block packaging, signing, notarization, or upload.

## Why the permissions issue was reduced

The release script had already been updated to accept an explicit signing identity:

- `--identity "Developer ID Application: Akinyemi Bajulaiye (R28KUQ4KQP)"`

That avoided a broader `security find-identity` scan across Keychain entries and removed unrelated permission prompts. The remaining prompt was the expected private-key access request from `codesign`.

## Fast rerun checklist

Use this when repeating the process:

1. Confirm the Developer ID certificate still exists in Keychain.
2. Confirm `xcrun notarytool history --keychain-profile voiyce-notary` succeeds.
3. Run the release script with the explicit `--identity`.
4. If prompted, approve `codesign` access to the Developer ID key.
5. Wait for notarization to reach `Accepted`.
6. Run the publish script with `CF_R2_BUCKET`, `R2_PUBLIC_BASE_URL`, and `UPLOAD_CLIENT=wrangler`.
7. Verify the public DMG, checksum, and `latest.json`.
