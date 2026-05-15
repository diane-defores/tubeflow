# Audit Log

| Date       | Scope | Code | Design | Copy | SEO | GTM | Translate | Deps | Perf | Overall | Issues |
|------------|-------|------|--------|------|-----|-----|-----------|------|------|---------|--------|
| 2026-05-10 | Deps  | —    | —      | —    | —   | —   | —         | C    | —    | C       | 0 critical / 0 high / 3 moderate security findings; 5 medium hygiene/config follow-ups |
| 2026-05-11 | Documentation layout | — | — | — | — | — | — | — | — | Pass | Root and subproject ShipFlow docs migrated under `shipflow_data/`; competitor registry created; metadata lint passed |
| 2026-05-11 | Deps: replayglowz_app | — | — | — | — | — | — | B- | — | B- | 0 OSV/Pub advisories; 0 critical / 0 high / 3 medium follow-ups: Clerk beta auth patch, unused codegen deps, Sentry/lints major lanes |
| 2026-05-11 | Deps fix: replayglowz_app | — | — | — | — | — | — | A- | — | A- | Beta Clerk SDKs removed and sign-in disabled; direct deps current; Flutter analyze/build web passed |
| 2026-05-14 | Perf: monorepo | — | — | — | — | — | — | — | A- | A- | 0 critical / 0 high open / 2 medium follow-ups; fixed unused 6.0 MB site payload, global Lenis JS, app playlist-sync waterfall, and eager notes subscription |
