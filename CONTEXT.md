---
artifact: documentation
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "tubeflow-site"
created: "2026-04-26"
updated: "2026-04-27"
status: "reviewed"
source_skill: "sf-docs"
scope: "file"
owner: "Diane"
confidence: "high"
risk_level: "low"
security_impact: "none"
docs_impact: "yes"
linked_systems:
  - "TubeFlow app"
  - "Astro content collections"
depends_on: []
supersedes: []
evidence:
  - "README.md"
  - "src/config/site.ts"
  - "src/i18n/index.ts"
  - "src/content.config.ts"
  - "src/pages/index.astro"
  - "src/pages/features.astro"
  - "src/pages/pricing.astro"
  - "src/pages/compare.astro"
  - "src/pages/blog/index.astro"
next_step: "npm run build"
---

# CONTEXT

## Product context

TubeFlow is presented here as a learning-focused video tool. The site consistently frames the product around:

- timestamped note-taking
- distraction-free video learning
- searchable knowledge capture
- better retention from educational video

The site’s main job is to convert visitors into app users and support organic discovery through SEO pages and blog content.

## User journeys

- Homepage visitor learns the value proposition and clicks into the app.
- Feature-aware visitor compares capabilities on `/features`.
- Pricing-aware visitor evaluates plans and FAQs on `/pricing`.
- Search visitor lands on `/compare` or blog posts and is funneled toward the app.
- French-speaking visitor uses `/fr` as a localized landing page.

## System context

- This repo is a static marketing surface, not the application backend.
- Public URLs are environment-driven through `PUBLIC_SITE_URL`, `PUBLIC_APP_URL`, and `PUBLIC_EMAIL_DOMAIN`.
- All canonical URLs and most CTA destinations derive from `src/config/site.ts`.
- Blog pages are generated from markdown files under `src/content/blog`.

## Localization context

- Shared locale utilities exist in `src/i18n/index.ts`.
- French is only clearly implemented for the homepage route `/fr`.
- The French homepage uses inline markup and scripts instead of the English shared component composition.
- This means localization is partial and structurally asymmetric.

## SEO and content context

- `Layout.astro` centralizes canonical tags, `hreflang`, Open Graph, Twitter card tags, and default JSON-LD.
- Route pages add page-specific structured data, especially blog, pricing, and comparison pages.
- The blog collection is schema-validated but lightweight.
- RSS is exposed through `/blog/feed.xml`.

## Important constraints

- Do not change URL generation logic casually; it affects canonicals, structured data, and app CTAs.
- Be careful with product claims on pricing, privacy, AI summaries, sync, and encryption unless they are verified upstream.
- Preserve accessibility affordances already present in layout and navigation, including skip link and reduced-motion handling.

## Current documentation confidence

- High confidence on technical structure and routing.
- Medium confidence on product capability claims because the product app is outside this repository.
- Medium confidence on localization strategy because only the homepage has an obvious French implementation.
