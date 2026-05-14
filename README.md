# ReplayGlowz Flutter

Canonical monorepo for the ReplayGlowz Flutter surfaces.

## Repository Layout

- `replayglowz_app` - Flutter application
- `replayglowz_site` - website
- `replayglowz_lab` - backend and tooling

## Deployment Model

- GitHub source of truth: `diane-defores/replayglowz`
- Vercel project `ReplayGlowz-App` uses `replayglowz_app` as its Root Directory
- Vercel project `ReplayGlowz-Site` uses `replayglowz_site` as its Root Directory
- `replayglowz_lab` is maintained in this monorepo and deployed separately from Vercel

## Related Repository

- `dianedef/tubeflow_expo` remains a separate active repository for the Expo surface

## Dependency Maintenance

Dependabot is configured at `.github/dependabot.yml` for the site npm lock,
worker Python requirements, Flutter pub packages, GitHub Actions, and the worker
Docker base image. Dependabot PRs require human review; no dependency updates
are auto-merged.

Use the subproject lockfiles and audit commands as the source of truth:

```bash
(cd replayglowz_site && npm ci && npm audit --json && npm run build)
(cd replayglowz_lab && pip-compile --generate-hashes --allow-unsafe --strip-extras --output-file requirements.lock requirements.in)
(cd replayglowz_lab && pip-audit -r requirements.lock -f json)
(cd replayglowz_app && flutter pub outdated --json && flutter analyze)
```

The worker installs from `replayglowz_lab/requirements.lock` with
`--require-hashes`; edit `requirements.in` first, then regenerate the lock.
If `pip-audit -r requirements.lock` cannot create its temporary environment on
the host, install the lock into a disposable target directory and audit that
directory with `pip-audit --path`.
The Flutter web deploy and Android workflow pin Flutter `3.41.7`.

## Working Rule

All Flutter web surfaces now live in this repository. Do not use the archived legacy repositories as active sources of truth.
