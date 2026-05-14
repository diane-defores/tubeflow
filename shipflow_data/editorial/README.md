---
artifact: editorial_content_context
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "replayglowz"
created: "2026-05-10"
updated: "2026-05-10"
status: "draft"
source_skill: sf-docs
scope: "editorial-governance"
owner: "Diane"
confidence: "medium"
risk_level: "medium"
security_impact: "unknown"
docs_impact: "yes"
content_surfaces:
  - "public_site"
  - "repo_docs"
  - "runtime_content"
claim_register: "shipflow_data/editorial/claim-register.md"
page_intent: "shipflow_data/editorial/page-intent-map.md"
linked_systems:
  - "replayglowz_site/src/pages"
  - "replayglowz_site/src/content/blog"
depends_on:
  - "shipflow_data/editorial/content-map.md"
supersedes: []
evidence:
  - "replayglowz_site/src/pages"
  - "replayglowz_site/src/content.config.ts"
next_review: "2026-06-10"
next_step: "/sf-docs editorial audit"
---

# Editorial Governance

## Purpose

This directory governs public ReplayGlowz content, public claims, page intent, and runtime content schema boundaries.

## Files

- `content-map.md`: monorepo content routing map.
- `public-surface-map.md`: public routes and docs surfaces.
- `page-intent-map.md`: route jobs, CTAs, and source contracts.
- `claim-register.md`: sensitive or proof-bound claims.
- `editorial-update-gate.md`: required plan format for public-content changes.
- `astro-content-schema-policy.md`: rules for Astro runtime content frontmatter.
- `blog-and-article-surface-policy.md`: blog route and article request policy.

## Maintenance Rule

Update this layer when a public route, public claim, pricing page, blog schema, content collection, or source contract changes.
