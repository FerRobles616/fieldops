# Google Play submission checklist

This is the manual Play Console path. The Android build, signing, privacy policy, screenshots, and
listing copy are prepared in the repository.

## 0. Account and prerequisites

- [ ] Google Play developer account ($25 one-time registration).
- [ ] Developer identity verification completed.
- [ ] If this is a **new personal developer account**, plan for the closed-testing requirement:
      Google currently requires a closed test with at least 12 testers for 14 continuous days before
      production access. The exact number is shown in Play Console and can change; verify it there.
      Organization accounts may have different requirements.
- [ ] A monitored contact email. Replace `REPLACE_WITH_YOUR_EMAIL` in
      [`listing.md`](listing.md) and add it in Play Console.
- [ ] Decide whether to use a **Play App Signing** upload key (recommended). The local keystore is an
      upload key; Google can manage the app signing key.

## 1. Signing and build

- [x] Upload keystore generated outside the repository:
      `~/.config/fieldops/android-upload.jks`
- [x] `key.properties` kept local and gitignored.
- [x] GitHub Actions signing secrets configured.
- [x] Release Gradle config uses the upload key when `app/android/key.properties` exists.
- [x] Signed AAB built and verified locally with `jarsigner`.
- [x] Android workflow builds both APK and AAB and verifies the AAB signature.
- [ ] After any icon, version, or code change, rebuild the AAB and re-verify it.
- [ ] Back up the keystore and properties in a password manager. **Do not commit them.**

Build command:

```bash
cd app
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://fieldops-api-muep.onrender.com
```

Artifact:

```text
app/build/app/outputs/bundle/release/app-release.aab
```

For CI, run **Actions → Android release (APK + AAB) → Run workflow** and download the
`fieldops-android-release` artifact.

## 2. Privacy policy and public pages

- [x] Privacy policy added at `app/web/privacy.html`.
- [x] Pages workflow copies it to `build/web/privacy.html`.
- [ ] Verify the public URL after the Pages deployment:
      https://FerRobles616.github.io/fieldops/privacy.html
- [ ] Confirm the contact method in the policy reaches a monitored inbox or issue tracker.
- [ ] Add the same contact email to the Play Console listing.

## 3. Create the app in Play Console

- [ ] **All apps → Create app**.
- [ ] App name: **FieldOps: Work Orders**.
- [ ] Default language: **English (United States)**.
- [ ] App or game: **App**.
- [ ] Free or paid: **Free**.
- [ ] Accept the developer program policies and US export laws.
- [ ] Package name: `com.fieldops.app`.
- [ ] Category: **Business**.

## 4. App content declarations

- [ ] **Privacy policy:** add the public privacy URL.
- [ ] **Ads:** No ads.
- [ ] **App access:** provide the demo technician and admin credentials; all features are reachable.
- [ ] **Content rating:** complete the questionnaire using [`listing.md`](listing.md).
- [ ] **Target audience:** 18+; not designed for children.
- [ ] **Data safety:** complete using [`data-safety.md`](data-safety.md).
- [ ] **Government apps:** No.
- [ ] **Financial features:** No.
- [ ] **Health:** No.
- [ ] **News:** No.
- [ ] **COVID-19 contact tracing:** No.
- [ ] **Data deletion:** provide the GitHub issue URL for deletion requests.

## 5. Store listing

- [ ] Short description from [`listing.md`](listing.md).
- [ ] Full description from [`listing.md`](listing.md).
- [ ] App icon: [`assets/icon-512.png`](assets/icon-512.png).
- [ ] Feature graphic: [`assets/feature-graphic-1024x500.png`](assets/feature-graphic-1024x500.png).
- [ ] Phone screenshots:
  - [ ] [`assets/phone-login-1080x1920.png`](assets/phone-login-1080x1920.png)
  - [ ] [`assets/phone-orders-1080x1920.png`](assets/phone-orders-1080x1920.png)
  - [ ] [`assets/phone-admin-1080x1920.png`](assets/phone-admin-1080x1920.png)
- [ ] Contact email and website.
- [ ] No placeholder text left in the listing.

## 6. Testing

- [ ] Create an **internal testing** release and upload the AAB.
- [ ] Add your own account as an internal tester; install from the Play link.
- [ ] Run the demo path:
  - [ ] Technician login with `tech@fieldops.dev / tech1234`.
  - [ ] Open a work order and update its status.
  - [ ] Disable connectivity, update again, confirm the pending outbox state.
  - [ ] Re-enable connectivity and confirm the sync completes.
  - [ ] Admin login with `admin@fieldops.dev / admin1234`.
  - [ ] Create a customer/work order and open the admin console.
  - [ ] Generate a PDF report and attach a photo.
- [ ] Review the **pre-launch report** (crashes, ANRs, accessibility, screenshots).
- [ ] Confirm the API cold start does not look like a broken app; wait up to 60 seconds.

## 7. Closed testing

- [ ] Create a **closed testing** track.
- [ ] Add at least the number of testers required by Play Console (commonly 12 for a new personal
      account; verify the current requirement in the console) for 14 continuous days.
- [ ] Give testers the demo credentials and the testing script above.
- [ ] Collect feedback and fix critical issues.
- [ ] If the app is rejected, read the policy reason and update the listing/privacy/data safety before
      resubmitting.

## 8. Production

- [ ] Promote the tested AAB to production.
- [ ] Use a staged rollout (for example 20%).
- [ ] Monitor crash-free rate and reviews.
- [ ] Keep the AAB, mapping file, and keystore backed up.

## 9. After release

- [ ] Bump `version` in `app/pubspec.yaml` for every upload; `versionCode` must increase.
- [ ] Run the Android workflow and upload the new AAB.
- [ ] Update the privacy policy and data safety form if features change.
- [ ] Move photo storage to S3-compatible storage before claiming durable photo uploads.
- [ ] Link the Play Store listing from the README and portfolio.

## Known limitations to tell testers

- The API is on Render's free tier and can cold-start. Wait before concluding that login failed.
- The public demo uses seeded demo accounts. Do not enter real customer data.
- Photo files are on an ephemeral filesystem and may disappear after a redeploy; the work order
  metadata remains in PostgreSQL.
- The app is a portfolio demo, not a production field-service system.
