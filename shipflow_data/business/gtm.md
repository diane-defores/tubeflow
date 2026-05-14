---
artifact: gtm_context
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "replayglowz"
created: "2026-05-10"
updated: "2026-05-10"
status: "draft"
source_skill: "sf-docs"
scope: "gtm"
owner: "Diane"
confidence: "medium"
risk_level: "medium"
target_segment: "Solo creators, students, educators, and learning-driven professionals evaluating structured YouTube learning workflows."
offer: "ReplayGlowz app access positioned around organized YouTube learning, with LTD plus recurring subscription language in reviewed subproject contracts."
channels:
  - "Astro marketing site"
  - "Blog"
  - "Pricing page"
  - "Comparison page"
proof_points:
  - "Flutter app implements authenticated YouTube-oriented note, playlist, and feedback workflows."
  - "Astro site exposes landing, feature, pricing, comparison, blog, privacy, and terms pages."
  - "Transcript worker exists as a separate backend capability."
docs_impact: "yes"
security_impact: "unknown"
evidence:
  - "replayglowz_site/shipflow_data/business/gtm.md"
  - "replayglowz_app/shipflow_data/business/gtm.md"
  - "replayglowz_site/src/pages/pricing.astro"
  - "replayglowz_site/src/pages/compare.astro"
depends_on:
  - "shipflow_data/business/business.md"
  - "shipflow_data/business/branding.md"
supersedes: []
next_review: "2026-06-10"
next_step: "/sf-docs editorial audit"
---

# GTM Context

## Primary Surface

`replayglowz_site` owns acquisition, public education, pricing, comparison, blog, and trust pages. It must not introduce product claims that conflict with `replayglowz_app`.

## Promise

The safe public promise is: ReplayGlowz helps users turn YouTube learning into organized, timestamped, revisitable knowledge workflows.

## Proof Limits

Do not strengthen claims about AI, automation, time savings, compliance, security, or billing beyond verified product behavior and reviewed contracts.
