# TubeFlow Site

Marketing site for TubeFlow, built with Astro.

## Environment

Copy `.env.example` and override these values when the domains change:

```bash
PUBLIC_SITE_URL=https://tubeflow.winflowz.com
PUBLIC_APP_URL=https://app.tubeflow.winflowz.com
PUBLIC_EMAIL_DOMAIN=winflowz.com
```

All canonicals, structured data URLs, and CTA links read from these variables through `src/config/site.ts`.

## Commands

All commands are run from the root of the project, from a terminal:

| Command                   | Action                                           |
| :------------------------ | :----------------------------------------------- |
| `npm install`             | Installs dependencies                            |
| `npm run dev`             | Starts local dev server at `localhost:4321`      |
| `npm run build`           | Build your production site to `./dist/`          |
| `npm run preview`         | Preview your build locally, before deploying     |
| `npm run astro ...`       | Run CLI commands like `astro add`, `astro check` |
| `npm run astro -- --help` | Get help using the Astro CLI                     |
