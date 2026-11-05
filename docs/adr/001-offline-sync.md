# ADR 001: Offline sync strategy

**Status:** Accepted  
**Date:** 2026-11-04

## Context

Field technicians often work without connectivity. The app must let them:

- Open their assigned work orders from a local cache.
- Change an order's status while offline.
- Keep those changes across app restarts.
- Sync reliably when connectivity returns, without applying a retry twice.

The server already exposes work orders with optimistic concurrency: every update carries a `base_version` and stale writes return `409 Conflict`. The sync design has to build on that instead of bypassing it.

## Decision

FieldOps uses a **local-first outbox** design.

### Local data

- **Drift** stores a mirror of the work orders assigned to the current user.
- The UI reads only from Drift. Remote calls update the cache; they do not feed the widgets directly.
- A `pending_sync` flag on each cached row drives the "waiting to sync" indicator.

### Writes

- A status change updates the local row and inserts an `outbox_operations` row in the same transaction.
- The outbox row contains:
  - A client-generated operation UUID.
  - The target work order and desired status.
  - The `base_version` observed when the user made the change.
  - Attempt count, last error, and timestamps.
- Repeated changes to the same order coalesce into one pending operation.

### Push

- The sync service pushes pending operations in creation order.
- Each request sends the operation UUID as `Idempotency-Key`.
- The backend stores the serialized response in `processed_operations`. A retry with the same key returns the stored response instead of applying the update again.
- On success, the local row is replaced with the server response and the operation is deleted.
- On a network error, the operation stays queued and the UI reports that the change is saved locally.
- On `409 Conflict`, the client fetches the current order, replaces the local row, deletes the operation, and reports the conflict. The server is authoritative.

### Pull

- `GET /sync?since=<cursor>` returns work orders changed after the cursor, including soft-deleted rows.
- The client applies changes to Drift, deletes local rows with tombstones, and stores the returned `next_since` in `sync_metadata`.
- The first sync and manual pull-to-refresh use a full pull (no cursor) and remove cached orders that are no longer assigned to the technician.

### Triggers

- App start opens the cached data immediately and starts a background sync.
- Connectivity changes trigger a sync when the device comes back online.
- Pull-to-refresh and the sync button force a full sync.
- Status updates attempt a sync immediately; if offline, they remain in the outbox.

## Consequences

### Positive

- The app is usable with no connection and survives restarts.
- Retries are safe because writes are idempotent.
- The UI is fast: it never waits for the network to render.
- Conflicts are explicit and use the existing version field.
- The same outbox pattern extends to notes, photos, and PDFs.

### Negative

- There is no real-time collaboration; the server wins conflicts and a local change can be discarded.
- The cursor uses `updated_at`; two changes with exactly the same timestamp could be missed. For the current scale this is acceptable, and a `change_log` table is the natural upgrade.
- Operations are coalesced per order, so the history of intermediate status changes is not preserved.
- Background sync while the app is terminated is not implemented yet; it will need WorkManager or a platform equivalent.

## Alternatives considered

- **Remote-only with a request retry:** simpler, but the app is useless without connectivity and loses the product's main differentiator.
- **CRDTs:** powerful for collaborative editing, but overkill for status transitions and much harder to reason about. The product does not need concurrent multi-user edits yet.
- **Firebase offline persistence:** would provide sync out of the box, but couples the backend to Firebase and hides the protocol this project is meant to demonstrate.
- **Full event sourcing:** a strong audit model, but too much scope for the first version.

## Follow-ups

- Add a `change_log` table with a monotonic cursor for exact incremental sync.
- Add background sync on Android.
- Let the user review a conflict instead of always accepting the server state.
- Extend the outbox to photo uploads and notes.
