---
artifact: brand_context
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "tubeflow_lab"
created: "2026-04-26"
updated: "2026-04-27"
status: "reviewed"
source_skill: sf-docs
scope: "branding"
owner: "Diane"
confidence: "medium"
risk_level: "low"
docs_impact: "yes"
security_impact: "none"
evidence:
  - "README.md"
  - "server.py"
brand_voice: "Practical, explicit, and operational"
trust_posture: "State assumptions clearly and avoid inflating transcript accuracy or platform scope"
depends_on:
  - "shipflow_data/business/business.md@1.0.0"
supersedes: []
next_review: "2026-05-26"
next_step: "Mirror public brand decisions from tubeflow-app while keeping this repo operational."
---

# shipflow_data/business/branding.md

## Decision Boundary

`tubeflow_lab` is not the public product surface. Public messaging and user-facing brand decisions belong to `tubeflow-app`.

## Brand Role Of This Repo

This repository uses an internal technical voice for operators and developers. It should stay practical, specific, and low-claim.

## Voice Guidelines

- Clear over clever.
- Operational over promotional.
- Specific over aspirational.
- Honest about limits and failure modes.

## Messaging Constraints

- Do not claim capabilities that are not implemented in `server.py`.
- Do not imply guaranteed transcript accuracy.
- Do not present internal rate estimates as public pricing.
- Do not frame this repository as the whole ReplayGlowz platform.

## Terminology

Preferred terms:

- transcript worker
- provider
- job
- preflight
- warning threshold
- hard limit
- bot-gated video

Avoid unless proven elsewhere:

- AI-powered platform
- enterprise-grade
- best-in-class
- unlimited
- fully automated

## Writing Style For Repo Docs

- Use short sections and direct headings.
- Explain operational impact, not only feature names.
- State when behavior is optional, required, or environment-specific.
- Keep a clean boundary between verified facts and assumptions.
