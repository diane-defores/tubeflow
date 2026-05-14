---
artifact: editorial_content_context
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "replayglowz"
created: "2026-05-10"
updated: "2026-05-10"
status: "draft"
source_skill: sf-docs
scope: "claim-register"
owner: "Diane"
confidence: "medium"
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
content_surfaces:
  - "public_site"
  - "repo_docs"
claim_register: "shipflow_data/editorial/claim-register.md"
page_intent: "shipflow_data/editorial/page-intent-map.md"
linked_systems:
  - "tubeflow_site/src/pages"
  - "tubeflow_app"
  - "tubeflow_lab"
depends_on:
  - "shipflow_data/business/product.md"
  - "shipflow_data/business/gtm.md"
supersedes: []
evidence:
  - "tubeflow_app/shipflow_data/business/product.md"
  - "tubeflow_site/shipflow_data/business/product.md"
  - "tubeflow_lab/shipflow_data/business/product.md"
next_review: "2026-06-10"
next_step: "/sf-docs editorial audit"
---

# Claim Register

| Claim area | Safe status | Evidence | Rule |
| --- | --- | --- | --- |
| Timestamped notes | supported | `tubeflow_app/README.md`, app screens/models | May be described as current product behavior. |
| Playlists and viewing workflows | supported | `tubeflow_app/README.md`, app providers/screens | May be described as current product behavior. |
| YouTube OAuth connect | supported with constraints | `tubeflow_app/api/auth/**`, app OAuth spec | Mention web redirect behavior only when aligned with implementation. |
| Transcript worker | internal/backend capability | `tubeflow_lab/server.py`, worker README | Do not market as a user-facing guarantee without app integration evidence. |
| AI automation | needs proof | No root-level reviewed proof in this update | Avoid present-tense public claims unless implemented and documented. |
| Time savings or productivity gains | needs proof | No quantified evidence in reviewed contracts | Use qualitative wording; avoid numeric gains. |
| Security/compliance/privacy | sensitive | Privacy/terms pages and implementation | Do not strengthen without legal and implementation evidence. |
| Pricing/LTD/subscription | sensitive | Business and GTM contracts | Keep pricing copy synchronized with actual offer and entitlement implementation. |
| Availability/reliability | sensitive | Deployment docs only | Avoid uptime or reliability guarantees unless evidence exists. |

## Claim Impact Plan

- Changed claim: `[claim]`
- Surface: `[route/file]`
- Evidence checked: `[contract/code/spec]`
- Status: `[supported|needs proof|claim mismatch|blocked]`
- Required action: `[none|weaken|remove|add proof|human review]`
