---
artifact: product_context
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "tubeflow-site"
created: "2026-04-26"
updated: "2026-04-27"
status: reviewed
source_skill: sf-docs
scope: product
owner: "Diane"
confidence: high
risk_level: medium
target_user: "Solo creators, students, educators, and learning-driven professionals who use video and need structured retrieval"
user_problem: "Video learning is fragmented when notes, context, and review are split across multiple tools"
desired_outcomes: "Capture timestamped notes, revisit exact moments, organize learning assets, and move from passive watch sessions to reusable knowledge workflows"
non_goals: "Entertainment discovery, social video engagement, creator publishing infrastructure, or a new standalone video platform"
security_impact: unknown
docs_impact: yes
evidence:
  - "README.md"
  - "src/config/site.ts"
  - "src/pages/index.astro"
  - "src/pages/features.astro"
  - "src/pages/pricing.astro"
  - "src/pages/compare.astro"
  - "src/pages/fr/index.astro"
  - "tubeflow_app/shipflow_data/business/product.md"
linked_artifacts:
  - "shipflow_data/business/gtm.md"
  - "shipflow_data/editorial/content-map.md"
depends_on:
  - artifact: "tubeflow_app/shipflow_data/business/product.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes:
  - artifact_version: "0.1.0"
next_review: "2026-05-27"
next_step: "/sf-docs audit shipflow_data/business/product.md"
---

# Product Context

## Product Summary

`tubeflow-site` is the public marketing and conversion layer for TubeFlow. It describes the product promise and routes visitors to the app at `app.tubeflow.winflowz.com`.

Canonical product truth is `tubeflow_app/shipflow_data/business/product.md`. This repository must stay aligned with that contract and avoid introducing a parallel product definition.

## Target User

Primary:

- Solo creators using video as a working knowledge surface.
- Students and educators using video for structured learning.
- Professionals and self-directed learners with repeat retrieval needs.

## Core Problem

Users lose value from video learning when notes are detached from source context and review requires manual timeline hunting.

## Desired Outcomes

TubeFlow should help users:

- watch with intention instead of drifting through recommendations
- capture notes at exact timestamps
- jump back to a precise source moment from any saved note
- organize videos into learning playlists
- search and review knowledge across multiple videos
- upgrade from passive viewing into repeatable study workflows

## Scope In

Claims strongly evidenced in current public copy:

- timestamped notes
- click-to-seek from notes
- support for YouTube plus broad video URL compatibility in public-facing copy
- playlists for organizing videos
- search across notes
- export framing in public-facing copy
- free and Pro plans
- bilingual public marketing support in English and French

## Scope Out

This repo does not justify treating the following as stable commitments:

- team collaboration as a mature current workflow
- broad creator or social features
- live streaming, publishing, or monetization workflows
- verified quantified learning outcomes beyond marketing rhetoric

## Product Positioning

The clearest product framing is:

`TubeFlow helps people learn from video by keeping notes attached to exact playback context.`

Secondary framing around escaping algorithmic distraction is acceptable as a hook, but should remain subordinate to the concrete workflow promise.

## Product Truth Alignment Rule

- This site documents and markets; it does not define app behavior canonically.
- Any product-level conflict resolves in favor of `tubeflow_app/shipflow_data/business/product.md`.
- Roadmap claims must be labeled as planned, not implied as shipped.

## Risks

- The public site implies some capabilities such as cross-device sync, encryption, and broad video support without technical proof inside this repo, so those claims should be treated as marketing assertions rather than implementation evidence.
- The pricing page currently presents Free/Pro monthly packaging, while canonical business direction is `LTD + subscription`; this needs copy discipline to avoid contradictory public messaging.
