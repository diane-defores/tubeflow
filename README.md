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

## Dependency Maintenance

Dependabot is configured at `.github/dependabot.yml` for the site npm lock,
worker Python requirements, Flutter pub packages, GitHub Actions, and the worker
Docker base image. Dependabot PRs require human review; no dependency updates
are auto-merged.

Use the subproject lockfiles and audit commands as the source of truth:

```bash
(cd tubeflow_site && npm ci && npm audit --json && npm run build)
(cd tubeflow_lab && pip-compile --generate-hashes --allow-unsafe --strip-extras --output-file requirements.lock requirements.in)
(cd tubeflow_lab && pip-audit -r requirements.lock -f json)
(cd tubeflow_app && flutter pub outdated --json && flutter analyze)
```

The worker installs from `tubeflow_lab/requirements.lock` with
`--require-hashes`; edit `requirements.in` first, then regenerate the lock.
If `pip-audit -r requirements.lock` cannot create its temporary environment on
the host, install the lock into a disposable target directory and audit that
directory with `pip-audit --path`.
The Flutter web deploy and Android workflow pin Flutter `3.41.7`.

## Working Rule

All Flutter web surfaces now live in this repository. Do not use the archived legacy repositories as active sources of truth.
