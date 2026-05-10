# TubeFlow App

Flutter app for watching YouTube videos, taking timestamped notes, and tracking viewing history. Built for web deployment on Vercel, backed by Convex and authenticated via Clerk.

## Quick Start

```bash
flutter pub get

# Run locally (web)
flutter run -d chrome \
  --dart-define=CONVEX_URL=https://your-deployment.convex.cloud \
  --dart-define=CLERK_PUBLISHABLE_KEY=pk_test_... \
  --dart-define=TUBEFLOW_APP_URL=https://app.tubeflow.winflowz.com

# Production build
CONVEX_URL=... CLERK_PUBLISHABLE_KEY=... TUBEFLOW_APP_URL=https://app.tubeflow.winflowz.com bash build.sh
```

The `build.sh` script wraps `flutter build web` and passes the required `--dart-define` values. Vercel runs it via `vercel.json`.

## Environment Variables

The Flutter values are required at **build time** (`--dart-define`), not runtime. Flutter web bakes them into the compiled JS bundle. The OAuth handler values are runtime environment variables for Vercel functions.

| Variable | Purpose |
|---|---|
| `CONVEX_URL` | Convex deployment URL (e.g. `https://xxx.convex.cloud`). App fails explicitly when missing. |
| `CLERK_PUBLISHABLE_KEY` | Clerk publishable key. When missing, app runs in guest mode without auth. |
| `TUBEFLOW_APP_URL` | Web app origin used for the YouTube OAuth callback URLs (current deployment: `https://app.tubeflow.winflowz.com`). |
| `CLERK_HOSTED_SIGN_IN_URL` | Optional hosted Clerk sign-in override. When omitted, the app derives the sign-in URL from `TUBEFLOW_APP_URL`. |
| `BUILD_COMMIT_SHA` | Optional build metadata shown in diagnostics. Defaults to `VERCEL_GIT_COMMIT_SHA` or the local Git short SHA in `build.sh`. |
| `BUILD_ENVIRONMENT` | Optional build metadata shown in diagnostics. Defaults to `VERCEL_ENV` or `local` in `build.sh`. |
| `BUILD_TIMESTAMP` | Optional build metadata shown in diagnostics. Defaults to the current UTC timestamp in `build.sh`. |
| `CLERK_SECRET_KEY` | Clerk backend secret used by the Vercel YouTube OAuth callback to mint the `convex` JWT from the current session. |
| `GOOGLE_CLIENT_ID` | Google OAuth client ID used for the YouTube consent screen. |
| `GOOGLE_CLIENT_SECRET` | Google OAuth client secret used to exchange the YouTube authorization code for tokens. |

See `.env.example`. Preferred names are the plain variables above; `build.sh` also accepts the legacy Vercel-style `NEXT_PUBLIC_CONVEX_URL` / `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` and the older `TUBEFLOW_WEB_URL` as compatibility fallbacks. The OAuth handlers also accept `NEXT_PUBLIC_APP_URL` and `NEXT_PUBLIC_GOOGLE_CLIENT_ID` as compatibility fallbacks.

Convex deployment variables used by backend features:

| Variable | Purpose |
|---|---|
| `FEEDBACK_ADMIN_EMAILS` | Comma-separated allowlist of admin emails allowed to open the in-app feedback admin screen. Set on the Convex deployment, not in Flutter `--dart-define`. |

## Tech Stack

- **Flutter 3.41.7 / Dart 3.11.5** — web target
- **Riverpod 3** — state management (`flutter_riverpod` + code-gen via `riverpod_generator`)
- **go_router 17** — routing with auth-aware redirects
- **Clerk** (`clerk_flutter 0.0.14-beta`) — authentication, custom `ClerkAuthState` owned by `ClerkService`
- **Convex** (`convex_flutter 3.0.1`) — backend queries / mutations / subscriptions, JWT-authenticated via Clerk `convex` template
- **youtube_player_flutter** — video playback
- **Material 3** — theming (light / dark / system)
- **record + just_audio** — feedback audio capture and playback

