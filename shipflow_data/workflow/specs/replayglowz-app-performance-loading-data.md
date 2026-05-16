---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "replayglowz"
created: "2026-05-16"
created_at: "2026-05-16 07:37:03 UTC"
updated: "2026-05-16"
updated_at: "2026-05-16 07:55:00 UTC"
status: reviewed
source_skill: sf-build
source_model: "GPT-5 Codex"
scope: "flutter-web-app-performance-loading-data"
owner: "Diane"
user_story: "As the ReplayGlowz maintainer, I want the Flutter web app to reduce avoidable initial loading and data subscription work so app navigation remains fast as the YouTube library and feature surface grow."
confidence: "high"
risk_level: "medium"
security_impact: "none"
docs_impact: "yes"
linked_systems:
  - "replayglowz_app"
  - "Flutter web"
  - "go_router"
  - "Riverpod providers"
  - "Convex YouTube data"
depends_on: []
supersedes: []
evidence:
  - "User requested `$sf-build subagents loops` after a local ReplayGlowz app performance audit."
  - "Local audit found `replayglowz_app/lib/app/router.dart` statically imports all screens, including heavy play, feedback, and admin routes."
  - "Local audit found `videosProvider` uses `youtube:getAllVideos` without pagination or an explicit limit."
  - "Local audit found `PlayScreen` watches YouTube connection, notes, progress, all videos, settings, and active transcript in one build, and loads transcript when the Transcript tab is inactive."
  - "Local audit found `VideosScreen` loads all videos before display."
  - "Local audit found `AppShell` banners may trigger connection checks across protected screens."
  - "Local audit found Sentry is imported at the app entry point."
  - "Local measurements: `flutter analyze` passed; `flutter build web --release` passed in about 89.8s; `build/web` was 37M; `main.dart.js` was 3.7M raw and about 1.08M gzip; `canvaskit.wasm` was 7.16M raw and about 2.87M gzip; `skwasm.wasm` was 3.55M raw and about 1.51M gzip."
  - "Local build emitted a non-blocking Wasm dry-run warning from transitive `flutter_rust_bridge`."
next_step: "/sf-ship ReplayGlowz app performance loading and data if release is requested"
---

# ReplayGlowz App Performance Loading And Data

## Status

Closed locally after the first app-only implementation loop. This spec targeted local Flutter web app performance work only. It did not require site changes, lab changes, release, deploy, or hosted Vercel proof unless the user later asks for a ship or production verification pass.

## Minimal Behavior Contract

ReplayGlowz should preserve the current user experience while reducing avoidable work during initial app load and high-traffic screens. Heavy route surfaces should not inflate or initialize common app paths when a safer lazy or isolated route pattern is available. Screen-level providers should subscribe only to data needed for the visible state, especially on Play and Videos screens.

## Scope In

- Flutter web app code under `replayglowz_app/`.
- Route-loading and import graph improvements for heavy app surfaces when feasible with Flutter web and `go_router`.
- Provider gating on Play screen so transcript work is tied to the active Transcript tab.
- Reduction of all-videos subscription usage on Play screen when narrower current-video metadata is already available or can be passed safely.
- Preservation of current navigation, tabs, feedback flows, YouTube connection banners, and playback behavior.
- Local validation with `flutter analyze` and `flutter build web --release`.

## Scope Out

- No changes to `replayglowz_site/`.
- No changes to `replayglowz_lab/`.
- No release, deploy, Vercel preview, or production proof in this first loop.
- No backend pagination or new Convex function contract unless explicitly split into a coordinated backend follow-up.
- No auth, OAuth scope, Firebase, Sentry project, or token-handling semantic changes.
- No broad visual redesign or copy changes.

## Acceptance Criteria

- [x] CA 1: App navigation and screen behavior remain equivalent for library, play, notes, feedback, preferences, and protected-route flows.
- [x] CA 2: Heavy route code paths for play, feedback, and feedback admin are deferred or isolated when feasible for Flutter web and `go_router`; if not feasible, the implementation documents the blocker and applies smaller safe import/provider gating instead. Route-level deferred loading was explicitly deferred because of `go_router`, deep-link, and auth risk.
- [x] CA 3: `PlayScreen` no longer watches the transcript provider while the Transcript tab is inactive.
- [x] CA 4: `PlayScreen` avoids subscribing to the full all-videos collection for current-video metadata when narrower metadata can be passed, selected, or fetched safely without backend contract changes. True single-video metadata is deferred because no safe narrow existing backend/provider contract exists; Worker 2 removed the normal render subscription and kept a one-shot queue fallback.
- [x] CA 5: The implementation does not introduce backend pagination/function changes in the same loop.
- [x] CA 6: YouTube connection status and AppShell banners still appear only where users need them and do not regress protected-route usability. Worker 2 found no obvious safe AppShell semantic change.
- [x] CA 7: `flutter analyze` passes in `replayglowz_app`.
- [x] CA 8: `flutter build web --release` passes in `replayglowz_app`.
- [x] CA 9: The verification report records bundle-size observations or explains why no size comparison was produced.

