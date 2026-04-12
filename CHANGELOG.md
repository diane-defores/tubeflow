# Changelog

All notable changes to this project will be documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [2026-04-12]

### Changed
- `build.sh`: read env vars directly as `CONVEX_URL` / `CLERK_PUBLISHABLE_KEY` (removed `NEXT_PUBLIC_*` fallbacks) — matches cleaned-up Doppler/Vercel variable names post-Next/Expo migration

## [2026-04-07]

### Added
- `mutations.dart`: 7 new helpers — `updateNote`, `hidePlaylist`, `unhideItem`, `upsertProgress`, `syncAllPlaylists`, `syncPlaylist`, `removeVideoFromPlaylist`
- `mutations.dart`: `updateSettings` now accepts a raw `Map<String, dynamic>` patch for flexible partial updates
- Security headers in `vercel.json` (X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy)
- Shared `color_utils.dart` with `parseHexColor()` extracted from duplicate screen implementations
- `.env.example` documenting required environment variables
- `AUDIT_LOG.md` tracking audit findings and resolutions

### Changed
- All screens now route Convex mutations through `mutations.dart` helpers — no screen imports `convex_provider.dart` directly for mutations
- `createPlaylist` helper updated to match actual backend endpoint (`playlists:createPlaylist`) with `title`, `color`, `privacyStatus` args
- `pubspec.lock` removed from `.gitignore` (must be committed for reproducible builds)
- Router wired to actual screen widgets (was using `_Placeholder` for all routes)
- `main.dart` surfaces bootstrap failures to user instead of swallowing them silently

### Fixed
- App no longer silently uses a placeholder Convex URL when `CONVEX_URL` is not set — fails explicitly with a clear error
