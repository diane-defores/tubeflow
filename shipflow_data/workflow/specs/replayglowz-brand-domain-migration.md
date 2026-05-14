---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "tubeflow-flutter"
created: "2026-05-14"
created_at: "2026-05-14 16:40:28 UTC"
updated: "2026-05-14"
updated_at: "2026-05-14 21:06:33 UTC"
status: ready
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: "brand-domain-migration"
owner: "Diane"
user_story: "As the ReplayGlowz maintainer, I want the monorepo brand, domains, deployment configuration, SEO surfaces, i18n copy, and operational docs migrated from TubeFlow/tubeflow to ReplayGlowz/replayglowz so main is the single aligned source of truth before creating a dedicated preview development branch for the app."
confidence: "high"
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "tubeflow_app"
  - "tubeflow_site"
  - "tubeflow_lab"
  - "Vercel"
  - "Firebase Auth"
  - "Google YouTube OAuth"
  - "Convex"
  - "Astro SEO"
depends_on:
  - artifact: "shipflow_data/business/branding.md"
    artifact_version: "0.1.0"
    required_status: "unknown"
  - artifact: "shipflow_data/business/business.md"
    artifact_version: "0.1.0"
    required_status: "unknown"
  - artifact: "shipflow_data/business/product.md"
    artifact_version: "0.1.0"
    required_status: "unknown"
  - artifact: "shipflow_data/business/gtm.md"
    artifact_version: "0.1.0"
    required_status: "unknown"
  - artifact: "shipflow_data/technical/architecture.md"
    artifact_version: "0.1.0"
    required_status: "unknown"
  - artifact: "shipflow_data/technical/guidelines.md"
    artifact_version: "0.1.0"
    required_status: "unknown"
  - artifact: "shipflow_data/editorial/content-map.md"
    artifact_version: "0.1.0"
    required_status: "unknown"
supersedes: []
evidence:
  - "Branch `main` is clean and aligned with `origin/main` after commit `ad88665`."
  - "Branch `previewdev` currently diverges from `main` with app-only commits `ec9ed53` and `2883a3a`; it must not be the source of truth for the global migration."
  - "`tubeflow_site/src/config/site.ts` defaults to `https://tubeflow.winflowz.com` and `https://app.tubeflow.winflowz.com`."
  - "`tubeflow_app/build.sh`, `.env.example`, OAuth handlers, PWA files, and diagnostics still expose `TUBEFLOW_*`, `TubeFlow`, and `tubeflow_*` names."
  - "`tubeflow_lab/server.py`, Docker/PM2 docs, and worker docs still expose TubeFlow/tubeflow names."
  - "Official Vercel monorepo docs consulted: https://vercel.com/docs/monorepos/"
  - "Official Vercel environment docs consulted: https://vercel.com/docs/environment-variables"
  - "Official Astro environment variable docs consulted: https://docs.astro.build/en/guides/environment-variables/"
next_step: "/sf-verify ReplayGlowz brand and domain migration"
---

# Title

ReplayGlowz Brand and Domain Migration

## Status

Verified locally and closed for main-branch shipping. This spec is intentionally created on `main`; implementation happened on `main` first. `previewdev` is a later app-preview branch and should be recreated or reset from the migrated `main` after the global rename is shipped and after explicit operator approval for any remote force-update.

## User Story

As the ReplayGlowz maintainer, I want the monorepo brand, domains, deployment configuration, SEO surfaces, i18n copy, and operational docs migrated from TubeFlow/tubeflow to ReplayGlowz/replayglowz so `main` is the single aligned source of truth before creating a dedicated preview development branch for the app.

## Minimal Behavior Contract

When a user, crawler, operator, or deployment reads any public app surface, marketing page, metadata file, URL config, worker label, or project guidance in this monorepo, it should present ReplayGlowz as the active product and use `replayglowz.com` / `app.replayglowz.com` as the canonical public domains; legacy TubeFlow names should remain only where explicitly required for backward compatibility, source history, external package identity, or migration notes. If a migration step cannot be completed safely because it would break auth, OAuth callbacks, package imports, existing local state, or branch history, the implementation must preserve compatibility and document the remaining legacy alias. The easiest edge case to miss is renaming storage, cookie, env, package, or branch identifiers without a fallback, which would silently break existing users or Vercel preview/prod deployments.

