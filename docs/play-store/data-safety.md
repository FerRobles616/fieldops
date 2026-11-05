# Play Console data safety answers

Use these answers for the FieldOps demo. The app is a portfolio project; the public demo accounts and
seed data are intentionally visible.

## Data collected

| Play category | Data type | Collected | Shared | Optional | Purpose |
| --- | --- | --- | --- | --- | --- |
| Personal info | Email address | Yes | No | No | Account management, app functionality |
| Personal info | Name | Yes | No | No | Account management, app functionality |
| Personal info | Other info (customer contact details entered by users) | Yes | No | Yes | App functionality |
| Photos and videos | Photos | Yes | No | Yes | App functionality (work order documentation and PDF reports) |
| App activity | Other actions (work order status, notes, sync) | Yes | No | No | App functionality |

The demo does not collect location, contacts, calendar, messages, financial info, health info, audio,
search history, installed apps, or advertising identifiers.

## Data handling

| Question | Answer |
| --- | --- |
| Is data encrypted in transit? | **Yes** — HTTPS between app and API |
| Can users request data deletion? | **Yes** — via the GitHub issue tracker linked in the privacy policy |
| Is data shared with third parties? | **No** — Render and GitHub are service providers that host the demo |
| Is data used for advertising or profiling? | **No** |
| Are there third-party ads or analytics SDKs? | **No** |
| Is data collection optional? | Account data is required to sign in; photos and customer details are optional fields |
| Is the app directed to children? | **No** |
| Does the app use an advertising ID? | **No** |

## Deletion request

The privacy policy points to:

https://github.com/FerRobles616/fieldops/issues

A deletion request should include the demo account email and the work orders or records to remove.
Because this is a public demo, users should not enter confidential data.

## Notes for the reviewer / maintainer

- The app has no user registration flow. Demo accounts are seeded by the backend; this is why there is
  no in-app account deletion screen.
- The demo API runs on Render's free tier. The original photo files are stored on an ephemeral
  filesystem; photo metadata is in PostgreSQL. This does not change the data-safety category, but it
  is a known durability limitation.
- If analytics, crash reporting, ads, or account registration are added later, update this form and
  the privacy policy before shipping.
