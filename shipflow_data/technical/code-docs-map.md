---
artifact: technical_module_context
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "tubeflow-flutter"
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
  - "tubeflow_app"
  - "tubeflow_site"
  - "tubeflow_lab"
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
| `tubeflow_app/lib/**` | Flutter app | `tubeflow_app/shipflow_data/technical/architecture.md` | `(cd tubeflow_app && flutter analyze)` | Auth, routing, Convex client, screens, models, providers, i18n, or widget behavior changes. |
| `tubeflow_app/api/**` | Vercel YouTube OAuth handlers | `tubeflow_app/shipflow_data/technical/architecture.md` | `(cd tubeflow_app && node --test api/auth/_youtube.test.js)` | OAuth request/return flow, cookie handling, token exchange, Clerk, or Convex mutation behavior changes. |
| `tubeflow_app/build.sh`, `tubeflow_app/vercel.json`, `tubeflow_app/.env.example` | Flutter app deployment | `tubeflow_app/README.md` | `(cd tubeflow_app && bash -n build.sh)` | Build variables, Vercel routing, install/build commands, or deployment headers change. |
| `tubeflow_site/src/pages/**`, `tubeflow_site/src/components/**`, `tubeflow_site/src/i18n/**` | Astro public site | `tubeflow_site/shipflow_data/technical/architecture.md` | `(cd tubeflow_site && npm run build)` | Public route, CTA, pricing, claim, i18n, layout, or component changes. |
| `tubeflow_site/src/content.config.ts`, `tubeflow_site/src/content/**` | Astro runtime content | `shipflow_data/editorial/astro-content-schema-policy.md` | `(cd tubeflow_site && npm run build)` | Content schema or blog frontmatter changes. |
| `tubeflow_lab/server.py`, `tubeflow_lab/main.py` | Transcript worker | `tubeflow_lab/shipflow_data/technical/architecture.md` | `(cd tubeflow_lab && python -m py_compile main.py server.py)` | API contract, auth, limits, providers, queueing, media handling, or health behavior changes. |
| `tubeflow_lab/.env.example`, `tubeflow_lab/Dockerfile`, `tubeflow_lab/ecosystem.config.cjs` | Worker deployment | `tubeflow_lab/README.md` | `(cd tubeflow_lab && python -m py_compile main.py server.py)` | Runtime variables, container, PM2, or worker deployment model changes. |
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
