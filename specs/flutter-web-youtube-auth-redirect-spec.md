# Title

Realign Flutter Web YouTube Auth To A Full-Redirect OAuth Flow

# Status

ready

# Problem

The Flutter web client currently uses a popup-based YouTube OAuth flow that diverges from the working `tubeflow` web implementation and introduces multiple failure surfaces:

- the Flutter widget tree remains mounted during a cross-origin OAuth transaction
- OAuth success is signaled through `postMessage` before Convex-backed state is necessarily visible to the app
- the flow depends on popup lifecycle, hash-route reconstruction, provider invalidation timing, and Clerk/Convex rehydration timing all lining up
- diagnostics show repeated Convex HTTP bridge failures during the same path that is supposed to confirm YouTube connectivity
- the working TypeScript web app uses a simpler redirect-driven flow with server-side token exchange and client-side rehydration after the browser returns

The result is a web YouTube auth path that is harder to reason about, harder to recover from, and less robust than the reference flow in `/home/claude/tubeflow`.

# Solution

Replace the Flutter web popup YouTube OAuth path with a full-page redirect flow aligned with the working `tubeflow` web app:

- the Flutter web client prepares the `clerk_session_id` cookie and redirects the current tab to `/api/auth/youtube`
- the Vercel serverless OAuth handlers continue to own the Google code exchange, Clerk-to-Convex token mint, `users:ensureUser`, and `youtube:saveYoutubeTokens`
- the callback returns to the Flutter app via a normal redirect carrying `youtube_connected` or `youtube_error` in the hash route
- after the app reloads and bootstrap completes, Flutter re-reads YouTube connection state from Convex, then runs the refresh pipeline for playlists and videos

This keeps the Clerk beta workaround where needed, but removes popup orchestration and restores a transactionally clean OAuth lifecycle on the web.

# Scope In

- Simplify Flutter web YouTube connect initiation to use `_self` redirect instead of popup orchestration.
- Remove popup-specific client flow handling from the Flutter web app.
- Simplify the Vercel OAuth handlers so redirect mode is the default and only supported web path.
- Keep `return_to` support for hash-based Flutter routes such as `/#/preferences` and `/#/videos`.
- Preserve server-side OAuth token exchange, Clerk Convex token minting, user ensuring, and token persistence.
- Keep the post-return Flutter feedback banner, but make it operate only on redirect-return URL params plus Convex state.
- Keep the current refresh strategy that fetches playlists first, then playlist items, and uses Convex as the source of truth.
- Update diagnostics and acceptance checks so failures are explained in redirect-based terms rather than popup-based terms.

# Scope Out

- Replacing the Clerk Flutter beta SDK or removing the Clerk web bridge.
- Reworking sign-in / hosted Clerk flows outside the YouTube connect path.
- Rewriting the Convex auth bootstrap layer.
- Changing Convex schema or backend function names.
- Migrating `youtubeConnectionProvider` from one-shot query to realtime subscription in this change.
- Reworking native/mobile YouTube auth behavior outside preserving `_self` redirect semantics already used on non-web.

# Constraints

- `CLERK_PUBLISHABLE_KEY` and `CONVEX_URL` remain build-time `--dart-define` inputs and must not be hardcoded.
- The Clerk Flutter beta limitation remains real; web still needs the JS bridge and `clerkWebPrepareSessionCookie()`.
- The Flutter web app uses hash routing, so OAuth return URLs must remain compatible with `/#/...`.
- Convex writes must continue to go through the established mutation/action helpers on the Flutter side.
- The serverless callback must remain able to recover the Clerk session from `clerk_session_id`.
- The implementation must preserve the existing auth bootstrap order in `main.dart` and `ClerkService`.

# Dependencies

- Clerk browser session availability via [web/clerk_bridge.js](/home/claude/tubeflow-app/web/clerk_bridge.js:297) and [lib/auth/clerk_web_bridge_web.dart](/home/claude/tubeflow-app/lib/auth/clerk_web_bridge_web.dart:86)
- OAuth initiation and callback handlers in [api/auth/youtube.js](/home/claude/tubeflow-app/api/auth/youtube.js:1), [api/auth/youtube/callback.js](/home/claude/tubeflow-app/api/auth/youtube/callback.js:1), and [api/auth/_youtube.js](/home/claude/tubeflow-app/api/auth/_youtube.js:1)
- Flutter bootstrap and Convex auth wiring in [lib/main.dart](/home/claude/tubeflow-app/lib/main.dart:1)
- YouTube connect UI and post-return feedback in [lib/widgets/youtube_connect.dart](/home/claude/tubeflow-app/lib/widgets/youtube_connect.dart:1)
- Refresh helpers in [lib/providers/mutations.dart](/home/claude/tubeflow-app/lib/providers/mutations.dart:177)
- YouTube status query in [lib/providers/providers.dart](/home/claude/tubeflow-app/lib/providers/providers.dart:295)
- Reference architecture in `/home/claude/tubeflow`:
  - [apps/web/src/hooks/use-youtube.ts](/home/claude/tubeflow/apps/web/src/hooks/use-youtube.ts:55)
  - [apps/web/src/app/api/auth/youtube/route.ts](/home/claude/tubeflow/apps/web/src/app/api/auth/youtube/route.ts:1)
  - [apps/web/src/app/api/auth/youtube/callback/route.ts](/home/claude/tubeflow/apps/web/src/app/api/auth/youtube/callback/route.ts:1)