## Success Behavior

- Preconditions: work starts on clean `main`, not `previewdev`; `previewdev` may exist but is not used as the global rename source.
- Trigger: implementation of this spec updates brand, URL, SEO, i18n, docs, deployment config, and worker labels across `tubeflow_app`, `tubeflow_site`, `tubeflow_lab`, and root `shipflow_data`.
- User-visible result: app UI, PWA metadata, marketing pages, legal pages, blog metadata, EN/FR copy, and diagnostics say ReplayGlowz except where a legacy compatibility note is deliberate.
- Operator-visible result: README/AGENT/CLAUDE docs, env examples, worker docs, Sentry release labels, Vercel config notes, and branch guidance align on ReplayGlowz naming and domains.
- System effect: app/site defaults point to `https://replayglowz.com` and `https://app.replayglowz.com`; OAuth origin/callback behavior stays same-domain safe; old local storage or cookie keys are migrated or retained as read fallbacks before being removed.
- Proof: focused `rg` checks show no accidental TubeFlow/tubeflow references outside allowlisted package/import paths and migration notes; Flutter analyze/build, Astro build, Python compile, metadata lint, and OAuth helper tests/checks pass where available.

## Error Behavior

- If a TubeFlow/tubeflow occurrence cannot be safely renamed because it is a Dart package name, import path, existing backend contract, historical spec title, or branch reference, leave it and add it to an explicit allowlist in the implementation notes or verification report.
- If Vercel, Firebase, Google OAuth, or Convex configuration still uses old environment names in production, the app must continue accepting the legacy variables as fallbacks during this migration instead of failing silently.
- If local user state exists under old keys, code must read/migrate it to the ReplayGlowz key where feasible; it must not discard drafts, preferences, or OAuth handoff state without a documented reason.
- If a validation command fails, do not continue to branch-reset or previewdev recreation. Fix the rename or document the blocker before shipping.
- Never log secrets, Firebase ID tokens, OAuth tokens, Convex auth tokens, Google client secrets, or full environment values while adding diagnostics.

## Problem

The repository still presents itself as TubeFlow across app UI, Astro SEO, docs, worker labels, env names, URLs, storage keys, Sentry labels, and branch/deployment assumptions. The active product direction is ReplayGlowz, and `main` must become the canonical aligned source before creating a Vercel-oriented `previewdev` branch for app development. Keeping the rename partially on `previewdev` creates drift: Vercel preview setup, docs, and product surfaces could disagree about what is canonical.

## Solution

Perform the global rename on `main` in ordered passes: establish naming/domain constants and compatibility rules, update app surfaces and compatibility fallbacks, update site SEO/i18n/content, update worker and operational docs, update root/subproject ShipFlow contracts, then validate residual legacy references against an allowlist. After `main` is shipped, recreate or reset `previewdev` from `main` and only then apply app-development changes there.

## Scope In

- Root guidance and ShipFlow contracts under `AGENT.md`, `README.md`, and `shipflow_data/**`.
- Flutter app visible copy, PWA metadata, web bootstrap metadata, diagnostics, Sentry release labels, `.env.example`, `build.sh`, Vercel config, YouTube OAuth helper naming, cookie/storage compatibility, and app-local ShipFlow docs.
- Astro site `src/config/site.ts`, layouts, JSON-LD, Open Graph, RSS/feed metadata, page titles/descriptions, compare page internal keys, EN/FR i18n, blog authors/CTA copy, legal copy, README/AGENT/CLAUDE docs, and package name when safe.
- Transcript worker app name, logger/temp prefixes where safe, Docker/PM2 examples, README/AGENT/CLAUDE docs, worker-local ShipFlow docs.
- Branch policy: keep implementation on `main`; later reset/recreate `previewdev` from `main` for app-only Vercel preview work.
- Validation and allowlisting of intentional legacy occurrences.

## Scope Out

- Do not implement feature changes unrelated to the rename.
- Do not change Convex schema, backend functions, YouTube OAuth scope, Firebase auth provider semantics, or transcript worker HTTP request/response contracts.
- Do not rename the `tubeflow_app`, `tubeflow_site`, or `tubeflow_lab` directories in this pass unless a later explicit repo-structure decision is made.
- Do not rename the Dart package/import namespace `package:tubeflow_app/...` in this pass; that is a higher-risk package identity refactor.
- Do not delete remote `origin/previewdev` during implementation. Recreate/reset preview branch only after `main` is migrated and shipped.
- Do not include the previously mentioned `apps/web/src/app/layout.tsx` dynamic-import/static-import change in this spec. That file is not present in this monorepo; if it exists in another repo, it needs a separate spec because it is behavioral, not a brand rename.

