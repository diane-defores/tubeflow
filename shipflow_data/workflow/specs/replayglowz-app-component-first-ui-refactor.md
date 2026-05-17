---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "replayglowz"
created: "2026-05-16"
created_at: "2026-05-16 13:56:51 UTC"
updated: "2026-05-17"
updated_at: "2026-05-17 09:36:18 UTC"
status: ready
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: "flutter-app-component-first-ui-refactor"
owner: "Diane"
user_story: "As the ReplayGlowz maintainer, I want the Flutter app UI refactored toward reusable, component-first widgets so app screens stay visually consistent and future feature work does not duplicate cards, empty states, loading states, and settings controls."
confidence: "high"
risk_level: "medium"
security_impact: "none"
docs_impact: "yes"
linked_systems:
  - "replayglowz_app"
  - "Flutter"
  - "Riverpod"
  - "go_router"
  - "Material 3"
depends_on:
  - artifact: "shipflow_data/business/product.md"
    artifact_version: "0.1.0"
    required_status: "draft"
  - artifact: "shipflow_data/business/branding.md"
    artifact_version: "0.1.0"
    required_status: "draft"
  - artifact: "shipflow_data/technical/architecture.md"
    artifact_version: "0.1.0"
    required_status: "draft"
  - artifact: "shipflow_data/technical/guidelines.md"
    artifact_version: "0.1.0"
    required_status: "draft"
supersedes: []
evidence:
  - "User clarified that public claims/copy are out of scope and requested focus on app design and component-first architecture."
  - "Design/component audit found the app is functional but screen-first: repeated Card/ListTile/thumbnail/skeleton/empty-state patterns are rebuilt inside screens."
  - "Audit found `replayglowz_app/lib/screens/play/play_screen.dart` is 1037 lines and mixes player, playback controls, notes, transcript, comments placeholder, queue, options, mutations, and error handling."
  - "Audit found `replayglowz_app/lib/widgets/youtube_connect.dart` is 1267 lines and mixes OAuth flow helpers, connection banners, settings cards, diagnostics, and empty states."
  - "Audit found repeated loading skeletons in `notes_screen.dart`, `videos_screen.dart`, `playlists_screen.dart`, `hidden_screen.dart`, `stats_screen.dart`, and `play_screen.dart`."
  - "Audit found repeated media card/list tile and thumbnail logic in `videos_screen.dart`, `playlists_screen.dart`, `playlist_detail_screen.dart`, and `hidden_screen.dart`."
  - "Audit found `PreferencesScreen` is 939 lines with repeated settings sections, ListTile/SwitchListTile choices, and selection dialog logic."
  - "`flutter analyze` passed in `replayglowz_app` on 2026-05-16."
  - "User decided on 2026-05-17 that the runtime theme selector wiring is included in this chantier and that focused widget tests should be added during the first implementation pass."
next_step: "/sf-ship ReplayGlowz App Component-First UI Refactor"
---

# Title

ReplayGlowz App Component-First UI Refactor

## Status

Ready for implementation. The chantier is intentionally limited to Flutter UI structure, reusable app widgets, a narrow runtime theme-selector wiring fix, and focused widget tests. Marketing copy, public site claims, pricing, SEO, lab worker behavior, backend schema, and deployment changes are out of scope.

## User Story

As the ReplayGlowz maintainer, I want the Flutter app UI refactored toward reusable, component-first widgets so app screens stay visually consistent and future feature work does not duplicate cards, empty states, loading states, and settings controls.

## Minimal Behavior Contract

ReplayGlowz should keep the current app behavior and navigation while replacing repeated screen-local UI patterns with reusable Flutter widgets for app states, media thumbnails, video/playlist/note rows, settings rows, and player panels. When data loads, fails, is empty, or requires YouTube connection, users should see the same or clearer states than today. The theme choice persisted from Preferences must also drive the app runtime `ThemeMode` without changing auth, routing, or backend behavior. Focused widget tests must cover the riskiest new reusable UI contracts. If a component extraction would alter auth, YouTube OAuth, Convex provider behavior, routing, playback semantics, or transcript generation, the implementation must stop or split that work. The easiest edge case to miss is extracting shared widgets too aggressively and accidentally coupling visually similar surfaces that have different domain behavior.

