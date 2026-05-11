---
artifact: project_guidelines
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "tubeflow-site"
created: "2026-04-26"
updated: "2026-04-27"
status: "reviewed"
source_skill: "sf-docs"
scope: "engineering-and-content"
owner: "Diane"
confidence: "high"
risk_level: "medium"
security_impact: "low"
docs_impact: "yes"
evidence:
  - "package.json shows an Astro 6 site with Tailwind v4 and Node 22.12+."
  - "astro.config.mjs enables English and French locales."
  - "src/config/site.ts centralizes public URL and email-domain configuration."
depends_on:
  - "shipflow_data/business/business.md"
  - "shipflow_data/business/branding.md"
supersedes: []
next_review: "2026-05-26"
next_step: "Keep route copy and app claims synchronized with product releases."
---
# Guidelines - TubeFlow Site

## Product Truth

- Market the current product honestly.
- Mark future capabilities as upcoming instead of present-tense facts.
- Keep CTA text aligned with the destination app flow and real onboarding path.

## Content Rules

- Lead with active learning outcomes, not generic productivity language.
- Explain the timestamped note workflow in concrete terms.
- Prefer short, scannable sections and direct benefit statements.
- Keep English and French pages aligned in meaning and offer structure.

## Technical Rules

- Route all public site and app URLs through `src/config/site.ts`.
- Add any new public environment variables to `.env.example` with non-production placeholder values.
- Do not hardcode canonical domains in page components, layouts, or structured data.
- Keep changes compatible with Astro conventions and the existing file layout.

## SEO and Metadata

- Canonical URLs must resolve from configured public site values.
- Structured data should never contain production-only or environment-specific private values.
- Titles and descriptions should match the page intent and locale.

## Design and UX

- Preserve a focused, study-oriented feel rather than a generic SaaS look.
- Favor clarity, hierarchy, and legibility over decorative complexity.
- Use visual emphasis to support timestamps, note capture, and review workflows.

## Documentation Rules

- When a doc uses YAML frontmatter, keep it valid and explicit.
- Use ISO dates for `created`, `updated`, and `next_review`.
- Avoid placeholder strings like `unknown` when a safer factual statement is available from the repository.

## Change Checklist

- Update `.env.example` when public env usage changes.
- Update `CLAUDE.md` when stack, commands, or architecture assumptions change.
- Update `shipflow_data/business/business.md` or `shipflow_data/business/branding.md` when product positioning or claims change materially.
