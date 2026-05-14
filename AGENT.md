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
  - "replayglowz_app"
  - "replayglowz_site"
  - "replayglowz_lab"
depends_on:
  - "shipflow_data/technical/architecture.md"
  - "shipflow_data/technical/guidelines.md"
supersedes: []
evidence:
  - "README.md"
  - "replayglowz_app/AGENT.md"
  - "replayglowz_site/AGENT.md"
  - "replayglowz_lab/AGENT.md"
next_step: "/sf-docs audit"
---

# AGENT

## Purpose

This repository is the canonical ReplayGlowz monorepo for the Flutter app, Astro marketing site, and transcript worker.

## Repository Layout

- `replayglowz_app/`: Flutter web app, Vercel API handlers for YouTube OAuth, and app-level product contracts.
- `replayglowz_site/`: Astro public marketing site, blog, pricing, comparison, privacy, and terms pages.
- `replayglowz_lab/`: FastAPI transcript worker and operational tooling.
- `shipflow_data/`: monorepo-level governance contracts and documentation maps.

## Working Rules

- Treat subproject contracts as source evidence, not as files to rewrite casually from the root.
- Keep product claims aligned with `replayglowz_app` contracts before changing public site copy.
- Preserve Astro runtime content frontmatter in `replayglowz_site/src/content/**`; do not add ShipFlow metadata there unless `src/content.config.ts` is changed first.
- Do not touch unrelated dirty files when updating docs.

## Validation

Use focused checks from the changed subproject:

```bash
(cd replayglowz_app && flutter analyze)
(cd replayglowz_site && npm run build)
(cd replayglowz_lab && python -m py_compile main.py server.py)
```

Run ShipFlow metadata validation for governance docs:

```bash
/home/claude/shipflow/tools/shipflow_metadata_lint.py AGENT.md shipflow_data
```
