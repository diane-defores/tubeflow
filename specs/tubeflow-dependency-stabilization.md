---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "tubeflow-flutter"
created: "2026-05-10"
created_at: "2026-05-10 21:05:58 UTC"
updated: "2026-05-10"
updated_at: "2026-05-10 21:39:16 UTC"
status: active
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: "audit-fix"
owner: "Diane"
user_story: "As the TubeFlow maintainer, I want the Flutter app, Astro site, and transcript worker dependencies patched, pinned, audited, and automatically monitored so security fixes and deploys are reproducible without weakening runtime behavior."
confidence: "high"
risk_level: "medium"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "tubeflow_app"
  - "tubeflow_site"
  - "tubeflow_lab"
  - "GitHub Actions"
  - "Vercel"
  - "Docker"
  - "Dependabot"
depends_on:
  - artifact: "AGENT.md"
    artifact_version: "0.1.0"
    required_status: "draft"
  - artifact: "shipflow_data/business/business.md"
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
  - "2026-05-10 sf-deps audit: overall dependency score C with 0 critical, 0 high, 3 moderate security findings and 5 medium hygiene/config follow-ups."
  - "tubeflow_site/npm audit --json reports GHSA-j687-52p2-xcff for astro <6.1.6 and GHSA-qx2v-qp2m-jg93 for postcss <8.5.10."
  - "GitHub Advisory Database: https://github.com/advisories/GHSA-j687-52p2-xcff"
  - "GitHub Advisory Database: https://github.com/advisories/GHSA-qx2v-qp2m-jg93"
  - "tubeflow_lab/pip-audit -r requirements.txt --no-deps --disable-pip -f json reports CVE-2026-25645 / GHSA-gc5v-m9x4-r6x2 for requests==2.32.5, fixed in 2.33.0."
  - "Requests vendor advisory: https://github.com/psf/requests/security/advisories/GHSA-gc5v-m9x4-r6x2"
  - "tubeflow_app/flutter pub outdated --json reports no current pub advisories but multiple patch/minor/major upgrade lanes."
  - "No .github/dependabot.yml, renovate.json, .node-version, .nvmrc, .python-version, pyproject.toml, uv.lock, Pipfile.lock, poetry.lock, or Python hash lockfile is present."
next_step: "/sf-ship TubeFlow dependency stabilization --bounded-scope"
---

# Title

TubeFlow Dependency Stabilization

# Status

active

# User Story

As the TubeFlow maintainer, I want the Flutter app, Astro site, and transcript worker dependencies patched, pinned, audited, and automatically monitored so security fixes and deploys are reproducible without weakening runtime behavior.

# Minimal Behavior Contract

When dependency maintenance is triggered from this spec, the system updates only compatible dependency ranges and lockfiles needed to close the known Astro/PostCSS and Requests advisories, adds reviewed automation for future updates, pins the package/tool versions that currently drift across Vercel, GitHub Actions, local Flutter, npm, and Python worker builds, and records a repeatable audit path. A successful run leaves the app, site, and worker buildable from clean installs with security scanners clean for the targeted advisories. If an update breaks a build, runtime contract, or major-version boundary, the change stops with the dependency reverted or isolated, the failure documented, and the remaining upgrade routed to `/sf-migrate`. The easy-to-miss edge case is that Python direct pins are not a reproducible worker image: transitive dependencies must be locked or hash-checked, otherwise a clean Docker build can differ from the audited local environment.

# Success Behavior

- Starting from the current audit state, `tubeflow_site` upgrades within the Astro 6 and PostCSS 8 lines so `npm audit --json` no longer reports GHSA-j687-52p2-xcff or GHSA-qx2v-qp2m-jg93.
- `tubeflow_site/package-lock.json` remains the committed npm lockfile, `npm run build` succeeds, and public SEO/i18n content behavior remains unchanged.
- `tubeflow_lab` upgrades `requests` to at least `2.33.0` and uses a deterministic install path for the worker, preferably `requirements.in` plus a generated hash-checked lock file installed by Docker and documented for operators.
- `tubeflow_lab` keeps the `/transcribe` response contract: `entries`, `fullText`, `estimatedCostUsd`, `warnings`.
- `tubeflow_app` preserves its current app behavior while adding a repeatable dependency audit/update path and pinning the Flutter toolchain used by deployment and Android CI.
- `.github/dependabot.yml` covers npm for `tubeflow_site`, pip or pip-compile for `tubeflow_lab`, pub for `tubeflow_app`, GitHub Actions, and Docker base image updates, with review-friendly cadence and no silent automerge.
- Documentation names the exact commands maintainers should run after future dependency updates.

# Error Behavior

