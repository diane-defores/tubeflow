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
  - "Clerk"
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
  - "lib/auth/clerk_service.dart"
  - "lib/auth/auth_state.dart"
  - "lib/convex/convex_client.dart"
  - "lib/providers/providers.dart"
  - "lib/providers/mutations.dart"
depends_on: []
supersedes:
  - artifact_version: "0.1.0"
next_review: "2026-07-25"
next_step: "Keep this file aligned with AGENT.md and ARCHITECTURE.md when bootstrap, auth, routing, or deployment changes."
---

# CLAUDE.md

Guidance for coding agents working in `tubeflow-app`, the Flutter web client for TubeFlow.

## Project overview

TubeFlow App is a Flutter web application for watching YouTube videos, taking timestamped notes, organizing playlists, tracking viewing history, managing preferences, and submitting feedback.

This repository is the client plus Vercel OAuth helper endpoints. The shared Convex backend lives outside this repo at `/home/claude/tubeflow/packages/backend/convex/` by default. Code under `lib/convex/` is client integration, not server code.

## Stack

- Flutter web, Dart SDK `>=3.8.0 <4.0.0`
- Riverpod 3 with `riverpod_generator`
- `go_router` 17 for auth-aware routing
- Clerk via `clerk_flutter` and `clerk_auth`
- Convex via `convex_flutter`
- Material 3, `youtube_player_flutter`, `record`, `just_audio`, `shared_preferences`, `http`
- Vercel static hosting plus Node serverless functions under `api/auth/`

## Architecture invariants

1. `ClerkService` owns the long-lived `ClerkAuthState`; feature widgets must not create competing Clerk auth owners.
2. `getConvexToken()` uses Clerk session token template `convex` and must fail soft by returning `null` when token minting is unavailable.
3. Convex writes should go through `lib/providers/mutations.dart`.
4. Feature reads should prefer typed providers in `lib/providers/providers.dart`.
5. Client and backend function names are a shared contract; verify them before relying on new or renamed Convex functions.
6. Build-time Flutter config is injected through `--dart-define`; server-only secrets stay in Vercel/backend env.

## Bootstrap flow

1. `main()` initializes Flutter bindings and error handlers.
2. `main()` logs config/build metadata from `lib/app/build_info.dart`.
3. `ConvexService.initialize(convexUrl)` runs only when `CONVEX_URL` is non-empty.
4. `_AppBootstrap` waits for `clerkServiceProvider.ready` when Convex and Clerk config are present.
5. `_AppBootstrap` wires `convex.setAuth(() => clerk.getConvexToken())`.
6. If a Clerk session already exists, bootstrap waits for `clerk.waitForConvexTokenReady()` before auth-required flows depend on Convex auth.
7. The app then renders either loading UI, configuration fallback UI, or `TubeFlowApp`.

## Routing model

`lib/app/router.dart` defines public and protected routes. `/feedback` and `/feedback/admin` are public. All feature routes under the `ShellRoute` are protected and redirect unauthenticated users to `/sign-in?tf_redirect=...`.

Protected feature routes include `/videos`, `/play`, `/playlists`, playlist detail/create routes, `/notes`, note detail routes, `/notifications`, `/preferences`, `/hidden`, and `/stats`.

## Auth and OAuth model

- `lib/auth/clerk_service.dart` initializes Clerk, handles web OAuth redirects, restores web sessions, mirrors state into `AuthNotifier`, and mints Convex JWTs.
- `lib/auth/auth_gate.dart` renders sign-in using the shared Clerk state.
- `api/auth/youtube.js` starts Google YouTube OAuth, stores state/return cookies, and redirects to Google.
- `api/auth/youtube/callback.js` validates state, exchanges the Google code, mints a Clerk `convex` JWT using `CLERK_SECRET_KEY`, ensures the Convex user, and saves YouTube tokens through Convex mutations.

## Environment variables

Flutter build-time variables:

- `CONVEX_URL`
- `CLERK_PUBLISHABLE_KEY`
- `TUBEFLOW_APP_URL`
- `CLERK_HOSTED_SIGN_IN_URL`
- `BUILD_COMMIT_SHA`
- `BUILD_ENVIRONMENT`
- `BUILD_TIMESTAMP`

Serverless/OAuth variables:

- `CLERK_SECRET_KEY`
- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`

Backend-only variables documented in `README.md`, such as `FEEDBACK_ADMIN_EMAILS`, belong on the Convex deployment, not in Flutter `--dart-define`.

## Common commands

```bash
flutter pub get
flutter run -d chrome --dart-define=CONVEX_URL=... --dart-define=CLERK_PUBLISHABLE_KEY=... --dart-define=TUBEFLOW_APP_URL=...
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
- When changing auth, verify both Flutter Clerk state ownership and Convex token readiness assumptions.
- When changing deployment or OAuth, inspect `build.sh`, `vercel.json`, `.env.example`, and `api/auth/**` together.

## Known gotchas

- Flutter web bakes `--dart-define` values into the built JS bundle.
- Missing Convex/Clerk config leads to skipped wiring and configuration fallback behavior, not runtime env recovery.
- Some providers intentionally use local defaults/fallbacks when auth or backend functions are unavailable; this can hide backend drift during development.
- The YouTube OAuth callback depends on Vercel cookies, Clerk server API access, Google token exchange, and Convex mutation auth all succeeding in sequence.
