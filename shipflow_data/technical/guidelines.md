---
artifact: technical_guidelines
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "replayglowz"
created: "2026-05-10"
updated: "2026-05-10"
status: "draft"
source_skill: "sf-docs"
scope: "guidelines"
owner: "Diane"
confidence: "medium"
risk_level: "medium"
docs_impact: "yes"
security_impact: "yes"
evidence:
  - "replayglowz_app/shipflow_data/technical/guidelines.md"
  - "replayglowz_site/shipflow_data/technical/guidelines.md"
  - "replayglowz_lab/shipflow_data/technical/guidelines.md"
  - "replayglowz_app/pubspec.yaml"
  - "replayglowz_site/package.json"
  - "replayglowz_lab/requirements.txt"
linked_systems:
  - "Flutter"
  - "Dart"
  - "Astro"
  - "Node.js"
  - "FastAPI"
  - "Python"
  - "Clerk"
  - "Convex"
  - "Vercel"
depends_on:
  - "AGENT.md"
supersedes: []
next_review: "2026-06-10"
next_step: "/sf-docs technical audit"
---

# Technical Guidelines

## General

- Work inside the affected subproject and run focused validation from that directory.
- Keep root documentation as coordination context; keep implementation-specific guidance in subproject docs.
- Preserve existing reviewed contracts unless the code or user decision clearly changes them.

## Flutter App

- Use build-time `--dart-define` values for Flutter web configuration.
- Keep Clerk session handling and Convex JWT minting aligned with `replayglowz_app/README.md` and `replayglowz_app/shipflow_data/technical/architecture.md`.
- Treat the shared Convex backend as external unless `REPLAYGLOWZ_BACKEND_ROOT` points to a local checkout.

## Astro Site

- Route URLs, CTA destinations, and public domains through `replayglowz_site/src/config/site.ts`.
- Preserve Astro content collection schemas before editing blog frontmatter.
- Keep English and French public promises aligned.

## Transcript Worker

- Keep the worker narrow: receive transcript jobs, process audio, return transcript payloads, and expose health/limit signals.
- Never document real secrets, provider tokens, cookies, or raw private logs.