- If `npm audit fix` proposes a major upgrade or changes outside Astro/PostCSS patch/minor lanes, do not accept it automatically; document the blocker and route major work to `/sf-migrate`.
- If `requests>=2.33.0` or a generated Python lock breaks worker imports, OpenAI/Deepgram requests, local speech engines, or Docker install, preserve the current worker runtime contract and isolate the failure before changing production Docker install behavior.
- If Dependabot cannot cover one ecosystem cleanly, do not fake coverage; document the unsupported path and add a manual audit command for that ecosystem.
- If a toolchain pin conflicts with Vercel, GitHub Actions, or the local Flutter SDK, stop and choose one supported target explicitly instead of leaving `stable` or floating versions in place.
- Never weaken security controls to make checks pass: do not disable audits, ignore advisories without a written reason, remove lockfile integrity, skip install scripts review, or downgrade scanner severity.
- Never log, commit, or expose package-manager tokens, PyPI credentials, npm tokens, Vercel secrets, Clerk secrets, Convex URLs beyond public build-time values, OpenAI keys, Deepgram keys, or worker bearer secrets.

# Problem

The dependency audit found a cross-project maintenance gap in the canonical TubeFlow monorepo. The public Astro site has two moderate XSS advisories, the transcript worker pins a vulnerable Requests version, update automation is absent, and runtime/package-manager pins are incomplete. The risk is not one isolated package: dependency health currently depends on manual scans and moving toolchains, while the app, site, and worker all feed user-facing TubeFlow flows.

Source-de-chantier intake preserved from `sf-deps`:

- Titre propose: TubeFlow dependency stabilization
- Raison: cross-project dependency/security work spans the site, Flutter app, Python worker, CI/deploy tooling, and update automation.
- Severite: P2
- Scope: `tubeflow_site`, `tubeflow_app`, `tubeflow_lab`, CI/deploy dependency policy
- Spec recommandee: `/sf-spec TubeFlow dependency stabilization: patch Astro/PostCSS and requests advisories, add update automation, pin package/tool versions, and add reproducible Python locking/auditing`

# Solution

Stabilize dependencies in three layers: first patch the known security advisories without major upgrades, then add reproducible install and audit paths for each package ecosystem, then add monitored update automation with human review. Keep the behavioral surfaces unchanged: Flutter app routing/auth, Astro public content, and transcript worker request/response contracts must continue to work after the dependency changes.

# Scope In

- Patch `tubeflow_site` Astro/PostCSS advisories by updating `package.json` and `package-lock.json` within compatible major ranges.
- Patch `tubeflow_lab` Requests advisory by updating the worker dependency to `requests>=2.33.0,<3`.
- Add a reproducible Python lock strategy for the worker using `pip-tools` with a `requirements.in` direct-dependency source and a generated hash-checked lock file used by Docker and local install docs.
- Add a dependency audit command path for npm, pip, and pub.
- Add Dependabot configuration for `npm`, `pip`, `pub`, `github-actions`, and `docker` ecosystems.
- Pin or document the Node/npm package manager used by `tubeflow_site`.
- Pin the Flutter SDK channel/version used by Vercel and Android GitHub Actions so app deploys are not bound to a moving `stable`.
- Review likely unused Flutter dependencies and remove them only after import/usage verification and `flutter analyze` succeeds.
- Update README/AGENT/docs that describe install, dependency update, scan, or deploy commands.

# Scope Out

- Major framework migrations such as Astro 6 to a future major, OpenAI Python SDK 1 to 2, Flutter major toolchain migration, or Clerk beta SDK replacement.
- Rewriting the Flutter app architecture, Convex transport, Clerk auth flow, YouTube OAuth flow, or transcript worker provider behavior.
- Changing public marketing copy, pricing, SEO content, or blog frontmatter beyond dependency/build docs.
- Adding new product features, providers, queues, telemetry products, or release pipelines.
- Auto-merging dependency updates.
- Replacing Dependabot with Renovate unless Dependabot proves insufficient during implementation.

# Constraints

- Preserve the repository guidance in `AGENT.md`: subproject contracts are source evidence, Astro runtime content frontmatter must not receive ShipFlow metadata, and unrelated dirty files must not be touched.
- Preserve `tubeflow_app` boundaries: backend schema/functions stay out of this repo, Convex transport remains in `lib/convex/`, and build-time values stay `String.fromEnvironment(...)` backed.
- Preserve `tubeflow_site` SEO behavior: canonical URLs, `hreflang`, Open Graph tags, JSON-LD, and content collection schema must remain valid.
- Preserve `tubeflow_lab` worker contract: `POST /transcribe` returns `entries`, `fullText`, `estimatedCostUsd`, and `warnings`; `youtube_captions` remains out of worker scope.
- Do not weaken security controls, scanner visibility, lockfile integrity, or review gates.
- No major dependency upgrades without an explicit `/sf-migrate` lane.
- Python full transitive vulnerability proof requires a lock or a virtualenv-capable environment; direct `pip-audit --no-deps --disable-pip` is not enough to close the proof gap.

