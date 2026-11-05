# Play Store listing copy

Replace `REPLACE_WITH_YOUR_EMAIL` with a monitored contact address before submitting. Google Play
requires a contact email that reaches the developer.

## App identity

| Field | Value |
| --- | --- |
| App name | **FieldOps: Work Orders** |
| Package name | `com.fieldops.app` |
| Default language | English (United States) |
| App or game | App |
| Free or paid | Free |
| Category | Business |
| Tags | Field service, Work orders, Offline |
| Contact email | `REPLACE_WITH_YOUR_EMAIL` |
| Website | https://github.com/FerRobles616/fieldops |
| Privacy policy | https://FerRobles616.github.io/fieldops/privacy.html |
| Ads | No |
| In-app purchases | No |

## Short description (80 characters max)

```text
Offline-first work orders for field service teams.
```

## Full description

```text
FieldOps keeps field technicians working when the signal drops.

Built for field service teams, FieldOps stores work orders locally, lets technicians update status and attach photos offline, and syncs every change when connectivity returns.

FEATURES
• Technician work orders with status and priority filters
• Offline-first local cache with an outbox sync queue
• Safe updates with optimistic concurrency and idempotency keys
• Customer and work order administration
• Photo capture and PDF work reports
• Role-based access for technicians and administrators

HOW IT WORKS
The app reads and writes to a local database first. Status changes, notes, and photos wait in an outbox and are pushed when the API is reachable. The app then pulls changes made by other users.

TEST ACCESS
This release includes public test accounts so reviewers and new users can explore without setup. Use test data only.
Technician: tech@fieldops.dev / tech1234
Administrator: admin@fieldops.dev / admin1234

The hosted demo may take up to a minute to start on the free hosting tier.
```

## App access instructions (Play Console)

All functionality is available without a special account. Reviewers can use the public demo buttons on
the login screen, or:

| Role | Email | Password |
| --- | --- | --- |
| Technician | `tech@fieldops.dev` | `tech1234` |
| Administrator | `admin@fieldops.dev` | `admin1234` |

No payment, subscription, or private network access is required.

## Graphics

| Asset | Specification | File |
| --- | --- | --- |
| App icon | 512 × 512 PNG | [`assets/icon-512.png`](assets/icon-512.png) |
| Feature graphic | 1024 × 500 PNG | [`assets/feature-graphic-1024x500.png`](assets/feature-graphic-1024x500.png) |
| Phone screenshot 1 | 1080 × 1920 PNG | [`assets/phone-login-1080x1920.png`](assets/phone-login-1080x1920.png) |
| Phone screenshot 2 | 1080 × 1920 PNG | [`assets/phone-orders-1080x1920.png`](assets/phone-orders-1080x1920.png) |
| Phone screenshot 3 | 1080 × 1920 PNG | [`assets/phone-admin-1080x1920.png`](assets/phone-admin-1080x1920.png) |

## Content rating

Complete the questionnaire in Play Console. The expected answers are:

- Category: **Utility, Productivity, Communication, or Other**
- Violence, sexuality, language, controlled substances, gambling: **No**
- User-generated content shared publicly: **No**
- Location sharing: **No**
- Purchases: **No**
- Unrestricted web access: **No**

The app is a business tool and is not directed to children.

## Target audience

- Age group: **18+**
- Designed for children: **No**
- Appeal to children: **No**

## Store listing declarations

- **Ads:** No ads.
- **App access:** Use the demo technician or admin account.
- **News app:** No.
- **COVID-19 contact tracing:** No.
- **Data safety:** See [`data-safety.md`](data-safety.md).
- **Government app:** No.
- **Financial features:** No.
- **Health features:** No.

## Release notes for 1.0.0

```text
Initial release.
- Offline-first work order management for field technicians
- Local cache and outbox sync with conflict protection
- Photo capture and PDF work reports
- Customer and work order administration
- Role-based access for technicians and admins
```
