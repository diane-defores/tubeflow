# Tasks — TubeFlow App

### Audit: Code

#### Critical
- [x] Harden YouTube OAuth helper parsing/origin handling to avoid malformed-cookie crashes and ambiguous forwarded headers

#### High
- [x] Replace `PlayScreen` placeholders with real player/transcript plumbing and implement queue/options actions
- [ ] Persist playlist reorder and complete playlist-detail navigation actions
- [ ] Add automated coverage for auth/bootstrap/OAuth critical paths and run it in CI

#### Medium
- [x] Wire no-op taps in Videos/Playlists/Notes screens to actual routes
- [x] Mark OAuth redirects as non-cacheable (`Cache-Control: no-store`)
- [ ] Add CSP/HSTS hardening headers in `vercel.json`
- [ ] Tighten Dart analyzer settings (`strict-casts`, `strict-inference`, `strict-raw-types`)
- [ ] Verify Clerk + Convex bootstrap and WebSocket startup end-to-end in a real Flutter environment
