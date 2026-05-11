---
artifact: content_map
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "tubeflow-site"
created: "2026-04-26"
updated: "2026-04-27"
status: reviewed
source_skill: sf-docs
scope: content-map
owner: "Diane"
confidence: high
risk_level: medium
content_surfaces:
  - landing_pages
  - comparison_pages
  - pricing_pages
  - blog
  - localization
  - trust_pages
  - repository_docs
security_impact: unknown
docs_impact: yes
evidence:
  - "README.md"
  - "src/config/site.ts"
  - "src/pages/index.astro"
  - "src/pages/features.astro"
  - "src/pages/pricing.astro"
  - "src/pages/compare.astro"
  - "src/pages/blog/index.astro"
  - "src/pages/blog/[slug].astro"
  - "src/pages/fr/index.astro"
  - "src/pages/privacy.astro"
  - "src/pages/terms.astro"
  - "src/content/blog"
linked_artifacts:
  - "shipflow_data/business/product.md"
  - "shipflow_data/business/gtm.md"
  - "shipflow_data/business/business.md"
  - "shipflow_data/business/branding.md"
depends_on:
  - artifact: "shipflow_data/business/product.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipflow_data/business/gtm.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "tubeflow_app/shipflow_data/business/product.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes:
  - artifact_version: "0.1.0"
next_review: "2026-05-27"
next_step: "/sf-docs audit shipflow_data/editorial/content-map.md"
---

# Content Map

## Purpose

This map defines where public messaging and trust content live in `tubeflow-site`, and what must be updated when core product framing changes.

Canonical product truth remains `tubeflow_app`.

## Content Surfaces

| Surface | Canonical path | Purpose | Source of truth |
|---|---|---|---|
| Homepage | `src/pages/index.astro` | Primary positioning and top-level conversion | Route file + shared marketing components |
| Features | `src/pages/features.astro` | Capability-level education and CTA progression | Route file |
| Pricing | `src/pages/pricing.astro` | Offer framing, objections, and upgrade intent | Route file |
| Comparison | `src/pages/compare.astro` | Competitive framing against YouTube learning workflows | Route file |
| Blog | `src/pages/blog/index.astro`, `src/pages/blog/[slug].astro`, `src/content/blog/*.md` | SEO and education funnel | Markdown posts + blog routes |
| French landing | `src/pages/fr/index.astro` | Bilingual acquisition surface | Route file + `src/i18n/*.ts` |
| Trust/legal | `src/pages/privacy.astro`, `src/pages/terms.astro` | Compliance and trust completion surfaces | Route files |
| Repo docs | `README.md`, `shipflow_data/business/business.md`, `shipflow_data/business/branding.md`, `shipflow_data/business/product.md`, `shipflow_data/business/gtm.md`, `shipflow_data/editorial/content-map.md` | Operating contracts for marketing and docs consistency | Root docs |

## Funnel Mapping

| Stage | Surfaces | Main objective |
|---|---|---|
| Awareness | `/blog`, `/compare` | Frame pain: passive watching and context loss |
| Consideration | `/`, `/features` | Prove workflow and reduce objections |
| Intent | `/pricing` | Clarify value and route to app |
| Conversion | All CTA buttons via `appUrl('/videos')` | Push to app signup/activation |
| Localization | `/fr` | Replicate conversion narrative for French audience |

## Internal Linking Rules

- Blog posts should link to at least one commercial route: `/features`, `/compare`, or `/pricing`.
- `/compare` should always offer direct path to `/pricing` and app CTA.
- `/fr` should stay aligned with core EN value proposition and CTA destination.

## Cross-Surface Update Rules

| Trigger | Required updates |
|---|---|
| Product promise changes | `/`, `/features`, `/compare`, `shipflow_data/business/product.md`, `shipflow_data/business/gtm.md` |
| Offer or pricing changes | `/pricing`, homepage pricing blocks, `shipflow_data/business/business.md`, `shipflow_data/business/gtm.md` |
| Brand voice/tagline changes | `/`, `/fr`, `shipflow_data/business/branding.md`, selected blog intros/outros |
| CTA destination changes | `src/config/site.ts` and all CTA-bearing pages |
| Legal/trust updates | `/privacy`, `/terms`, plus any impacted pricing/support copy |

## Governance Rule

When `tubeflow-site` messaging conflicts with canonical product artifacts, resolve in favor of `tubeflow_app`.
