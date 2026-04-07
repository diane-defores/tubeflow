# Tasks — TubeFlow App

### Audit: Code

#### Critical
- [x] Fail explicitly when CONVEX_URL is not set (was silently using placeholder URL)
- [ ] Implement `ClerkService.getConvexToken()` — currently returns null, so all Convex calls run unauthenticated

#### High
- [x] Wire router to actual screen widgets (was using _Placeholder for all routes)
- [x] Remove `pubspec.lock` from `.gitignore` (must be committed for reproducible builds)
- [x] Surface bootstrap failures to user (was silently swallowed)

#### Medium
- [x] Extract duplicated `_parseColor()` into shared `color_utils.dart`
- [x] Add security headers to `vercel.json` (X-Frame-Options, X-Content-Type-Options, Referrer-Policy)
- [x] Use mutation helpers from `mutations.dart` consistently instead of calling `convexServiceProvider` directly in screens
- [ ] Add tests (zero test coverage currently)
