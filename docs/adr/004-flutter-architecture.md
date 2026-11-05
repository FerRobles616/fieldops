# ADR 004: Flutter app architecture

**Status:** Accepted  
**Date:** 2026-11-04

## Context

The mobile client must:

- Work on Android and web (web is the public demo).
- Keep the authenticated session across restarts.
- Redirect between login and the authenticated area without manual navigation.
- Be testable without a running backend or platform plugins.

The first milestone only needs login and an empty orders screen. The architecture should still leave room for the offline cache, outbox, and sync engine that come next.

## Decision

- **Riverpod 3** for dependency injection and state management.
- **go_router** with a single redirect based on the auth state.
- **Feature-first structure**: `core/`, `features/auth`, `features/orders`, `features/splash`, `shared/`.
- **`TokenStorage` interface** with a `flutter_secure_storage` implementation and an in-memory implementation for tests.
- **Dio** wrapped by `ApiClient`; the auth interceptor reads the stored session and attaches the bearer token.
- **Sealed `AuthState`** (`AuthUnauthenticated` / `AuthAuthenticated`) to make the redirect logic exhaustive.
- **Synchronous auth form state** in `LoginScreen`; the controller only changes global state on success. This avoids navigating to the splash screen while the login request is in flight.

## Consequences

### Positive

- The auth redirect lives in one place and is easy to reason about.
- Tests can override `authRepositoryProvider` without touching secure storage or the network.
- The same `TokenStorage` boundary will let the sync engine read the session without depending on a plugin.
- Feature folders keep the upcoming orders and sync code isolated.

### Negative

- The app currently restores the session from storage without revalidating it against `/me`. An expired token is handled by the backend on the first request; a background validation can be added later.
- `flutter_secure_storage` on Linux requires `libsecret`; the supported demo targets for now are Android and web.
- There is no offline cache yet; the orders screen is a placeholder.

## Alternatives considered

- **Bloc:** strong separation, but more boilerplate than needed for this scope.
- **Provider:** simpler, but Riverpod's testing and override model is a better fit for the sync work.
- **Navigator 1.0:** fewer dependencies, but auth redirects and deep links would be manual.
- **`shared_preferences` for the token:** simpler, but not appropriate for credentials on mobile.