# Dependencies

- Local Node/npm: Node `v22.22.2`, npm `11.14.1`.
- Local Flutter/Dart: Flutter `3.41.7`, Dart `3.11.5`.
- Local Python: Python `3.12.3`; Docker worker image is aligned to `python:3.12-slim`.
- Local scanner: `pip-audit 2.10.0`.
- `tubeflow_site`: npm, Astro 6, Tailwind CSS 4, `package-lock.json`.
- `tubeflow_lab`: FastAPI, Uvicorn, Requests, yt-dlp, faster-whisper, OpenAI Python SDK, FunASR, Docker.
- `tubeflow_app`: Flutter, Dart pub, Clerk beta packages, Convex, Riverpod, GoRouter.
- Fresh external docs checked:
  - GitHub Advisory Database for Astro GHSA-j687-52p2-xcff: affected `<6.1.6`, patched `6.1.6`, moderate CWE-79 XSS.
  - GitHub Advisory Database for PostCSS GHSA-qx2v-qp2m-jg93: affected `<8.5.10`, patched `8.5.10`, moderate XSS.
  - Requests vendor advisory GHSA-gc5v-m9x4-r6x2: standard usage is not affected, direct `extract_zipped_paths()` use is affected, upgrade to at least `2.33.0`.
  - GitHub Docs Dependabot supported ecosystems: `npm`, `pip`, `pip-compile`, `pub`, `github-actions`, and `docker` are covered ecosystem values.
  - pip-tools docs v7.5.3: `requirements.in` can generate a pinned `requirements.txt`, `--generate-hashes` enables pip hash-checking mode, and `--upgrade-package` can target specific packages.
  - Dart docs: pubspec supports `dependencies`, `dev_dependencies`, `environment`, and `ignored_advisories`; `dart pub outdated` is the dependency currency command.
- Fresh-docs verdict: `fresh-docs checked`.

# Invariants

- The site build must remain static/marketing-focused and must still route conversion links through `src/config/site.ts`.
- The app deploy must still produce a Flutter web build in `build/web` for Vercel.
- The worker Docker image must still expose port `8090` and run `server.py`.
- Existing lockfiles remain committed and updated only by the relevant package manager.
- Every automated dependency update must produce a PR requiring human review.
- The final implementation must leave vulnerability scanners quieter because advisories are patched, not because advisory output is ignored.

# Links & Consequences

- `tubeflow_site/package.json` and `tubeflow_site/package-lock.json`: patch Astro/PostCSS and add package manager metadata.
- `tubeflow_site/README.md` and `tubeflow_site/CLAUDE.md`: align install commands to `npm ci` when lockfile-based installs are expected, plus audit/update commands.
- `tubeflow_lab/requirements.txt`: either becomes generated lock output or remains direct pins only if a separate lock file is introduced and Docker uses it.
- `tubeflow_lab/requirements.in`: direct worker dependencies source if pip-tools is adopted.
- `tubeflow_lab/requirements.lock` or generated `requirements.txt`: transitive hash-checked lock consumed by Docker and CI.
- `tubeflow_lab/Dockerfile`: install from the locked/hash-checked file and keep `ffmpeg` install behavior.
- `tubeflow_lab/README.md`: update local, Docker, and PM2 setup commands for the lock/audit strategy.
- `tubeflow_app/pubspec.yaml` and `tubeflow_app/pubspec.lock`: remove unused deps only after verification, and keep direct/runtime deps correctly placed.
- `tubeflow_app/vercel.json`: replace `git clone -b stable` with a pinned Flutter SDK strategy or an explicit documented stable version source.
- `tubeflow_app/.github/workflows/android-apk.yml`: pin Flutter action input beyond floating `stable` when feasible.
- `.github/dependabot.yml`: new root automation config with multiple directory entries.
- Root `README.md`, `AGENT.md`, `TASKS.md`: docs only if implementation changes command expectations; `sf-spec` itself does not update tasks.
- Downstream product consequences: fewer public XSS exposures on the marketing site, lower worker supply-chain drift, more predictable Flutter web/app builds, and less manual security monitoring.

# Documentation Coherence

- Update `tubeflow_site/README.md` if the preferred install command becomes `npm ci` and if dependency scanning commands are added.
- Update `tubeflow_lab/README.md` wherever it currently says `pip install -r requirements.txt`; it must name the authoritative locked install file and how to regenerate it.
- Update `tubeflow_lab/AGENT.md` only if the source-of-truth dependency file changes from `requirements.txt` to `requirements.in` plus lock.
- Update `tubeflow_app/README.md`, `tubeflow_app/AGENT.md`, or `tubeflow_app/CLAUDE.md` only if Flutter SDK pinning changes local/deploy commands.
- Update root `README.md` or `AGENT.md` only if monorepo-level dependency maintenance commands are added.
- Changelog entry is required if the implementation changes dependency versions, Docker install behavior, or CI automation.

