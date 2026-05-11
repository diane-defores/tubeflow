---
artifact: content_map
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "tubeflow-app"
created: "2026-04-26"
updated: "2026-04-26"
status: reviewed
source_skill: sf-docs
scope: content-map
owner: "Diane"
confidence: high
risk_level: medium
content_surfaces:
  - repository_readme
  - product_artifacts
  - product_specs
  - release_notes
  - in_app_feedback
  - developer_guidance
security_impact: unknown
docs_impact: yes
evidence:
  - "README.md"
  - "CLAUDE.md"
  - "CHANGELOG.md"
  - "shipflow_data/workflow/TASKS.md"
  - "shipflow_data/workflow/AUDIT_LOG.md"
  - "shipflow_data/business/product.md"
  - "shipflow_data/business/business.md"
  - "shipflow_data/business/branding.md"
  - "shipflow_data/business/gtm.md"
  - "shipflow_data/workflow/specs/feedback-v1.md"
  - "shipflow_data/workflow/specs/flutter-web-youtube-auth-redirect-spec.md"
  - "lib/app/router.dart"
linked_artifacts:
  - "shipflow_data/business/product.md"
  - "shipflow_data/business/business.md"
  - "shipflow_data/business/branding.md"
  - "shipflow_data/business/gtm.md"
  - "README.md"
  - "CHANGELOG.md"
depends_on:
  - artifact: "shipflow_data/business/product.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipflow_data/business/gtm.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes:
  - artifact_version: "0.1.0"
next_review: "2026-05-26"
next_step: "/sf-repurpose"
---

# Content Map

## Purpose

This repository does not contain a public blog, public landing-page system, or docs site. Its content map is therefore centered on product truth, business and brand artifacts, operator docs, specs, release communication, and in-product feedback collection.

This file maps where product and support knowledge belongs so future specs, docs updates, release notes, and repurposed content can land in the right surface without rediscovering the repo.

## Content Surfaces

| Surface | Canonical path | Purpose | Format | Source of truth | Update when |
|---|---|---|---|---|---|
| Repository overview | `README.md` | Public-facing repo summary, setup, stack, env vars, deployment notes | Markdown | Current app implementation plus deployed workflow assumptions | Setup, auth, deploy, env, or architecture expectations change |
| Developer/operator guidance | `CLAUDE.md` | Maintainer guidance for contributors working in this repo | Markdown | Active implementation constraints in frontend auth, routing, Convex integration, and build flow | Architecture, workflow rules, or critical gotchas change |
| Product context | `shipflow_data/business/product.md` | Reviewed product scope, target user, workflows, non-goals, and claim boundaries | Markdown artifact | Evidenced product behavior and specs | Product scope, workflows, or claim boundaries change |
| Business context | `shipflow_data/business/business.md` | Business assumptions, monetization unknowns, target audience, and commercial claim limits | Markdown artifact | Diane decisions plus product evidence | Diane confirms model, segment, ICP, pricing, or commercial strategy |
| Brand context | `shipflow_data/business/branding.md` | Voice, messaging pillars, tagline candidates, and brand claim boundaries | Markdown artifact | Diane decisions plus product and business context | Diane confirms tone, tagline, language priorities, or positioning |
| GTM context | `shipflow_data/business/gtm.md` | Reviewed product-led GTM framing, activation path, proof points, objections, and KPI candidates | Markdown artifact | Product evidence and repo-visible routes/config | Offer, activation, channels, or product proof points change |
| Product specs | `specs/*.md` | Decision and implementation planning for features or refactors | Markdown | Approved product/technical decisions for active work | A feature scope, acceptance criteria, or rollout approach changes |
| Release notes | `CHANGELOG.md` | User-facing change narrative | Markdown | Shipped changes worth communicating | A user-visible feature, fix, or workflow change ships |
| In-app support and product learning | `/feedback`, `/feedback/admin` | Capture user issues and product input; review feedback operationally | Flutter routes backed by app screens and Convex/Vercel flows | Live product behavior and feedback workflow implementation | Feedback collection or admin review flow changes |
| Work trackers | `shipflow_data/workflow/TASKS.md`, `shipflow_data/workflow/AUDIT_LOG.md` | Active backlog and audit trace | Markdown | Current work management, not canonical product truth | Work status changes; do not treat as decision contracts |

## Semantic Architecture

