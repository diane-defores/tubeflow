---
artifact: product_context
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "replayglowz_lab"
created: "2026-04-26"
updated: "2026-04-27"
status: "reviewed"
source_skill: sf-docs
scope: "product"
owner: "Diane"
confidence: "medium"
risk_level: "medium"
target_user: "ReplayGlowz operators and developers needing reliable transcript execution outside the app runtime"
user_problem: "the app layer should not own long-running media downloads, ffmpeg normalization, model loading, or provider-specific transcription failures"
desired_outcomes: "offload heavy jobs safely, keep orchestration responsive, support multiple providers, and expose clear health/limit/failure signals"
non_goals: "being the main user-facing product, owning transcript editing UX, replacing app orchestration, or becoming a generic media-processing platform"
security_impact: "yes"
docs_impact: "yes"
evidence:
  - "README.md defines the worker as the heavy transcript execution component"
  - "server.py implements /health and /transcribe with bearer-token authorization"
  - "requirements.txt confirms FastAPI, yt-dlp, and transcription provider dependencies"
  - "CHANGELOG.md tracks operational behavior changes"
linked_artifacts:
  - "README.md"
  - "shipflow_data/business/gtm.md"
  - "shipflow_data/editorial/content-map.md"
depends_on: []
supersedes: []
next_review: "2026-05-26"
next_step: "Keep user-facing product claims in replayglowz-app and limit this doc to worker scope."
---

# Product Context

## Decision Boundary

`replayglowz_lab` documents a backend and experimental worker surface. The user-facing product truth is in `replayglowz-app`.

## Target User

- Direct user: operator/developer maintaining transcript generation reliability.
- Indirect beneficiary: end user receiving transcript output in the parent app.

## Problem

- Orchestration code should not run heavy media extraction and transcription tasks.
- Transcript jobs are long-running and can fail for external reasons.
- Without a dedicated worker, scaling and incident handling become harder.

## Desired Outcomes

- Keep orchestration responsive in the app layer.
- Execute transcript jobs through a narrow worker API contract.
- Support multiple providers without changing the integration surface.
- Provide visible health and runtime control signals for operations.

## Product Principles

- Keep scope narrow: transcript execution, not general backend expansion.
- Fail explicitly with actionable diagnostics.
- Prefer configurable guardrails over hidden behavior.
- Preserve a stable contract as providers evolve.

## Core Workflows

- `POST /transcribe` receives provider, video id, language, and optional API key.
- Worker performs preflight checks, extraction, normalization, and transcription.
- Worker returns normalized segments, full text, estimated cost, and warnings.
- `GET /health` reports readiness and key runtime dependencies.

## Scope In

- YouTube transcript execution for ReplayGlowz pipeline needs.
- Provider switching across local and API-backed transcription options.
- Runtime controls for limits, timeouts, concurrency, and auth.
- Deployment patterns for local, Docker, and server hosting.

## Scope Out

- User-facing UI, onboarding, and pricing narrative.
- Transcript browsing/editing experience.
- Product packaging and commercialization decisions.
- Non-ReplayGlowz media workflows.

## Success Signals

- Heavy jobs are delegated without degrading orchestration responsiveness.
- Failures are diagnosable from health checks and logs.
- Large or bot-gated jobs fail with explicit reasons.
- Provider changes preserve the app-to-worker contract.
