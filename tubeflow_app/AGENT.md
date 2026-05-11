---
artifact: documentation
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "tubeflow-app"
created: "2026-04-26"
updated: "2026-04-26"
status: "reviewed"
source_skill: sf-docs
scope: "file"
owner: "Diane"
confidence: "high"
risk_level: "medium"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "Flutter"
  - "Clerk"
  - "Convex"
  - "Vercel"
  - "YouTube OAuth"
depends_on:
  - "README.md"
  - "CLAUDE.md"
  - "shipflow_data/technical/architecture.md"
supersedes:
  - artifact_version: "0.1.0"
evidence:
  - "README.md"
  - ".env.example"
  - "pubspec.yaml"
  - "build.sh"
  - "vercel.json"
  - "api/auth/_youtube.js"
  - "api/auth/youtube.js"
  - "api/auth/youtube/callback.js"
  - "lib/main.dart"
  - "lib/app/router.dart"
  - "lib/auth/clerk_service.dart"
  - "lib/auth/auth_state.dart"
  - "lib/convex/convex_client.dart"
  - "lib/convex/convex_provider.dart"
  - "lib/providers/providers.dart"
  - "lib/providers/mutations.dart"
  - "tool/check_shared_backend_contract.dart"
next_step: "Run dart run tool/check_shared_backend_contract.dart before client changes that depend on backend functions."
---

# AGENT

Operational guide for agents working in `tubeflow-app`.

## Repository role

`tubeflow-app` is a Flutter web client. It renders the TubeFlow UI, restores Clerk sessions, obtains Clerk-minted Convex JWTs, calls a shared Convex backend, and deploys as a Vercel static build with a small YouTube OAuth API under `api/auth/`.

This repository is not the Convex backend source of truth. The shared backend is expected next to this checkout at `/home/claude/tubeflow/packages/backend/convex/`, unless `TUBEFLOW_BACKEND_ROOT` points elsewhere.

## Non-negotiable boundaries

- Keep backend schema and server functions out of this repo.
- Treat `lib/convex/` as client transport and provider wiring only.
- Do not hardcode real origins, secrets, tokens, or deployment URLs in Dart or docs.
- Use `String.fromEnvironment(...)`-backed build-time config for Flutter web values.
- Keep the Clerk JWT template name `convex` aligned with Convex backend auth config.
- Coordinate backend deployment before shipping Flutter calls to new Convex functions.

## Runtime flow

1. `main()` installs Flutter/platform error logging and logs build/config metadata.
2. If `CONVEX_URL` is present, `ConvexService.initialize(convexUrl)` creates the process-wide Convex client.
3. `_AppBootstrap` reads `clerkServiceProvider` and waits for `clerk.ready`.
4. When both Convex and Clerk config exist, bootstrap wires `convex.setAuth(() => clerk.getConvexToken())`.
5. If a user is already authenticated, bootstrap waits for a mintable Convex token before auth-required startup providers fully engage.
6. `routerProvider` redirects unauthenticated protected routes to `/sign-in` with `tf_redirect`.

## Source-of-truth files

- `lib/main.dart`: application bootstrap and configuration fallback UI.
- `lib/app/router.dart`: route constants, redirects, public routes, and protected shell.
- `lib/auth/clerk_service.dart`: long-lived Clerk lifecycle, web session restoration, OAuth callback handling, Convex token minting.
- `lib/auth/auth_state.dart`: app-local auth state consumed by routing and UI.
- `lib/convex/convex_client.dart`: Convex singleton wrapper for query, mutation, action, subscription, auth, and web HTTP bridge fallback.
- `lib/providers/providers.dart`: typed Riverpod read providers and local fallback behavior.
- `lib/providers/mutations.dart`: expected write boundary for screens.
- `api/auth/youtube.js` and `api/auth/youtube/callback.js`: Vercel YouTube OAuth start and callback handlers.
- `tool/check_shared_backend_contract.dart`: local contract check against the shared Convex backend checkout.

## Route map

Public routes:

- `/sign-in`
- `/feedback`
- `/feedback/admin`

Protected shell routes:

- `/videos`
- `/play`
- `/playlists`
- `/playlists/create`
- `/playlists/:id`
- `/notes`
- `/notes/:slug`
- `/notifications`
- `/preferences`
- `/hidden`
- `/stats`

## Environment contract

Flutter build-time values:

- `CONVEX_URL`: Convex deployment URL. Missing value skips Convex initialization and triggers configuration fallback behavior.
- `CLERK_PUBLISHABLE_KEY`: Clerk publishable key. Missing value skips Clerk/Convex auth wiring.
- `TUBEFLOW_APP_URL`: app origin used for OAuth callback/origin handling.
- `CLERK_HOSTED_SIGN_IN_URL`: optional hosted sign-in URL passed through `build.sh`.
- `BUILD_COMMIT_SHA`, `BUILD_ENVIRONMENT`, `BUILD_TIMESTAMP`: build metadata injected by `build.sh`.
- `SENTRY_DSN`: optional Sentry DSN. Missing value leaves Sentry disabled.
- `SENTRY_ENVIRONMENT`, `SENTRY_RELEASE`, `SENTRY_TRACES_SAMPLE_RATE`: optional Sentry metadata/tuning values injected by `build.sh`.

Vercel serverless/OAuth values:

- `CLERK_SECRET_KEY`: used by `api/auth/youtube/callback.js` to mint a Clerk `convex` JWT for the current session.
- `GOOGLE_CLIENT_ID`: Google OAuth client ID for YouTube consent.
- `GOOGLE_CLIENT_SECRET`: exchanged with Google authorization codes in the callback.

Compatibility fallbacks currently exist for `NEXT_PUBLIC_CONVEX_URL`, `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`, `NEXT_PUBLIC_APP_URL`, `NEXT_PUBLIC_GOOGLE_CLIENT_ID`, and `TUBEFLOW_WEB_URL`.

## Safe change patterns

- UI/navigation: edit `lib/screens/**`, `lib/widgets/**`, and, when needed, `lib/app/router.dart`.
- Reads: add or tighten typed providers in `lib/providers/providers.dart`.
- Writes: add helpers in `lib/providers/mutations.dart`; avoid ad hoc screen-level Convex writes.
- Auth/session: inspect `lib/auth/clerk_service.dart`, `lib/auth/auth_state.dart`, and web bridge/persistor files first.
- Convex transport: inspect `lib/convex/convex_client.dart` and `lib/convex/convex_provider.dart`.
- Deployment/OAuth: inspect `build.sh`, `vercel.json`, `.env.example`, and `api/auth/**`.

## Commands

```bash
flutter pub get
flutter run -d chrome --dart-define=CONVEX_URL=... --dart-define=CLERK_PUBLISHABLE_KEY=... --dart-define=TUBEFLOW_APP_URL=...
dart analyze lib/
bash build.sh
dart run tool/check_shared_backend_contract.dart
dart run build_runner build --delete-conflicting-outputs
```

## Risk areas

- Clerk web persistence and OAuth redirect restoration.
- Convex JWT minting with template `convex`.
- Shared backend function drift, especially provider and mutation path names.
- Silent local fallbacks hiding missing backend functions during bootstrap.
- Vercel OAuth cookies, return URL sanitization, and deployment env mismatch.
