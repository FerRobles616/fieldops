# Deployment guide

## Current live deployment

| Piece | URL |
|---|---|
| Web demo | <https://FerRobles616.github.io/fieldops/> |
| API | <https://fieldops-api-muep.onrender.com> |
| API docs | <https://fieldops-api-muep.onrender.com/docs> |
| APK `v1.0.0` | <https://github.com/FerRobles616/fieldops/releases/tag/v1.0.0> |

The Render service name is `fieldops-api`, but Render assigned the suffix `-muep` because the base name was taken. A new deployment may get a different URL; update the `API_BASE_URL` repository variable if it does.

FieldOps deploys as two independent pieces:

- **API:** FastAPI + PostgreSQL on Render using the `render.yaml` Blueprint.
- **Web demo:** Flutter web on GitHub Pages using the `Deploy web demo` workflow.
- **APK:** built by the `Android APK` workflow and attached to GitHub Releases on version tags.

```
Browser / APK
      │  HTTPS + JWT
      ▼
https://fieldops-api.onrender.com  ──►  Render PostgreSQL
      │
      └── local photo storage (ephemeral on the free plan)
```

## 1. Push the repository

```bash
cd fieldops
git add .
git commit -m "Initial FieldOps release"
git remote add origin git@github.com:<your-user>/fieldops.git
git push -u origin main
```

The CI workflow runs on every push. Fix any failing job before deploying.

## 2. Deploy the API on Render

1. Create a [Render](https://render.com) account.
2. **New → Blueprint**, connect the GitHub repository, and select the root `render.yaml`.
3. Render creates:
   - `fieldops-api` — Docker web service.
   - `fieldops-db` — PostgreSQL database.
4. The Blueprint sets:
   - `ENVIRONMENT=production`
   - A generated `SECRET_KEY`
   - `DATABASE_URL` from the database
   - `CORS_ORIGINS=*` for the public demo
   - `SEED_DEMO=true`, which runs the idempotent demo seed on startup
5. Wait for the deploy and open:

```text
https://fieldops-api.onrender.com/health
https://fieldops-api.onrender.com/docs
```

If Render assigns a different service name, update the URL everywhere.

### Verify the API

```bash
curl https://fieldops-api.onrender.com/health

curl -X POST https://fieldops-api.onrender.com/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"tech@fieldops.dev","password":"tech1234"}'
```

### Free-plan caveats

- The web service may sleep after inactivity; the first request can take a few seconds.
- PostgreSQL free instances may expire or have limited storage. Treat the demo data as disposable.
- Local photo uploads are stored on the container filesystem and are lost on redeploy. The `StorageService` boundary is ready for S3-compatible storage.

## 3. Deploy the web demo on GitHub Pages

1. In the repository, go to **Settings → Pages**.
2. Set **Source** to **GitHub Actions**.
3. Go to **Settings → Secrets and variables → Actions → Variables** and add:
   - `API_BASE_URL` = `https://fieldops-api.onrender.com` (no trailing slash).
4. Push to `main` or run the **Deploy web demo** workflow manually.
5. Open:

```text
https://<your-user>.github.io/fieldops/
```

The workflow builds with:

```bash
flutter build web --release \
  --base-href "/fieldops/" \
  --dart-define=API_BASE_URL=https://fieldops-api.onrender.com
```

If the repository is not named `fieldops`, the `--base-href` is generated from the repository name automatically. For a user site (`<user>.github.io`), change the base href to `/`.

## 4. Build the APK

### Locally

```bash
cd app
flutter build apk --release \
  --dart-define=API_BASE_URL=https://fieldops-api.onrender.com
```

The APK is written to:

```text
app/build/app/outputs/flutter-apk/app-release.apk
```

### With GitHub Actions

- Run the **Android APK** workflow manually, or push a tag such as `v1.0.0`.
- The APK is uploaded as an artifact and attached to the GitHub Release for tag builds.

> The current Gradle configuration signs release builds with the debug keystore. Create a real keystore and configure `signingConfigs` before publishing to Google Play. Play Store closed testing also requires a developer account, a privacy policy, and the required number of testers.

## 5. Demo credentials

| Role | Email | Password |
|---|---|---|
| Admin | `admin@fieldops.dev` | `admin1234` |
| Technician | `tech@fieldops.dev` | `tech1234` |

These accounts are intentionally public for the portfolio demo. Do not store real customer data in this deployment.

## 6. Troubleshooting

| Symptom | Check |
|---|---|
| Web app shows `Could not reach the server` | `API_BASE_URL` variable and Render health check |
| Browser CORS error | `CORS_ORIGINS` on Render; `*` is intentional for the demo |
| API fails at startup with a database URL error | The config normalizes `postgres://` and `postgresql://` to `postgresql+psycopg://`; verify `DATABASE_URL` is set |
| Render deploy fails | Check the Render logs; migrations run in the container command |
| Photos disappear after redeploy | Render free filesystem is ephemeral; move to S3-compatible storage |
| GitHub Pages is blank | Confirm Pages source is **GitHub Actions** and the base href matches the repository name |
| APK points to localhost | Rebuild with `--dart-define=API_BASE_URL=https://...` |

## 7. Production checklist

- [ ] Real `SECRET_KEY` (Render generates one; never commit it)
- [ ] Managed PostgreSQL with backups
- [ ] S3-compatible bucket for photos
- [ ] Restrict `CORS_ORIGINS` to the web demo origin
- [ ] Replace demo accounts or disable the public seed
- [ ] Enable Render health checks and alerts
- [ ] Configure a real Android keystore and Play Store listing
- [ ] Add a privacy policy if the app is published
