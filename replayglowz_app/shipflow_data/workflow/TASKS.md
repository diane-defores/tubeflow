# Tasks — ReplayGlowz App

### Audit: Code

#### Critical
- [x] Harden YouTube OAuth helper parsing/origin handling to avoid malformed-cookie crashes and ambiguous forwarded headers

#### High
- [x] Replace `PlayScreen` placeholders with real player/transcript plumbing and implement queue/options actions
- [ ] Retest `BUG-2026-05-10-001`: YouTube connection check must not fall back to an uninitialized Convex client
- [ ] Persist playlist reorder and complete playlist-detail navigation actions
- [ ] Add automated coverage for auth/bootstrap/OAuth critical paths and run it in CI

#### Medium
- [x] Wire no-op taps in Videos/Playlists/Notes screens to actual routes
- [x] Mark OAuth redirects as non-cacheable (`Cache-Control: no-store`)
- [x] Add CSP/HSTS hardening headers in `vercel.json`
- [x] Tighten Dart analyzer settings (`strict-casts`, `strict-inference`, `strict-raw-types`)
- [ ] Verify Clerk + Convex bootstrap and WebSocket startup end-to-end in a real Flutter environment

### Audit: Perf

#### Critical
- [ ] None

#### High
- [x] Defer `convex_bridge.js` and `flutter_bootstrap.js` in `web/index.html` to avoid render-blocking startup work on web.
- [ ] Decide whether Convex web subscriptions should use a less chatty poll strategy than every 10 seconds for all query streams.

#### Medium
- [x] Cache the lowercased search query in `NotesScreen` so filtering does not recompute `toLowerCase()` per row.
