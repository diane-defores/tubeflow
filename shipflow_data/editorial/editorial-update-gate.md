---
artifact: editorial_content_context
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "tubeflow-flutter"
created: "2026-05-10"
updated: "2026-05-10"
status: "draft"
source_skill: sf-docs
scope: "content-gate"
owner: "Diane"
confidence: "medium"
risk_level: "medium"
security_impact: "unknown"
docs_impact: "yes"
content_surfaces:
  - "public_site"
  - "repo_docs"
  - "blog"
claim_register: "shipflow_data/editorial/claim-register.md"
page_intent: "shipflow_data/editorial/page-intent-map.md"
linked_systems:
  - "tubeflow_site/src/pages"
depends_on:
  - "shipflow_data/editorial/claim-register.md"
  - "shipflow_data/editorial/page-intent-map.md"
supersedes: []
evidence:
  - "ShipFlow editorial governance template"
next_review: "2026-06-10"
next_step: "/sf-docs editorial audit"
---

# Editorial Update Gate

## Editorial Update Plan

- Changed behavior or source: `[source]`
- Impacted surface: `[route/file/surface]`
- Source of truth: `[contract/spec/evidence]`
- Required action: `[none|review|update|create|remove|surface missing|pending final copy]`
- Reason: `[why]`
- Owner role: `[Editorial Reader|executor|integrator|human decision]`
- Parallel-safe: `[yes|no]`
- Validation: `[check]`
- Closure status: `[complete|no editorial impact|pending final copy|blocked]`

## Rules

- Use `no editorial impact` only when no public, README, blog, pricing, support, trust, or repo-doc surface is affected.
- Use `pending final copy` when implementation is done but owner-approved wording is still required.
- Use `surface missing: blog` when article output is requested but no declared blog route exists. This repo currently has a declared blog route.
- Route sensitive claims through `claim-register.md` before publishing.