## Implementation Tasks

- [x] Task 1: Inspect route graph and heavy imports.
  - Files: `replayglowz_app/lib/app/router.dart`, play screen files, feedback screen files, feedback admin files.
  - Action: Identify static imports that pull heavy public feedback, admin, audio, and playback code into common route construction.
  - User story link: Reduces avoidable startup and first-route parse work.
  - Depends on: None.
  - Validate with: Source review and `flutter analyze`.
  - Notes: Preserve route paths, redirects, auth behavior, and existing `go_router` semantics.

- [x] Task 2: Defer or isolate heavy route code paths where feasible.
  - Files: `replayglowz_app/lib/app/router.dart` and any small route-loader wrappers created under `replayglowz_app/lib/`.
  - Action: Use Flutter/Dart-supported lazy or deferred import patterns if compatible with `go_router`; otherwise isolate heavy route builders behind smaller wrappers and document why full deferred loading is blocked.
  - User story link: Keeps common app paths lighter without changing visible behavior.
  - Depends on: Task 1.
  - Validate with: `flutter analyze` and `flutter build web --release`.
  - Notes: Deferred for this loop; route-level deferred loading was not forced because of `go_router`, browser refresh, deep-link, and auth redirect risk.

- [x] Task 3: Gate PlayScreen transcript loading by active tab.
  - Files: `replayglowz_app/lib/screens/play/play_screen.dart` and related provider helpers only if needed.
  - Action: Watch transcript data only when the Transcript tab is active, while preserving loading/error states when the user opens that tab.
  - User story link: Avoids unnecessary data and rendering work for users using Notes or other play-side surfaces.
  - Depends on: None.
  - Validate with: `flutter analyze` and targeted source review of tab switching behavior.
  - Notes: Keep notes, progress, and playback state stable while changing tab selection.

- [x] Task 4: Remove all-videos dependency from PlayScreen when safe.
  - Files: `replayglowz_app/lib/screens/play/play_screen.dart`, route arguments/helpers, and existing app model/provider files only if needed.
  - Action: Prefer current video metadata already available from route state, selected video, or a narrow existing provider over `videosProvider`/`youtube:getAllVideos`.
  - User story link: Prevents the Play screen from scaling with the full library size.
  - Depends on: Task 1.
  - Validate with: `flutter analyze` and manual source review for direct-play and deep-link entry paths.
  - Notes: Normal PlayScreen render no longer subscribes to the full all-videos collection; true single-video metadata is deferred because no existing narrow provider/backend source is safe. A one-shot existing `youtube:getAllVideos` fallback remains for the queue drawer.

- [x] Task 5: Review AppShell connection banner provider usage.
  - Files: `replayglowz_app/lib/widgets/app_shell.dart` and existing YouTube connection providers/widgets.
  - Action: Confirm banner checks remain necessary on protected screens, and gate or reuse state only if this can be done without hiding actionable connection failures.
  - User story link: Avoids repeated connection checks while preserving user trust and recoverability.
  - Depends on: None.
  - Validate with: `flutter analyze`.
  - Notes: Reviewed with no obvious safe semantic change; OAuth, token, and connection semantics were unchanged.

- [x] Task 6: Measure and report local results.
  - Files: no required source file; optional spec/changelog updates only if implementation changes justify them.
  - Action: Run required local checks and compare `build/web`, `main.dart.js`, and key wasm artifact sizes against the audit baseline when practical.
  - User story link: Confirms the loop improved or at least did not regress local web build output.
  - Depends on: Tasks 2-5.
  - Validate with: `flutter analyze` and `flutter build web --release`.
  - Notes: Bundle size may not move much if Flutter web retains symbols despite route isolation; data subscription reduction is still valuable and should be verified structurally.

## Stop Conditions

- Backend pagination, new Convex functions, or server-side query contract changes become necessary to meet a target. Stop and create a separate backend-coordination spec or explicit follow-up.
- Dart deferred loading conflicts with Flutter web, `go_router`, browser refresh, deep-link handling, auth redirects, or current build tooling. Implement smaller safe gating only, and document the route-splitting blocker in the verification report.
- A proposed optimization changes OAuth, Firebase auth, token storage, Sentry security posture, or YouTube connection semantics. Stop for an explicit security/data decision.
- A proposed optimization changes visible product behavior beyond loading timing or loading states. Stop for a user decision.
- Local validation fails and the fix would require broad unrelated refactoring.