## Constraints

- Work from clean `main`; do not use `previewdev` as the base for implementation.
- Preserve build/runtime compatibility for legacy env names during the migration: `TUBEFLOW_APP_URL`, `TUBEFLOW_WEB_URL`, `NEXT_PUBLIC_APP_URL`, and current OAuth compatibility names may remain as fallback inputs while preferred ReplayGlowz names are introduced.
- Preserve OAuth state validation, return URL sanitization, cookie cleanup, Firebase token handling, and Convex mutation behavior.
- Preserve Astro content frontmatter schema; do not add ShipFlow metadata to `tubeflow_site/src/content/**`.
- Keep user-facing French copy natural and accented where edited.
- Treat historical changelog/spec names as possible allowlisted legacy references rather than blindly rewriting past evidence.
- Use ASCII in new technical docs unless existing content requires non-ASCII for user-facing French.

## Dependencies

- Flutter app: Dart/Flutter web, Firebase Auth, Convex client, Vercel serverless OAuth handlers, `shared_preferences`, Sentry.
- Astro site: Astro 6, `import.meta.env.PUBLIC_*` env exposure, static SEO generation, RSS/feed generation.
- Worker: FastAPI/Uvicorn Python service, Docker/PM2 docs, temp directory behavior.
- Vercel: monorepo projects can set a project root directory; pushing to a repo can trigger connected projects; environment variables are scoped by environment and custom environment settings.
- Fresh docs checked:
  - Vercel monorepos: https://vercel.com/docs/monorepos/
  - Vercel environment variables: https://vercel.com/docs/environment-variables
  - Astro environment variables: https://docs.astro.build/en/guides/environment-variables/

## Invariants

- `main` is the global rename source of truth.
- `previewdev` is disposable/recreatable after `main` is migrated.
- App auth, OAuth, Convex data access, transcript response shape, and site routing behavior must not change as a side effect of the rename.
- Legacy names may remain only when they are technical compatibility names, package/import identity, historical records, or explicitly documented migration notes.
- No committed file may contain real secrets or tokens.

## Links & Consequences

- Vercel app project should use `tubeflow_app` as Root Directory until directory renaming is explicitly scoped.
- Vercel site project should use `tubeflow_site` as Root Directory if connected; its canonical URL defaults move to ReplayGlowz.
- Google OAuth redirect URIs must include the active app domain callback: `https://app.replayglowz.com/api/auth/youtube/callback`.
- Firebase authorized domains must include `app.replayglowz.com` before hosted auth validation.
- Convex auth/env config must remain compatible with Firebase token issuer and deployment envs.
- SEO canonical URLs, Open Graph, JSON-LD, hreflang, RSS, legal pages, and blog metadata change publicly and should be verified by build output or source checks.
- Existing users may have browser state under legacy keys; state migration or read fallback prevents unnecessary data loss.
- Branch cleanup after shipping may require deleting/recreating local `previewdev` and possibly force-updating remote `previewdev`, but that must be a separate explicit ship step after `main` is clean.

## Documentation Coherence

- Update root `README.md`, `AGENT.md`, and `shipflow_data/**` for ReplayGlowz naming, domains, branch policy, and source-of-truth guidance.
- Update `tubeflow_app/README.md`, `AGENT.md`, `CLAUDE.md`, `.env.example`, and app-local ShipFlow docs for preferred `REPLAYGLOWZ_*` env names with `TUBEFLOW_*` fallbacks documented.
- Update `tubeflow_site/README.md`, `AGENT.md`, `CLAUDE.md`, site config docs, public copy, i18n, blog metadata, pricing, compare, privacy, and terms.
- Update `tubeflow_lab/README.md`, `AGENT.md`, `CLAUDE.md`, and worker-local ShipFlow docs for ReplayGlowz naming while preserving the worker contract.
- Update changelogs only if implementation changes shipped behavior or operator setup commands; do not rewrite historical release entries unless they are active docs.

