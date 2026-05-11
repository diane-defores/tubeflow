---
artifact: brand_context
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "tubeflow-site"
created: "2026-04-25"
updated: "2026-04-27"
status: "reviewed"
source_skill: "sf-docs"
scope: "brand"
owner: "Diane"
confidence: "high"
risk_level: "medium"
security_impact: "none"
docs_impact: "yes"
brand_voice: "Professional, clear, practical, and low-hype in both English and French"
trust_posture: "Conservative claims only; marketing copy must stay compatible with canonical app truth"
depends_on:
  - artifact: "tubeflow_app/shipflow_data/business/branding.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "tubeflow_app/shipflow_data/business/business.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes:
  - artifact_version: "0.1.1"
evidence:
  - "README.md (site role is marketing and conversion)"
  - "src/pages/index.astro (hero and CTA framing)"
  - "src/pages/features.astro (benefit language and workflow framing)"
  - "src/pages/fr/index.astro (active French marketing surface)"
  - "tubeflow_app/shipflow_data/business/branding.md (canonical brand contract)"
next_review: "2026-05-26"
next_step: "Apply these voice rules to homepage, features, compare, pricing, and bilingual surfaces."
---
# Branding Context

## Brand Idea

TubeFlow should feel like a focused learning workspace layered on top of video usage. The brand should emphasize practical control, retrieval speed, and low-distraction execution.

## Name

TubeFlow combines:

- `Tube`: a direct reference to online video
- `Flow`: continuity, focus, and forward motion while learning

## Official Tagline

English:
"Turn YouTube watch time into organized learning."

French:
"Transforme ton temps YouTube en apprentissage organise."

## Voice and Tone

- Clear over clever
- Specific over hype
- Practical over academic
- Calm over aggressive

The copy should sound confident and useful. Avoid inflated claims about AI, productivity, or learning outcomes unless the product can prove them.

## Bilingual Policy

- English and French are both first-class marketing surfaces.
- Do not treat French as a literal translation fallback.
- Keep product nouns consistent across locales (notes, timestamps, playlists, review).

## Messaging Priorities

1. Timestamped notes keep context attached to the source.
2. Review is faster because users can jump back to exact moments.
3. The workflow supports focused learning, productivity, and veille.
4. The product is simple enough to adopt immediately.

## Visual Direction

- Clean layouts with strong separation between watching and working
- A restrained base palette with one sharper accent for timestamps, CTAs, and highlights
- High legibility over decorative density
- Motion that supports flow, not novelty

## UX Motifs

- Split-screen or paired-surface compositions
- Timeline and note relationships shown clearly
- Timestamp elements treated as actionable anchors
- Study-oriented framing rather than entertainment-oriented framing

## Trust Guidelines

- Do not present roadmap items as shipped parity.
- Keep product screenshots, structured data, and CTA language in sync with the real app path configured through environment variables.
- Prefer proof points, examples, and concrete workflow benefits over abstract slogans.
