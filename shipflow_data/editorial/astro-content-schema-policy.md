---
artifact: editorial_content_context
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "tubeflow-flutter"
created: "2026-05-10"
updated: "2026-05-10"
status: "draft"
source_skill: sf-docs
scope: "schema-policy"
owner: "Diane"
confidence: "high"
risk_level: "medium"
security_impact: "none"
docs_impact: "yes"
content_surfaces:
  - "runtime_content"
  - "blog"
claim_register: "shipflow_data/editorial/claim-register.md"
page_intent: "shipflow_data/editorial/page-intent-map.md"
linked_systems:
  - "tubeflow_site/src/content.config.ts"
  - "tubeflow_site/src/content/blog"
depends_on:
  - "shipflow_data/editorial/public-surface-map.md"
supersedes: []
evidence:
  - "tubeflow_site/src/content.config.ts"
next_review: "2026-06-10"
next_step: "/sf-docs editorial audit"
---

# Astro Content Schema Policy

## Runtime Schema

`tubeflow_site/src/content.config.ts` defines the blog collection frontmatter schema:

- `title: string`
- `description: string`
- `date: string`
- `author: string` optional
- `tags: string[]` optional

## Policy

- Do not add ShipFlow governance frontmatter to `tubeflow_site/src/content/blog/**` unless the Astro schema is explicitly extended first.
- Store governance metadata in `shipflow_data/editorial/**`, not in runtime blog content.
- Validate content schema changes with `(cd tubeflow_site && npm run build)`.

## Maintenance Rule

Update this policy whenever `tubeflow_site/src/content.config.ts` changes.
