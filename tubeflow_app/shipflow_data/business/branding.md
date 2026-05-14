---
artifact: brand_context
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "tubeflow-app"
created: "2026-04-26"
updated: "2026-04-27"
status: "reviewed"
source_skill: "sf-init"
scope: "branding"
owner: "Diane"
confidence: "high"
risk_level: "medium"
target_audience: "Solo creators, students, and educators using YouTube for productivity and learning"
value_proposition: "Turn YouTube watch time into organized, reusable learning and execution flow"
market: "Bilingual English/French web users"
docs_impact: "yes"
security_impact: "none"
evidence:
  - "shipflow_data/business/product.md reviewed product scope and claim boundaries"
  - "shipflow_data/business/business.md reviewed business direction (LTD + subscription, segments confirmed)"
  - "Owner decisions confirmed in working session on 2026-04-27"
brand_voice: "Professional, clear, practical, and low-hype"
trust_posture: "Conservative on claims; only promise workflows the shipped app clearly supports"
depends_on:
  - artifact: "shipflow_data/business/product.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipflow_data/business/business.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes:
  - artifact_version: "0.1.0"
next_review: "2026-05-26"
next_step: "Use as source of truth for bilingual copy and landing-page messaging."
---

# Branding Context

## Brand Role

ReplayGlowz's brand should make the product feel like a focused personal workspace for learning from YouTube. The brand should reduce cognitive load, not add hype.

The brand direction is confirmed for a productivity and learning positioning aimed first at solo creators, students, and educators.

## Brand Voice

Professional, clear, practical, and low-hype.

The product should sound capable and structured without becoming academic, corporate, or inflated. It should speak to the workflow users already recognize: watch, capture, organize, revisit.

## Address Style

Default to direct, plain language in both English and French.

French and English should carry the same intent, confidence, and level of detail. Avoid treating one language as secondary.

## Personality

- Focused.
- Reliable.
- Practical.
- Thoughtful.
- Low-friction.
- Respectful of user attention.

## Messaging Pillars

- Turn watch time into productive output.
- Capture timestamped notes while context is fresh.
- Organize useful videos into reusable playlists.
- Return to what mattered without rebuilding the trail.
- Support ongoing learning and veille with low friction.
- Keep claims grounded in actual product behavior.

## Official Tagline

English:
"Turn YouTube watch time into organized learning."

French:
"Transforme ton temps YouTube en apprentissage organise."

Short fallback (UI-constrained surfaces):

- EN: "Watch. Note. Learn."
- FR: "Regarde. Note. Apprends."

## Values

- Clarity over noise.
- Utility over gimmicks.
- Flow over friction.
- Concrete workflows over abstract productivity claims.
- Trustworthy handling of sessions and user content.

## What the Brand Is Not

- Not playful to the point of reducing trust.
- Not corporate or inflated.
- Not overloaded with productivity jargon.
- Not vague about what the product actually helps users do.
- Not an AI product unless AI functionality is implemented and documented.
- Not a creator growth platform unless creator-side workflows are implemented and documented.

## Writing Guidance

- Lead with the user's workflow: watch, capture, organize, revisit.
- Prefer concrete product language over abstract vision statements.
- Reflect the confirmed model direction (`LTD + subscription`) without inventing pricing details.
- Avoid claims about AI, automation, analytics, collaboration, or creator growth unless the feature exists.
- Keep CTAs short and specific.
- Treat sign-in and YouTube connection as practical product steps, not as hidden details.
- When unsure, write narrower copy rather than broader copy.

## Claim Boundaries

Safe claims:

- ReplayGlowz helps users capture timestamped notes from YouTube videos.
- ReplayGlowz supports playlists and viewing continuity.
- ReplayGlowz is built around authenticated persistence.
- ReplayGlowz serves solo creators, students, and educators.
- ReplayGlowz follows an `LTD + subscription` trajectory.

Unsafe claims until confirmed:

- The best YouTube note-taking app.
- AI-powered learning workspace.
- Built for teams.
- Guaranteed creator growth outcomes.
- Enterprise-ready knowledge management.
- Exact pricing promises, offer limits, or "unlimited" language.