# Edge Cases

- Astro advisory is most dangerous for SSR and `define:vars`; the current site is mostly static and no `define:vars` usage was found, but patching remains required because the public site ships the vulnerable framework version.
- PostCSS advisory depends on CSS stringification contexts; no exploit path was proven locally, but transitive exposure exists through the build chain.
- Requests CVE is limited for standard usage, but the worker uses `requests.post` on OpenAI/Deepgram paths and the package is direct; patching should not wait for a proven exploit path.
- `pip-audit -r requirements.txt` full resolution currently fails in this host when virtualenv creation needs `python3-venv`; implementation must either use a managed tool environment or hash lock strategy that lets audit run without ad hoc host packages.
- Hash-checked Python installs can fail when packages publish platform-specific wheels without all hashes; generation must be performed in a way that supports the Docker target platform.
- Dependabot `pub` support is community-maintained; if it opens noisy or unusable PRs, document that and fall back to scheduled manual `flutter pub outdated`.
- Moving Flutter from floating `stable` to a pinned version can reveal incompatibilities on Vercel or GitHub Actions; this must stop the implementation until the supported version target is explicit.
- Removing apparently unused Flutter deps can break generated-provider or planned UI flows; remove only when no imports, generated files, or documented near-term use remains.

# Implementation Tasks

- [x] Task 1: Add dependency automation scaffold
  - File: `.github/dependabot.yml`
  - Action: Create Dependabot v2 config covering `npm` in `/tubeflow_site`, `pip` in `/tubeflow_lab`, `pub` in `/tubeflow_app`, `github-actions` in `/`, and `docker` in `/tubeflow_lab`; use weekly or grouped schedules and no automerge.
  - User story link: Future security fixes are surfaced automatically.
  - Depends on: None.
  - Validate with: `python3 - <<'PY'\nimport yaml\nprint(yaml.safe_load(open('.github/dependabot.yml'))['version'])\nPY` if PyYAML exists, otherwise visually validate YAML plus `git diff --check`.
  - Notes: Use exact supported ecosystem values from GitHub Docs: `npm`, `pip`, `pub`, `github-actions`, `docker`.

- [x] Task 2: Patch Astro/PostCSS advisories within current majors
  - File: `tubeflow_site/package.json`
  - Action: Keep Astro on major 6 and Tailwind on major 4; if needed, raise direct ranges so lockfile resolution reaches `astro>=6.1.6` and `postcss>=8.5.10` without forcing unrelated major upgrades.
  - User story link: Public site dependency vulnerabilities are closed.
  - Depends on: Task 1 can be independent, but do this before final validation.
  - Validate with: `cd tubeflow_site && npm install && npm audit --json && npm run build`.
  - Notes: If npm proposes a major upgrade, stop and route to `/sf-migrate`.

- [x] Task 3: Commit the site lockfile result
  - File: `tubeflow_site/package-lock.json`
  - Action: Update lockfile through npm so resolved `astro` and `postcss` versions are patched and integrity fields remain present.
  - User story link: Clean installs reproduce the patched site.
  - Depends on: Task 2.
  - Validate with: `cd tubeflow_site && npm ci && npm audit --json && npm run build`.
  - Notes: Do not manually edit lockfile internals except through npm.

- [x] Task 4: Add Node/npm package-manager pin for the site
  - File: `tubeflow_site/package.json`
  - Action: Add `packageManager` matching the committed lockfile and local npm line, for example `npm@11.14.1`, unless implementation verifies Vercel requires a different supported npm version.
  - User story link: Site installs use a predictable package manager.
  - Depends on: Task 3.
  - Validate with: `cd tubeflow_site && npm ci && npm run build`.
  - Notes: Keep `engines.node` compatible with current `>=22.12.0`.

- [x] Task 5: Separate Python direct requirements from generated lock input
  - File: `tubeflow_lab/requirements.in`
  - Action: Create a direct dependency source from current top-level worker requirements, with `requests>=2.33.0,<3` and existing top-level pins or compatible constraints for FastAPI, Uvicorn, yt-dlp, faster-whisper, OpenAI, and FunASR.
  - User story link: Worker dependencies become understandable and reproducible.
  - Depends on: None.
  - Validate with: `cd tubeflow_lab && python3 -m pip install pip-tools && pip-compile --generate-hashes --output-file requirements.lock requirements.in`.
  - Notes: If local Python cannot install tooling, use the same Python version as Docker or a managed tool environment and document it.

