---
artifact: gtm_context
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "tubeflow-site"
created: "2026-04-26"
updated: "2026-04-27"
status: reviewed
source_skill: sf-docs
scope: gtm
owner: "Diane"
confidence: high
risk_level: medium
target_segment: "Solo creators, students, educators, and learning-driven professionals using video as a core workflow"
offer: "A learning-focused video workflow: playback plus timestamped notes, organization, and fast review"
channels: "SEO blog content, product-led landing pages, comparison pages, pricing pages, bilingual homepage traffic, and direct app CTAs"
proof_points: "Timestamped notes, click-to-seek review framing, playlists, search framing, export framing, distraction-reduction narrative, and bilingual EN/FR acquisition pages"
security_impact: unknown
docs_impact: yes
evidence:
  - "README.md"
  - "src/config/site.ts"
  - "src/pages/index.astro"
  - "src/pages/features.astro"
  - "src/pages/pricing.astro"
  - "src/pages/compare.astro"
  - "src/pages/blog/index.astro"
  - "src/pages/fr/index.astro"
  - "tubeflow_app/shipflow_data/business/gtm.md"
linked_artifacts:
  - "shipflow_data/business/product.md"
  - "shipflow_data/editorial/content-map.md"
depends_on:
  - artifact: "shipflow_data/business/product.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "tubeflow_app/shipflow_data/business/gtm.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes:
  - artifact_version: "0.1.0"
next_review: "2026-05-27"
next_step: "/sf-docs audit shipflow_data/business/gtm.md"
---

# GTM Context

## GTM Scope

This repository is the acquisition and conversion layer for TubeFlow. Canonical product truth is maintained in `tubeflow_app`.

GTM claims in this file are reviewed for marketing use, not for implementation proof.

## Target Segment

Primary segment:

- Solo creators who use video as an execution and learning surface.
- Students and educators using long-form video for structured learning.
- Professionals and self-directed learners with repeat retrieval needs.

Secondary segment:

- Researchers and analysts who need source-linked notes instead of generic bookmarks.

## Offer

Core offer:

`Learn from video without losing context.`

Operational expression:

- Watch in a focused workflow.
- Capture notes at exact moments.
- Revisit source context instantly.
- Organize learning assets for reuse.

## Positioning

TubeFlow is positioned between:

1. Algorithm-first video platforms optimized for watch time.
2. Generic notes tools that break source context.

Positioning line:

`TubeFlow is a learning layer for video, not a replacement video platform.`

## Channels

Evidence-backed channels:

- Homepage conversion on `/`.
- Feature education on `/features`.
- Evaluation and objection handling on `/compare`.
- Plan intent capture on `/pricing`.
- SEO acquisition via `/blog`.
- French acquisition surface on `/fr`.

## Conversion Path

1. Visitor arrives via blog, homepage, comparison, or features page.
2. Visitor understands the timestamped-note learning workflow.
3. Visitor clicks CTA to app routes via `appUrl('/videos')`.
4. Visitor starts with free access and qualifies for paid upgrades.

## Proof Points Safe to Use

- Timestamped notes and source-linked review workflow.
- Organization and search positioning for video learning.
- Bilingual marketing support (EN and FR).
- Product-led entry with direct app CTAs.

## Claims That Need Caution

- Numeric trust claims (for example "2,000+ users") need independent proof.
- Security depth claims (for example encryption wording) need technical substantiation.
- Real-time sync and broad compatibility claims should be treated as marketing assertions.
- Pricing page packaging (Free/Pro monthly) must stay compatible with canonical `LTD + subscription` direction in `tubeflow-app`.

## Core Objections

| Objection | Response direction supported by the repo |
|---|---|
| "Why not just use YouTube?" | YouTube is for discovery and entertainment; TubeFlow is for intentional learning and retrieval |
| "Why not use YouTube plus a notes app?" | External notes lose source context; TubeFlow keeps timestamps connected |
| "Is this only for students?" | No; copy also addresses creators, educators, and professionals |
| "Does this replace YouTube?" | No; TubeFlow is complementary |

## GTM Discipline

- Keep note-taking and review as the primary promise.
- Use anti-distraction framing as a hook, not the full narrative.
- Resolve product-level messaging conflicts in favor of `tubeflow_app` artifacts.
