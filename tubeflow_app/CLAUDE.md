---
artifact: agent_guidance
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "tubeflow-app"
created: "2026-04-26"
updated: "2026-04-26"
status: "reviewed"
source_skill: "sf-init"
scope: "agent-guidance"
owner: "Diane"
confidence: "high"
risk_level: "medium"
docs_impact: "yes"
security_impact: "medium"
linked_systems:
  - "Flutter"
  - "Dart"
  - "Riverpod"
  - "go_router"
  - "Firebase Auth"
  - "Convex"
  - "Vercel"
  - "YouTube OAuth"
evidence:
  - "README.md"
  - ".env.example"
  - "pubspec.yaml"
  - "build.sh"
  - "vercel.json"
  - "api/auth/youtube.js"
  - "api/auth/youtube/callback.js"
  - "lib/main.dart"
  - "lib/app/router.dart"
  - "lib/auth/auth_service.dart"
  - "lib/auth/auth_state.dart"
  - "lib/convex/convex_client.dart"
  - "lib/providers/providers.dart"
  - "lib/providers/mutations.dart"
depends_on: []
supersedes:
  - artifact_version: "0.1.0"
next_review: "2026-07-25"
next_step: "Keep this file aligned with AGENT.md and shipflow_data/technical/architecture.md when bootstrap, auth, routing, or deployment changes."
---

# CLAUDE.md

Guidance for coding agents working in `tubeflow-app`, the Flutter web client for ReplayGlowz.

## Project overview

ReplayGlowz App is a Flutter web application for watching YouTube videos, taking timestamped notes, organizing playlists, tracking viewing history, managing preferences, and submitting feedback.

This repository is the client plus Vercel OAuth helper endpoints. The shared Convex backend lives outside this repo at `/home/claude/tubeflow_expo/packages/backend/convex/` by default. Code under `lib/convex/` is client integration, not server code.

## Stack

- Flutter web, Dart SDK `>=3.8.0 <4.0.0`
- Riverpod 3
- `go_router` 17 for auth-aware routing
- Firebase Auth for stable Google sign-in and Firebase ID tokens
- Convex via `convex_flutter`
- Material 3, `youtube_player_flutter`, `record`, `just_audio`, `shared_preferences`, `http`
- Vercel static hosting plus Node serverless functions under `api/auth/`

## Architecture invariants

1. Do not reintroduce beta authentication SDKs. Firebase Auth is the stable auth provider.
2. Authenticated Convex calls use Firebase ID tokens; keep backend `auth.config.ts` aligned with `FIREBASE_PROJECT_ID`.
3. Convex writes should go through `lib/providers/mutations.dart`.
4. Feature reads should prefer typed providers in `lib/providers/providers.dart`.
5. Client and backend function names are a shared contract; verify them before relying on new or renamed Convex functions.
6. Build-time Flutter config is injected through `--dart-define`; server-only secrets stay in Vercel/backend env.

## Bootstrap flow

1. `main()` initializes Flutter bindings and error handlers.
2. `main()` logs config/build metadata from `lib/app/build_info.dart`.
3. `ConvexService.initialize(convexUrl)` runs only when `CONVEX_URL` is non-empty.
4. `_AppBootstrap` initializes Firebase Auth and wires Firebase ID token refresh into Convex.
5. Protected routes redirect to the Firebase sign-in page until a session exists.
7. The app then renders either loading UI, configuration fallback UI, or `ReplayGlowzApp`.

## Routing model

`lib/app/router.dart` defines public and protected routes. `/feedback` and `/feedback/admin` are public. All feature routes under the `ShellRoute` are protected and redirect unauthenticated users to `/sign-in?tf_redirect=...`.

Protected feature routes include `/videos`, `/play`, `/playlists`, playlist detail/create routes, `/notes`, note detail routes, `/notifications`, `/preferences`, `/hidden`, and `/stats`.

## Auth and OAuth model

- `lib/auth/auth_service.dart` is the Firebase-backed auth service.
- `lib/auth/auth_gate.dart` renders Firebase Google sign-in.
- `api/auth/youtube.js` starts Google YouTube OAuth after receiving a Firebase ID token from the app.
- `api/auth/youtube/callback.js` validates state, exchanges the Google code, reuses the Firebase ID token as the Convex JWT, ensures the Convex user, and saves YouTube tokens through Convex mutations.

## Environment variables

Flutter build-time variables:

- `CONVEX_URL`
- `FIREBASE_API_KEY`
- `FIREBASE_AUTH_DOMAIN`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_STORAGE_BUCKET`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_APP_ID`
- `REPLAYGLOWZ_APP_URL`
- `BUILD_COMMIT_SHA`
- `BUILD_ENVIRONMENT`
- `BUILD_TIMESTAMP`

Serverless/OAuth variables:

- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`

Backend-only variables documented in `README.md`, such as `FEEDBACK_ADMIN_EMAILS`, belong on the Convex deployment, not in Flutter `--dart-define`.

## Common commands

```bash
flutter pub get
flutter run -d chrome --dart-define=CONVEX_URL=... --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_PROJECT_ID=... --dart-define=FIREBASE_MESSAGING_SENDER_ID=... --dart-define=FIREBASE_APP_ID=... --dart-define=REPLAYGLOWZ_APP_URL=...
dart analyze lib/
bash build.sh
dart run tool/check_shared_backend_contract.dart
dart run build_runner build --delete-conflicting-outputs
```

## Working rules

- Do not hardcode secrets, live API keys, or production-only config in source.
- Do not treat generated or committed files as disposable without checking project convention.
- Keep public setup docs separate from product/business docs.
- When changing providers or mutations, update the shared backend first or coordinate a same-window deployment.
- When changing auth, verify Firebase state ownership and Convex token readiness assumptions.
- When changing deployment or OAuth, inspect `build.sh`, `vercel.json`, `.env.example`, and `api/auth/**` together.

## Known gotchas

- Flutter web bakes `--dart-define` values into the built JS bundle.
- Missing Convex/Firebase config leads to skipped wiring and configuration fallback behavior, not runtime env recovery.
- Some providers intentionally use local defaults/fallbacks when auth or backend functions are unavailable; this can hide backend drift during development.
- The YouTube OAuth callback depends on Vercel cookies, Firebase ID token handoff, Google token exchange, and Convex mutation auth all succeeding in sequence.