Convex backend lives in a **separate repository** at `/home/claude/tubeflow/packages/backend/convex/` — not in this project. This Flutter app is a client of that shared backend. The code under `lib/convex/` is client transport/state only, not server code.

## Project Structure

```
lib/
├── main.dart                   # Entry point + bootstrap sequence
├── app/
│   ├── router.dart             # go_router config + auth redirects
│   └── theme.dart              # Material 3 light/dark themes
├── auth/
│   ├── clerk_service.dart      # Owns long-lived ClerkAuthState, mints Convex JWTs
│   ├── clerk_web_persistor.dart# Web-only session persistence
│   ├── auth_gate.dart          # Sign-in page (ClerkAuth widget)
│   └── auth_state.dart         # AuthNotifier + current-user state
├── convex/
│   ├── convex_client.dart      # Convex client wrapper (query/mutate/subscribe)
│   └── convex_provider.dart    # Riverpod providers for the shared backend
├── providers/
│   ├── providers.dart          # Shared Riverpod providers
│   └── mutations.dart          # Centralised Convex mutation helpers
├── models/                     # Data models (video, note, playlist, ...)
├── screens/                    # Feature screens (videos, notes, play, ...)
├── widgets/                    # Shared widgets (app_shell, error_feedback)
├── utils/                      # color / date / duration helpers
└── i18n/                       # EN + FR translations
```

## Bootstrap Sequence

1. `main()` initialises `ConvexService` (WebSocket to Convex).
2. `_AppBootstrap` creates `ClerkService`, which asynchronously builds a `ClerkAuthState` (the long-lived Clerk session holder).
3. Once `clerk.ready` resolves, `convex.setAuth(() => clerk.getConvexToken())` wires Convex requests to Clerk-issued JWTs.
4. Router mounts. Unauthenticated users are redirected to `/sign-in`, which mounts `ClerkAuth(authState: ...)` using the shared state from step 2.

Because `ClerkAuthState` is owned by the service — not the sign-in widget — the Clerk session survives navigation away from `/sign-in`.

Important: a restored Clerk session is not enough on its own. Flutter now waits for a mintable Convex JWT before sending auth-required bootstrap mutations such as `users:ensureUser`.

## Convex Authentication

`ClerkService.getConvexToken()` calls `authState.sessionToken(templateName: 'convex')` and returns the `.jwt`. This requires:

1. A JWT template named exactly `convex` in the Clerk dashboard (preset: Convex, RS256).
2. `CLERK_JWT_ISSUER_DOMAIN` set on the Convex deployment — value is the Clerk Issuer URL (e.g. `https://clerk.tubeflow.winflowz.com`).
3. `packages/backend/convex/auth.config.ts` declaring the Clerk provider with `applicationID: "convex"`.

No shared secret — verification is RS256 + JWKS.

## Deployment

- **Platform**: Vercel (static build of `build/web/` + `/api/auth/youtube` functions for YouTube OAuth)
- **Build command**: `bash build.sh` (see `vercel.json`)
- **Install command**: clones Flutter `3.41.7` from GitHub into `./flutter/`, runs `pub get`
- **Security headers**: `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy: camera=(), microphone=(), geolocation=()`
- **SPA routing**: all routes rewritten to `/index.html`

If a Flutter change depends on a new Convex function or schema change, deploy the shared backend from `/home/claude/tubeflow/packages/backend` before rolling out the Flutter build. Flutter and the legacy Next app both consume that same production backend contract.

## Tests

Currently no test coverage. Listed as an open task in `TASKS.md`.

Before shipping a Flutter change that depends on backend functions, you can run:

```bash
dart run tool/check_shared_backend_contract.dart
```

This verifies that the critical Convex functions used by Flutter still exist in the shared backend source checkout next to this repo. Use `TUBEFLOW_BACKEND_ROOT=/path/to/packages/backend/convex` if your local layout differs.

## Files

- `TASKS.md` — open work items (audit findings)
- `CHANGELOG.md` — user-facing changes
- `AUDIT_LOG.md` — code audit history
- `CLAUDE.md` — guidance for Claude Code working in this repo
