---
artifact: architecture_context
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "tubeflow-flutter"
created: "2026-05-10"
updated: "2026-05-10"
status: "draft"
source_skill: "sf-docs"
scope: "architecture"
owner: "Diane"
confidence: "medium"
risk_level: "medium"
docs_impact: "yes"
security_impact: "yes"
evidence:
  - "README.md"
  - "tubeflow_app/ARCHITECTURE.md"
  - "tubeflow_site/ARCHITECTURE.md"
  - "tubeflow_lab/ARCHITECTURE.md"
linked_systems:
  - "Flutter Web"
  - "Vercel"
  - "Astro"
  - "FastAPI"
  - "Clerk"
  - "Convex"
  - "YouTube OAuth"
external_dependencies:
  - "Clerk"
  - "Convex"
  - "Google OAuth / YouTube API"
  - "Vercel"
  - "Astro"
  - "FastAPI"
  - "yt-dlp"
  - "ffmpeg"
invariants:
  - "AGENTS.md remains a compatibility symlink to AGENT.md."
  - "Astro runtime content frontmatter follows tubeflow_site/src/content.config.ts."
  - "Public site claims stay bounded by app/product contracts and the claim register."
depends_on:
  - "shipflow_data/technical/guidelines.md"
supersedes: []
next_review: "2026-06-10"
next_step: "/sf-docs technical audit"
---

# Architecture Context

## System Map

- `tubeflow_app`: Flutter web client with Riverpod, go_router, Clerk auth, Convex client state, Vercel static deployment, and Vercel API handlers for YouTube OAuth.
- `tubeflow_site`: Astro static marketing site with English/French routes, blog content collection, public pricing/comparison/trust pages, and app CTA routing through `src/config/site.ts`.
- `tubeflow_lab`: FastAPI transcript worker for media download, normalization, provider transcription, health checks, and operational deployment.

## Integration Boundaries

- The shared Convex backend is external to this monorepo and remains a separate source of truth.
- Flutter app code under `lib/convex/` is client transport/state, not backend schema or functions.
- Public site content must use app/product contracts as claim boundaries.
- Worker secrets, provider keys, cookies, and raw logs must not be copied into docs.

## Invariants

- `AGENTS.md`, when present, is a compatibility symlink to `AGENT.md`.
- Astro runtime content frontmatter follows `tubeflow_site/src/content.config.ts`.
- YouTube OAuth callback behavior must stay aligned across Flutter app routes and Vercel handlers.