- [x] Task 6: Generate and use Python hash lock
  - File: `tubeflow_lab/requirements.lock`
  - Action: Generate transitive, pinned, hash-checked worker dependencies with pip-tools and include `requests>=2.33.0`.
  - User story link: Docker and audits install what was reviewed.
  - Depends on: Task 5.
  - Validate with: `cd tubeflow_lab && python3 -m pip install --require-hashes -r requirements.lock` in a disposable environment.
  - Notes: If package hashes fail for the Docker target, regenerate using the target platform or document why hash mode cannot be adopted and keep a lock file plus explicit proof gap.

- [x] Task 7: Switch worker Docker install to locked dependencies
  - File: `tubeflow_lab/Dockerfile`
  - Action: Copy `requirements.lock` and install with `pip install --no-cache-dir --require-hashes -r requirements.lock`; keep `ffmpeg` install and `server.py` entrypoint unchanged.
  - User story link: Worker image builds reproducibly.
  - Depends on: Task 6.
  - Validate with: `cd tubeflow_lab && docker build -t tubeflow-transcript-worker-deps-test .` when Docker is available; otherwise run Python import and compile checks locally.
  - Notes: If Docker is unavailable, mark Docker build as a proof gap in final verification.

- [x] Task 8: Update worker docs for lock and audit workflow
  - File: `tubeflow_lab/README.md`
  - Action: Replace install snippets that imply direct `requirements.txt` is authoritative; document `requirements.in`, lock regeneration, locked install, `pip-audit` command, and Docker behavior.
  - User story link: Operators can reproduce the audited worker environment.
  - Depends on: Tasks 5-7.
  - Validate with: `rg -n "requirements\\.(txt|in|lock)|pip-audit|pip-compile" tubeflow_lab/README.md`.
  - Notes: Update `.env.example` only if no dependency-only changes require it; otherwise leave env untouched.

- [x] Task 9: Add or update worker agent guidance if source files change
  - File: `tubeflow_lab/AGENT.md`
  - Action: If implementation introduces `requirements.in` and `requirements.lock`, name their roles in the source-of-truth and safe-change sections.
  - User story link: Future agents do not regress dependency reproducibility.
  - Depends on: Tasks 5-8.
  - Validate with: `/home/claude/shipflow/tools/shipflow_metadata_lint.py tubeflow_lab/AGENT.md`.
  - Notes: Do not rewrite unrelated agent guidance.

- [x] Task 10: Pin Flutter SDK/deploy toolchain
  - File: `tubeflow_app/vercel.json`
  - Action: Replace the moving `git clone --depth 1 -b stable` install with a pinned Flutter version, commit SHA, or documented version-management command that installs Flutter `3.41.7` or another explicit chosen version.
  - User story link: App deploys are reproducible.
  - Depends on: None.
  - Validate with: `cd tubeflow_app && flutter --version && flutter pub get && flutter analyze`.
  - Notes: If Vercel cannot support the pinned approach, stop and document the deployment constraint.

- [x] Task 11: Pin Android CI Flutter version
  - File: `tubeflow_app/.github/workflows/android-apk.yml`
  - Action: Configure `subosito/flutter-action` with an explicit Flutter version or otherwise align it with the Vercel pin; keep Java 17 and existing secrets unchanged.
  - User story link: Android builds match the audited Flutter dependency state.
  - Depends on: Task 10.
  - Validate with: `cd tubeflow_app && flutter pub get && flutter analyze`; workflow validation by GitHub Actions on branch if available.
  - Notes: Do not change build-time secrets or Convex/Clerk defines.

- [x] Task 12: Verify and clean likely unused Flutter dependencies
  - File: `tubeflow_app/pubspec.yaml`
  - Action: For each of `flutter_slidable`, `google_fonts`, `riverpod_annotation`, `build_runner`, and `riverpod_generator`, verify imports/generated usage; remove only packages with no runtime, generated, or documented near-term use.
  - User story link: App attack surface and update noise are reduced without breaking features.
  - Depends on: Tasks 10-11 preferred so validation uses pinned Flutter.
  - Validate with: `cd tubeflow_app && flutter pub get && flutter analyze`.
  - Notes: Do not remove packages used by generated Riverpod code if generation is about to be restored under another active chantier.

- [x] Task 13: Update Flutter dependency docs only where commands change
  - File: `tubeflow_app/README.md`
  - Action: Document pinned Flutter version and dependency audit commands if implementation changes current install/build expectations.
  - User story link: Maintainers can reproduce app dependency checks.
  - Depends on: Tasks 10-12.
  - Validate with: `rg -n "Flutter|flutter pub|get|outdated|analyze" tubeflow_app/README.md tubeflow_app/AGENT.md`.
  - Notes: Keep docs concise and avoid hardcoding secrets.