## Success Behavior

- Screens remain behaviorally equivalent: Videos, Playlists, Playlist Detail, Play, Notes, Hidden, Preferences, Feedback, Feedback Admin, Stats, and Notifications continue to navigate and act as before.
- Shared UI primitives exist for common app shell states: empty states, loading lists, section headers, status cards, thumbnails, timestamp badges, and app-level surfaces.
- Domain widgets exist for repeated app concepts: video cards/list tiles, playlist cards/list tiles, note tiles, transcript entry tiles, and settings rows.
- Large screen files shrink because rendering subtrees move into named widgets without moving unrelated provider or mutation semantics prematurely.
- `youtube_connect.dart` is split so OAuth/helper logic and UI widgets are not all in one file.
- The Preferences theme selector changes the runtime app theme by wiring persisted `settings.theme` into `themeModeProvider` or an equivalent Riverpod bridge.
- Focused widget tests exist for shared app-state/media/settings/theme behavior where the new component layer carries regression risk.
- Component names make the architecture discoverable for future work.
- Flutter static validation passes.

## Error Behavior

- If extraction changes behavior, revert or narrow that extraction before proceeding.
- If a shared component needs many boolean flags or unrelated configuration branches, leave the use cases separate and document why abstraction was not applied.
- If an extracted widget needs direct access to Riverpod providers for domain behavior, keep the provider boundary explicit and prefer passing data/actions from screens unless the widget is an intentionally domain-aware component.
- If theme-mode wiring would require auth, backend, settings persistence, or routing changes beyond reading the existing settings stream/model, stop and split it out rather than widening this chantier.
- If Flutter analyze reveals deprecated or invalid Material usage during the refactor, fix within the touched component only; do not start broad dependency upgrades.
- If a widget test needs broad app bootstrapping, network-backed providers, OAuth, Convex, Firebase, or real YouTube data, replace it with a smaller component-level test and keep the full flow in manual QA.
- If visual parity cannot be verified by tests alone, record the manual screen checklist required for the implementation pass.

## Problem

The Flutter app currently works, but its UI architecture is mostly screen-first. Several screens rebuild the same Card/ListTile layouts, thumbnail fallbacks, shimmer loading lists, empty states, timestamp badges, and settings rows locally. Large files such as `play_screen.dart`, `youtube_connect.dart`, and `preferences_screen.dart` mix UI composition, state, side effects, routing, mutations, and diagnostics. That makes visual consistency harder to maintain and increases the cost of adding new app surfaces.

## Solution

Introduce a small component-first layer under `replayglowz_app/lib/widgets/` and migrate the highest-duplication app screens incrementally. Start with low-risk primitives and domain display widgets, then split the largest screens into panel components while preserving provider and navigation behavior. Keep abstractions narrow and domain-aware where needed; do not create a universal component that hides different business behavior behind flags.

## Scope In

- Flutter app only: `replayglowz_app/lib/**`.
- Shared app UI primitives under `replayglowz_app/lib/widgets/`, with subfolders if useful.
- Domain UI widgets for videos, playlists, notes, transcripts, YouTube connection, and settings.
- Refactor of screen rendering code in:
  - `replayglowz_app/lib/screens/play/play_screen.dart`
  - `replayglowz_app/lib/widgets/youtube_connect.dart`
  - `replayglowz_app/lib/screens/preferences/preferences_screen.dart`
  - `replayglowz_app/lib/screens/videos/videos_screen.dart`
  - `replayglowz_app/lib/screens/playlists/playlists_screen.dart`
  - `replayglowz_app/lib/screens/playlists/playlist_detail_screen.dart`
  - `replayglowz_app/lib/screens/notes/notes_screen.dart`
  - `replayglowz_app/lib/screens/hidden/hidden_screen.dart`
