---
artifact: gtm_context
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "tubeflow-app"
created: "2026-04-26"
updated: "2026-04-26"
status: reviewed
source_skill: sf-docs
scope: gtm
owner: "Diane"
confidence: medium
risk_level: medium
target_segment: "Self-serve individual users who actively learn from or organize YouTube content and want structured note-taking plus continuity features."
offer: "A web app that combines YouTube watching, timestamped notes, playlists, history-oriented organization, and account-backed persistence in one flow."
channels: "Direct web app access, README-driven operator onboarding, in-product sign-in and YouTube connect activation flows, and in-app feedback collection."
proof_points: "Timestamped note-taking, playlists, viewing history, Clerk authentication, Convex-backed persistence, Vercel deployment, YouTube OAuth support, and built-in feedback routes."
security_impact: unknown
docs_impact: yes
evidence:
  - "README.md"
  - "CLAUDE.md"
  - ".env.example"
  - "vercel.json"
  - "lib/app/router.dart"
  - "specs/feedback-v1.md"
  - "specs/flutter-web-youtube-auth-redirect-spec.md"
linked_artifacts:
  - "PRODUCT.md"
  - "BUSINESS.md"
  - "BRANDING.md"
  - "CONTENT_MAP.md"
  - "README.md"
depends_on:
  - artifact: "PRODUCT.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes:
  - artifact_version: "0.1.0"
next_review: "2026-05-26"
next_step: "/sf-docs audit"
---

# GTM Context

## GTM Scope

This file defines go-to-market claims that are supportable from the repository. It is not a full commercial strategy because pricing, ICP, channel strategy, and monetization are not evidenced in code or docs.

Reviewed GTM posture: product-led, narrow, and feature-grounded.

## Target Segment

The repo supports a practical self-serve segment:

- Individual users.
- Heavy YouTube use for learning, research, tutorials, or repeat reference.
- Need for structured recall through notes, playlists, and history-like continuity.
- Willingness to sign in for persistent state.
- Possible need to connect YouTube for richer account-linked workflows.

The repo does not establish demographics, price sensitivity, geography, buyer role, or a formal ICP.

## Offer

Working offer:

"Use one web app to watch YouTube content, capture timestamped notes, manage playlists, and keep viewing context without stitching multiple personal tools together."

The strongest value is workflow compression. TubeFlow is not positioned by the repo as an entertainment discovery engine, a creator growth platform, or a team knowledge base.

## Positioning

Evidence supports positioning around:

- Focused video learning workflow.
- Note-taking tied to playback moments.
- Personal organization across videos and playlists.
- Authenticated continuity across sessions.
- Product feedback loop for improvement.

Evidence does not support positioning around:

- Team collaboration.
- Creator publishing or audience growth.
- Enterprise knowledge management.
- AI-powered summarization, search, or recommendations.
- Analytics-heavy study optimization.
- Public content marketing engine.

## Channels

Observed or repo-adjacent channels:

- Direct app entry through the deployed web origin.
- Sign-in flow as the primary activation gate.
- YouTube connection flow as a secondary activation step.
- Feedback route as a retention and product-learning loop.
- Repository README as operator/developer onboarding.

Absent or unproven channels:

- SEO program.
- Blog engine.
- Public landing pages.
- Paid acquisition scaffolding.
- Lifecycle email or CRM surfaces.
- Partner, creator, school, or team sales motion.

## Conversion Path

The most defensible conversion path from the codebase is activation-oriented:

1. User lands in the app or is directed to it.
2. User signs in through Clerk.
3. User reaches core routes such as videos, play, playlists, notes, and preferences.
4. User connects YouTube when needed.
5. User experiences retained value through notes, playlists, and continuity.
6. User submits feedback if a workflow breaks or expected value is missing.

This is not yet a commercial funnel because pricing, plans, checkout, lifecycle messaging, and sales flows are not evidenced.

## Proof Points

- The app explicitly supports timestamped notes and playlist/video workflows.
- Authentication and persistence are first-class architecture concerns.
- Deployment and OAuth infrastructure support a hosted web product.
- Feedback capture and admin review specs indicate an iteration loop.
- English and French translation assets suggest multilingual usability, though not a validated international GTM strategy.

## Objections

- "Why not just use YouTube plus a notes app?"  
  TubeFlow's defensible answer is the unified workflow and timestamp-specific context.

- "Is this only a prototype?"  
  The repo shows deployment, auth, OAuth, and backend integration, but docs do not prove full launch maturity.

- "Does it work for teams?"  
  No evidence supports team collaboration today.

- "Is there a public product website or docs hub?"  
  Not in this repository.

- "Is this an AI learning product?"  
  Not based on current repo evidence.

## KPIs to Validate Later

These metrics are appropriate to instrument or review later, but they are not proven current KPIs in this repository:

- Sign-in completion rate.
- YouTube connection completion rate.
- Note creation rate per active user.
- Playlist creation or save rate.
- Return usage after first session.
- Feedback submission rate on broken or confusing flows.

## Claim Boundaries

Safe GTM claims:

- YouTube watching plus timestamped notes.
- Playlist and history-oriented organization.
- Authenticated persistence.
- Feedback loop.

Unsafe GTM claims until Diane or implementation confirms them:

- Pricing or paid value.
- Team workflows.
- Creator growth outcomes.
- AI differentiation.
- Enterprise readiness.
- Validated SEO or paid acquisition motion.
