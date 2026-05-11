---
artifact: gtm_context
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "tubeflow_lab"
created: "2026-04-26"
updated: "2026-04-27"
status: "reviewed"
source_skill: sf-docs
scope: "gtm"
owner: "Diane"
confidence: "medium"
risk_level: "medium"
target_segment: "Primary: TubeFlow internal builders/operators. Secondary: technical teams needing a dedicated YouTube transcript worker."
offer: "A focused transcript execution worker that keeps the app layer responsive while handling extraction, normalization, provider execution, and guardrails."
channels: "README onboarding, deployment runbooks, internal engineering docs, and architecture documentation in parent repos."
proof_points: "FastAPI API, multiple providers, yt-dlp preflight, concurrency and timeout controls, structured logs, health endpoint, bearer-token protection."
security_impact: "unknown"
docs_impact: "yes"
evidence:
  - "README.md is the primary onboarding surface in this repo"
  - "server.py exposes a narrow worker contract"
  - "CHANGELOG.md emphasizes reliability, bot-gate handling, and observability"
linked_artifacts:
  - "README.md"
  - "shipflow_data/business/product.md"
  - "shipflow_data/editorial/content-map.md"
depends_on:
  - artifact: "shipflow_data/business/product.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes: []
next_review: "2026-05-26"
next_step: "Keep GTM language scoped to backend value; defer user-facing claims to tubeflow-app."
---

# GTM Context

## Decision Boundary

This GTM artifact is for backend positioning only. User-facing GTM truth belongs to `tubeflow-app`.

## Target Segment

- Primary: internal TubeFlow builder/operator maintaining transcript infrastructure.
- Secondary: technical team deploying a dedicated transcript worker for a video workflow.

## Offer

- Position the worker as infrastructure that protects the app from media-processing complexity.
- Value is operational clarity and transcript reliability, not a standalone consumer offer.
- Core promise: keep orchestration in the app, execute heavy transcript work in the worker.

## Positioning

- Not a standalone end-user SaaS.
- Not a generic AI gateway for arbitrary workloads.
- Not a replacement for the app orchestrator.
- Best fit: dedicated transcript execution service for TubeFlow pipeline operations.

## Channels

- `README.md` for onboarding and adoption.
- Internal deployment documentation for local, Docker, and server execution.
- Parent-product docs for end-user narrative.

## Conversion Path

- Discovery via parent codebase or deployment need.
- Evaluation via API contract, provider coverage, and runtime controls.
- Adoption when teams can deploy and integrate with predictable behavior.

## Proof Points

- Providers: `faster_whisper`, `sensevoice`, `openai_mini`, `openai`, `deepgram`.
- Explicit `/health` and `/transcribe` endpoints.
- Preflight checks with warning and hard limits.
- Structured logs and shared-secret protection.

## KPIs

- Transcript job completion rate.
- Time to diagnose worker failures.
- Oversized job warning versus rejection rate.
- Stability after provider and extraction tool updates.

## Evidence Limits

- No validated acquisition funnel, pricing, or revenue evidence exists in this repo.
- External-market messaging should stay conservative and defer to `tubeflow-app`.
