---
artifact: documentation
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "replayglowz"
created: "2026-05-10"
updated: "2026-05-10"
status: "draft"
source_skill: sf-docs
scope: "repository_guidance"
owner: "Diane"
confidence: "medium"
risk_level: "medium"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "tubeflow_app"
  - "tubeflow_site"
  - "tubeflow_lab"
depends_on:
  - "shipflow_data/technical/architecture.md"
  - "shipflow_data/technical/guidelines.md"
supersedes: []
evidence:
  - "README.md"
  - "tubeflow_app/AGENT.md"
  - "tubeflow_site/AGENT.md"
  - "tubeflow_lab/AGENT.md"
next_step: "/sf-docs audit"
---

# AGENT

## Purpose

This repository is the canonical ReplayGlowz monorepo for the Flutter app, Astro marketing site, and transcript worker.

## Repository Layout

- `tubeflow_app/`: Flutter web app, Vercel API handlers for YouTube OAuth, and app-level product contracts.
- `tubeflow_site/`: Astro public marketing site, blog, pricing, comparison, privacy, and terms pages.
- `tubeflow_lab/`: FastAPI transcript worker and operational tooling.
- `shipflow_data/`: monorepo-level governance contracts and documentation maps.

## Working Rules

- Treat subproject contracts as source evidence, not as files to rewrite casually from the root.
- Keep product claims aligned with `tubeflow_app` contracts before changing public site copy.
- Preserve Astro runtime content frontmatter in `tubeflow_site/src/content/**`; do not add ShipFlow metadata there unless `src/content.config.ts` is changed first.
- Do not touch unrelated dirty files when updating docs.

## Validation

Use focused checks from the changed subproject:

```bash
(cd tubeflow_app && flutter analyze)
(cd tubeflow_site && npm run build)
(cd tubeflow_lab && python -m py_compile main.py server.py)
```

Run ShipFlow metadata validation for governance docs:

```bash
/home/claude/shipflow/tools/shipflow_metadata_lint.py AGENT.md shipflow_data
```
