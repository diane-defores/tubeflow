---
artifact: technical_guidelines
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "tubeflow-app"
created: "2026-04-26"
updated: "2026-04-26"
status: "reviewed"
source_skill: "sf-init"
scope: "guidelines"
owner: "Diane"
confidence: "high"
risk_level: "medium"
docs_impact: "yes"
security_impact: "medium"
linked_systems:
  - "Flutter"
  - "Riverpod"
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
  - "api/auth/_youtube.js"
  - "api/auth/youtube.js"
  - "api/auth/youtube/callback.js"
  - "lib/main.dart"
  - "lib/app/router.dart"
  - "lib/auth/clerk_service.dart"
  - "lib/convex/convex_client.dart"
  - "lib/providers/providers.dart"
  - "lib/providers/mutations.dart"
depends_on:
  - artifact: "CLAUDE.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes:
  - artifact_version: "0.1.0"
next_review: "2026-07-25"
next_step: "Update when auth ownership, provider boundaries, env names, or deployment flow changes."
---

# Guidelines — tubeflow-app

## Technical stack

- Flutter web client written in Dart.
- Riverpod 3 for state management and generated providers.
- `go_router` for routing and auth redirects.
- Clerk for authentication and web session restoration.
- Convex for queries, mutations, actions, subscriptions, and JWT-authenticated data access.
- Vercel for static hosting, SPA routing, security headers, and YouTube OAuth serverless endpoints.

## Code conventions

- Read Flutter build-time config through `String.fromEnvironment(...)` helpers, not runtime env access.
- Keep authentication state centralized in `ClerkService` and mirrored through `AuthNotifier`.
- Do not instantiate a second independent `ClerkAuthState` in screens or route widgets.
- Keep `ClerkService.getConvexToken()` non-throwing from caller perspective.
- Route write operations through `lib/providers/mutations.dart` unless there is a documented reason not to.
- Prefer typed Riverpod providers in `lib/providers/providers.dart` for screen-level reads.
- Treat `lib/convex/` as client transport and provider plumbing only.
- Preserve local fallback behavior intentionally; do not add silent fallbacks that mask security or data-loss errors.

## Project structure

- `lib/main.dart`: app entry, error hooks, Convex init, Clerk/Convex bootstrap, config fallback UI.
- `lib/app/`: router, theme, build metadata helpers.
- `lib/auth/`: Clerk integration, auth state, web bridge, session persistence, sign-in gate.
- `lib/convex/`: Convex service wrapper, web bridge, generic provider helpers, error classification.
- `lib/providers/`: typed reads and centralized mutation/action helpers.
- `lib/screens/`: feature screens for videos, playback, playlists, notes, notifications, preferences, hidden items, stats, and feedback.
- `lib/widgets/`: shell, navigation, OAuth/connect banners, shared UI.
- `lib/models/`: app/domain data models and JSON decoding.
- `lib/i18n/`: English and French translations.
- `api/auth/`: Vercel Node handlers for YouTube OAuth.
- `tool/`: local maintenance scripts such as the shared backend contract check.

## Environment and secrets

- Never commit real secrets, live API keys, user tokens, or deployment-only credentials.
- Use reserved placeholders such as `example.com`, `pk_test_your_clerk_publishable_key`, and `sk_test_your_clerk_secret_key`.
- Distinguish Flutter build-time config from Vercel serverless secrets and Convex backend env.
- Keep `CONVEX_URL`, `CLERK_PUBLISHABLE_KEY`, and `TUBEFLOW_APP_URL` documented as build-time values.
- Keep `CLERK_SECRET_KEY`, `GOOGLE_CLIENT_ID`, and `GOOGLE_CLIENT_SECRET` documented as serverless OAuth values.
- Keep backend-only variables, including `FEEDBACK_ADMIN_EMAILS`, out of Flutter build config.

## Cross-repository rules

- The Convex schema and server functions live in the shared backend repo, not here.
- If Flutter starts calling a new Convex function, deploy or coordinate the backend change first.
- Use `dart run tool/check_shared_backend_contract.dart` for critical function-name drift checks.
- Set `TUBEFLOW_BACKEND_ROOT` when the shared backend checkout is not at `../tubeflow/packages/backend/convex`.
- Keep Clerk/Convex auth contract details aligned: Clerk JWT template `convex`, backend provider `applicationID: "convex"`, and trusted Clerk issuer domain.

## Deployment conventions

- Vercel runs `bash build.sh` and serves `build/web`.
- `build.sh` passes Flutter `--dart-define` values and accepts documented legacy fallbacks.
- `vercel.json` rewrites all paths to `/index.html` for SPA routing.
- Security headers are configured in `vercel.json`; current microphone permission is `microphone=(self)` because feedback audio capture is part of the app.
- YouTube OAuth handlers must keep return targets sanitized and state cookies short-lived.

## Documentation conventions

- Technical docs should be factual, repo-backed, and clear about client/backend boundaries.
- Product/business documents are outside this technical-doc maintenance scope.
- If a claim cannot be inferred from repo files, leave it as a question instead of presenting it as fact.
- Keep English as the primary documentation language unless a file is explicitly localized.