- Theme/token cleanup inside `replayglowz_app/lib/app/theme.dart` only when needed to support extracted components.
- Narrow runtime theme selector wiring in `replayglowz_app/lib/app/theme.dart`, `replayglowz_app/lib/main.dart`, and existing settings provider/model code paths, limited to making persisted `settings.theme` affect `MaterialApp.themeMode`.
- Focused widget tests under `replayglowz_app/test/**` for newly extracted component contracts and the theme-mode mapping/bridge. The test folder does not exist yet and may be created.
- Local validation with `flutter analyze`; run `flutter test` once widget tests are added.
- Documentation or changelog note only if the implementation changes project guidance or visible app behavior.

## Scope Out

- No `replayglowz_site` changes.
- No public marketing copy, public claims, pricing, SEO, or GTM changes.
- No `replayglowz_lab` changes.
- No Convex backend schema/function changes.
- No Firebase Auth, YouTube OAuth scope, token storage, or Vercel API handler changes.
- No redesign of app flows or information architecture.
- No dependency upgrades unless required to keep touched Flutter code valid.
- No route path changes.
- No broad localization pass. Existing strings can be preserved unless moving them into components requires a local parameter.

## Constraints

- Preserve existing app behavior and route names.
- Keep provider ownership clear: screens or existing providers should continue to own data subscriptions and mutations unless a widget is intentionally domain-aware.
- Prefer composition (`child`, `children`, action widgets, callback parameters) over large prop bags.
- Avoid "universal" components with many optional flags. Use domain-specific components when behavior differs.
- Use Material 3 platform widgets and current project style before inventing custom interaction primitives.
- Keep extracted widgets small enough to be readable and testable.
- Preserve accessibility basics: labels/tooltips, keyboard focus through Material widgets, target sizes, readable error/empty states.
- Maintain ASCII in technical source comments/docs unless user-facing localization already requires non-ASCII.

## Dependencies

- Flutter 3/Dart app under `replayglowz_app`.
- Material 3 `ThemeData`, `CardThemeData`, `InputDecorationTheme`, buttons, ListTile, NavigationBar, NavigationRail, dialogs, and sheets.
- Riverpod for state management.
- go_router for navigation.
- Existing `settingsProvider`, `UserSettings`, and `AppThemeMode` for persisted preferences.
- Existing app models: `YouTubeVideo`, `YouTubePlaylist`, `Note`, transcript entries parsed in `PlayScreen`, settings models.
- Existing utility functions: duration/date formatting, color parsing, error feedback helpers.
- Fresh external docs: not needed for this spec because it uses existing local Flutter/Material/Riverpod/go_router patterns and introduces no new dependency or framework behavior. If implementation needs a new package or a newer Material API, official docs must be checked before coding that change.

## Invariants

- Auth and protected route semantics remain unchanged.
- YouTube connection and OAuth feedback behavior remain unchanged.
- Playback, progress saving, transcript generation, note creation/deletion, playlist hiding, and sync behavior remain unchanged.
- Error copy can move between widgets but must stay at least as actionable as current `ErrorStateView`/`InlineErrorCard` behavior.
- Empty/loading states must not hide recoverable actions such as Connect YouTube, Refresh, Retry, Sync now, or Generate Transcript.
- App screens remain usable on compact and wide layouts.
- Theme wiring remains local to the existing settings model/provider and must not change settings persistence semantics or require a backend schema change.

## Links & Consequences

