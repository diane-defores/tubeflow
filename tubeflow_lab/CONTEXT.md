---
artifact: documentation
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "tubeflow_lab"
created: "2026-04-26"
updated: "2026-04-26"
status: "reviewed"
source_skill: sf-docs
scope: "file"
owner: "Diane"
confidence: "high"
risk_level: "medium"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "TubeFlow Convex app"
  - "YouTube"
  - "FastAPI"
  - "yt-dlp"
  - "ffmpeg"
  - "OpenAI Audio Transcriptions API"
  - "Deepgram API"
depends_on:
  - "README.md"
  - "server.py"
  - ".env.example"
  - "requirements.txt"
supersedes: []
evidence:
  - "README.md"
  - "server.py"
  - "main.py"
  - ".env.example"
  - "requirements.txt"
next_step: "sed -n '1,220p' server.py"
---

# CONTEXT

## Project summary

`tubeflow_lab` is a standalone Python/FastAPI transcript worker for TubeFlow. It exists to offload CPU-heavy and binary-dependent transcription work that should not run inside Convex.

## Core responsibilities

- Accept authenticated transcription jobs from the main app
- Inspect YouTube media metadata before download
- Warn on oversized jobs and optionally reject them with hard limits
- Download best audio with `yt-dlp`
- Normalize audio to mono 16 kHz WAV with `ffmpeg`
- Run one of several transcription providers
- Return normalized transcript segments, combined text, warnings, and optional estimated cost

## Runtime shape

- Language: Python
- HTTP framework: FastAPI
- ASGI server: Uvicorn
- Main app object: `server.app`
- Entry launcher: `main.py`
- Direct launcher fallback: `server.py` can run `uvicorn` itself under `__main__`

## Supported providers

- `faster_whisper`
- `sensevoice`
- `openai_mini` mapped to `gpt-4o-mini-transcribe`
- `openai` mapped to `gpt-4o-transcribe`
- `deepgram`

Unsupported in the worker on purpose:

- `youtube_captions`

## HTTP contract

### `GET /health`

Returns:

- service identity
- whether the worker secret is configured
- binary availability for `yt-dlp`, `ffmpeg`, `ffprobe`
- cookies file health
- active threshold and concurrency settings
- active job count
- availability of optional local Python engines

### `POST /transcribe`

Request body fields:

- `provider`
- `youtubeVideoId`
- `language`
- `apiKey`

Response fields:

- `entries`
- `fullText`
- `estimatedCostUsd`
- `warnings`

## Configuration highlights

Key env groups from `.env.example`:

- Network/runtime: `TRANSCRIPT_WORKER_HOST`, `TRANSCRIPT_WORKER_PORT`, `TRANSCRIPT_WORKER_RELOAD`
- Auth: `TRANSCRIPT_WORKER_SECRET`
- Local model tuning: `TRANSCRIPT_FASTER_WHISPER_*`, `TRANSCRIPT_SENSEVOICE_*`
- Pricing metadata: `TRANSCRIPT_OPENAI_MINI_RATE_PER_MIN`, `TRANSCRIPT_OPENAI_RATE_PER_MIN`, `TRANSCRIPT_DEEPGRAM_RATE_PER_MIN`
- Safety/timeouts: warn and hard size/duration limits, metadata/download/normalize timeouts
- Capacity control: `TRANSCRIPT_MAX_CONCURRENT_JOBS`, `TRANSCRIPT_JOB_QUEUE_TIMEOUT_SECONDS`
- Binary paths and bot-gate support: `YTDLP_BIN`, `FFMPEG_BIN`, `FFPROBE_BIN`, `YTDLP_COOKIES_FILE`, `YTDLP_COOKIES_MAX_AGE_DAYS`

## Deployment context

- Local development assumes Flox and a Python virtualenv
- PM2 deployment uses `ecosystem.config.cjs`
- Container deployment uses `Dockerfile`
- Default port is `8090`

## Operational risks

- External APIs can fail or return shape changes
- YouTube anti-bot gating may require a valid cookies file
- Local models can be missing even if the worker boots successfully
- Queue saturation returns `429`
- Hard media limits return `413`
- Invalid or missing bearer auth returns `401` or `403` when the secret is enabled
