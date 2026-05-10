---
artifact: editorial_content_context
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "tubeflow-flutter"
created: "2026-05-10"
updated: "2026-05-10"
status: "draft"
source_skill: sf-docs
scope: "page-intent"
owner: "Diane"
confidence: "medium"
risk_level: "medium"
security_impact: "unknown"
docs_impact: "yes"
content_surfaces:
  - "public_site"
  - "blog"
claim_register: "shipflow_data/editorial/claim-register.md"
page_intent: "shipflow_data/editorial/page-intent-map.md"
linked_systems:
  - "tubeflow_site/src/pages"
depends_on:
  - "shipflow_data/editorial/public-surface-map.md"
supersedes: []
evidence:
  - "tubeflow_site/src/pages"
next_review: "2026-06-10"
next_step: "/sf-docs editorial audit"
---

# Page Intent Map

| Route | Job | Primary CTA | Source contract | Shared-file risk |
| --- | --- | --- | --- | --- |
| `/` | Explain TubeFlow and convert qualified users to the app. | App signup/open app. | Business, product, brand, GTM. | Shared components and config can affect multiple pages. |
| `/fr/` | French-language version of the main offer. | App signup/open app. | Brand language rules and English source intent. | Translation drift with `/`. |
| `/features` | Explain current product capabilities. | App CTA. | App product and implementation truth. | Feature claims can outrun shipped behavior. |
| `/pricing` | Present offer and pricing path. | Purchase/signup CTA. | Business and GTM contracts. | Pricing mismatch is high risk. |
| `/compare` | Position TubeFlow against alternative workflows. | App/pricing CTA. | Product and GTM contracts. | Competitive claims require proof and careful wording. |
| `/privacy` | Explain privacy/data handling. | Trust/support path. | Legal/data handling truth. | Legal copy must not be changed casually. |
| `/terms` | Explain terms of use. | Trust/support path. | Legal/business terms. | Legal copy must not be changed casually. |
| `/blog` | Route readers to educational articles. | Article links and app CTA. | Content map and blog policy. | Article metadata/schema changes affect RSS and pages. |
| `/blog/[slug]` | Deliver a specific article. | App CTA or related reading. | Article frontmatter, claim register, schema policy. | Runtime content schema is strict. |