## Edge Cases

- Legacy `TUBEFLOW_APP_URL` is still set in Vercel while new `REPLAYGLOWZ_APP_URL` is absent.
- A user has a feedback draft stored under `tubeflow_feedback_text_draft`.
- OAuth callback returns with old cookie name `tubeflow_youtube_firebase_id_token` after the start endpoint has been updated.
- `rg TubeFlow` finds historical changelog/spec evidence that should remain.
- `rg tubeflow` finds Dart import paths or directory names that must remain for now.
- Google OAuth redirect URI is updated in code but not in Google Cloud console.
- Firebase authorized domain is missing for `app.replayglowz.com`.
- A Vercel monorepo project deploys the site or worker when only app changes were expected after branch recreation.

## Implementation Tasks

- [x] Task 1: Establish migration constants and compatibility policy.
  - File: `shipflow_data/workflow/specs/replayglowz-brand-domain-migration.md`
  - Action: During implementation, keep an allowlist note for intentional `TubeFlow`/`tubeflow` occurrences: directory names, Dart package imports, historical specs/changelogs, compatibility env/cookie keys, and external paths.
  - User story link: Prevents a naive rename from breaking package identity, history, or runtime compatibility.
  - Depends on: None.
  - Validate with: `rg -n "TubeFlow|tubeflow|TUBEFLOW" .` reviewed against the allowlist.
  - Notes: Do not use the allowlist to hide public-facing stale copy.

- [x] Task 2: Update root monorepo guidance and project contracts.
  - File: `AGENT.md`, `README.md`, `shipflow_data/business/*.md`, `shipflow_data/technical/*.md`, `shipflow_data/editorial/*.md`
  - Action: Rename public product references to ReplayGlowz, update domains, explain that `main` owns global migration and `previewdev` will be recreated/reset from `main` for app-only preview development.
  - User story link: Makes `main` the aligned source of truth.
  - Depends on: Task 1.
  - Validate with: `/home/claude/shipflow/tools/shipflow_metadata_lint.py AGENT.md shipflow_data`.
  - Notes: Preserve stable section headings and frontmatter keys.

- [x] Task 3: Update Flutter app brand-visible metadata and copy.
  - File: `tubeflow_app/web/manifest.json`, `tubeflow_app/web/index.html`, `tubeflow_app/lib/main.dart`, `tubeflow_app/lib/app/theme.dart`, `tubeflow_app/lib/i18n/en.dart`, `tubeflow_app/lib/i18n/fr.dart`, `tubeflow_app/lib/screens/**`, `tubeflow_app/lib/widgets/**`
  - Action: Replace user-visible TubeFlow strings with ReplayGlowz and update diagnostics labels that are visible to operators.
  - User story link: Users and operators see the active product brand.
  - Depends on: Task 1.
  - Validate with: `cd tubeflow_app && flutter analyze`.
  - Notes: Do not rename Dart classes/package imports unless necessary for visible copy.

- [x] Task 4: Introduce ReplayGlowz app URL env names with fallbacks.
  - File: `tubeflow_app/build.sh`, `tubeflow_app/lib/app/build_info.dart`, `tubeflow_app/lib/widgets/youtube_connect.dart`, `tubeflow_app/.env.example`, `tubeflow_app/README.md`, `tubeflow_app/AGENT.md`, `tubeflow_app/CLAUDE.md`
  - Action: Prefer `REPLAYGLOWZ_APP_URL` or a clearly chosen new name while continuing to accept `TUBEFLOW_APP_URL` and `TUBEFLOW_WEB_URL` as compatibility fallbacks; update default app URL to `https://app.replayglowz.com`.
  - User story link: Deployment config moves to ReplayGlowz without breaking existing Vercel envs.
  - Depends on: Task 3.
  - Validate with: `cd tubeflow_app && bash -n build.sh && flutter analyze`.
  - Notes: Keep `NEXT_PUBLIC_*` fallbacks only where currently supported and documented.

