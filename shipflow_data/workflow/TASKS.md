# Tasks — replayglowz

## Audit: Deps

| Pri | Task | Status |
|-----|------|--------|
| ✅ | Remove beta auth packages `clerk_flutter` / `clerk_auth` and replace the disabled path with stable Firebase Auth | ✅ done |
| ✅ | Remove unused Flutter codegen packages: `riverpod_annotation`, `build_runner`, and `riverpod_generator` | ✅ done |
| ✅ | Upgrade direct non-beta dependencies to latest resolvable versions, including `go_router`, `sentry_flutter`, and `flutter_lints` | ✅ done |
| 🟠 | Validate Firebase Auth, Convex token acceptance, and YouTube OAuth on the deployed Vercel/Convex environment | ⏳ pending `/sf-prod` |

## Documentation Governance

| Pri | Task | Status |
|-----|------|--------|
| 🟠 | Align root and subproject ShipFlow docs under canonical `shipflow_data/` paths | ✅ done |

## Audit: Perf

| Pri | Task | Status |
|-----|------|--------|
| ✅ | Remove unused `replayglowz_site/public/professional-headshot-*.png` payloads that were copied into every static build despite having no source references | ✅ done |
| ✅ | Remove global `lenis` smooth-scroll dependency and layout script so the Astro site build emits no client JavaScript chunks | ✅ done |
| ✅ | Batch `youtube:fetchPlaylistItems` calls in `syncAllPlaylists` instead of waiting for each playlist sync sequentially | ✅ done |
| ✅ | Defer the all-notes subscription on `VideosScreen` until the Notes view is active | ✅ done |
| ✅ | Gate `PlayScreen` transcript subscriptions to the active Transcript tab and avoid the normal full-library videos subscription during play render | ✅ done |
| ✅ | Self-host/subset the Google and Cal Sans font stack to remove remaining render-blocking remote font CSS | ✅ done |
| 🟡 | Evaluate transcript worker preflight/download duplication if `/transcribe` latency becomes an operational bottleneck | 📋 todo |

## Audit: Design

| Pri | Task | Status |
|-----|------|--------|
| 🟠 | Open a spec to align public marketing claims, pricing, AI/security badges, and social proof with the product and claim-register evidence | ⏳ pending `/sf-spec ReplayGlowz public design and claim alignment` |
| 🟠 | Wire persisted app theme settings into `themeModeProvider` or remove the non-functional selector until the preference changes the UI | 📋 todo |
| 🟡 | Consolidate site/app design tokens for typography, radius, color roles, focus states, and motion so both surfaces feel like one product | 📋 todo |