- `AppShell` already centralizes bottom navigation and rail behavior; new components should not duplicate shell navigation.
- `ErrorStateView` and `InlineErrorCard` are existing primitives and should be reused or extended instead of replaced casually.
- `YoutubeAwareEmptyState` is a useful domain component but currently lives inside an oversized `youtube_connect.dart`; moving it affects Videos, Playlists, and Notes.
- Media cards and thumbnails appear across Videos, Playlists, Playlist Detail, Hidden, and Play queue surfaces; a single wrong thumbnail abstraction could affect many screens.
- Settings rows affect user configuration and should remain simple, predictable, and accessible.
- Runtime theme selection affects the whole `MaterialApp`; a bad provider bridge can create rebuild loops, loading flicker, or forced fallback to system mode.
- Introducing the first app widget tests affects local developer workflow and must avoid fragile tests that depend on live auth, network, Convex, Firebase, or YouTube state.
- A component-first layer will make later design audits and app feature work faster, but the first implementation pass may touch many imports.

## Documentation Coherence

- Update `replayglowz_app/README.md` or `replayglowz_app/AGENT.md` only if the implementation establishes a durable component organization convention that future agents should follow.
- Do not edit root product/business docs unless visible app behavior changes.
- Do not edit public site documentation.
- If a changelog is maintained for app internals, add a concise entry after implementation only if the user requests shipping/closeout or the project convention requires it.

## Edge Cases

- A list surface needs a Connect YouTube action when disconnected, but a normal empty state when connected.
- A media item has no thumbnail URL or the image request fails.
- A playlist color is missing or malformed.
- A note is not timestamped.
- Transcript entries have optional speaker labels or empty payloads.
- A loading state appears on a dark theme and should not hardcode white/grey values that reduce contrast.
- Preferences theme choices persist and must affect runtime theme without creating a transient blank/loading app state while settings load.
- Wide web layout uses NavigationRail while compact layout uses NavigationBar.
- A component extraction creates a callback that captures stale `BuildContext` after an async operation.
- A widget test should be skipped or narrowed if it requires live auth, network, OAuth, Convex, Firebase, or YouTube state.

## Implementation Tasks

- [ ] Task 1: Establish app UI primitive folder and token helpers.
  - File: `replayglowz_app/lib/widgets/app_states.dart` or `replayglowz_app/lib/widgets/app_states/*.dart`
  - Action: Add reusable primitives for generic empty states, centered loading states, list skeleton wrappers, section headers, status cards, timestamp badges, and thumbnail fallbacks.
  - User story link: Creates the component-first foundation that prevents screen-local duplication.
  - Depends on: None.
  - Validate with: `flutter analyze`.
  - Notes: Reuse `ErrorStateView` and `InlineErrorCard` instead of replacing them.

- [ ] Task 2: Add media display components for videos and playlists.
  - File: `replayglowz_app/lib/widgets/media/video_card.dart`, `replayglowz_app/lib/widgets/media/video_list_tile.dart`, `replayglowz_app/lib/widgets/media/playlist_card.dart`, or equivalent paths.
  - Action: Extract repeated thumbnail, title, channel, duration, playlist color, playlist count, and tap/menu rendering from Videos, Playlists, Playlist Detail, Hidden, and queue surfaces.
  - User story link: Keeps repeated library surfaces visually consistent.
  - Depends on: Task 1.
  - Validate with: `flutter analyze` and source review of all migrated call sites.
  - Notes: Keep actions as callbacks or supplied widgets so list/card variants do not become a flag-heavy universal component.

- [ ] Task 3: Add note and transcript display components.
  - File: `replayglowz_app/lib/widgets/notes/note_tile.dart`, `replayglowz_app/lib/widgets/notes/note_group_header.dart`, `replayglowz_app/lib/widgets/transcripts/transcript_entry_tile.dart`, or equivalent paths.
  - Action: Extract timestamp badge display, note list item layout, note group header, active transcript entry styling, speaker label rendering, and transcript seek callback shape.
  - User story link: Makes the learning workflow UI reusable across Notes and Play.
  - Depends on: Task 1.
  - Validate with: `flutter analyze`.
  - Notes: Preserve timestamp seek and note detail navigation semantics.