- [x] Task 14: Add monorepo dependency maintenance docs
  - File: `README.md`
  - Action: Add a short dependency-maintenance section that points to each subproject's authoritative commands and the Dependabot policy.
  - User story link: The monorepo has one place to discover the maintenance workflow.
  - Depends on: Tasks 1-13.
  - Validate with: `sed -n '1,220p' README.md`.
  - Notes: Keep product/deployment content aligned with root `AGENT.md`.

- [x] Task 15: Final verification pass
  - File: no code file; verification task
  - Action: Run focused checks for all changed subprojects and record any proof gaps.
  - User story link: Dependency stabilization is proven rather than assumed.
  - Depends on: Tasks 1-14.
  - Validate with: `cd tubeflow_site && npm audit --json && npm run build`; `cd tubeflow_lab && pip-audit -r requirements.lock --require-hashes -f json && python -m py_compile main.py server.py`; `cd tubeflow_app && flutter pub outdated --json && flutter analyze`; `/home/claude/shipflow/tools/shipflow_metadata_lint.py AGENT.md shipflow_data specs/tubeflow-dependency-stabilization.md`.
  - Notes: If Docker is available, include `docker build` for the worker; if not, list Docker as unverified.

# Acceptance Criteria

- [x] CA 1: Given the current `tubeflow_site` audit findings, when compatible npm updates are applied, then `npm audit --json` no longer reports GHSA-j687-52p2-xcff or GHSA-qx2v-qp2m-jg93.
- [x] CA 2: Given the updated site lockfile, when `npm ci` and `npm run build` run in `tubeflow_site`, then the production Astro build succeeds.
- [x] CA 3: Given the worker dependency source, when the Python lock is regenerated, then the locked output includes `requests>=2.33.0` and pinned transitive dependencies.
- [x] CA 4: Given a clean worker install from the lock file, when `pip-audit` runs against the locked requirements, then it reports no Requests CVE-2026-25645 finding.
- [ ] CA 5: Given the updated worker Dockerfile, when a worker image is built, then it installs locked dependencies and still starts `server.py` on port `8090`.
- [x] CA 6: Given the updated Flutter deploy config, when the app dependency checks run, then the Flutter version used is explicit and `flutter analyze` succeeds.
- [x] CA 7: Given likely unused Flutter dependencies are reviewed, when a package is removed, then no import, generated file, or documented near-term flow still depends on it.
- [x] CA 8: Given `.github/dependabot.yml`, when inspected, then it covers npm, pip or pip-compile, pub, GitHub Actions, and Docker update surfaces without automerge.
- [x] CA 9: Given updated docs, when a fresh maintainer follows dependency commands, then each subproject has a clear install, audit, and update path.
- [x] CA 10: Given all patches are complete, when final verification runs, then no scanner finding is hidden by ignore config unless the ignore has a documented rationale and owner approval.

# Verification Notes

- `npm ci`, `npm audit --json`, and `npm run build` passed in `tubeflow_site`; audit metadata reports zero vulnerabilities.
- `tubeflow_lab` lock resolves `requests==2.33.1`, `fastapi==0.124.4`, and `starlette==0.50.0`; fallback audit of the disposable locked install reported no known vulnerabilities.
- `pip-audit -r requirements.lock` remains host-sensitive because this machine lacks Python `venv`/`ensurepip`; docs now include the `pip-audit --path` fallback used for verification.
- `python -m py_compile main.py server.py` passed for `tubeflow_lab`.
- `flutter pub get`, `flutter pub outdated --json`, and `flutter analyze` passed in `tubeflow_app`; `flutter pub outdated` reported no current advisory or retraction flags.
- `git ls-remote --tags https://github.com/flutter/flutter.git refs/tags/3.41.7` confirmed the pinned Flutter tag exists.
- `.github/dependabot.yml` parsed as YAML and covers `npm`, `pip`, `pub`, `github-actions`, and `docker`.
- `tubeflow_site/CHANGELOG.md`, `tubeflow_lab/CHANGELOG.md`, and `tubeflow_app/CHANGELOG.md` record the dependency, Docker, and CI changes.
- ShipFlow metadata lint passed for root governance docs, the spec, and changed worker docs.
- `git diff --check` passed.
- CA 5 remains a proof gap at image level because `docker` is not installed on this host; Dockerfile now installs `requirements.lock` with `--require-hashes` and uses `python:3.12-slim` to match the generated lock.

# Test Strategy

- Node/site:
  - `cd tubeflow_site && npm ci`
  - `cd tubeflow_site && npm audit --json`
  - `cd tubeflow_site && npm run build`
- Python/worker:
  - `cd tubeflow_lab && pip-compile --generate-hashes --output-file requirements.lock requirements.in`
  - `cd tubeflow_lab && python -m pip install --require-hashes -r requirements.lock` in a disposable environment
  - `cd tubeflow_lab && pip-audit -r requirements.lock --require-hashes -f json`
  - `cd tubeflow_lab && python -m py_compile main.py server.py`
  - `cd tubeflow_lab && docker build -t tubeflow-transcript-worker-deps-test .` when Docker is available
