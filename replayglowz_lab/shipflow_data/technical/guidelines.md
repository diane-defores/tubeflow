---
artifact: technical_guidelines
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "replayglowz_lab"
created: "2026-04-26"
updated: "2026-04-26"
status: "reviewed"
source_skill: sf-docs
scope: "guidelines"
owner: "Diane"
confidence: "medium"
risk_level: "medium"
docs_impact: "yes"
security_impact: "yes"
evidence:
  - "server.py"
  - "main.py"
  - "requirements.txt"
  - "Dockerfile"
  - "ecosystem.config.cjs"
  - ".env.example"
linked_systems:
  - "main.py"
  - "server.py"
  - ".env.example"
  - "Dockerfile"
  - "ecosystem.config.cjs"
depends_on:
  - "CLAUDE.md@0.1.0"
supersedes: []
next_review: "2026-05-26"
next_step: "Align these repository guidelines with the main ReplayGlowz engineering standards if a shared standard exists."
---

# shipflow_data/technical/guidelines.md

## Engineering principles

- Keep the worker narrow in scope: receive jobs, process audio, return transcript payloads.
- Favor explicit operational controls over hidden automation.
- Preserve compatibility with the caller contract before refactoring internals.
- Treat binary availability, timeouts, and concurrency as first-class runtime concerns.

## API change policy

- Any change to request fields, response fields, auth behavior, or status-code semantics must be coordinated with the calling ReplayGlowz app.
- `GET /health` may grow, but existing keys should not be removed casually because operators may depend on them.

## Environment variable policy

- Add every new runtime variable to `.env.example` in the same change.
- Use safe placeholders only.
- Do not commit real secrets, API keys, cookies files, or absolute machine-specific secrets paths.
- If a variable is optional, document what happens when it is omitted.

## Security guidelines

- Keep bearer-token enforcement intact when `TRANSCRIPT_WORKER_SECRET` is set.
- Treat `YTDLP_COOKIES_FILE` as sensitive operational data.
- Avoid logging secrets, raw authorization headers, or full credential-bearing commands.
- Do not downgrade error handling in ways that leak sensitive environment data.

## Runtime guidelines

- Respect both `TRANSCRIPT_WORKER_PORT` and `PORT` semantics.
- Keep Docker and PM2 startup paths working when changing entrypoints.
- Preserve support for `yt-dlp`, `ffmpeg`, and `ffprobe` overrides through env vars.
- Keep queue saturation behavior explicit; if capacity logic changes, update docs and callers.

## Dependency guidelines

- Keep Python dependencies pinned.
- Prefer small, explicit additions over broad framework expansion.
- If adding a provider SDK or binary dependency, document host requirements and fallback behavior.

## Documentation guidelines

- README can explain operation and setup, but decision records belong in these metadata-backed docs.
- Business or branding claims must remain marked as assumptions until confirmed outside this repo.
- When code and docs diverge, code wins until docs are corrected.
