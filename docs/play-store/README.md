# Google Play release package

This directory contains the Play Store materials and the release checklist for FieldOps.

## Status

| Item | Status |
| --- | --- |
| Upload keystore | Created locally on 2026-11-05; not in the repository |
| GitHub Actions signing secrets | Configured |
| Signed AAB | Built; available from the Android release workflow artifact |
| Signed APK | Built by the same workflow |
| Privacy policy | `app/web/privacy.html`, published with GitHub Pages |
| Phone screenshots | 3 captures at 1080 × 1920 |
| Feature graphic | 1024 × 500 |
| App icon | 512 × 512, matching the in-app logo |
| Play Console app | **Not created yet**; manual step |
| Closed testing | **Pending**; new personal accounts need closed testing |

## Keystore and secrets

The upload key is **outside the repository**:

```text
~/.config/fieldops/android-upload.jks
~/.config/fieldops/key.properties
~/.config/fieldops/android-upload.jks.b64
```

Back up the `.jks` and `key.properties` in a password manager or encrypted storage. Losing the
upload key can delay updates; Play App Signing can help with a reset, but the upload key should still
be treated as permanent.

The following repository secrets are configured for GitHub Actions:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

The local build reads `app/android/key.properties`, which is gitignored. The workflow writes its own
`key.properties` from the secrets and a temporary keystore file.

**Never commit** the keystore, `key.properties`, the base64 file, or the passwords.

## Build the signed AAB

Local:

```bash
cd app
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://fieldops-api-muep.onrender.com
```

Output:

```text
app/build/app/outputs/bundle/release/app-release.aab
```

GitHub Actions:

1. Open **Actions → Android release (APK + AAB) → Run workflow**.
2. Run it on `main`.
3. Download the `fieldops-android-release` artifact.
4. Upload the AAB from that artifact to Play Console.

The workflow verifies the AAB signature with `jarsigner` and attaches both the APK and AAB to tagged
releases.

## Play Store listing materials

- **App name:** FieldOps
- **Package:** `com.fieldops.app`
- **Version:** `1.0.0` (`versionCode` 1)
- **Category:** Business
- **Privacy policy:** https://FerRobles616.github.io/fieldops/privacy.html (after the Pages deploy)
- **Contact email:** replace the placeholder in `listing.md` with a monitored address
- **App access:** demo accounts are on the login screen and in `listing.md`
- **Ads:** none
- **In-app purchases:** none

Copy for the listing: [`listing.md`](listing.md).  
Data safety answers: [`data-safety.md`](data-safety.md).  
Step-by-step submission: [`checklist.md`](checklist.md).

## Store assets

| Asset | File |
| --- | --- |
| App icon 512×512 | [`assets/icon-512.png`](assets/icon-512.png) |
| Feature graphic 1024×500 | [`assets/feature-graphic-1024x500.png`](assets/feature-graphic-1024x500.png) |
| Phone screenshot: login | [`assets/phone-login-1080x1920.png`](assets/phone-login-1080x1920.png) |
| Phone screenshot: technician orders | [`assets/phone-orders-1080x1920.png`](assets/phone-orders-1080x1920.png) |
| Phone screenshot: admin console | [`assets/phone-admin-1080x1920.png`](assets/phone-admin-1080x1920.png) |

Regenerate the icon and feature graphic with:

```bash
python docs/play-store/generate_assets.py
```

The screenshots are real 1080×1920 mobile-web captures of the Flutter app, not desktop mockups.

## Limitations to disclose

- This is a public portfolio demo with public demo credentials. Testers should not enter real
  customer data.
- The API runs on Render's free tier and may cold-start for ~50 seconds.
- Photos are stored on an ephemeral filesystem; they can disappear after a redeploy. The app remains
  functional because the photo metadata is in PostgreSQL, but the image files are not durable.
- The Play Store listing and closed testing require a Google Play developer account and testers; these
  are manual steps outside this repository.
