---
artifact: editorial_content_context
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "tubeflow-flutter"
created: "2026-05-10"
updated: "2026-05-10"
status: "draft"
source_skill: sf-docs
scope: "surface-map"
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
  - "tubeflow_site/src/content/blog"
depends_on:
  - "shipflow_data/editorial/content-map.md"
supersedes: []
evidence:
  - "find tubeflow_site/src/pages -maxdepth 3 -type f"
next_review: "2026-06-10"
next_step: "/sf-docs editorial audit"
---

# Public Surface Map

| Surface | Path | Role | Source of truth | Update trigger |
| --- | --- | --- | --- | --- |
| Home | `tubeflow_site/src/pages/index.astro` | Main English landing page | Business, product, brand, GTM contracts | Positioning, CTA, feature, or offer changes. |
| French home | `tubeflow_site/src/pages/fr/index.astro` | French landing page | English page intent plus brand language rules | English landing meaning or French market copy changes. |
| Features | `tubeflow_site/src/pages/features.astro` | Product capability education | App product and implementation truth | Feature behavior or availability changes. |
| Pricing | `tubeflow_site/src/pages/pricing.astro` | Commercial offer | Business and GTM contracts | Pricing, packaging, entitlement, or billing changes. |
| Compare | `tubeflow_site/src/pages/compare.astro` | Alternative/comparison evaluation | Product and GTM contracts | Competitive framing or product scope changes. |
| Privacy | `tubeflow_site/src/pages/privacy.astro` | Trust/legal information | Current data handling and legal review | Auth, analytics, storage, provider, or legal changes. |
| Terms | `tubeflow_site/src/pages/terms.astro` | Terms/legal information | Legal review and product scope | Offer, account, payment, or legal changes. |
| Blog index | `tubeflow_site/src/pages/blog/index.astro` | Blog listing | Astro content collection | Blog route or collection changes. |
| Blog article | `tubeflow_site/src/pages/blog/[slug].astro` | Blog article rendering | Astro content schema and article frontmatter | Article schema, layout, or content rules change. |
| RSS feed | `tubeflow_site/src/pages/blog/feed.xml.ts` | Blog RSS output | Astro content collection | Feed metadata or collection changes. |
| Root README | `README.md` | Monorepo orientation | Repository layout and deployment model | Subproject ownership or deployment changes. |
| App README | `tubeflow_app/README.md` | App setup/product docs | App implementation and contracts | App setup, env, auth, backend, or deployment changes. |
| Worker README | `tubeflow_lab/README.md` | Worker setup/operations | Worker implementation and contracts | Worker API, env, provider, deployment, or security changes. |
