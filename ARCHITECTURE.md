---
artifact: architecture_context
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "tubeflow-site"
created: "2026-04-26"
updated: "2026-04-27"
status: "reviewed"
source_skill: "sf-docs"
scope: "architecture"
owner: "Diane"
confidence: "high"
risk_level: "medium"
docs_impact: "yes"
security_impact: "low"
evidence:
  - "package.json"
  - "src/config/site.ts"
  - "src/content.config.ts"
  - "src/i18n/index.ts"
  - "src/layouts/Layout.astro"
  - "src/pages/index.astro"
  - "src/pages/fr/index.astro"
  - "src/pages/blog/index.astro"
  - "src/pages/blog/[slug].astro"
  - "src/pages/blog/feed.xml.ts"
linked_systems:
  - "src/config/site.ts"
  - "src/content.config.ts"
  - "src/i18n"
  - "src/layouts/Layout.astro"
  - "src/pages"
external_dependencies:
  - "Astro"
  - "Tailwind CSS"
  - "RSS consumers"
  - "TubeFlow app public URLs"
invariants:
  - "Canonical URLs and CTA targets remain derived from src/config/site.ts."
  - "Blog content remains build-time sourced from astro:content collections."
  - "The site stays static-first with no internal application backend in this repo."
depends_on: []
supersedes: []
next_review: "2026-05-26"
next_step: "Reduce EN/FR homepage drift by converging shared section composition."
---

# ARCHITECTURE

## Overview

`tubeflow-site` is an Astro-based marketing site. Its architecture is static-first, with minimal client-side enhancement and no visible server-side business logic beyond Astro build-time content generation and an RSS route.

## Top-level architecture

### 1. Presentation layer

- Astro page routes under `src/pages`
- Shared layout shell in `src/layouts/Layout.astro`
- Reusable homepage-oriented components under `src/components`
- Tailwind-powered styling via global CSS

### 2. Configuration layer

- `src/config/site.ts` normalizes environment-driven site URLs
- Public environment variables shape canonical URLs, structured data, and CTA destinations

### 3. Content layer

- Markdown blog content under `src/content/blog`
- Collection schema defined in `src/content.config.ts`
- Blog list, detail pages, and RSS all read from the same collection

### 4. Localization layer

- Locale helper functions in `src/i18n/index.ts`
- Translation dictionaries in `src/i18n/en.ts` and `src/i18n/fr.ts`
- Actual localized rendering is partial: `/fr` is implemented explicitly, while most route duplication is not generalized

## Rendering model

- Static route rendering for marketing pages
- Build-time content loading for blog posts
- Dynamic path generation for blog entries through `getStaticPaths()`
- A lightweight response route for RSS feed generation

No persistent datastore, auth logic, or internal API surface is visible in this repository.

## Shared shell responsibilities

`Layout.astro` is the main architecture hub. It centralizes:

- favicon and app icon registration
- viewport and page metadata
- canonical URL generation
- English/French `hreflang` alternates
- Open Graph and Twitter card tags
- default JSON-LD for `WebSite`, `Organization`, and `WebApplication`
- route-specific JSON-LD injection
- a skip link for accessibility
- reduced-motion-aware scroll enhancement and reveal animations

This means metadata behavior is intentionally coupled to the layout layer rather than duplicated across pages.

## Route architecture

### Shared-component route

- `src/pages/index.astro` composes the homepage from reusable sections.

### Standalone marketing routes

- `features.astro`
- `pricing.astro`
- `compare.astro`
- likely legal pages such as `privacy.astro` and `terms.astro`

These pages use local arrays for content and render primarily static markup.

### Localized route

- `src/pages/fr/index.astro` is not composed from the English component set.
- It embeds localized content, structure, and mobile menu behavior inline.

This is the clearest maintainability divergence in the current architecture.

### Blog routes

- `blog/index.astro` lists posts sorted by date descending.
- `blog/[slug].astro` generates static article pages from the blog collection.
- `blog/feed.xml.ts` serializes the same collection into RSS.

## Configuration and URL flow

All public-facing URLs depend on `src/config/site.ts`:

- `SITE_URL` drives canonical and structured data URLs.
- `APP_URL` drives signup and product CTA links.
- `EMAIL_DOMAIN` supports contact email composition.

Because metadata and CTAs depend on this file, it is a high-leverage architectural boundary.

## Architectural risks

### Content drift risk

The French homepage is structurally separate from the English homepage, so changes to navigation, sections, copy patterns, or CTA behavior can diverge.

### Claim integrity risk

The site makes product and pricing claims, but the product system is external to this repo. Claims can become stale without a synchronized update process.

### SEO coupling risk

Metadata, canonical behavior, and structured data are heavily centralized in `Layout.astro`. This is efficient, but regressions there affect every route.

## Recommended direction

- Keep shared SEO logic in `Layout.astro`.
- Consider moving `/fr` toward the same component architecture as `/`.
- Treat `site.ts` as a protected contract for URL behavior.
- Keep blog schema changes synchronized across content files, route templates, and RSS generation.
