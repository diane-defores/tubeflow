---
artifact: product_context
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "tubeflow-flutter"
created: "2026-05-10"
updated: "2026-05-10"
status: "draft"
source_skill: "sf-docs"
scope: "product"
owner: "Diane"
confidence: "medium"
risk_level: "medium"
target_user: "Learning-focused YouTube users who need notes, playlists, retrieval, review, and optional transcript support across TubeFlow surfaces."
user_problem: "Video learning becomes fragmented when playback, notes, playlists, feedback, transcripts, and later retrieval live in disconnected tools."
desired_outcomes: "Capture timestamped notes, organize videos and playlists, reconnect YouTube reliably, submit feedback, and support transcript workflows through a dedicated worker."
non_goals: "Entertainment discovery, creator publishing infrastructure, a generic video platform, collaboration suite, or unproven AI automation claims."
docs_impact: "yes"
security_impact: "unknown"
evidence:
  - "tubeflow_app/PRODUCT.md"
  - "tubeflow_site/PRODUCT.md"
  - "tubeflow_lab/PRODUCT.md"
depends_on: []
supersedes: []
next_review: "2026-06-10"
next_step: "/sf-docs audit"
---

# Product Context

## Product Truth

TubeFlow is an authenticated video-learning workflow centered on YouTube playback, timestamped notes, playlists, history, feedback, and backend-supported transcript operations.

## Core Workflows

- Watch YouTube videos in the app.
- Capture and revisit timestamped notes.
- Organize videos and playlists.
- Connect YouTube through the web OAuth redirect flow.
- Submit feedback from the app.
- Run transcript work through the separate FastAPI worker when enabled by backend integration.

## Non-Goals

Do not describe TubeFlow as a creator publishing platform, generic video platform, entertainment discovery engine, collaboration suite, or AI automation product unless the implementation and reviewed contracts prove that capability.
