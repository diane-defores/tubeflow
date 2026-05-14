---
artifact: technical_module_context
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "replayglowz"
created: "2026-05-10"
updated: "2026-05-10"
status: "draft"
source_skill: sf-docs
scope: "code-docs-map"
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
  - "rg --files"
next_review: "2026-06-10"
next_step: "/sf-docs technical audit"
---

# Code Docs Map

## Purpose

Route changed paths to the technical docs and validation commands that must be checked before shipping.

## Map

| Path pattern | Subsystem | Primary doc | Validation | Docs update trigger |
| --- | --- | --- | --- | --- |
| `replayglowz_app/lib/**` | Flutter app | `replayglowz_app/shipflow_data/technical/architecture.md` | `(cd replayglowz_app && flutter analyze)` | Auth, routing, Convex client, screens, models, providers, i18n, or widget behavior changes. |
| `replayglowz_app/api/**` | Vercel YouTube OAuth handlers | `replayglowz_app/shipflow_data/technical/architecture.md` | `(cd replayglowz_app && node --test api/auth/_youtube.test.js)` | OAuth request/return flow, cookie handling, token exchange, Clerk, or Convex mutation behavior changes. |
| `replayglowz_app/build.sh`, `replayglowz_app/vercel.json`, `replayglowz_app/.env.example` | Flutter app deployment | `replayglowz_app/README.md` | `(cd replayglowz_app && bash -n build.sh)` | Build variables, Vercel routing, install/build commands, or deployment headers change. |
| `replayglowz_site/src/pages/**`, `replayglowz_site/src/components/**`, `replayglowz_site/src/i18n/**` | Astro public site | `replayglowz_site/shipflow_data/technical/architecture.md` | `(cd replayglowz_site && npm run build)` | Public route, CTA, pricing, claim, i18n, layout, or component changes. |
| `replayglowz_site/src/content.config.ts`, `replayglowz_site/src/content/**` | Astro runtime content | `shipflow_data/editorial/astro-content-schema-policy.md` | `(cd replayglowz_site && npm run build)` | Content schema or blog frontmatter changes. |
| `replayglowz_lab/server.py`, `replayglowz_lab/main.py` | Transcript worker | `replayglowz_lab/shipflow_data/technical/architecture.md` | `(cd replayglowz_lab && python -m py_compile main.py server.py)` | API contract, auth, limits, providers, queueing, media handling, or health behavior changes. |
| `replayglowz_lab/.env.example`, `replayglowz_lab/Dockerfile`, `replayglowz_lab/ecosystem.config.cjs` | Worker deployment | `replayglowz_lab/README.md` | `(cd replayglowz_lab && python -m py_compile main.py server.py)` | Runtime variables, container, PM2, or worker deployment model changes. |
| `README.md`, `AGENT.md`, `shipflow_data/**` | Monorepo governance | `shipflow_data/technical/README.md` | `/home/claude/shipflow/tools/shipflow_metadata_lint.py AGENT.md shipflow_data` | Repository layout, governance, source-of-truth, or cross-project routing changes. |

## Non-Coverage

- External Convex backend code is not in this monorepo. Validate it from its own checkout when Flutter or worker changes depend on backend schema/functions.

## Documentation Update Plan

- Code changed: `[path/or/pattern]`
- Subsystem: `[name]`
- Primary technical doc: `[path]`
- Secondary docs: `[path or none]`
- Required action: `[none|review|update|create]`
- Priority: `[low|medium|high]`
- Reason: `[why this doc is impacted]`
- Owner role: `[executor|integrator]`
- Parallel-safe: `[yes|no]`
- Notes: `[constraints or blockers]`

## Maintenance Rule

Update this map when major paths, validation commands, source-of-truth docs, public APIs, auth flows, deployment boundaries, or runtime content schemas change.