- [ ] Task 4: Split YouTube connection UI from OAuth/helper logic.
  - File: `replayglowz_app/lib/widgets/youtube_connect.dart` plus new files such as `youtube_connect_flow.dart`, `youtube_connect_banner.dart`, `youtube_connection_card.dart`, `youtube_empty_states.dart`.
  - Action: Move connection banners, loading/required states, settings card, and empty states into discoverable files while preserving public APIs used by screens.
  - User story link: Reduces the current 1200+ line component module into maintainable pieces.
  - Depends on: Task 1.
  - Validate with: `flutter analyze`; source review for import cycles and OAuth flow preservation.
  - Notes: Do not change OAuth, token, redirect, sync, or diagnostic behavior.

- [ ] Task 5: Refactor Videos, Playlists, Hidden, and Notes screens to use shared components.
  - File: `replayglowz_app/lib/screens/videos/videos_screen.dart`, `replayglowz_app/lib/screens/playlists/playlists_screen.dart`, `replayglowz_app/lib/screens/hidden/hidden_screen.dart`, `replayglowz_app/lib/screens/notes/notes_screen.dart`.
  - Action: Replace screen-local cards, empty states, skeletons, thumbnails, and note rows with the new primitives/domain widgets.
  - User story link: Removes duplication from repeated library surfaces.
  - Depends on: Tasks 1-4 as applicable.
  - Validate with: `flutter analyze` and manual checklist for Videos, Playlists, Hidden, Notes connected/disconnected/loading/empty states.
  - Notes: Keep business logic and provider watching in screens unless moving it is explicitly safer.

- [ ] Task 6: Split PlayScreen into panel components.
  - File: `replayglowz_app/lib/screens/play/play_screen.dart` plus new files under `replayglowz_app/lib/screens/play/widgets/` or `replayglowz_app/lib/widgets/play/`.
  - Action: Extract player area, playback controls, notes panel, transcript panel, comments placeholder, queue sheet, and video options sheet into named widgets/functions with explicit inputs and callbacks.
  - User story link: Makes the core learning screen maintainable without changing playback behavior.
  - Depends on: Tasks 1 and 3.
  - Validate with: `flutter analyze`; manual checklist for play, seek, add/delete note, transcript generation, queue open, video options.
  - Notes: Keep `YoutubePlayerController` ownership and progress side effects in the screen state unless a narrow controller abstraction is explicitly introduced.

- [ ] Task 7: Refactor PreferencesScreen settings rows.
  - File: `replayglowz_app/lib/screens/preferences/preferences_screen.dart` plus new widgets such as `settings_section.dart`, `settings_choice_tile.dart`, `settings_switch_tile.dart`.
  - Action: Extract repeated section headers, choice rows, switch rows, and choice dialog wiring into small reusable settings widgets.
  - User story link: Keeps future settings additions consistent and cheaper to implement.
  - Depends on: Task 1.
  - Validate with: `flutter analyze`; manual checklist for theme, language, notification, playback, notes, transcript, support, admin link visibility.
  - Notes: Include the narrow runtime theme fix: persisted theme selection must update the running app theme, but settings persistence semantics must remain unchanged.

- [ ] Task 8: Wire the runtime theme selector and perform focused token cleanup only where needed.
  - File: `replayglowz_app/lib/app/theme.dart`
  - File: `replayglowz_app/lib/main.dart`
  - File: `replayglowz_app/lib/providers/providers.dart`
  - File: `replayglowz_app/lib/models/settings.dart`
  - Action: Replace the fixed `ThemeMode.system` provider with a provider that maps the existing persisted `AppThemeMode` setting to Flutter `ThemeMode`, with `ThemeMode.system` as the loading/null fallback. Add or reuse semantic styles for extracted components only if needed to avoid hardcoded grey/white values.
  - User story link: Makes the existing Preferences design control truthful while centralizing design consistency.
  - Depends on: Task 7.
  - Validate with: `flutter analyze`; widget test for theme mode mapping/bridge.
  - Notes: Do not perform a visual redesign; do not change backend schema, settings field names, or auth requirements.