# Invariants

- A successful Google OAuth callback must only be considered complete once the server has:
  - exchanged the code for Google tokens
  - minted a Convex JWT from the Clerk session
  - ensured the user exists in Convex
  - saved YouTube tokens in Convex
- Flutter must treat Convex status as the source of truth for “connected” rather than a client-side callback signal.
- `return_to` must always resolve to a safe in-app hash route and must never redirect off-origin.
- Failure to read YouTube status immediately after redirect must not crash the UI; the user must get a recoverable message and retry path.
- Disconnect and manual sync behavior must continue to work from the preferences card and other entry points.

# Links & Consequences

- [lib/widgets/youtube_connect.dart](/home/claude/tubeflow-app/lib/widgets/youtube_connect.dart:1) is the main orchestration point and will lose popup-specific concerns while keeping route cleanup, feedback banner behavior, diagnostics, and refresh triggers.
- [api/auth/youtube.js](/home/claude/tubeflow-app/api/auth/youtube.js:1) and [api/auth/youtube/callback.js](/home/claude/tubeflow-app/api/auth/youtube/callback.js:1) will become easier to reason about by using redirect as the only supported web completion path.
- [lib/widgets/youtube_oauth_popup_bridge_web.dart](/home/claude/tubeflow-app/lib/widgets/youtube_oauth_popup_bridge_web.dart:1), [lib/widgets/youtube_oauth_popup_bridge.dart](/home/claude/tubeflow-app/lib/widgets/youtube_oauth_popup_bridge.dart:1), [lib/widgets/youtube_oauth_popup_bridge_stub.dart](/home/claude/tubeflow-app/lib/widgets/youtube_oauth_popup_bridge_stub.dart:1), and [lib/widgets/youtube_oauth_popup_result.dart](/home/claude/tubeflow-app/lib/widgets/youtube_oauth_popup_result.dart:1) become dead weight and should either be removed or left unused temporarily with a follow-up cleanup explicitly avoided in the same implementation if removal creates unnecessary churn.
- User-facing copy across the connect CTA, empty states, and diagnostics must stop claiming that “Google opens in a secure popup” on web.
- The app shell continues to mount [YoutubeOAuthFeedbackBanner](/home/claude/tubeflow-app/lib/widgets/youtube_connect.dart:481), so redirect-return state must stay compatible with the current shell-level post-auth banner approach.
- The implementation must preserve the ability to start YouTube connect from multiple surfaces:
  - persistent connect banner
  - preferences settings card
  - videos screen
  - playlists screen
  - play screen
  - empty states
- Because the app fully reloads after OAuth, this change reduces dependency on the Convex HTTP bridge during the critical path and shifts status confirmation to post-bootstrap rehydration.

# Edge Cases

- The browser returns from Google with `youtube_error` and the app lands on `/#/preferences`.
- The `clerk_session_id` cookie is missing or expired before `/api/auth/youtube` or the callback runs.
- Google returns success but Convex status is not yet visible on the first query after redirect.
- `return_to` is absent, malformed, absolute, or points to `/`.
- The user starts connect from a route with its own query string, for example `/#/videos?sortOrder=newest`.
- The callback succeeds server-side but the first refresh of playlists or playlist items fails.
- The user is already connected and starts connect again from preferences.
- The Convex HTTP bridge fails and the service falls back to the WebSocket client during status reads or refresh.
- The user closes the tab during OAuth or navigates away after redirect; the flow must still be recoverable on the next app load through persisted Convex state.

# Implementation Tasks

- [ ] Task 1: Simplify OAuth initiation to full redirect on web
  - File: `lib/widgets/youtube_connect.dart`
  - Action: Remove popup-specific launch logic in `_launchYoutubeConnect`; on web, prepare the Clerk session cookie and redirect the current tab to `/api/auth/youtube?return_to=...` using `_self`.
  - Depends on: none
  - Validate with: manual connect from preferences, videos, playlists, play screen, and empty-state CTA; confirm the browser leaves and returns in the same tab
  - Notes: Preserve `_currentYoutubeReturnTo(...)` and the diagnostics block, but remove any dependency on popup completion payloads.

