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
  - "Riverpod"
  - "go_router"
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
  - "lib/app/build_info.dart"
  - "lib/app/router.dart"
  - "lib/auth/clerk_service.dart"
  - "lib/auth/auth_state.dart"
  - "lib/convex/convex_client.dart"
  - "lib/convex/convex_provider.dart"
  - "lib/providers/providers.dart"
  - "lib/providers/mutations.dart"
  - "lib/widgets/app_shell.dart"
  - "tool/check_shared_backend_contract.dart"
next_step: "Revisit after route, provider, auth, or deployment changes."
---

# CONTEXT

## Project summary

`tubeflow-app` is a Flutter web application deployed to Vercel. It lets users browse synced YouTube videos and playlists, watch videos, take timestamped notes, track watch progress, manage preferences, view notifications/stats/hidden items, and submit feedback. Authentication is handled by Clerk. App data and live updates are handled by a shared Convex backend.

The repo also contains Vercel Node handlers for YouTube OAuth under `api/auth/`. Convex schema and server functions are not in this repo.

## Stack

- Flutter web with Dart SDK `>=3.8.0 <4.0.0`
- Riverpod 3 with code generation
- `go_router` 17
- Clerk (`clerk_flutter`, `clerk_auth`)
- Convex (`convex_flutter`)
- Material 3
- `youtube_player_flutter`, `record`, `just_audio`, `shared_preferences`, `http`, `url_launcher`
- Vercel static hosting and Node serverless functions

## Top-level code map

- `lib/main.dart`: app bootstrap, error logging, Convex initialization, Clerk/Convex auth wiring, config fallback UI.
- `lib/app/`: router, theme, build info helpers.
- `lib/auth/`: Clerk lifecycle, app auth state, sign-in gate, web bridge, session persistence.
- `lib/convex/`: Convex service wrapper, generic providers, error helpers, web bridge fallback.
- `lib/providers/`: typed read providers and centralized mutation/action helpers.
- `lib/models/`: domain models for videos, notes, playlists, settings, subscriptions, notifications, feedback, hidden/watched/progress records.
- `lib/screens/`: feature screens.
- `lib/widgets/`: app shell, shared actions, error feedback, YouTube connection/OAuth banners.
- `lib/i18n/`: English and French translations.
- `api/auth/`: YouTube OAuth start/callback handlers and shared helper functions.
- `tool/`: maintenance scripts.

## User-facing feature areas

- Videos feed: `VideosScreen`
- Playback: `PlayScreen`
- Playlists: list, detail, create, sync, remove video
- Notes: list, detail, create/update/delete through mutation helpers
- Notifications and unread count
- Preferences/settings and subscription-derived data
- Hidden items and watched/progress state
- Stats and quota usage
- Feedback text/audio submission and feedback admin
- YouTube account connection through Vercel OAuth handlers

## Runtime entrypoints

- `main()` sets Flutter and platform error handlers, logs build/config state, initializes Convex when configured, and mounts `ProviderScope`.
- `_AppBootstrap` waits for Clerk readiness, wires Convex auth, waits for Convex token readiness for restored sessions, then renders the app or fallback UI.
- `routerProvider` enforces auth-aware redirects and builds the public/protected route graph.
- `ReplayGlowzApp` uses `MaterialApp.router` with light/dark/system theme support.

## Auth and session model

- `ClerkService` owns the long-lived `ClerkAuthState`.
- `AuthNotifier` exposes app-local states consumed by router/UI: loading, authenticated, unauthenticated.
- On web, Clerk startup includes bridge initialization, OAuth callback handling, and persisted session restoration.
- Convex tokens are minted from Clerk session tokens using template name `convex`.
- Authenticated bootstrap waits for a mintable Convex token before relying on auth-required backend work.

## Data access model

- `ConvexService` wraps query, mutation, action, subscription, auth refresh, and connection waiting.
- Web calls can attempt an HTTP bridge and fall back to the Convex WebSocket client.
- Typed Riverpod providers convert raw backend payloads into Dart models.
- Mutation helpers in `lib/providers/mutations.dart` are the expected write boundary for screens.
- Several providers provide local defaults or empty fallbacks when auth is not ready or optional backend functions are missing.

## Shared backend contract

- This repo depends on Convex functions defined in `/home/claude/tubeflow/packages/backend/convex/` by default.
- `tool/check_shared_backend_contract.dart` checks critical functions such as `users:ensureUser`, `users:getCurrentUser`, `settings:getSettings`, `subscriptions:getSubscription`, YouTube connection status, feedback admin, and notifications.
- Set `TUBEFLOW_BACKEND_ROOT` when the backend checkout is elsewhere.
- Flutter and any other clients consuming the same backend must coordinate schema/function changes.

## Deployment model

- Vercel install command clones Flutter stable into `./flutter/` and runs `flutter/bin/flutter pub get`.
- Vercel build command is `bash build.sh`.
- Build output is `build/web`.
- `vercel.json` rewrites all paths to `/index.html` for SPA routing.
- Security headers include frame denial, `nosniff`, strict referrer policy, and a constrained permissions policy with microphone allowed for same-origin feedback recording.
- `build.sh` injects app config and build metadata through `--dart-define`.

## Environment contract

Flutter build-time:

- `CONVEX_URL`
- `CLERK_PUBLISHABLE_KEY`
- `REPLAYGLOWZ_APP_URL`
- `CLERK_HOSTED_SIGN_IN_URL`
- `BUILD_COMMIT_SHA`
- `BUILD_ENVIRONMENT`
- `BUILD_TIMESTAMP`

Vercel OAuth/serverless:

- `CLERK_SECRET_KEY`
- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`

Compatibility fallbacks still exist for selected legacy Vercel-style names in `build.sh` and `api/auth/**`.

## Documentation confidence

High confidence on bootstrap, routing, auth ownership, Convex integration, build/deployment, YouTube OAuth handler responsibilities, and provider/mutation boundaries. Feature behavior is documented at module level, not as a full product walkthrough.
