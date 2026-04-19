# Tasks — TubeFlow App

### Audit: Code

#### Critical
- [x] Fail explicitly when CONVEX_URL is not set (was silently using placeholder URL)
- [x] Implement `ClerkService.getConvexToken()` — Convex calls now use the Clerk `convex` JWT template

#### High
- [x] Wire router to actual screen widgets (was using _Placeholder for all routes)
- [x] Remove `pubspec.lock` from `.gitignore` (must be committed for reproducible builds)
- [x] Surface bootstrap failures to user (was silently swallowed)

#### Medium
- [x] Extract duplicated `_parseColor()` into shared `color_utils.dart`
- [x] Add security headers to `vercel.json` (X-Frame-Options, X-Content-Type-Options, Referrer-Policy)
- [x] Use mutation helpers from `mutations.dart` consistently instead of calling `convexServiceProvider` directly in screens
- [x] Implement feedback collection + admin review flow (text/audio, Convex storage, admin allowlist)
- [ ] Verify Clerk + Convex bootstrap and WebSocket startup end-to-end in a real Flutter environment
- [ ] Add tests (zero test coverage currently)