- Flutter/app:
  - `cd tubeflow_app && flutter pub get`
  - `cd tubeflow_app && flutter pub outdated --json`
  - `cd tubeflow_app && flutter analyze`
- Governance/docs:
  - `/home/claude/shipflow/tools/shipflow_metadata_lint.py AGENT.md shipflow_data specs/tubeflow-dependency-stabilization.md`
  - `git diff --check`

# Risks

- Security risk: leaving the Astro/PostCSS and Requests advisories unpatched keeps known moderate findings in public and worker surfaces.
- Supply-chain risk: adding automation without review controls can create noisy or risky major-version PRs.
- Reproducibility risk: Python hashes can be platform-sensitive; Docker target validation matters.
- Deployment risk: pinning Flutter may reveal divergence between local Flutter 3.41.7, Vercel, and GitHub Actions.
- Product risk: dependency patches can break the marketing site build or worker transcript providers even when scanners pass.
- Operational risk: Docker may not be available locally, leaving image-level proof to CI or a later production verification.
- Documentation risk: if README snippets continue to point at old install commands, future agents can bypass the lock strategy.

# Execution Notes

- Read first:
  - `AGENT.md`
  - `tubeflow_site/package.json`
  - `tubeflow_site/package-lock.json`
  - `tubeflow_lab/requirements.txt`
  - `tubeflow_lab/Dockerfile`
  - `tubeflow_app/vercel.json`
  - `tubeflow_app/.github/workflows/android-apk.yml`
  - `tubeflow_app/pubspec.yaml`
- Implementation order:
  1. Add automation config.
  2. Patch npm advisories and verify site.
  3. Add Python lock and patch Requests, then verify worker.
  4. Pin Flutter toolchain, then verify app.
  5. Review optional unused Flutter deps.
  6. Update docs.
  7. Run final cross-project checks.
- Packages allowed:
  - Use npm for `tubeflow_site` because `package-lock.json` is committed.
  - Use pip-tools for Python lock generation unless implementation proves another already-supported project tool exists.
  - Use Dependabot for first-pass automation because GitHub Docs list all required ecosystems for this repo.
- Packages or moves to avoid:
  - Do not introduce pnpm/yarn to `tubeflow_site`.
  - Do not switch the worker to Poetry/uv as part of this chantier unless pip-tools is blocked and the decision is documented.
  - Do not move app dependencies across Flutter packages without import proof.
  - Do not edit Astro content frontmatter.
- Stop conditions:
  - Any required fix needs a major upgrade.
  - Any build or analyzer failure cannot be explained as unrelated.
  - Python hash locking cannot install in the Docker target.
  - Dependabot config cannot represent a required ecosystem.
  - Flutter pinning breaks Vercel or Android CI assumptions.
  - Task 10 cannot choose a Flutter pin format supported by both Vercel and GitHub Actions.
- Adversarial review applied during spec creation:
  - The spec is multi-project and security-sensitive, so it uses full depth.
  - The minimal contract explicitly covers success, failure, and the Python transitive-lock edge case.
  - Tasks are ordered by foundation, patch, reproducibility, automation, docs, and verification.
  - Known proof gaps are included rather than hidden: Python transitive audit, Docker availability, and exploit reachability.

# Execution Batches

These batches authorize spec-gated parallelism only after `sf-ready` marks this spec ready. Each worker is not alone in the codebase, must preserve unrelated dirty files, and must not revert edits made by other agents.

## Batch A: Site Dependencies

- Write ownership: `tubeflow_site/package.json`, `tubeflow_site/package-lock.json`, `tubeflow_site/README.md`, and site-local dependency notes only.
- Forbidden files: `tubeflow_app/**`, `tubeflow_lab/**`, root `README.md`, `.github/**`, `bugs/**`, and `specs/**`.
- Tasks covered: Tasks 2, 3, 4, and the site portion of Task 14 only as notes for the integrator.
- Dependency order: Can run after readiness; independent from B and C.
- Per-batch validation: `(cd tubeflow_site && npm ci)`, `(cd tubeflow_site && npm audit --json)`, `(cd tubeflow_site && npm run build)`, and `git diff --check -- tubeflow_site`.
- Integration owner: `sf-build` integrator.

## Batch B: Worker Python Locking