- [ ] Task 2: Remove popup-specific client completion flow
  - File: `lib/widgets/youtube_connect.dart`
  - Action: Delete `_handleYoutubePopupResult(...)` and any client logic that treats popup result as authoritative; keep only redirect-return feedback via `youtube_connected` / `youtube_error`.
  - Depends on: Task 1
  - Validate with: no code path in Flutter waits on popup result; connect flow still reaches the post-return banner
  - Notes: The client should only react after app rehydration and URL-param detection.

- [ ] Task 3: Retune redirect-return feedback and refresh orchestration
  - File: `lib/widgets/youtube_connect.dart`
  - Action: Keep `YoutubeOAuthFeedbackBanner`, but ensure its logic is the single post-return success/error handler: it should invalidate YouTube data, wait for Convex truth with 5 retries max (`3s` timeout per read, `700ms` delay between retries), run playlist/video refresh, and present success, recoverable warning, or error states.
  - Depends on: Task 2
  - Validate with: redirect success path, redirect error path, and delayed Convex visibility path all show deterministic UI without crashes
  - Notes: The banner should no longer imply that success came from popup messaging; it should explicitly describe server-completed auth and app-side refresh.

- [ ] Task 4: Simplify serverless OAuth handlers to redirect-only web behavior
  - File: `api/auth/youtube.js`
  - Action: Remove popup-mode branching and stop setting `youtube_oauth_popup`; keep state, session, and return-to cookies plus redirect to Google.
  - Depends on: none
  - Validate with: request to `/api/auth/youtube?return_to=%2F%23%2Fpreferences` sets only the cookies needed for redirect flow and redirects to Google correctly
  - Notes: `return_to` sanitization must remain intact and continue to support Flutter hash routes.

- [ ] Task 5: Simplify callback response generation to redirect-only completion
  - File: `api/auth/youtube/callback.js`
  - Action: Remove popup HTML / `postMessage` generation and always redirect back to the app using `buildReturnUrl(...)` with either `youtube_connected=true` or `youtube_error=...`, while still clearing temporary cookies.
  - Depends on: Task 4
  - Validate with: success callback returns to the correct in-app hash route; error callback returns with an error param; cookies are cleared in both cases
  - Notes: Preserve server-side exchange, Convex JWT minting, `ensureConvexUser`, and `saveYoutubeTokens` exactly as the transactional core.

- [ ] Task 6: Align user-facing copy and diagnostics with redirect semantics
  - File: `lib/widgets/youtube_connect.dart`
  - Action: Replace popup-specific UI strings with redirect-based wording across connect banners, empty states, CTA helper text, and diagnostics references.
  - Depends on: Task 1
  - Validate with: all web YouTube connect surfaces describe redirect behavior accurately; no user-facing reference to popup remains
  - Notes: Native copy can remain tab-based if already correct for non-web.

- [ ] Task 7: Remove or quarantine dead popup bridge code
  - File: `lib/widgets/youtube_oauth_popup_bridge.dart`
  - Action: Either remove popup bridge files entirely or leave them unused but explicitly disconnected from the auth flow, depending on the minimal-change path chosen during implementation.
  - Depends on: Task 2
  - Validate with: no production code imports or executes popup bridge logic after the refactor
  - Notes: If deletion creates broader churn than value, leaving unused files for a follow-up cleanup is acceptable, but production entry points must be disconnected now.

# Acceptance Criteria

