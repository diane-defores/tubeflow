---
artifact: business_context
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "tubeflow-site"
created: "2026-04-25"
updated: "2026-04-27"
status: "reviewed"
source_skill: "sf-docs"
scope: "business"
owner: "Diane"
confidence: "high"
risk_level: "medium"
security_impact: "unknown"
docs_impact: "yes"
target_audience: "Solo creators, students, and educators who use video for structured learning and ongoing veille"
value_proposition: "TubeFlow turns watch time into organized learning with timestamped notes, retrieval, and focused review."
business_model: "LTD offer + recurring subscription"
market: "Bilingual English/French web audience for learning-centric video workflows"
depends_on:
  - artifact: "tubeflow_app/shipflow_data/business/business.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "tubeflow_app/shipflow_data/business/product.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes:
  - artifact_version: "0.1.1"
evidence:
  - "README.md (repo positioned as TubeFlow marketing site)"
  - "src/config/site.ts (PUBLIC_APP_URL points to app.tubeflow.winflowz.com)"
  - "src/pages/pricing.astro (commercial offer and upgrade framing)"
  - "tubeflow_app/shipflow_data/business/business.md (canonical product business contract)"
next_review: "2026-05-26"
next_step: "Keep public pricing copy and offer framing aligned with the canonical app business contract."
---
# Business Context

## Role of This Repo in Business Decisions

`tubeflow-site` is the acquisition and conversion surface for TubeFlow. It is not the canonical product contract.

Canonical product truth lives in `tubeflow_app`. This site can frame, qualify, and convert demand, but it should not introduce business claims that diverge from the app contract.

## Mission

Convert visitors who learn from video into activated app users by presenting a clear value proposition:

"Turn watch time into organized learning."

## Business Direction (Canonical Alignment)

Confirmed direction inherited from the canonical product business contract:

- Monetization model: `LTD + recurring subscription`.
- Priority segments: solo creators, students, educators.
- Positioning axis: productivity plus learning/veille workflows.

Site-level pricing copy can vary by package naming, but it must stay compatible with this business direction.

## Value Proposition for Site Conversion

The strongest defensible message on this repository is:

- Users can capture timestamped notes while watching video.
- Users can revisit exact moments quickly.
- Users can organize and retrieve learning material more reliably.

The site should treat any advanced claims as qualified commercial messaging unless implementation evidence is available in the canonical app contract.

## Target Audience

Primary:

- Solo creators using video as an execution or research surface.
- Students following lectures, courses, and tutorial workflows.
- Educators curating and revisiting instructional video content.

Secondary:

- Self-directed learners and professionals with similar watch-note-review behavior.

## Positioning

TubeFlow sits between algorithm-first video consumption and disconnected note-taking tools. The differentiation is preserving learning context at source timestamp granularity while reducing friction to retrieval.

## Conversion Metrics

- Visitor -> app click-through from `/`, `/features`, `/compare`, `/pricing`, `/fr`.
- Visitor -> signup conversion once redirected to app routes.
- Activation quality (first note created, repeat use signals) tracked in the app layer.

## Business Claim Guardrails

- Safe claims: timestamped notes, focused learning workflow, bilingual audience support, and `LTD + subscription` direction.
- Review-required claims: hard numbers (for example user counts), security/compliance depth, and roadmap features presented as shipped.