## Test Strategy

- Root governance: `/home/claude/shipflow/tools/shipflow_metadata_lint.py AGENT.md shipflow_data`.
- Flutter app static check: `cd replayglowz_app && flutter analyze`.
- Flutter web build: `cd replayglowz_app && flutter build web --release`.
- Local size observations after build:
  - `du -sh replayglowz_app/build/web`
  - inspect `replayglowz_app/build/web/main.dart.js`
  - inspect `replayglowz_app/build/web/canvaskit/canvaskit.wasm` and `replayglowz_app/build/web/canvaskit/skwasm.wasm` when present.
- Source review: confirm PlayScreen transcript provider is gated by active tab and all-videos usage is removed or explicitly justified.

## Risks

- Medium route risk: deferred imports can be awkward with Flutter web and `go_router`; broken deep links or auth redirects would be worse than the performance issue.
- Medium data risk: removing `getAllVideos` from Play screen may miss metadata for direct-entry paths unless route state or a narrow existing provider covers them.
- Low UX risk: gating transcript loading can introduce a first-open loading state on the Transcript tab; this is acceptable if clear and stable.
- Low measurement risk: Flutter web bundle sizes may not reflect all route or provider improvements, so verification should include structural evidence.

## Execution Notes

- Start with the safest app-only wins: PlayScreen provider gating before more invasive route import changes.
- Treat route-level deferred loading as a best-effort optimization, not a requirement to force through unsafe architecture.
- Keep the first loop narrow enough for one delegated sequential implementation pass.
- Do not touch site, lab, deployment config, or release docs.
- Do not run hosted Vercel proof unless a later ship/deploy command asks for it.

## Open Questions

None for the first loop. Backend pagination and new narrow Convex functions are intentionally deferred unless the implementation proves they are required.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-16 07:37:03 UTC | sf-build | GPT-5 Codex | Created ready app-only performance spec from the local audit findings; scoped first loop to route isolation where feasible, PlayScreen provider gating, and local Flutter validation only. | Ready. | `/sf-start ReplayGlowz app performance loading and data` |
| 2026-05-16 07:43:00 UTC | sf-start | GPT-5 Codex | Worker 2 implemented the first local app-only performance loop in `replayglowz_app/lib/screens/play/play_screen.dart`: transcript provider watching is gated to the active Transcript tab, the Play screen no longer subscribes to `videosProvider` during normal render, and queue metadata falls back to a one-shot existing `youtube:getAllVideos` query only when the queue drawer is opened. Reviewed AppShell banner usage and route-level deferred loading; no safe tiny route or banner semantic change was applied in this loop. | Implemented with route-level deferred loading deferred and single-video metadata still blocked by lack of an existing narrow provider/backend contract. Validation passed: `flutter analyze`, `flutter build web --release`, and ShipFlow metadata lint. Size observations: `build/web` 37M, `main.dart.js` 3714284 bytes, `canvaskit.wasm` 7155824 bytes, `skwasm.wasm` 3549782 bytes. | `/sf-verify ReplayGlowz app performance loading and data` |
| 2026-05-16 07:50:00 UTC | sf-verify | GPT-5 Codex | Worker 3 performed scoped verification of the app-only performance loop and reran `flutter analyze`. | Passed with no blocking issues and no edits. Route-level deferred loading, true single-video metadata, and AppShell semantic changes remain documented deferrals. | `/sf-end ReplayGlowz app performance loading and data` |
| 2026-05-16 07:55:00 UTC | sf-end | GPT-5 Codex | Worker 4 closed local bookkeeping for the implemented app-only performance loop. | Closed locally. No commit, push, deploy, site, or lab work requested. | `/sf-ship ReplayGlowz app performance loading and data` if release is requested |

## Current Chantier Flow

| Step | Status | Notes |
|------|--------|-------|
| sf-spec | ready | Spec created from `$sf-build subagents loops` request and local app performance audit. |
| sf-ready | ready | Implementation contract, acceptance criteria, validation, and stop conditions are explicit. |
| sf-start | implemented | Worker 2 completed app-only PlayScreen provider/data reductions and local validation; route-level deferred loading and a true narrow current-video provider remain deferred follow-ups. |
| sf-verify | passed | Worker 3 found no blocking issues and reran `flutter analyze` successfully. |
| sf-end | closed locally | Worker 4 updated local closure bookkeeping. No commit, push, deploy, site, or lab work requested. |
| sf-ship | pending | Not requested. No release or deploy requested for this first local loop. |

Next command: `/sf-ship ReplayGlowz app performance loading and data` if release is requested.