- [x] Task 5: Update OAuth cookie/storage compatibility.
  - File: `tubeflow_app/api/auth/_youtube.js`, `tubeflow_app/api/auth/youtube.js`, `tubeflow_app/api/auth/youtube/callback.js`, `tubeflow_app/lib/screens/feedback/feedback_service.dart`
  - Action: Rename preferred cookie/storage keys to ReplayGlowz names while reading/clearing legacy TubeFlow keys during the migration window.
  - User story link: Existing users and OAuth flows survive the brand migration.
  - Depends on: Task 4.
  - Validate with: `cd tubeflow_app && node --test api/auth/_youtube.test.js` if present, otherwise run targeted syntax/import checks plus `flutter analyze`.
  - Notes: Do not log Firebase ID tokens or OAuth tokens. Preserve SameSite, HttpOnly, Secure, Max-Age, state validation, and return URL sanitization.

- [x] Task 6: Update app observability and technical labels.
  - File: `tubeflow_app/lib/app/build_info.dart`, `tubeflow_app/lib/main.dart`, `tubeflow_app/lib/convex/convex_client.dart`, `tubeflow_app/web/convex_bridge.js`
  - Action: Update Sentry release default, Sentry context keys, Convex client ID, script IDs, and operator diagnostics to ReplayGlowz names where safe.
  - User story link: Operator tooling and logs no longer imply the old product brand.
  - Depends on: Task 4.
  - Validate with: `cd tubeflow_app && flutter analyze && flutter build web`.
  - Notes: Preserve bridge behavior and generated Flutter web assumptions.

- [x] Task 7: Update Astro site URLs, SEO, i18n, and content.
  - File: `tubeflow_site/src/config/site.ts`, `tubeflow_site/src/layouts/Layout.astro`, `tubeflow_site/src/i18n/*.ts`, `tubeflow_site/src/components/*.astro`, `tubeflow_site/src/pages/**/*.astro`, `tubeflow_site/src/pages/blog/feed.xml.ts`, `tubeflow_site/src/content/blog/*.md`
  - Action: Replace TubeFlow public copy with ReplayGlowz, update default canonical/app URLs to `https://replayglowz.com` and `https://app.replayglowz.com`, update JSON-LD/Open Graph/RSS/legal/blog metadata, and rename compare-page internal keys from `tubeflow` to `replayglowz` where they are not external contracts.
  - User story link: Public SEO and acquisition surfaces match the active product.
  - Depends on: Task 1.
  - Validate with: `cd tubeflow_site && npm run build`.
  - Notes: Preserve Astro content frontmatter schema.

- [x] Task 8: Update Astro site docs and package metadata.
  - File: `tubeflow_site/package.json`, `tubeflow_site/README.md`, `tubeflow_site/AGENT.md`, `tubeflow_site/CLAUDE.md`, `tubeflow_site/shipflow_data/**`
  - Action: Rename package/docs/project copy to ReplayGlowz where safe, document `PUBLIC_SITE_URL=https://replayglowz.com` and `PUBLIC_APP_URL=https://app.replayglowz.com`.
  - User story link: Operators configure the site with the correct domains.
  - Depends on: Task 7.
  - Validate with: `cd tubeflow_site && npm run build`.
  - Notes: Keep directory names unchanged.

- [x] Task 9: Update transcript worker labels and docs.
  - File: `tubeflow_lab/server.py`, `tubeflow_lab/ecosystem.config.cjs`, `tubeflow_lab/README.md`, `tubeflow_lab/AGENT.md`, `tubeflow_lab/CLAUDE.md`, `tubeflow_lab/shipflow_data/**`
  - Action: Rename app name, logger/temp prefixes where safe, Docker image examples, PM2 labels, and docs from TubeFlow to ReplayGlowz.
  - User story link: Backend worker operations match the active product.
  - Depends on: Task 1.
  - Validate with: `cd tubeflow_lab && python -m py_compile main.py server.py`.
  - Notes: Preserve `/transcribe` request/response contract and provider names such as `youtube_captions`.

- [ ] Task 10: Reconcile `previewdev` branch after `main` ships.
  - File: Git branch state, no source file unless a branch note is added to docs.
  - Action: After `main` migration is committed and pushed, decide whether to delete/recreate local `previewdev` or reset it from `origin/main`; only force-update remote `previewdev` after explicit operator approval.
  - User story link: Future app development branch starts from the migrated source of truth.
  - Depends on: All implementation tasks shipped on `main`.
  - Validate with: `git log --oneline --decorate --graph main previewdev -8` and `git status --short`.
  - Notes: Current `previewdev` has app commits `ec9ed53` and `2883a3a`; review whether to cherry-pick their useful app changes onto `main` before branch reset.