- Write ownership: `tubeflow_lab/requirements.txt`, `tubeflow_lab/requirements.in`, `tubeflow_lab/requirements.lock`, `tubeflow_lab/Dockerfile`, `tubeflow_lab/README.md`, and `tubeflow_lab/AGENT.md`.
- Forbidden files: `tubeflow_app/**`, `tubeflow_site/**`, root `README.md`, `.github/**`, `bugs/**`, and `specs/**`.
- Tasks covered: Tasks 5, 6, 7, 8, and 9.
- Dependency order: Can run after readiness; independent from A and C.
- Per-batch validation: `(cd tubeflow_lab && python -m py_compile main.py server.py)`, a disposable locked install when feasible, `pip-audit -r requirements.lock -f json` or documented audit fallback, optional Docker build when Docker is available, and `git diff --check -- tubeflow_lab`.
- Integration owner: `sf-build` integrator.

## Batch C: App Toolchain And Dependency Hygiene

- Write ownership: `tubeflow_app/vercel.json`, `tubeflow_app/.github/workflows/android-apk.yml`, `tubeflow_app/pubspec.yaml`, `tubeflow_app/pubspec.lock`, `tubeflow_app/README.md`, and app-local dependency notes only.
- Forbidden files: `tubeflow_app/lib/auth/auth_gate.dart`, other unrelated dirty app source files, `tubeflow_site/**`, `tubeflow_lab/**`, root `README.md`, root `.github/**`, `bugs/**`, and `specs/**`.
- Tasks covered: Tasks 10, 11, 12, and 13.
- Dependency order: Can run after readiness; independent from A and B.
- Per-batch validation: import/usage search for candidate dependency removals, `(cd tubeflow_app && flutter pub get)`, `(cd tubeflow_app && flutter pub outdated --json)`, `(cd tubeflow_app && flutter analyze)`, and `git diff --check -- tubeflow_app`.
- Integration owner: `sf-build` integrator.

## Batch D: Automation, Shared Docs, And Final Integration

- Write ownership: `.github/dependabot.yml`, root `README.md`, `specs/tubeflow-dependency-stabilization.md`, and final integration notes only.
- Forbidden files: `bugs/**`, `tubeflow_app/lib/auth/auth_gate.dart`, and any subproject files already owned by active Batch A, B, or C workers.
- Tasks covered: Task 1, Task 14, Task 15, status/checklist updates, and final docs coherence.
- Dependency order: Start after A, B, and C have returned, unless only `.github/dependabot.yml` is edited before the wave with no overlap.
- Per-batch validation: YAML parse for `.github/dependabot.yml` when PyYAML is available, ShipFlow metadata lint, full targeted cross-project checks from Task 15, and `git diff --check`.
- Integration owner: `sf-build` integrator.

# Open Questions

None.

# Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-10 21:05:58 UTC | sf-spec | GPT-5 Codex | Created dependency stabilization chantier spec from sf-deps intake and local/external evidence. | Draft spec saved. | /sf-ready TubeFlow dependency stabilization |
| 2026-05-10 21:16:26 UTC | sf-ready | GPT-5.5 medium subagent + GPT-5 Codex | Validated required sections, documentation freshness, security review, and added safe Execution Batches for spec-gated parallelism. | Ready. | /sf-start TubeFlow dependency stabilization |
| 2026-05-10 21:39:16 UTC | sf-start | GPT-5.5 medium subagents + GPT-5 Codex | Implemented dependency patches, automation, toolchain pins, Python hash lock, changelogs, and docs through safe batches A-D. | Implemented with Docker proof gap. | /sf-verify TubeFlow dependency stabilization |
| 2026-05-10 21:39:16 UTC | sf-verify | GPT-5 Codex | Ran site, worker, app, metadata, YAML, audit, and diff validations against the spec. | Partial: local checks pass; Docker image build unavailable. | /sf-ship TubeFlow dependency stabilization --bounded-scope |
| 2026-05-10 21:39:16 UTC | sf-build | GPT-5 Codex | Orchestrated readiness, spec-gated parallel implementation, integration, changelogs, and final local verification. | Partial: ship blocked by Docker proof gap and unrelated dirty files. | Confirm bounded ship scope or run Docker build where available. |

# Current Chantier Flow

| Step | Status | Notes |
|------|--------|-------|
| sf-spec | done | Draft spec created in `specs/tubeflow-dependency-stabilization.md`. |
| sf-ready | done | Spec marked ready after metadata, Open Questions, and Execution Batches were corrected. |
| sf-start | done | Safe batches A-D implemented site, worker, app, automation, and docs changes. |
| sf-verify | partial | Local validation passed; Docker image build could not run because Docker is unavailable. |
| sf-end | blocked | Closure is blocked until the Docker proof gap and bounded ship scope are accepted. |
| sf-ship | blocked | Ship scope must exclude unrelated dirty files: `bugs/BUG-2026-05-10-001.md` and `tubeflow_app/lib/auth/auth_gate.dart`. |

Next command: `/sf-ship TubeFlow dependency stabilization --bounded-scope`