- [ ] CA 1: Given a signed-in Flutter web user on `/#/preferences`, when they press “Connect YouTube”, then the current tab redirects to `/api/auth/youtube?return_to=%2F%23%2Fpreferences` after preparing `clerk_session_id`.
- [ ] CA 2: Given a successful Google OAuth flow, when the callback finishes server-side persistence, then the browser returns to the original in-app hash route with `youtube_connected=true` and no popup is involved.
- [ ] CA 3: Given a failed Google OAuth flow or a missing Clerk session during callback, when the browser returns to the app, then the route contains `youtube_error=...` and the Flutter UI displays a visible error state without crashing.
- [ ] CA 4: Given a redirect return with `youtube_connected=true`, when the app bootstrap completes, then Flutter invalidates YouTube state, confirms connection via Convex with bounded retries, and starts playlist refresh.
- [ ] CA 5: Given that Convex status is still delayed on the first post-return read, when retries exhaust, then the user sees a recoverable “connected but setup needs attention” state and can retry sync manually.
- [ ] CA 6: Given the user starts connect from `/#/videos` or `/#/play`, when OAuth succeeds, then the app returns to the same logical route rather than always forcing `/#/playlists`.
- [ ] CA 7: Given the server callback succeeds, when temporary OAuth cookies are cleaned up, then `youtube_oauth_state`, `youtube_oauth_return_to`, and `clerk_session_id` are removed from the browser, and Flutter web session restoration still succeeds from the Clerk JS session after redirect.
- [ ] CA 8: Given the user opens the preferences diagnostics after this change, when they read the help text, then no copy incorrectly states that Google opened in a popup on web.
- [ ] CA 9: Given connect is initiated from any existing CTA surface, when the implementation is complete, then all surfaces use the same redirect-based path and none relies on popup completion payloads.
- [ ] CA 10: Given the app is already connected to YouTube, when the user manually triggers sync, then the refresh pipeline still fetches playlists first and playlist items second using the current Convex action names.

# Test Strategy

- Manual web smoke tests in a real browser:
  - connect from preferences
  - connect from videos screen
  - connect from playlists empty state
  - connect from play screen
  - retry after an intentional OAuth denial
  - retry after disconnect
- Serverless callback verification:
  - success path with valid `clerk_session_id`
  - missing session path
  - invalid state path
  - missing env var path
- Automated coverage where practical:
  - add focused tests for `_youtube.js` route sanitization helpers if the repo already has a lightweight JS test path available
  - otherwise document “manual-only for serverless handlers in this repo” in implementation notes rather than inventing an ad hoc test harness
- Post-return app verification:
  - initial status re-read after redirect
  - delayed status propagation path
  - manual sync after successful auth
  - route cleanup after dismissing the feedback banner
- Regression checks:
  - disconnect still works from preferences
  - sync now still works from preferences
  - playlists and videos screens still honor their existing refresh helpers
  - no code path imports popup bridge as part of the connect flow

# Risks

- If redirect-return route cleanup is mishandled, users may get stuck with stale `youtube_connected` or `youtube_error` params in the hash.
- If `return_to` sanitization regresses, users may always land on playlists or lose screen-specific context.
- If the callback clears `clerk_session_id` too early or fails before persistence completes, the user may return without a saved connection and with weak diagnostics.
- If the feedback banner becomes the only place that runs refresh, route/shell changes could unintentionally suppress the initial sync.
- Removing popup support changes UX expectations; copy and diagnostics must be updated together to avoid confusion during rollout.
- Because the current `youtubeConnectionProvider` is still a one-shot query, excessively aggressive invalidation could still produce transient loading states; retries and copy must make that recoverable rather than fatal.

# Execution Notes

- Read first:
  - `lib/widgets/youtube_connect.dart`
  - `api/auth/youtube.js`
  - `api/auth/youtube/callback.js`
  - `api/auth/_youtube.js`
  - `lib/providers/mutations.dart`
- Reference implementation to mirror conceptually:
  - `/home/claude/tubeflow/apps/web/src/hooks/use-youtube.ts`
  - `/home/claude/tubeflow/apps/web/src/app/api/auth/youtube/route.ts`
  - `/home/claude/tubeflow/apps/web/src/app/api/auth/youtube/callback/route.ts`
- Recommended execution order:
  1. simplify server handlers
  2. simplify Flutter connect initiation
  3. remove popup-specific client completion flow
  4. simplify post-return banner orchestration
  5. update copy and diagnostics
  6. remove or isolate popup bridge leftovers
  7. run end-to-end browser validation and compare final flow against the working `tubeflow` reference
- Validation commands:
  - build/deploy web app with the usual Flutter production path
  - hit `/api/auth/youtube` and callback through a browser, not just unit-like checks
  - run static checks available in the environment after implementation
- Implementation verification checklist:
  - confirm the final flow still matches the working `tubeflow` pattern: set Clerk session cookie, redirect to server auth route, let server callback persist tokens, return with URL flag, then refresh from Convex
  - confirm `clerk_session_id` is treated as a temporary transport cookie only and not as the source of truth for the restored session after redirect
- Stop conditions / reroute:
  - if `return_to` reconstruction fails for hash routes, pause and validate `buildReturnUrl(...)` behavior before changing more UI code
  - if server callback persistence succeeds but Convex status never reflects tokens after redirect, reroute investigation to backend `youtube:getYoutubeConnectionStatus` and Convex auth propagation before changing Flutter UI further

# Open Questions

None. The implementation should treat redirect-only web OAuth as the target design and preserve the current backend transactional core.
