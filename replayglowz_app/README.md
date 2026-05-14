# ReplayGlowz App

Flutter app for watching YouTube videos, taking timestamped notes, and tracking viewing history. Built for web deployment on Vercel, backed by Convex and authenticated via Firebase Auth.

## Quick Start

```bash
flutter pub get

# Run locally (web)
flutter run -d chrome \
  --dart-define=CONVEX_URL=https://your-deployment.convex.cloud \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=REPLAYGLOWZ_APP_URL=https://app.replayglowz.com

# Production build
CONVEX_URL=... FIREBASE_API_KEY=... FIREBASE_PROJECT_ID=... FIREBASE_MESSAGING_SENDER_ID=... FIREBASE_APP_ID=... REPLAYGLOWZ_APP_URL=https://app.replayglowz.com bash build.sh
```

The `build.sh` script wraps `flutter build web` and passes the required `--dart-define` values. Vercel runs it via `vercel.json`.

## Environment Variables

The Flutter values are required at **build time** (`--dart-define`), not runtime. Flutter web bakes them into the compiled JS bundle. The OAuth handler values are runtime environment variables for Vercel functions.

| Variable | Purpose |
|---|---|
| `CONVEX_URL` | Convex deployment URL (e.g. `https://xxx.convex.cloud`). App fails explicitly when missing. |
| `FIREBASE_API_KEY` | Firebase web API key used by `firebase_core`. |
| `FIREBASE_AUTH_DOMAIN` | Optional Firebase auth domain, usually `your-project.firebaseapp.com`. |
| `FIREBASE_PROJECT_ID` | Firebase project ID. Also required by the Convex backend auth config. |
| `FIREBASE_STORAGE_BUCKET` | Optional Firebase storage bucket. |
| `FIREBASE_MESSAGING_SENDER_ID` | Firebase web messaging sender ID. |
| `FIREBASE_APP_ID` | Firebase web app ID. |
| `REPLAYGLOWZ_APP_URL` | Web app origin used for the YouTube OAuth callback URLs (current deployment: `https://app.replayglowz.com`). |
| `BUILD_COMMIT_SHA` | Optional build metadata shown in diagnostics. Defaults to `VERCEL_GIT_COMMIT_SHA` or the local Git short SHA in `build.sh`. |
| `BUILD_ENVIRONMENT` | Optional build metadata shown in diagnostics. Defaults to `VERCEL_ENV` or `local` in `build.sh`. |
| `BUILD_TIMESTAMP` | Optional build metadata shown in diagnostics. Defaults to the current UTC timestamp in `build.sh`. |
| `SENTRY_DSN` | Optional Sentry DSN for Flutter error capture. When missing, Sentry stays disabled. |
| `SENTRY_ENVIRONMENT` | Optional Sentry environment. Defaults to `BUILD_ENVIRONMENT` in `build.sh`. |
| `SENTRY_RELEASE` | Optional Sentry release. Defaults to `replayglowz_app@BUILD_COMMIT_SHA` in `build.sh`. |
| `SENTRY_TRACES_SAMPLE_RATE` | Optional Sentry performance tracing sample rate. Defaults to `0` (off). |
| `GOOGLE_CLIENT_ID` | Google OAuth client ID used for the YouTube consent screen. |
| `GOOGLE_CLIENT_SECRET` | Google OAuth client secret used to exchange the YouTube authorization code for tokens. |

See `.env.example`. Preferred names are the plain variables above; `build.sh` also accepts the legacy Vercel-style `NEXT_PUBLIC_CONVEX_URL` plus the older `TUBEFLOW_APP_URL` and `TUBEFLOW_WEB_URL` as compatibility fallbacks. The OAuth handlers also accept `NEXT_PUBLIC_APP_URL` and `NEXT_PUBLIC_GOOGLE_CLIENT_ID` as compatibility fallbacks.

Convex deployment variables used by backend features:

| Variable | Purpose |
|---|---|
| `FEEDBACK_ADMIN_EMAILS` | Comma-separated allowlist of admin emails allowed to open the in-app feedback admin screen. Set on the Convex deployment, not in Flutter `--dart-define`. |

## Tech Stack

- **Flutter 3.41.7 / Dart 3.11.5** — web target
- **Riverpod 3** — state management (`flutter_riverpod`)
- **go_router 17** — routing with auth-aware redirects
- **Firebase Auth** (`firebase_auth`) — stable Google sign-in provider and ID token source for Convex auth
- **Convex** (`convex_flutter 3.0.1`) — backend queries / mutations / subscriptions
- **youtube_player_flutter** — video playback
- **Material 3** — theming (light / dark / system)
- **record + just_audio** — feedback audio capture and playback

Convex backend lives in a **separate repository** at `/home/claude/tubeflow_expo/packages/backend/convex/` — not in this project. This Flutter app is a client of that shared backend. The code under `lib/convex/` is client transport/state only, not server code.

## Project Structure

```
lib/
├── main.dart                   # Entry point + bootstrap sequence
├── app/
│   ├── router.dart             # go_router config + auth redirects
│   └── theme.dart              # Material 3 light/dark themes
├── auth/
│   ├── firebase_config.dart    # Firebase web dart-define configuration
│   ├── auth_service.dart       # Firebase-backed auth service
│   ├── auth_gate.dart          # Firebase Google sign-in page
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
2. `_AppBootstrap` initializes Firebase Auth and wires Firebase ID token refresh into the Convex client.
3. Router mounts. Protected routes redirect to `/sign-in` until Firebase restores or creates a session.

## Convex Authentication

Convex now trusts Firebase ID tokens directly. The backend `convex/auth.config.ts` must use:

1. `domain: https://securetoken.google.com/<FIREBASE_PROJECT_ID>`
2. `applicationID: <FIREBASE_PROJECT_ID>`

No shared secret is used; verification is through Firebase's public token issuer metadata.

## Deployment

- **Platform**: Vercel (static build of `build/web/` + `/api/auth/youtube` functions for YouTube OAuth)
- **Build command**: `bash build.sh` (see `vercel.json`)
- **Install command**: clones Flutter `3.41.7` from GitHub into `./flutter/`, runs `pub get`
- **Security headers**: `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy: camera=(), microphone=(), geolocation=()`
- **SPA routing**: all routes rewritten to `/index.html`

If a Flutter change depends on a new Convex function or schema change, deploy the shared backend from `/home/claude/tubeflow_expo/packages/backend` before rolling out the Flutter build.

## Tests

Currently no test coverage. Listed as an open task in `shipflow_data/workflow/TASKS.md`.

Before shipping a Flutter change that depends on backend functions, you can run:

```bash
dart run tool/check_shared_backend_contract.dart
```

This verifies that the critical Convex functions used by Flutter still exist in the shared backend source checkout next to this repo. Use `REPLAYGLOWZ_BACKEND_ROOT=/path/to/packages/backend/convex` if your local layout differs.

## Files

- `shipflow_data/workflow/TASKS.md` — open work items (audit findings)
- `CHANGELOG.md` — user-facing changes
- `shipflow_data/workflow/AUDIT_LOG.md` — code audit history
- `CLAUDE.md` — guidance for Claude Code working in this repo
