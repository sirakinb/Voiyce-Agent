# Cloudflare R2 Release Setup

Recommended split:

- Vercel hosts the marketing site
- Cloudflare R2 stores the notarized macOS DMG
- A custom domain like `downloads.voiyce.com` serves the DMG

## 1. Create the R2 bucket

In Cloudflare:

1. Open `R2 Object Storage`
2. Create a bucket named `voiyce-downloads`
3. Expose the bucket through a custom domain instead of relying on `r2.dev`

Why:

- Cloudflare documents custom domains for production use with public buckets
- This keeps the download URL on your domain instead of a Cloudflare dev hostname
- Leave `r2.dev` disabled once the custom domain is active so users cannot bypass your Cloudflare controls

## 2. Attach a download subdomain

Use a hostname like:

- `downloads.voiyce.com`

In the bucket settings:

1. Open `Settings`
2. Add a `Custom Domain`
3. Point it at the same Cloudflare zone that owns `voiyce.com`

Once it is active, your public URL pattern will be:

```text
https://downloads.voiyce.com/Voiyce.dmg
```

## 3. Create R2 access keys

Create an R2 access key pair in Cloudflare and copy:

- Access Key ID
- Secret Access Key
- Account ID

The publish script uses the S3-compatible R2 endpoint:

```text
https://<ACCOUNT_ID>.r2.cloudflarestorage.com
```

## 4. Set local environment variables

Create local shell exports or copy `config/cloudflare/r2.env.example` into your own secret file:

```bash
export CF_R2_ACCOUNT_ID="your-account-id"
export CF_R2_BUCKET="voiyce-downloads"
export CF_R2_ACCESS_KEY_ID="your-access-key-id"
export CF_R2_SECRET_ACCESS_KEY="your-secret-access-key"
export R2_PUBLIC_BASE_URL="https://downloads.voiyce.com"
```

## 5. Publish the notarized DMG

After building and notarizing the macOS release, run:

```bash
export DEVELOPER_IDENTITY="Developer ID Application: Your Company Name (R28KUQ4KQP)"
./scripts/release-macos-dmg.sh --clean --notary-profile "<your-profile>"
./scripts/publish-dmg-to-r2.sh
```

`scripts/publish-dmg-to-r2.sh` will fail fast if the DMG is not stapled or if Gatekeeper still rejects it.

If you omit `DEVELOPER_IDENTITY`, the release script falls back to `security find-identity` and macOS may show extra keychain prompts for unrelated identities. Passing the exact identity avoids that broad scan. If your certificate lives in a dedicated build keychain, you can also add `--keychain /path/to/build.keychain-db`.

That uploads:

- `Voiyce.dmg`
- `Voiyce.dmg.sha256`
- `latest.json`
- a versioned archive copy like `releases/Voiyce-1.0+1.dmg`

## 6. Point the Vercel site at Cloudflare

Set this environment variable in Vercel:

```bash
NEXT_PUBLIC_DOWNLOAD_URL=https://downloads.voiyce.com/Voiyce.dmg
```

If the env var is missing, the site falls back to that same URL by default.

If the custom domain is not connected yet, temporarily point Vercel at the live `r2.dev` object instead:

```bash
NEXT_PUBLIC_DOWNLOAD_URL=https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/Voiyce.dmg
```

Once `voiyce.us` is attached to the R2 bucket and its SSL certificate is active, switch the env var back to your branded download hostname.

## 7. Add a Cloudflare cache rule

The stable latest URL is intentionally cacheable but not immutable.

Recommended cache rule:

- hostname equals `downloads.voiyce.com`
- path matches `/*`

That keeps downloads fast globally while still allowing the stable `Voiyce.dmg` URL to be refreshed on a new release.

## 8. Verify the public artifact

Before upload and after upload, verify:

```bash
xcrun stapler validate build/release/Voiyce.dmg
spctl -a -t open --context context:primary-signature -vv build/release/Voiyce.dmg
curl -I https://downloads.voiyce.com/Voiyce.dmg
curl https://downloads.voiyce.com/Voiyce.dmg.sha256
```

## Release flow

1. Build, notarize, and staple the DMG
2. Upload to R2 with `scripts/publish-dmg-to-r2.sh`
3. Confirm `https://downloads.voiyce.com/Voiyce.dmg`
4. Publish or email the download link
