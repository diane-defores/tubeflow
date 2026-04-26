# CLAUDE.md

Guidance for Claude Code when working in `tubeflow-app` (the Flutter web client).

---

## Project Overview

Flutter web app for watching YouTube videos with timestamped notes, playlists, and viewing history. Authenticated via **Clerk**, backed by **Convex** (WebSocket + JWT). Deployed on Vercel as a static bundle.

The **Convex backend itself** (`packages/backend/convex/`) lives in a **different repository** at `/home/claude/tubeflow/` — not in this one. When a task mentions Convex schema or server functions, it's in that other repo.

This Flutter app is a client of that shared backend. Files under `lib/convex/` are client/runtime integration only; they are not Convex server functions.

---

## Architecture

### Bootstrap

`main.dart` → `_AppBootstrap` widget runs `_bootstrap()` once after the first frame:

1. `ConvexService.initialize(convexUrl)` — opens the WebSocket (done earlier in `main()`).
2. `ref.read(clerkServiceProvider)` creates `ClerkService`, which kicks off `ClerkAuthState.create(...)` in its constructor.
3. `await clerk.ready` — waits for the Clerk state to be ready.
4. `convex.setAuth(() => clerk.getConvexToken())` — wires the token callback.
5. If a Clerk session is already present, bootstrap waits for a mintable Convex JWT before auth-required startup providers run.

**Critical**: the `ClerkAuthState` is owned by `ClerkService` (long-lived), not by the `ClerkAuth` widget in the sign-in page. The sign-in page mounts `ClerkAuth(authState: service.authState)` using the shared state, so the session survives navigation out of `/sign-in`.

### Auth

- `ClerkService` (`lib/auth/clerk_service.dart`) — the auth entry point for the rest of the app.
  - `ready: Future<void>` — completes when `ClerkAuthState` is constructed (or when init failed / key missing).
  - `authState: ClerkAuthState?` — the live state, non-null after `ready` if `CLERK_PUBLISHABLE_KEY` is set.
  - `getConvexToken()` — calls `authState.sessionToken(templateName: 'convex')`, returns `.jwt` or `null`.
  - `signOut()` — terminates Clerk session + updates `AuthNotifier`.
- `AuthNotifier` (`lib/auth/auth_state.dart`) — Riverpod notifier the router watches to decide redirects.
- `ClerkWebPersistor` (`lib/auth/clerk_web_persistor.dart`) — web-only session persistence (imports a `lib/src/` file from `clerk_auth`; this is expected, ignore the lint).

### Convex

- `ConvexService` (`lib/convex/convex_client.dart`) — wraps `convex_flutter`'s singleton client.
  - `query<T>(path, args)`, `mutate<T>(path, args)`, `action<T>(path, args)` — all await `_waitForConnection()` first.
  - `subscribe(path, args, onData, onError)` — WebSocket subscription.
  - `setAuth(tokenFn)` — installs the token provider. Called once from bootstrap.
- Production backend contract is shared with `/home/claude/tubeflow`. If Flutter starts calling a new Convex function, the backend deploy must land first or at the same time.
- **All mutations go through `lib/providers/mutations.dart`** — screens must never call `convexServiceProvider` directly for writes. Reads (queries/subs) can go through providers or the service.
- `_waitForConnection()` waits up to 30s for the WebSocket to reach `connected` state. Throws `TimeoutException` otherwise.

### Routing

- `lib/app/router.dart` — `go_router` config. Watches `authStateProvider` to redirect unauthenticated users to `/sign-in` and authenticated users away from it.
- Screens are split by feature under `lib/screens/<feature>/`. Shell (bottom nav) lives in `lib/widgets/app_shell.dart`.

### State management

- **Riverpod 3** with code generation (`riverpod_annotation` + `riverpod_generator`).
- Providers live in `lib/providers/providers.dart` and feature-adjacent `*_provider.dart` files.
- Never call `ref.read(convexServiceProvider).mutate(...)` from a screen — use the helpers in `mutations.dart`.

---

## Environment variables

Both passed at **build time** via `--dart-define` (Flutter web bakes them into `main.dart.js`):

- `CONVEX_URL` — **required**. App fails explicitly when missing (bootstrap throws, config-fallback screen renders).
- `CLERK_PUBLISHABLE_KEY` — **optional**. When missing, the app runs in an unauth "guest mode" and `ClerkService` logs a warning.

No `NEXT_PUBLIC_` / `EXPO_` prefixes. These were removed in commit `0a09d3e`.

For the Convex side:

- `CLERK_JWT_ISSUER_DOMAIN` must be set on the **Convex deployment** (not in this repo). Current value: `https://clerk.tubeflow.winflowz.com`.
- A JWT template named `convex` (RS256 preset) must exist in the Clerk dashboard.

---

## Common tasks

```bash
# Install deps
flutter pub get

# Run dev (web)
flutter run -d chrome \
  --dart-define=CONVEX_URL=... \
  --dart-define=CLERK_PUBLISHABLE_KEY=...

# Static analyse (no network)
dart analyze lib/

# Build web production
bash build.sh

# Check that Flutter's critical Convex functions still exist
dart run tool/check_shared_backend_contract.dart

# Regenerate Riverpod-annotated providers
dart run build_runner build --delete-conflicting-outputs
```

---

## Critical rules

1. **Never hardcode env vars.** Always read via `String.fromEnvironment(...)` with the exact names `CONVEX_URL` / `CLERK_PUBLISHABLE_KEY`.
2. **Never mount a second `ClerkAuth` widget that constructs its own `ClerkAuthState`.** If you need Clerk in a widget, use `ClerkAuth.of(context)` below the existing `ClerkAuth(authState: ...)` in the sign-in page, or (preferred) read the shared `clerkServiceProvider`.
3. **All Convex writes go through `lib/providers/mutations.dart`.** Screens calling `convexServiceProvider.mutate(...)` directly are a regression — this was cleaned up in commit `c554790`.
4. **`getConvexToken()` must never throw.** Return `null` on any error — Convex will fall back to unauthenticated access rather than failing the whole request.
5. **Don't commit generated files** unless already tracked (`*.g.dart` from Riverpod — check `.gitignore`).
6. **`pubspec.lock` IS committed** (removed from `.gitignore` in commit `4606d66`).

---

## Gotchas

- `clerk_flutter 0.0.14-beta` exposes `ClerkAuthState` only via an InheritedWidget (`ClerkAuth.of(context)`). We work around this by owning the state in `ClerkService` and passing it to `ClerkAuth(authState: ...)`.
- Flutter web session persistence isn't supported out-of-the-box by `clerk_flutter` — `ClerkWebPersistor` fills the gap.
- `ConvexClient.instance` is a global singleton provided by `convex_flutter`. `ConvexService` is just a wrapper; don't instantiate multiple `ConvexService`s against different URLs in the same process.
- The JWT template name `convex` must match `applicationID: "convex"` in `packages/backend/convex/auth.config.ts`. Changing one requires changing the other.

---

## Related files

- `README.md` — public-facing quick start + stack overview
- `TASKS.md` — current audit / backlog items
- `CHANGELOG.md` — user-facing changes
- `AUDIT_LOG.md` — code audit history
- `.env.example` — required build-time variables