- [x] Task 11: Final residual-reference audit.
  - File: Whole repository.
  - Action: Run targeted searches for `TubeFlow`, `tubeflow`, `TUBEFLOW`, old domains, `ReplayGlowz`, `replayglowz`, and new env/cookie/storage names; classify each legacy hit as fixed, intentional compatibility, historical, or out of scope.
  - User story link: Prevents partial migration from shipping unnoticed.
  - Depends on: Tasks 2-10.
  - Validate with: `rg -n "TubeFlow|tubeflow|TUBEFLOW|tubeflow\\.winflowz\\.com|app\\.tubeflow\\.winflowz\\.com" .`.
  - Notes: The verification report must include the allowlist summary.

## Acceptance Criteria

- [x] CA 1: Given a clean checkout of `main`, when the migration is implemented, then root docs and ShipFlow contracts identify ReplayGlowz as the active product and explain the `main`-first branch strategy.
- [x] CA 2: Given the Flutter app build metadata and PWA files, when searched for user-visible TubeFlow strings, then visible app metadata and copy use ReplayGlowz.
- [x] CA 3: Given Vercel envs still use `TUBEFLOW_APP_URL`, when the app is built, then the build continues to resolve the app origin through legacy fallback while documenting the ReplayGlowz preferred env name.
- [x] CA 4: Given a user has a feedback draft under `tubeflow_feedback_text_draft`, when feedback draft storage is accessed after migration, then the value is read or migrated instead of being silently lost.
- [x] CA 5: Given an OAuth flow starts before or during the cookie-key migration, when Google redirects back, then state validation and Firebase token handoff still complete or fail with a recoverable user-facing error.
- [x] CA 6: Given the Astro site build, when generated source is inspected through config and page metadata, then canonical/app URLs point to `https://replayglowz.com` and `https://app.replayglowz.com`.
- [x] CA 7: Given EN/FR marketing copy and legal pages, when searched for old brand copy, then no public-facing TubeFlow references remain except explicit historical or compatibility notes.
- [x] CA 8: Given the transcript worker is compiled, when its API contract is checked, then the rename has not changed `/transcribe` request fields, response fields, provider semantics, or error status codes.
- [x] CA 9: Given the residual-reference audit, when legacy hits remain, then each is recorded as intentional package/import identity, directory path, compatibility fallback, historical evidence, or out of scope.
- [ ] CA 10: Given `main` is shipped, when `previewdev` is prepared later, then it is recreated/reset from the migrated `main` only after explicit confirmation about preserving or dropping its current app commits.

## Test Strategy

- Root governance: `/home/claude/shipflow/tools/shipflow_metadata_lint.py AGENT.md shipflow_data`.
- Flutter app: `cd tubeflow_app && bash -n build.sh && flutter analyze && flutter build web`.
- OAuth helper: run `node --test api/auth/_youtube.test.js` if the test exists; otherwise use targeted source review plus hosted OAuth validation after deployment.
- Astro site: `cd tubeflow_site && npm run build`.
- Worker: `cd tubeflow_lab && python -m py_compile main.py server.py`.
- Residual audit: `rg -n "TubeFlow|tubeflow|TUBEFLOW|tubeflow\\.winflowz\\.com|app\\.tubeflow\\.winflowz\\.com" .` plus allowlist review.
- Branch verification: `git status --short`, `git branch --show-current`, and branch graph comparison before touching `previewdev`.
- Hosted validation after ship: Vercel deployment checks for app/site domains, OAuth start/callback behavior, Firebase authorized domain, Google OAuth redirect URI, and Convex env readiness.

## Risks

- High SEO risk: wrong canonical URLs, OG tags, JSON-LD, RSS, or hreflang could split indexing between old and new domains.
- High auth/OAuth risk: changing env names, app origin, redirect URI, or cookie names can break YouTube connection.
- Medium data-loss risk: renaming local storage/shared preference keys can drop feedback drafts or preferences.
- Medium deployment risk: Vercel monorepo projects can deploy multiple roots from the same branch if project settings are not scoped correctly.
- Medium operational risk: old worker Docker/PM2 names in docs can cause operators to run or monitor the wrong process.
- Medium branch risk: resetting `previewdev` without reviewing its two current commits can lose useful app env/OAuth rename work.
- Low package risk if directory/package names are left unchanged; high package risk if they are renamed without a dedicated refactor.

