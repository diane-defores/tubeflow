---
artifact: content_map
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "tubeflow_lab"
created: "2026-04-26"
updated: "2026-04-27"
status: "reviewed"
source_skill: sf-docs
scope: "content-map"
owner: "Diane"
confidence: "medium"
risk_level: "low"
content_surfaces:
  - repo_docs
  - decision_contracts
  - api_contract
  - deployment_runbook
  - release_history
security_impact: "none"
docs_impact: "yes"
evidence:
  - "README.md is the main operational and architecture surface"
  - "server.py is the canonical API and runtime contract"
  - "CHANGELOG.md records operator-visible behavior changes"
linked_artifacts:
  - "README.md"
  - "PRODUCT.md"
  - "GTM.md"
depends_on:
  - artifact: "PRODUCT.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "GTM.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes: []
next_review: "2026-05-26"
next_step: "Keep this map synced when worker API, providers, or deployment model changes."
---

# Content Map

## Purpose

`CONTENT_MAP.md` defines where canonical documentation lives for `tubeflow_lab` and what each surface may claim. This repository is backend/experimental; user-facing product truth is handled in `tubeflow-app`.

## Content Surfaces

| Surface | Canonical path | Purpose | Source of truth | Update when |
|---|---|---|---|---|
| Repo overview and runbook | `README.md` | Explain what the worker does and how to run/deploy it | Worker code and runtime behavior | Endpoints, providers, deployment flow, or env assumptions change |
| Product contract | `PRODUCT.md` | Define worker user, problem, outcomes, scope, and risks | Worker behavior plus explicit boundary to parent product | Worker role in pipeline changes |
| GTM contract | `GTM.md` | Define backend positioning, channels, proof points, and KPIs | Product contract plus distribution reality | Positioning assumptions change |
| Editorial map | `CONTENT_MAP.md` | Route docs to the right surface | Current repository structure | A new content surface appears |
| API/runtime contract | `server.py` | Canonical request models, endpoints, auth, and runtime controls | Implementation | API fields, providers, or behavior change |
| Release history | `CHANGELOG.md` | Operator-visible change ledger | Merged runtime changes | Any behavior change affecting operations |
| Dependency inventory | `requirements.txt` | Runtime dependency list | Active package set | Framework/provider/runtime dependencies change |

## Semantic Architecture

| Cluster | Pillar surface | Supporting surfaces | Target intent | Status |
|---|---|---|---|---|
| Worker purpose and architecture | `README.md` | `PRODUCT.md`, `server.py` | Understand why the worker exists | live |
| Operations and deployment | `README.md` | `CHANGELOG.md`, `requirements.txt` | Run and maintain safely | live |
| API and integration contract | `server.py` | `README.md` | Integrate parent app with predictable behavior | live |
| Product and positioning decisions | `PRODUCT.md` | `GTM.md`, `CONTENT_MAP.md` | Keep scope and messaging coherent | reviewed |

## Page Roles

| Page type | Job | Must include | Must not include |
|---|---|---|---|
| Repo doc | Operational onboarding and architecture | Setup, deployment, endpoint overview | Unverified market claims |
| Product contract | Worker decision boundary | User, problem, workflows, scope, risks | Public pricing or packaging claims |
| GTM contract | Backend positioning boundary | Segment, offer, proof points, KPIs | Revenue claims without evidence |
| Editorial map | Documentation routing | Surfaces, update rules, boundaries | Backlog management |
| Release history | Change ledger | Operator-visible behavior deltas | Full replacement for API/product docs |
| Source contract | Executable truth | Real endpoint/auth/runtime behavior | Marketing language |

## Cross-Surface Update Rules

| Trigger | Check these surfaces |
|---|---|
| Provider added or removed | `README.md`, `PRODUCT.md`, `GTM.md`, `server.py`, `requirements.txt` |
| Endpoint or auth change | `README.md`, `server.py`, deployment notes |
| Deployment model change | `README.md`, `CONTENT_MAP.md` |
| New guardrail or warning behavior | `README.md`, `CHANGELOG.md`, `PRODUCT.md` |
| Parent-product positioning update | `PRODUCT.md`, `GTM.md`, and boundaries referencing `tubeflow-app` |

## Open Gaps

- No dedicated public docs surface exists in this repo.
- API reference is still source-first (`server.py`) plus README narrative.
- Parent-product assumptions must be validated in `tubeflow-app` before external messaging.