- [ ] Task 9: Add focused widget tests for component contracts.
  - File: `replayglowz_app/test/widgets/**` or equivalent `replayglowz_app/test/**` paths created during implementation.
  - Action: Add small widget/provider tests for the riskiest reusable components: empty/loading state rendering, media thumbnail fallback, settings tile/dialog behavior, and theme-mode mapping. Use fakes or direct widget inputs; avoid live auth, network, Convex, Firebase, OAuth, and YouTube dependencies.
  - User story link: Prevents future feature work from breaking shared UI states.
  - Depends on: Tasks 1-8.
  - Validate with: `flutter test` and `flutter analyze`.
  - Notes: Do not create fragile golden tests unless the project already supports them.

## Acceptance Criteria

- [ ] CA 1: No public site, lab, backend, OAuth scope, Firebase auth, Convex schema, or route path changes are made.
- [ ] CA 2: `flutter analyze` passes in `replayglowz_app`.
- [ ] CA 3: At least one shared app state/skeleton/empty-state primitive replaces duplicated local code in three or more screens.
- [ ] CA 4: Video and playlist display logic is extracted into reusable widgets or explicitly justified where behavior differs.
- [ ] CA 5: Note and transcript display logic is extracted into reusable widgets or panels without changing seek/navigation semantics.
- [ ] CA 6: `youtube_connect.dart` is split or reduced so OAuth flow helpers and UI surfaces are no longer all concentrated in one 1200+ line file.
- [ ] CA 7: `PlayScreen` is split into named UI panels/components while preserving playback, progress, notes, transcript, queue, and options behavior.
- [ ] CA 8: `PreferencesScreen` uses reusable settings section/tile/dialog components for repeated rows.
- [ ] CA 9: New abstractions do not introduce universal components with large boolean flag farms; domain-specific components are used where behavior differs.
- [ ] CA 10: Manual QA checklist covers compact and wide layouts for Videos, Playlists, Play, Notes, Hidden, and Preferences.
- [ ] CA 11: Changing the theme selector in Preferences updates the app runtime `ThemeMode` through the existing settings model/provider path, with system mode as the loading/null fallback.
- [ ] CA 12: Focused widget tests are added under `replayglowz_app/test/**` and `flutter test` passes.

## Test Strategy

- Static validation: `cd replayglowz_app && flutter analyze`.
- Widget tests: create focused tests under `replayglowz_app/test/**`, then run `cd replayglowz_app && flutter test`.
- Root governance validation after spec or docs updates: `/home/claude/shipflow/tools/shipflow_metadata_lint.py AGENT.md shipflow_data`.
- Manual QA checklist:
  - Videos: disconnected, loading, empty connected, card view, list view, summary view, thumbnail failure.
  - Playlists: disconnected, loading, empty connected, playlist card tap, hide action, create playlist FAB.
  - Play: no video selected, connected video playback, seek controls, add/delete note, transcript empty/generate, transcript entries, queue sheet, video options sheet.
  - Notes: disconnected, loading, no notes, search empty, grouped notes, note detail navigation.
  - Hidden: empty videos/playlists, unhide video, unhide playlist, confirm dialog.
  - Preferences: settings choice dialogs, switches, YouTube settings card, diagnostics/logs cards, admin link loading/visible states.
  - Layout: compact width with bottom navigation and wide width with navigation rail.

## Risks

- Medium behavior risk: component extraction can accidentally change callbacks, provider invalidation, or navigation.
- Medium design risk: over-abstraction can hide different domain behaviors behind flags and make components harder to maintain.
- Medium regression risk: PlayScreen is central and stateful; extracting panels must not disturb controller ownership or progress side effects.
- Medium test-infra risk: the app currently has no `replayglowz_app/test` directory, so the first tests must stay small and fake-driven to avoid brittle auth/network setup.
- Low accessibility risk: Material widgets preserve much of the baseline, but custom cards/InkWell wrappers still need tooltips/labels where actions are icon-only.
- Low validation risk: `flutter analyze` proves static correctness but not visual parity, so manual QA remains required.

