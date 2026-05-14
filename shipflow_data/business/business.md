---
artifact: business_context
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "replayglowz"
created: "2026-05-10"
updated: "2026-05-10"
status: "draft"
source_skill: "sf-docs"
scope: "business"
owner: "Diane"
confidence: "medium"
risk_level: "medium"
business_model: "LTD offer plus recurring subscription, with app-level pricing and entitlement truth owned by tubeflow_app."
market: "Bilingual English/French web audience for learning-centric YouTube workflows."
target_audience: "Solo creators, students, educators, and learning-driven professionals who use YouTube for structured learning and ongoing veille."
value_proposition: "Turn YouTube watch time into organized, timestamped, revisitable learning workflows."
docs_impact: "yes"
security_impact: "unknown"
evidence:
  - "README.md"
  - "tubeflow_app/shipflow_data/business/business.md"
  - "tubeflow_site/shipflow_data/business/business.md"
  - "tubeflow_lab/shipflow_data/business/business.md"
depends_on:
  - "shipflow_data/business/product.md"
supersedes: []
next_review: "2026-06-10"
next_step: "/sf-docs audit"
---

# Business Context

## Mission

ReplayGlowz helps learning-focused YouTube users turn watch sessions into structured notes, playlists, retrieval, and review workflows.

## Monorepo Role

This repository consolidates three active surfaces:

- `tubeflow_app`: the authenticated Flutter application and primary product contract.
- `tubeflow_site`: the public acquisition and education site.
- `tubeflow_lab`: the transcript worker and backend experimentation surface.

## Audience

The documented audience is solo creators, students, educators, and learning-driven professionals who use video for learning, curation, or ongoing veille.

## Business Model

The subproject contracts describe an LTD offer plus recurring subscription. Pricing, entitlement, and packaging decisions must remain aligned with the app contract before they are promoted on public pages.

## Decision Boundary

This root contract coordinates the monorepo. Product-level truth remains in `tubeflow_app`; public claims are routed through `tubeflow_site`; transcript-worker operational claims are routed through `tubeflow_lab`.
