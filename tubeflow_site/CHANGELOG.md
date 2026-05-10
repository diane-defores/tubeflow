# Changelog

All notable changes to this project will be documented in this file.

## [2026-05-10]

### Security
- Patched Astro/PostCSS advisory exposure by updating Astro within the 6.x line and regenerating the npm lockfile.

### Changed
- Added the npm package-manager pin and documented `npm ci` plus `npm audit --json` as the maintenance path.

## [2026-04-07]

### Added
- Full landing page migrated from Next.js (v0-winflowz-landing) to Astro 6
- Tailwind CSS 4 with dark theme (oklch color tokens)
- Lenis smooth scroll, navbar hover pill, micro-animations
- CSS animations replacing Framer Motion: text reveal, fade-up, scroll-triggered reveals
- Homepage sections from apps/web: ProblemSection, SolutionSection, Benefits, Testimonials, Newsletter
- Features page (/features) with 8-card grid + How It Works 3-step flow
- Pricing page (/pricing) with Free/Pro plans + FAQ section + Product JSON-LD
- Compare page (/compare) — YouTube vs TubeFlow: feature table, use cases, pricing comparison, verdict
- Blog with Astro content collections: 3 MDX posts migrated, index page, dynamic [slug] routes
- Terms of Service (/terms) and Privacy Policy (/privacy) pages
- SEO: Open Graph, Twitter Card, canonical URLs on all pages
- JSON-LD structured data: WebSite, Organization, WebApplication, BreadcrumbList, BlogPosting, Product, FAQ schemas
- Custom blog prose CSS styles
- Footer links updated to point to real pages

### Fixed
- Newsletter: submit feedback with success (emerald) / error (red) states, loading + disabled button during request, aria-live region for screen readers
- Pricing FAQ: converted static divs to native `<details>`/`<summary>` accordion — keyboard accessible, chevron animates on open
- Blog prose: added blockquote, `<hr>`, inline `<code>`, and `<pre><code>` styles to `.blog-content`
- Compare table: added `aria-label="Yes/No"` + `role="img"` to all check/x SVGs in feature table cells
- Benefits section: replaced generic "note-taking app" copy with video-learning specific content (Timestamped Notes, Searchable Knowledge Base, Distraction-Free Learning, AI Summaries)

### Changed
- All placeholder "Apex" copy replaced with real TubeFlow product content from apps/web i18n
- Hero: "Stop Fighting YouTube's Algorithm. Start Enjoying Your Content."
- Features: Smart Organization, Subscription Dashboard, Intelligent Search, Distraction-Free, Cross-Device Sync, Privacy-First
- Pricing: Free ($0) / Pro ($9) / Team ($29) matching real i18n values
- Testimonials: 3 real reviews (Ryan Lowry, John Collins, Moe Partuj)
- LogoMarquee removed (not in source app)
