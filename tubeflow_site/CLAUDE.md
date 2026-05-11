# CLAUDE.md

This file provides guidance to coding agents working in this repository.

## Project Overview

- Project: `tubeflow-site`
- Type: Astro marketing site
- Runtime: Node.js `>=22.12.0`
- Styling: Tailwind CSS v4 through Vite
- Locales: `en` and `fr`
- Purpose: public-facing site for TubeFlow, with marketing pages and blog content that route users into the app

## Commands

- `npm install` - install dependencies
- `npm run dev` - start the Astro dev server
- `npm run build` - create the production build
- `npm run preview` - preview the built site
- `npm run astro -- --help` - access Astro CLI help

## Architecture

- `src/pages` - route files for the main site, blog pages, and French pages
- `src/components` - reusable Astro components used across landing pages
- `src/layouts` - page-level layout wrappers
- `src/content/blog` - blog content
- `src/config/site.ts` - canonical source for site/app URLs and contact email generation
- `src/i18n` - locale support files
- `src/styles` - shared styling entrypoints

## Environment

Public runtime config is read from `src/config/site.ts`:

- `PUBLIC_SITE_URL`
- `PUBLIC_APP_URL`
- `PUBLIC_EMAIL_DOMAIN`

Use safe placeholders in `.env.example`. Do not commit production-only secrets or environment-specific private values.

## Working Conventions

- Preserve the Astro structure unless there is a clear reason to refactor.
- Keep all canonical URLs, structured-data URLs, and app CTA destinations flowing through `src/config/site.ts`.
- Treat this repo as a marketing site, not the product app. Marketing copy must not promise features that the product cannot currently support.
- Keep English and French content aligned in meaning, not just wording.
- When editing docs, maintain valid YAML frontmatter where present and prefer explicit dates over `unknown`.

## Content and Brand References

- Business context lives in `shipflow_data/business/business.md`.
- Brand direction lives in `shipflow_data/business/branding.md`.
- Implementation and editing guardrails live in `shipflow_data/technical/guidelines.md`.

## Agent Notes

- Prefer minimal, targeted edits.
- Avoid hardcoding environment-specific domains in source when a config helper already exists.
- If you introduce new public environment variables, update `.env.example`, `README.md`, and this file in the same change.
