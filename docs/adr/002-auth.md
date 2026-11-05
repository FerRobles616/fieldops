# ADR 002: Authentication and roles

**Status:** Accepted  
**Date:** 2026-11-04

## Context

FieldOps has two kinds of users:

- **Technicians** work from the mobile app, often offline. They need to read assigned orders and record progress.
- **Admins** use the web panel to create, assign, and review orders.

The API needs a stateless authentication mechanism that works well for mobile clients, supports role-based authorization, and does not add session infrastructure in the first iteration.

## Decision

- Use **JWT access tokens** signed with HS256.
- Hash passwords with **Argon2** through `pwdlib`.
- Store the user role in the `users` table as `admin` or `technician`.
- Protect routes with a `get_current_user` dependency and a `require_role(...)` dependency factory.
- Access tokens expire after 8 hours by default. Refresh tokens are out of scope for the MVP.
- Return `401` for missing/invalid credentials and `403` for insufficient permissions.

## Consequences

### Positive

- No server-side session store; horizontal scaling is straightforward.
- The Flutter client can attach the token to every request with a `dio` interceptor.
- Role checks are explicit and testable.

### Negative

- Revoking a single token before expiry is not possible without a denylist.
- A long-lived token in a mobile app must be stored securely (Android Keystore / iOS Keychain) when the app is implemented.
- Refresh tokens will be needed if the product requires short-lived access tokens.

## Alternatives considered

- **Server-side sessions:** simpler revocation, but adds state and does not fit the mobile-first API as cleanly.
- **OAuth2 with an external provider:** valuable for a real product, but too much scope for the MVP. The JWT boundary keeps that migration possible later.