## Execution Notes

- Start with primitives and low-risk display widgets before touching PlayScreen.
- Read these files first before implementation: `replayglowz_app/lib/app/theme.dart`, `replayglowz_app/lib/main.dart`, `replayglowz_app/lib/providers/providers.dart`, `replayglowz_app/lib/models/settings.dart`, `replayglowz_app/lib/screens/preferences/preferences_screen.dart`, `replayglowz_app/lib/widgets/youtube_connect.dart`, `replayglowz_app/lib/screens/play/play_screen.dart`, and one representative library screen before extracting shared widgets.
- Prefer many small components over one large flexible component.
- Move code mechanically first, then simplify only where tests/source review make behavior clear.
- Keep function and widget names domain-specific and easy to search.
- Make one screen migration compile before migrating the next one.
- Validate incrementally with `cd replayglowz_app && flutter analyze`; after tests are introduced, also run `cd replayglowz_app && flutter test`.
- Stop and update the spec before coding if the theme fix requires backend/schema/auth changes, if tests require live external services, or if a component extraction would move provider ownership or side effects in a way that changes app behavior.
- Use `apply_patch` for source edits and avoid unrelated refactors.

## Open Questions

None. User decision on 2026-05-17: include the narrow runtime theme selector wiring fix in this chantier, and add focused widget tests during the first implementation pass.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-16 13:56:51 UTC | sf-spec | GPT-5 Codex | Created app-only component-first UI refactor spec from the design/component audit and user confirmation. | Draft created. | `/sf-ready ReplayGlowz app component-first UI refactor` |
| 2026-05-17 08:03:24 UTC | sf-ready | GPT-5 Codex | Evaluated the component-first UI refactor spec against the readiness gate. | Not ready: open questions still change scope/validation decisions. | `/sf-spec ReplayGlowz app component-first UI refactor` |
| 2026-05-17 08:05:38 UTC | sf-spec | GPT-5 Codex | Resolved open questions from the user decision: include runtime theme wiring and focused widget tests. | Draft updated. | `/sf-ready ReplayGlowz app component-first UI refactor` |
| 2026-05-17 08:07:21 UTC | sf-ready | GPT-5 Codex | Re-evaluated the spec after open questions were resolved and test/theme scope was made explicit. | Ready. | `/sf-start ReplayGlowz App Component-First UI Refactor` |
| 2026-05-17 09:31:51 UTC | sf-start | GPT-5 Codex | Implemented component-first UI extraction across app screens, split YouTube connect UI from flow helpers, wired runtime theme mode to persisted settings, and added focused widget/provider tests. | implemented | `/sf-verify ReplayGlowz App Component-First UI Refactor` |
| 2026-05-17 09:36:18 UTC | sf-verify | GPT-5 Codex | Re-ran local Flutter checks, inspected component/theme/test changes, fixed a sliver loading skeleton constraint risk, and evaluated ship-readiness gates. | partial: local checks pass, but Vercel preview/manual QA and an active high YouTube/auth bug gate remain. | `/sf-ship ReplayGlowz App Component-First UI Refactor` |

## Current Chantier Flow

| Step | Status | Notes |
|------|--------|-------|
| sf-spec | done | Draft spec updated with user decisions on theme wiring and widget tests. |
| sf-ready | ready | Spec has no blocking open questions and has explicit scope, validation, security, docs, and execution boundaries. |
| sf-start | done | Component layer extracted and integrated across targeted app screens; local analyze/test checks passed. |
| sf-verify | partial | Local analyze/test/metadata lint pass; Vercel preview/manual compact-wide QA and high YouTube/auth bug retest remain before ship-readiness. |
| sf-end | pending | Close documentation/bookkeeping after implementation. |
| sf-ship | next | Push a preview for hosted/browser validation if the user wants to continue toward ship-readiness. |