| Cluster | Pillar page | Supporting pages | Target intent | Internal link rule | Status |
|---|---|---|---|---|---|
| Product truth and setup | `README.md` | `shipflow_data/business/product.md`, `CLAUDE.md`, `.env.example`, `vercel.json` | Operator and contributor understanding | README points to deeper setup or architecture context when needed | live |
| Product and market context | `shipflow_data/business/product.md` | `shipflow_data/business/business.md`, `shipflow_data/business/branding.md`, `shipflow_data/business/gtm.md` | Keep claims aligned across product, business, brand, and GTM | Downstream copy should inherit product claim boundaries before expanding | live |
| Active feature decision-making | `shipflow_data/workflow/specs/flutter-web-youtube-auth-redirect-spec.md` | `shipflow_data/workflow/specs/feedback-v1.md`, future feature specs | Implementation and review intent | Specs should reference product context and related routes/workflows | live |
| Product feedback loop | `/feedback` | `/feedback/admin`, `shipflow_data/workflow/specs/feedback-v1.md`, `shipflow_data/business/product.md` | Support and product-learning intent | User-facing feedback entry should stay consistent with admin review workflow and specs | live |
| Release communication | `CHANGELOG.md` | `README.md`, `shipflow_data/business/product.md` when behavior materially changes | Change-awareness intent | User-visible changes belong in changelog; structural changes may also require README updates | live |

## Page Roles

| Page type | Job | Must include | Must not include |
|---|---|---|---|
| README | Describe what the product is and how to run or deploy it | Real setup commands, env requirements, architecture caveats | Claims unsupported by code or deployment config |
| Product artifact | Define durable product truth | Target user, problem, workflows, scope, non-goals, claim boundaries | Business model or brand decisions not yet confirmed |
| Business artifact | Track commercial assumptions and decisions | Audience, value proposition, monetization status, open business questions | Pricing or ICP claims without Diane confirmation |
| Brand artifact | Define voice and messaging boundaries | Voice, tone, values, safe claims, unsafe claims, tagline status | Final tagline or market positioning if still unapproved |
| GTM artifact | Translate product truth into defensible market-facing framing | Segment, offer, channels, proof points, objections, KPI candidates | Unsupported channel strategy or revenue claims |
| Spec | Define a concrete change or feature contract | Problem, solution, scope, acceptance criteria, risks | Vague aspirations without execution implications |
| Changelog entry | Explain a shipped user-visible change | What changed and why it matters | Hidden implementation detail with no user impact |
| In-app feedback surface | Collect precise user issues or product input | Clear prompt, low-friction submission, accurate privacy/auth expectations | Marketing copy that hides limitations |
| Tracker | Record work state | Tasks, findings, follow-ups | Durable product decisions that should live in an artifact |

## Repurposing Rules

- Use `README.md` as the base source for setup, architecture summary, and environment truth.
- Use `shipflow_data/business/product.md` for product framing before writing feature docs, support copy, release copy, or GTM copy.
- Use `shipflow_data/business/business.md` only for commercial assumptions that are clearly marked as confirmed or open.
- Use `shipflow_data/business/branding.md` for tone and safe phrasing, but do not treat tagline candidates as approved until reviewed.
- Use `shipflow_data/business/gtm.md` for positioning language and activation framing, while keeping revenue and channel claims narrow.
- Convert feature work into `CHANGELOG.md` only when a user-visible behavior actually ships.
- Convert problem reports or repeated confusion into either a spec update, README clarification, or feedback-flow improvement.
- Do not treat `shipflow_data/workflow/TASKS.md` or `shipflow_data/workflow/AUDIT_LOG.md` as canonical content sources for product claims.

## Cross-Surface Update Rules

| Trigger | Check these surfaces |
|---|---|
| New user-visible feature | `README.md`, `CHANGELOG.md`, related `specs/*.md`, `shipflow_data/business/product.md` |
| Auth or YouTube-connect change | `README.md`, `CLAUDE.md`, relevant spec, `shipflow_data/business/gtm.md` if activation messaging changes |
| Feedback flow change | `/feedback` and `/feedback/admin` behavior, `shipflow_data/workflow/specs/feedback-v1.md`, `shipflow_data/business/product.md`, `CHANGELOG.md` if user-visible |
| Deployment or env change | `README.md`, `.env.example`, `CLAUDE.md` |
| Repositioning or target-user change | `shipflow_data/business/product.md`, `shipflow_data/business/business.md`, `shipflow_data/business/branding.md`, `shipflow_data/business/gtm.md`, then any user-facing README or changelog framing |
| Monetization or pricing decision | `shipflow_data/business/business.md`, `shipflow_data/business/gtm.md`, `shipflow_data/business/branding.md`, then product or README surfaces only if user-visible |
| Voice, tagline, or language-priority decision | `shipflow_data/business/branding.md`, then user-facing app copy, README, and GTM surfaces if affected |

## Current Gaps

- `shipflow_data/business/business.md` remains draft until Diane confirms monetization, primary segment, and individual-versus-team trajectory.
- `shipflow_data/business/branding.md` remains draft until Diane confirms tone, tagline, and language priority.
- No public landing pages, blog, or docs hub exist in this repo; if those are created later, extend this map before repurposing content into them.
- KPI candidates in `shipflow_data/business/gtm.md` are recommended validation metrics, not confirmed analytics instrumentation.
