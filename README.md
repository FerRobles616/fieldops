# FieldOps

Offline-first work order management for field teams.

> **Status:** Day 9. FieldOps is live on GitHub Pages with a Render API and PostgreSQL. The signed
> `v1.0.1` release contains the APK and Play-ready AAB. Play Store submission and closed testing are
> optional remaining manual steps.

[![CI](https://github.com/FerRobles616/fieldops/actions/workflows/ci.yml/badge.svg)](https://github.com/FerRobles616/fieldops/actions/workflows/ci.yml)

[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy?repo=https://github.com/FerRobles616/fieldops)

| Live demo | API docs | Signed release | Play Store package |
|---|---|---|---|
| [FerRobles616.github.io/fieldops](https://FerRobles616.github.io/fieldops/) | [fieldops-api-muep.onrender.com/docs](https://fieldops-api-muep.onrender.com/docs) | [v1.0.1 release](https://github.com/FerRobles616/fieldops/releases/tag/v1.0.1) | [docs/play-store](docs/play-store/README.md) |

> The Render free instance sleeps after inactivity. The app sends a warm-up request on load, but the first API call can still take around 50 seconds.

![FieldOps login screen](docs/screenshots/login-web.png)

![FieldOps work order list](docs/screenshots/orders-web.png)

![Offline status update queued in the outbox](docs/screenshots/offline-sync-web.png)

![FieldOps admin console](docs/screenshots/admin-web.png)

## Why

Field technicians often work in basements, rural areas, or buildings with poor connectivity. Most work order tools assume a stable connection and lose data when the network drops.

FieldOps is designed around the opposite constraint: the app works offline first, stores every change locally, and syncs when connectivity returns.

## Architecture

```mermaid
flowchart LR
    App[Flutter app] -->|HTTPS + JWT| API[FastAPI]
    Admin[Admin web] -->|HTTPS + JWT| API
    API --> DB[(PostgreSQL<br/>SQLite in development)]
    API -.planned.-> Storage[(S3-compatible<br/>photo storage)]
```

The backend is intentionally modular: API routes, schemas, models, and services are separated so the sync and work order domains can grow without turning `main.py` into a dumping ground.

## Stack

- **Mobile:** Flutter, Riverpod, go_router, Dio, flutter_secure_storage, Drift, connectivity_plus, image_picker, share_plus
- **Backend:** FastAPI, SQLAlchemy 2.0, Alembic, Pydantic v2, ReportLab, python-multipart
- **Auth:** JWT access tokens, Argon2 password hashing
- **Database:** PostgreSQL in production, SQLite for local development
- **Testing:** pytest, httpx2, Flutter test
- **Quality:** Ruff, mypy, flutter analyze
- **CI:** GitHub Actions
- **Planned:** S3-compatible photo storage, Play Store submission

> The Flutter web build vendors `sqlite3.wasm` and `drift_worker.js` from the matching Drift 2.35.3 release. Update both together when upgrading Drift.

## Quickstart

### 1. Backend

Requirements: Python 3.12+.

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
cp .env.example .env
alembic upgrade head
python -m app.seed
uvicorn app.main:app --reload
```

Open:

- API docs: <http://localhost:8000/docs>
- Health check: <http://localhost:8000/health>

### 2. Flutter app

Requirements: Flutter 3.47+.

```bash
cd app
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

For the Android emulator, the host machine is `10.0.2.2`:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

For a physical device, replace the URL with your machine's LAN IP.

For a deployed web build, pass the HTTPS API URL at build time:

```bash
flutter build web --release --dart-define=API_BASE_URL=https://api.example.com
```

### Demo credentials

| Role | Email | Password |
|---|---|---|
| Admin | `admin@fieldops.dev` | `admin1234` |
| Technician | `tech@fieldops.dev` | `tech1234` |

These accounts are for local demos only. Change or remove them before deploying.

The seed also creates three customers and four work orders assigned to the technician, covering pending, in-progress, and done states.

## API

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Health check |
| `POST` | `/auth/login` | Exchange email and password for a JWT |
| `GET` | `/me` | Current authenticated user |
| `GET` | `/work-orders` | List work orders (technicians only see their own) |
| `POST` | `/work-orders` | Create a work order (admin) |
| `GET` | `/work-orders/{id}` | Work order detail |
| `PATCH` | `/work-orders/{id}` | Update with `base_version` and optional `Idempotency-Key` (technicians can only change status) |
| `DELETE` | `/work-orders/{id}` | Soft delete a work order (admin) |
| `POST` | `/work-orders/{id}/photos` | Upload a photo (JPEG, PNG, WebP) with optional `Idempotency-Key` |
| `GET` | `/work-orders/{id}/photos` | List photos for a work order |
| `GET` | `/work-orders/{id}/photos/{photo_id}/file` | Download a photo |
| `GET` | `/work-orders/{id}/report.pdf` | Generate a PDF report with order details and photos |
| `GET` | `/sync` | Pull changes since a cursor, including tombstones |
| `POST` | `/customers` | Create a customer (admin) |
| `GET` | `/customers` | List customers (admin) |
| `GET` | `/admin/technicians` | List technicians (admin) |
| `PATCH` | `/admin/work-orders/{id}/assign` | Assign a technician (admin) |
| `GET` | `/admin/ping` | Admin-only role check |

Login example:

```bash
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"tech@fieldops.dev","password":"tech1234"}'
```

Authenticated request:

```bash
curl http://localhost:8000/me \
  -H "Authorization: Bearer <access_token>"
```

### Work order rules

- Technicians only see work orders assigned to them.
- Technicians can only update the `status` field.
- Admins can create, edit, assign, and soft-delete work orders.
- Updates require the current `base_version`; a stale version returns `409 Conflict` with the current entity.
- Deleted work orders keep a `deleted_at` tombstone for the future sync engine.

## App flow

1. The app starts on a splash screen while it restores the stored session.
2. Without a valid session, the router redirects to login.
3. A successful login stores the token and user in secure storage and redirects to the orders screen.
4. Expired sessions are cleared automatically.
5. Logout clears the session and the local cache.
6. The orders screen reads cached work orders from Drift immediately and triggers a background sync.
7. Status changes and photos are written locally and queued in the outbox; the UI updates before the network call.
8. On reconnect, the outbox pushes with an `Idempotency-Key`; the app pulls `/sync` changes and tombstones.
9. A `409` conflict fetches the current server state, replaces the local row, and shows a message.
10. The detail screen can generate a server-side PDF with the order details and attached photos.
11. Admins get an extra app bar action that opens the admin console.

### Admin console

- Create customers and work orders.
- Assign or reassign technicians from a dialog.
- Review total, unassigned, and pending workload.
- Reuse the same offline-first order cache as the technician view.
- Admin mutations are online-only for now; after each action the app performs a full sync.

### Offline sync

- **Local first:** every screen reads from Drift. The network is a background detail, not a blocker.
- **Outbox:** status changes and photo uploads are persisted with the base version and retried when connectivity returns.
- **Idempotent writes:** each queued operation has a UUID used as `Idempotency-Key`, so retries never apply twice.
- **Photos:** image bytes live in Drift while pending, so a photo survives an app restart and uploads later.
- **Cursor pull:** `GET /sync?since=...` returns changes and tombstones; the client stores `next_since`.
- **Full reconciliation:** manual refresh performs a full pull and removes cached orders that are no longer assigned.
- **Conflict policy:** the server is authoritative. A stale `base_version` returns `409`, the client fetches the current order, replaces the local row, and tells the user.

## Tests and quality

Backend:

```bash
cd backend
pytest
ruff check .
ruff format --check .
mypy app
```

Flutter:

```bash
cd app
flutter analyze
flutter test
flutter build web --release
```

End-to-end smoke test (with the backend running):

```bash
cd app
dart run tool/smoke_api.dart
```

Backend tests use an in-memory SQLite database. The CI pipeline also runs migrations and the seed script against PostgreSQL.

## Deployment

**Live deployment:**

- **Web demo:** <https://FerRobles616.github.io/fieldops/>
- **API docs:** <https://fieldops-api-muep.onrender.com/docs>
- **Signed release:** <https://github.com/FerRobles616/fieldops/releases/tag/v1.0.1> (APK + AAB)
- **Legacy debug-signed APK:** <https://github.com/FerRobles616/fieldops/releases/tag/v1.0.0>

The project is deployment-ready:

- **API:** Render Blueprint (`render.yaml`) with PostgreSQL. Click the **Deploy to Render** button above.
- **Web demo:** GitHub Pages workflow in `.github/workflows/deploy-web.yml`. The `API_BASE_URL` repository variable points to the Render URL.
- **Android:** `.github/workflows/android.yml` builds a release APK and a signed AAB on demand or on `v*` tags. The AAB is the Play Store artifact.
- **Privacy policy:** <https://FerRobles616.github.io/fieldops/privacy.html> (deployed with the web build).

See [`docs/deploy.md`](docs/deploy.md) for the full guide, security notes, and troubleshooting.

### Google Play

The Play Store package is prepared in [`docs/play-store`](docs/play-store/README.md):

- Real 4096-bit upload keystore (kept outside the repository; GitHub Actions secrets configured).
- Signed AAB built and verified locally, plus an Android workflow for future releases.
- 512×512 icon, 1024×500 feature graphic, and three 1080×1920 phone screenshots.
- Listing copy, data-safety answers, content-rating notes, and a closed-testing checklist.
- Privacy policy at `app/web/privacy.html`, published with GitHub Pages.

The Play Console app itself still has to be created and the AAB uploaded; closed testing for a new
personal account requires testers for 14 continuous days (confirm the current tester count in Play
Console). The full manual path is in
[`docs/play-store/checklist.md`](docs/play-store/checklist.md).

## PostgreSQL with Docker

Docker is optional for local development. To run the API and PostgreSQL together:

```bash
docker compose -f infra/docker-compose.yml up --build
```

The API will be available at <http://localhost:8000>.

To use a managed PostgreSQL instance, set:

```dotenv
DATABASE_URL=postgresql+psycopg://user:password@host:5432/fieldops
```

## Project structure

```text
fieldops/
├── backend/
│   ├── app/
│   │   ├── api/          # Routes and dependencies
│   │   ├── core/         # Settings and security
│   │   ├── db/           # SQLAlchemy base and session
│   │   ├── models/       # ORM models
│   │   ├── schemas/      # Pydantic schemas
│   │   ├── services/     # Work order domain services
│   │   └── main.py
│   ├── migrations/       # Alembic migrations
│   └── tests/
├── app/
│   ├── lib/
│   │   ├── core/         # Config, database, network, router, storage, sync, theme
│   │   ├── features/     # admin, auth, orders (data/domain/application/presentation), splash
│   │   └── shared/       # Reusable widgets
│   └── test/
├── infra/
│   └── docker-compose.yml
├── docs/
│   ├── adr/              # Architecture decision records
│   ├── play-store/       # Listing copy, assets, data safety, checklist
│   └── screenshots/      # Login, work order list, offline sync
└── .github/workflows/
```

## Roadmap

- [x] Repository, CI, authentication, roles, migrations
- [x] Flutter app shell, login, routing, theme, secure token storage
- [x] Work orders CRUD with role-based access and optimistic concurrency
- [x] Work order list, filters, detail, and status updates
- [x] Local cache with Drift
- [x] Offline outbox with retries and idempotency
- [x] Sync push/pull, tombstones, and conflict resolution
- [x] Offline photo capture with queued uploads
- [x] PDF reports with order details and photos
- [x] Admin console for customers, work orders, and assignments
- [x] Public repository and green CI
- [x] Deployment configs and Android APK build
- [x] Live demo (Render + GitHub Pages)
- [x] APK release (`v1.0.0`, debug-signed sideload)
- [x] Signed GitHub release (`v1.0.1`, APK + AAB)
- [x] Real upload keystore, signed AAB, and Android release workflow
- [x] Privacy policy, Play Store assets, listing copy, and data-safety answers
- [ ] Play Store closed testing and production release

## Decisions

- **SQLite locally, PostgreSQL in production.** Keeps onboarding fast without giving up a production-grade database.
- **Synchronous SQLAlchemy.** Simpler to reason about and test; the API is not throughput-bound yet. Revisit if concurrency becomes a bottleneck.
- **JWT + Argon2.** Stateless auth for mobile clients and current password hashing best practice.
- **UUID primary keys.** Safe to generate on the client, which the offline sync engine will need.
- **Riverpod + go_router.** Testable state management and declarative routing with an auth redirect.
- **Secure storage abstraction.** `flutter_secure_storage` on mobile/web behind a `TokenStorage` interface, with an in-memory implementation for tests.
- **Optimistic concurrency.** Work orders carry a `version`; updates require `base_version` and stale writes get `409 Conflict`. The client refreshes and asks the user to retry.
- **Soft deletes.** Deleted work orders keep a `deleted_at` tombstone so the sync engine can propagate deletions.
- **Offline-first with Drift + outbox.** The UI reads from the local database; mutations are persisted locally and pushed later.
- **Idempotent writes.** Every queued operation sends an `Idempotency-Key`; the server stores the response and returns it on retries.
- **Cursor sync with tombstones.** `/sync?since=...` returns changed and deleted rows, and the client persists `next_since`.
- **Local photo storage.** Image bytes are cached in Drift while pending, then uploaded with the same idempotent outbox.
- **Storage abstraction.** Photos use a `StorageService` protocol backed by the local filesystem in development; S3-compatible storage is the production follow-up.
- **Server-side PDF.** ReportLab generates the report from the order and its photos, so the format is consistent across clients.
- **Admin console online-only.** Admin mutations go straight to the API and then run a full sync; the technician workflow remains offline-first.

See [`docs/adr`](docs/adr) for the full decision records.

## License

MIT
