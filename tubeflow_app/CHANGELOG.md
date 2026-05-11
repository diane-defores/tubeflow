# Changelog

All notable changes to this project will be documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [2026-05-10]

### Changed
- Pinned the Vercel and Android CI Flutter toolchains to Flutter 3.41.7.
- Removed unused `flutter_slidable` and `google_fonts` dependencies after usage verification.
- Documented the pinned Flutter/Dart toolchain in the app README.

## [2026-04-19]

### Added
- In-app feedback submission flow with text and audio support, anonymous fallback, and dedicated Flutter screens/services for creation and admin review
- Admin-only feedback inbox in Preferences with filters, audio playback, metadata, and mark-as-reviewed actions
- `FEEDBACK_ADMIN_EMAILS` deployment variable documentation for the Convex-backed feedback admin allowlist

### Changed
- Router/auth flow now keeps `/feedback` publicly reachable while exposing the admin screen only to allowlisted users
- Flutter feedback submissions now depend on Convex-backed providers/mutations instead of a local-only draft flow
- Web deployment now allows microphone access via `Permissions-Policy` so browser audio feedback recording works in production

## [2026-04-18]

### Fixed
- Restored compatibility with legacy Vercel env names: `build.sh` now falls back to `NEXT_PUBLIC_CONVEX_URL` / `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`, and Clerk bootstrap accepts the legacy publishable-key `dart-define` so sign-in buttons still render on older deployments

## [2026-04-12]

### Changed
- `build.sh`: read env vars directly as `CONVEX_URL` / `CLERK_PUBLISHABLE_KEY` (removed `NEXT_PUBLIC_*` fallbacks) — matches cleaned-up Doppler/Vercel variable names post-Next/Expo migration
- Clerk auth bootstrap now owns a shared `ClerkAuthState`, waits for service readiness before wiring Convex auth, and keeps the session available outside the sign-in route
- Screen-level error handling is consolidated through `widgets/error_feedback.dart` with copyable error messages and consistent retry actions across the app

### Fixed
- `ClerkService.getConvexToken()` now mints the Clerk `convex` JWT template instead of returning `null`, so authenticated Convex calls no longer run as guests
- Convex queries, mutations, actions, and subscriptions now wait for the WebSocket connection before sending requests, avoiding startup failures such as `bad state: web socket not connected` on the videos screen
- Flutter web no longer crashes during Clerk bootstrap (`MissingPluginException(getApplicationDocumentsDirectory)`): Clerk now uses a SharedPreferences-backed persistor on web instead of `path_provider`

## [2026-04-07]

### Added
- `mutations.dart`: 7 new helpers — `updateNote`, `hidePlaylist`, `unhideItem`, `upsertProgress`, `syncAllPlaylists`, `syncPlaylist`, `removeVideoFromPlaylist`
- `mutations.dart`: `updateSettings` now accepts a raw `Map<String, dynamic>` patch for flexible partial updates
- Security headers in `vercel.json` (X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy)
- Shared `color_utils.dart` with `parseHexColor()` extracted from duplicate screen implementations
- `.env.example` documenting required environment variables
- `shipflow_data/workflow/AUDIT_LOG.md` tracking audit findings and resolutions

### Changed
- All screens now route Convex mutations through `mutations.dart` helpers — no screen imports `convex_provider.dart` directly for mutations
- `createPlaylist` helper updated to match actual backend endpoint (`playlists:createPlaylist`) with `title`, `color`, `privacyStatus` args
- `pubspec.lock` removed from `.gitignore` (must be committed for reproducible builds)
- Router wired to actual screen widgets (was using `_Placeholder` for all routes)
- `main.dart` surfaces bootstrap failures to user instead of swallowing them silently

### Fixed
- App no longer silently uses a placeholder Convex URL when `CONVEX_URL` is not set — fails explicitly with a clear error
