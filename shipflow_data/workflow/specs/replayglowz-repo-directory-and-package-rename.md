---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "replayglowz"
created: "2026-05-14"
created_at: "2026-05-14 21:53:59 UTC"
updated: "2026-05-14"
updated_at: "2026-05-14 21:53:59 UTC"
status: ready
source_skill: sf-build
source_model: "GPT-5 Codex"
scope: "repo-directory-and-package-rename"
owner: "Diane"
user_story: "As the ReplayGlowz maintainer, I want the monorepo directories, package namespace, scripts, docs, and deployment references renamed from tubeflow_* to replayglowz_* so the repository structure matches the shipped product identity."
confidence: "high"
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "replayglowz_app"
  - "replayglowz_site"
  - "replayglowz_lab"
  - "Flutter package imports"
  - "Vercel root directory"
  - "Docker/PM2 worker operations"
depends_on:
  - artifact: "shipflow_data/workflow/specs/replayglowz-brand-domain-migration.md"
    artifact_version: "1.0.0"
    required_status: "ready"
supersedes: []
evidence:
  - "User selected full rename option on 2026-05-14 after the brand/domain migration shipped."
  - "Current repo directories are `replayglowz_app`, `replayglowz_site`, and `replayglowz_lab`."
  - "`replayglowz_app/pubspec.yaml` still declares `name: replayglowz_app`, driving `package:replayglowz_app/...` imports."
next_step: "/sf-auth-debug https://app.replayglowz.com YouTube OAuth ReplayGlowz"
---

# ReplayGlowz Repo Directory And Package Rename

## Status

Verified locally and ready to ship. User approved the full rename path: directories, package namespace, scripts, docs, and operational references.

## Minimal Behavior Contract

The monorepo should use `replayglowz_app`, `replayglowz_site`, and `replayglowz_lab` as active project directories. The Flutter package should import through `package:replayglowz_app/...`. Legacy `tubeflow_*` references should remain only in historical specs, historical bug logs, migration evidence, external old remote names, or explicitly documented compatibility notes. Vercel project root directories must be updated outside the repository after this ship.

## Scope In

- Rename directories: `tubeflow_app` -> `replayglowz_app`, `tubeflow_site` -> `replayglowz_site`, `tubeflow_lab` -> `replayglowz_lab`.
- Rename Flutter package identity and imports from `tubeflow_app` to `replayglowz_app`.
- Update repo docs, ShipFlow corpus, specs, bug references, changelogs, scripts, Docker/PM2 examples, package metadata, and validation commands.
- Keep product behavior unchanged.

## Scope Out

- Do not change OAuth scopes, Firebase/Convex semantics, worker API contracts, or app feature behavior.
- Do not change Vercel dashboard Root Directory settings directly from this repo run.
- Do not delete or reset `previewdev`.
- Do not rewrite the archived `claude/` conversation capture.

## Acceptance Criteria

- [x] CA 1: `find . -maxdepth 2 -type d -name 'tubeflow*'` has no active project directories.
- [x] CA 2: Flutter imports use `package:replayglowz_app/...`, and `flutter analyze` passes in `replayglowz_app`.
- [x] CA 3: `npm run build` passes in `replayglowz_site`.
- [x] CA 4: `python3 -m py_compile main.py server.py` passes in `replayglowz_lab`.
- [x] CA 5: Active docs and commands point to `replayglowz_app`, `replayglowz_site`, and `replayglowz_lab`.
- [x] CA 6: Remaining `tubeflow_app`, `tubeflow_site`, or `tubeflow_lab` hits are historical or compatibility references and are reported.

## Test Strategy

- `/home/claude/shipflow/tools/shipflow_metadata_lint.py AGENT.md shipflow_data`
- `cd replayglowz_app && bash -n build.sh && node --test api/auth/_youtube.test.js && flutter analyze && flutter build web`
- `cd replayglowz_site && npm run build`
- `cd replayglowz_lab && python3 -m py_compile main.py server.py`
- `rg -n "tubeflow_app|tubeflow_site|tubeflow_lab|package:tubeflow_app|name: tubeflow_app" . --glob '!claude/**'`

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-14 21:53:59 UTC | sf-build | GPT-5 Codex | Created ready spec after user selected full directory/package rename. | Ready. | `/sf-start ReplayGlowz repo directory and package rename` |
| 2026-05-14 21:59:15 UTC | sf-start | GPT-5 Codex | Renamed active monorepo directories to `replayglowz_app`, `replayglowz_site`, and `replayglowz_lab`; renamed Flutter package/import namespace and active app type/bridge names. | Implemented locally. | `/sf-verify ReplayGlowz repo directory and package rename` |
| 2026-05-14 21:59:15 UTC | sf-verify | GPT-5 Codex | Ran metadata lint, Python compile, OAuth helper tests, Flutter analyze/build, Astro build, diff check, and residual path audit. | Passed locally; residual old path mentions are changelog documentation only. | `/sf-end ReplayGlowz repo directory and package rename` |
| 2026-05-14 21:59:15 UTC | sf-end | GPT-5 Codex | Updated subproject changelogs and chantier state for the structure rename. | Closed locally, ready to ship. | `/sf-ship ReplayGlowz repo directory and package rename` |
| 2026-05-14 22:07:58 UTC | sf-ship | GPT-5 Codex | Committed and pushed `309cbfc` to `origin/main`. Initial Vercel deploy failed because project Root Directory still pointed at `tubeflow_app`; updated Vercel project `replayglowz_app` Root Directory to `replayglowz_app` and redeployed. | Shipped. Redeploy `replayglowz-dfpiic665` is Ready and `https://app.replayglowz.com/` returns 200 with ReplayGlowz metadata. | `/sf-auth-debug https://app.replayglowz.com YouTube OAuth ReplayGlowz` |

## Current Chantier Flow

| Step | Status | Notes |
|------|--------|-------|
| sf-spec | done | Spec created from explicit user decision. |
| sf-ready | ready | Scope is explicit and validation is defined. |
| sf-start | implemented | Directories, package namespace, docs, scripts, and active code references renamed. |
| sf-verify | passed | Local validation passed; residual old path hits are changelog entries documenting the rename. |
| sf-end | closed | Changelogs and spec state updated. |
| sf-ship | shipped | Commit `309cbfc` pushed; Vercel app Root Directory updated and production redeploy is Ready. |

Next command: `/sf-auth-debug https://app.replayglowz.com YouTube OAuth ReplayGlowz`
