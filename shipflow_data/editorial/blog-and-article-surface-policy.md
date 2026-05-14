---
artifact: editorial_content_context
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "replayglowz"
created: "2026-05-10"
updated: "2026-05-10"
status: "draft"
source_skill: sf-docs
scope: "blog-policy"
owner: "Diane"
confidence: "medium"
risk_level: "medium"
security_impact: "unknown"
docs_impact: "yes"
content_surfaces:
  - "blog"
claim_register: "shipflow_data/editorial/claim-register.md"
page_intent: "shipflow_data/editorial/page-intent-map.md"
linked_systems:
  - "replayglowz_site/src/pages/blog"
  - "replayglowz_site/src/content/blog"
depends_on:
  - "shipflow_data/editorial/astro-content-schema-policy.md"
supersedes: []
evidence:
  - "replayglowz_site/src/pages/blog/index.astro"
  - "replayglowz_site/src/pages/blog/[slug].astro"
next_review: "2026-06-10"
next_step: "/sf-docs editorial audit"
---

# Blog And Article Surface Policy

## Declared Surface

The blog surface exists at `replayglowz_site/src/pages/blog` and renders Markdown entries from `replayglowz_site/src/content/blog`.

## Article Rules

- Preserve the Astro content schema in `astro-content-schema-policy.md`.
- Check `claim-register.md` for sensitive claims before publishing.
- Link article intent back to the relevant product, business, brand, or GTM contract.
- Do not create article claims about AI, automation, savings, compliance, security, or pricing without proof.

## Validation

```bash
(cd replayglowz_site && npm run build)
```
