# TubeFlow Flutter

Canonical monorepo for the TubeFlow Flutter surfaces.

## Repository Layout

- `tubeflow_app` - Flutter application
- `tubeflow_site` - website
- `tubeflow_lab` - backend and tooling

## Deployment Model

- GitHub source of truth: `dianedef/tubeflow_flutter`
- Vercel project `Tubeflow-App` uses `tubeflow_app` as its Root Directory
- Vercel project `Tubeflow-Site` uses `tubeflow_site` as its Root Directory
- `tubeflow_lab` is maintained in this monorepo and deployed separately from Vercel

## Related Repository

- `dianedef/tubeflow_expo` remains a separate active repository for the Expo surface

## Working Rule

All Flutter web surfaces now live in this repository. Do not use the archived legacy repositories as active sources of truth.