## Execution Notes

- Read first: `tubeflow_site/src/config/site.ts`, `tubeflow_app/build.sh`, `tubeflow_app/lib/app/build_info.dart`, `tubeflow_app/api/auth/_youtube.js`, `tubeflow_lab/server.py`.
- Implementation order: docs/constants and allowlist, app visible/env/OAuth compatibility, site SEO/i18n/content, worker labels/docs, root and subproject ShipFlow docs, validation and residual audit.
- Use structured code changes and existing constants/helpers. Avoid a blind repository-wide replacement.
- Keep legacy fallbacks for env/cookie/storage keys during this migration. Prefer adding new ReplayGlowz names and reading old names as fallback.
- Do not rename directories or Dart import package identity in this pass.
- Do not delete or force-push `previewdev` during implementation. Branch cleanup is a separate explicit step after `main` is shipped.
- Stop conditions: OAuth state/cookie behavior becomes unclear; Google/Firebase/Convex required hosted config cannot be verified; residual `TubeFlow` hits cannot be classified; or implementation touches non-rename behavior such as `layout.tsx` dynamic import semantics.
- Fresh external docs verdict: `fresh-docs checked` for Vercel monorepo/environment behavior and Astro public env behavior; `fresh-docs not needed` for purely local string/copy replacements.

## Open Questions

None. Decisions captured for this spec: implement the global migration on `main`; keep directory and Dart package names unchanged for now; keep legacy env/cookie/storage fallbacks; handle `previewdev` only after `main` is migrated and shipped.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-14 16:40:28 UTC | sf-spec | GPT-5 Codex | Created `main`-first ReplayGlowz brand/domain migration spec after scanning branch state, app/site/worker surfaces, legacy keys, and Vercel/Astro docs. | Draft spec saved. | `/sf-ready ReplayGlowz brand and domain migration` |
| 2026-05-14 16:56:14 UTC | sf-ready | GPT-5 Codex | Evaluated structure, metadata, user-story alignment, ambiguity, task ordering, docs coherence, fresh external docs, adversarial risks, and security posture. | Ready: no blocking ambiguity; OAuth/env/storage/SEO/branch risks are explicitly scoped with validations and stop conditions. | `/sf-start ReplayGlowz brand and domain migration` |
| 2026-05-14 21:06:33 UTC | sf-build | GPT-5 Codex | Implemented the main-branch ReplayGlowz rename across root governance docs, Flutter app branding/env/OAuth/storage, Astro SEO/i18n/content, worker labels/docs, and changelogs; ran local validation and residual audit. | Implemented locally; validation passed. `previewdev` reconciliation remains intentionally deferred until after main is shipped. | `/sf-verify ReplayGlowz brand and domain migration` |
| 2026-05-14 21:33:40 UTC | sf-verify | GPT-5 Codex | Re-ran local validation: metadata lint, OAuth helper tests, `bash -n`, `flutter analyze`, `flutter build web`, Astro build, Python compile, and residual-reference audit. | Passed locally. Hosted OAuth/Firebase/Vercel evidence remains post-ship. | `/sf-end ReplayGlowz brand and domain migration` |
| 2026-05-14 21:33:40 UTC | sf-end | GPT-5 Codex | Closed the main-branch migration scope with documentation and changelog updates already included in app/site/worker changes. | Closed for bounded ship; `previewdev` reconciliation remains deferred. | `/sf-ship ReplayGlowz brand and domain migration` |

## Current Chantier Flow

| Step | Status | Notes |
|------|--------|-------|
| sf-spec | done | Draft spec created on `main`. |
| sf-ready | ready | Spec passed readiness gate on 2026-05-14. |
| sf-start | implemented | Implementation completed locally through `sf-build`; changes remain unshipped. |
| sf-verify | passed | Local checks passed; residual legacy references are allowlisted as directory/package/import identity, compatibility fallbacks, historical specs/changelogs, or explicit migration notes. |
| sf-end | closed | Main-branch migration scope closed locally; hosted validation remains post-ship. |
| sf-ship | ready | Ship `main` first; handle `previewdev` after explicit operator approval. |

Next command: `/sf-ship ReplayGlowz brand and domain migration`
