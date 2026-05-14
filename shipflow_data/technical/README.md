---
artifact: documentation
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "replayglowz"
created: "2026-05-10"
updated: "2026-05-10"
status: "draft"
source_skill: sf-docs
scope: "technical"
owner: "Diane"
confidence: "medium"
risk_level: "medium"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "shipflow_data/technical/code-docs-map.md"
depends_on:
  - "shipflow_data/technical/architecture.md"
  - "shipflow_data/technical/guidelines.md"
supersedes: []
evidence:
  - "README.md"
next_step: "/sf-docs technical audit"
---

# Technical Governance

This directory maps code areas to the documentation that must be checked when implementation changes.

## Files

- `architecture.md`: monorepo architecture and integration boundaries.
- `guidelines.md`: engineering and documentation rules across subprojects.
- `code-docs-map.md`: path-to-doc routing for technical updates.

## Maintenance Rule

Update this layer when a subproject is added, removed, renamed, or changes its validation commands, runtime boundaries, auth, public API, or deployment model.
