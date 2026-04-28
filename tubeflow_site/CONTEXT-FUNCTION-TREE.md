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
  - "Astro routing"
  - "Astro content collections"
depends_on: []
supersedes: []
evidence:
  - "src/config/site.ts"
  - "src/i18n/index.ts"
  - "src/content.config.ts"
  - "src/layouts/Layout.astro"
  - "src/pages/index.astro"
  - "src/pages/fr/index.astro"
  - "src/pages/blog/[slug].astro"
  - "src/pages/blog/feed.xml.ts"
next_step: "npm run build"
---

# CONTEXT FUNCTION TREE

## Route and composition tree

```text
src/
  config/
    site.ts
      stripTrailingSlash(url)
      SITE_URL
      APP_URL
      EMAIL_DOMAIN
      siteUrl(path)
      appUrl(path)
      contactEmail(localPart)

  i18n/
    index.ts
      getTranslations(locale)
      getLocaleFromUrl(url)
      localizeHref(href, locale)
    en.ts
    fr.ts

  content.config.ts
    collections.blog

  layouts/
    Layout.astro
      Props:
        title
        description
        path
        image
        noIndex
        jsonLd
        lang
      derives:
        canonicalUrl
        ogImageUrl
        defaultSchemas
        allSchemas
      client behavior:
        Lenis smooth scrolling
        reveal-on-scroll IntersectionObserver
        reduced-motion fallback

  components/
    Navbar.astro
    Hero.astro
    ProblemSection.astro
    SolutionSection.astro
    Benefits.astro
    BentoGrid.astro
    Testimonials.astro
    Pricing.astro
    FinalCTA.astro
    Newsletter.astro
    Footer.astro
    LogoMarquee.astro

  pages/
    index.astro
      Layout
        Navbar
        Hero
        ProblemSection
        SolutionSection
        Benefits
        BentoGrid
        Testimonials
        Pricing
        FinalCTA
        Newsletter
        Footer

    fr/index.astro
      Layout(lang="fr", path="/fr")
      inline localized sections
      inline mobile menu toggle script
      getTranslations("fr")
      appUrl("/videos")

    features.astro
      Layout(path="/features")
      Navbar
      feature grid from local array
      process steps from local array
      Newsletter
      Footer

    pricing.astro
      Layout(path="/pricing")
      Navbar
      pricing cards from local plans array
      FAQ from local faqs array
      Newsletter
      Footer

    compare.astro
      Layout(path="/compare")
      Navbar
      comparison table from local features array
      use-case matrix from local useCases array
      benefits summary from local benefits array
      Footer

    privacy.astro
    terms.astro

    blog/
      index.astro
        getCollection("blog")
        sort posts by date desc
        Layout(path="/blog")
        Navbar
        Footer

      [slug].astro
        getStaticPaths()
        render(post)
        BlogPosting JSON-LD
        Layout(path=`/blog/${slug}`)
        Navbar
        Footer

      feed.xml.ts
        GET()
          getCollection("blog")
          sort posts by date desc
          build RSS XML response

  content/
    blog/
      *.md
```

## Responsibility summary

- `site.ts` owns environment-derived public addressing.
- `Layout.astro` owns global metadata, structured data framing, fonts, and shared client-side UX behavior.
- `pages/index.astro` is the shared-component homepage.
- `pages/fr/index.astro` is a separate localized landing page implementation.
- `blog/[slug].astro` and `blog/feed.xml.ts` are the only clearly function-heavy routes.
- Most other pages are static render trees driven by local content arrays.
