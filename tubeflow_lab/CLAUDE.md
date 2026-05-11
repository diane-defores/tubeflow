---
artifact: documentation
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "tubeflow_lab"
created: "2026-04-26"
updated: "2026-04-26"
status: "reviewed"
source_skill: sf-docs
scope: "repository_guidance"
owner: "Diane"
confidence: "medium"
risk_level: "medium"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "TubeFlow"
  - "Convex"
  - "YouTube"
depends_on:
  - "shipflow_data/technical/guidelines.md@0.1.0"
supersedes: []
evidence:
  - "README.md"
  - "server.py"
  - "main.py"
  - "requirements.txt"
  - "Dockerfile"
  - "ecosystem.config.cjs"
  - ".env.example"
next_step: "Review assumptions against the main TubeFlow app and production deployment."
---

# CLAUDE.md

## Repository purpose

`tubeflow_lab` is the TubeFlow transcript worker. It is a standalone FastAPI service that accepts transcript jobs from the main TubeFlow system, downloads and normalizes audio, runs a transcription provider, and returns normalized transcript data.

This repository is not the full TubeFlow product. Treat it as a narrow infrastructure component with a stable HTTP contract.

## Runtime shape

- Entrypoint: `main.py`
- App definition: `server.py`
- Local server: `uvicorn`
- Primary endpoint: `POST /transcribe`
- Health endpoint: `GET /health`
- Python dependencies are pinned in `requirements.txt`
- External binaries expected at runtime: `yt-dlp`, `ffmpeg`, `ffprobe`

## Supported providers

The worker accepts these `provider` values:

- `youtube_captions`
- `faster_whisper`
- `sensevoice`
- `openai_mini`
- `openai`
- `deepgram`

Do not document or expose additional providers unless they are implemented in `server.py`.

## Environment contract

The canonical environment variable surface is `.env.example` plus `server.py`.

Important variables:

- network: `TRANSCRIPT_WORKER_HOST`, `TRANSCRIPT_WORKER_PORT`, `PORT`
- auth: `TRANSCRIPT_WORKER_SECRET`
- binaries: `YTDLP_BIN`, `FFMPEG_BIN`, `FFPROBE_BIN`
- model/runtime tuning: `TRANSCRIPT_FASTER_WHISPER_*`, `TRANSCRIPT_SENSEVOICE_*`
- rate estimates: `TRANSCRIPT_OPENAI_MINI_RATE_PER_MIN`, `TRANSCRIPT_OPENAI_RATE_PER_MIN`, `TRANSCRIPT_DEEPGRAM_RATE_PER_MIN`
- queue/limits: `TRANSCRIPT_WARN_*`, `TRANSCRIPT_HARD_MAX_*`, `TRANSCRIPT_*_TIMEOUT_SECONDS`, `TRANSCRIPT_MAX_CONCURRENT_JOBS`, `TRANSCRIPT_JOB_QUEUE_TIMEOUT_SECONDS`
- optional YouTube auth: `YTDLP_COOKIES_FILE`, `YTDLP_COOKIES_MAX_AGE_DAYS`

## Editing guardrails

- Preserve the request and response contract used by the main TubeFlow app.
- Keep secret names and environment variable names stable unless the caller contract is updated too.
- Do not weaken auth behavior around `TRANSCRIPT_WORKER_SECRET`.
- Do not silently remove preflight checks, queue limits, or warnings for large jobs.
- Keep local, Docker, and PM2 run paths aligned when changing startup behavior.
- Prefer explicit runtime errors over silent fallback when required binaries are missing.

## Documentation rules for this repo

- Mark product-strategy statements as assumptions unless proven by code or linked product docs.
- Keep operational docs anchored to checked-in files.
- Use safe placeholders in `.env.example`; never check in real secrets, cookie files, or private endpoints.
- If a new environment variable is introduced in code, update `.env.example` in the same change.

## Deployment notes

- Docker starts `python server.py` and exposes port `8090`.
- PM2 starts `./.venv/bin/python main.py` and injects Flox `ffmpeg`/`ffprobe` paths.
- `PORT` is respected for generic hosting environments.

## Known confidence limits

- This repository does not prove TubeFlow pricing, ICP, or customer messaging.
- The README describes integration with TubeFlow and Convex, but the main application repo was not inspected here.
- Business and branding artifacts should be treated as working assumptions until confirmed by the product owner.
