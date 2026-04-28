---
artifact: architecture_context
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "tubeflow_lab"
created: "2026-04-26"
updated: "2026-04-26"
status: "reviewed"
source_skill: "sf-docs"
scope: "architecture"
owner: "Diane"
confidence: "high"
risk_level: "medium"
docs_impact: "yes"
security_impact: "yes"
evidence:
  - "README.md"
  - "main.py"
  - "server.py"
  - ".env.example"
  - "requirements.txt"
  - "ecosystem.config.cjs"
  - "Dockerfile"
linked_systems:
  - "main.py"
  - "server.py"
  - "TubeFlow Convex app"
  - "yt-dlp"
  - "ffmpeg"
external_dependencies:
  - "YouTube"
  - "OpenAI Audio Transcriptions API"
  - "Deepgram API"
  - "faster_whisper"
  - "FunASR / SenseVoice"
invariants:
  - "The worker stays a narrow transcript service, not the main TubeFlow app."
  - "The POST /transcribe response contract remains stable for the Convex caller."
  - "Media download and normalization continue to happen before provider transcription."
depends_on:
  - "README.md"
  - ".env.example"
supersedes: []
next_review: "2026-05-26"
next_step: "sed -n '1,260p' ARCHITECTURE.md"
---

# ARCHITECTURE

## System role

This repository contains a narrow worker service that sits beside the main TubeFlow application. Convex remains the orchestrator and system of record, while this worker performs external-binary and compute-heavy transcript generation.

## Primary components

### 1. API layer

- Implemented with FastAPI in `server.py`
- Exposes `GET /health` and `POST /transcribe`
- Handles auth, queue admission, error mapping, and response normalization

### 2. Job control layer

- `reserve_job_slot()` limits concurrent work with a bounded semaphore
- `ACTIVE_JOBS` and `ACTIVE_JOBS_LOCK` expose lightweight runtime state
- Queue saturation is surfaced as HTTP `429`

### 3. Media acquisition layer

- `yt-dlp` is invoked via subprocess
- A metadata preflight runs before download
- The worker estimates audio size from metadata, emits warnings, and can enforce hard rejections
- Optional Netscape-format cookies allow bot-gated or age-restricted video access

### 4. Audio normalization layer

- `ffmpeg` converts downloaded audio into mono 16 kHz WAV
- Downstream providers therefore receive a stable input format

### 5. Transcription provider layer

- Local models:
  - `faster_whisper`
  - `sensevoice` via FunASR
- Remote APIs:
  - OpenAI `gpt-4o-mini-transcribe`
  - OpenAI `gpt-4o-transcribe`
  - Deepgram `nova-3`

### 6. Observability layer

- Logging is structured JSON via `_JsonFormatter`
- Health reporting exposes binary presence, cookies health, limits, concurrency, and local package availability

## Request flow

1. Caller sends `POST /transcribe` with provider, video ID, language, and optional API key.
2. Worker validates bearer auth if `TRANSCRIPT_WORKER_SECRET` is configured.
3. Worker rejects `youtube_captions` because that path belongs in Convex.
4. Worker waits for a concurrency slot.
5. Worker fetches YouTube metadata with `yt-dlp --dump-single-json`.
6. Worker evaluates duration and estimated audio-size thresholds.
7. Worker downloads best audio with `yt-dlp`.
8. Worker re-checks actual downloaded size.
9. Worker normalizes audio with `ffmpeg`.
10. Worker dispatches to the chosen transcription provider.
11. Worker merges warnings, computes estimated cost where supported, and returns normalized transcript output.

## Data contracts

### Input contract

`TranscribeRequest` contains:

- `provider`
- `youtubeVideoId`
- `language`
- `apiKey`

### Output contract

The worker response returns:

- `entries`: normalized transcript entries with `start`, `duration`, `text`, and optional `speaker`
- `fullText`: concatenated transcript string
- `estimatedCostUsd`: present for priced remote providers
- `warnings`: operational or quality warnings

## Deployment surfaces

### Local/Flox

- Flox provides Python and system packages
- A local virtualenv installs Python dependencies
- `main.py` is the preferred app launcher

### PM2

- `ecosystem.config.cjs` starts `main.py` through `bash -lc`
- It injects `PORT`, prepends the local virtualenv to `PATH`, and pins `FFMPEG_BIN` and `FFPROBE_BIN` to Flox-provided binaries

### Docker

- `Dockerfile` builds from `python:3.11-slim`
- Installs `ffmpeg`
- Installs Python requirements
- Copies `server.py`
- Exposes port `8090`
- Starts with `python server.py`

## Dependency model

### Python packages

- `fastapi`
- `uvicorn[standard]`
- `requests`
- `yt-dlp`
- `faster-whisper`
- `openai`
- `funasr`

### External binaries

- `yt-dlp`
- `ffmpeg`
- `ffprobe`
- Node.js is also assumed for the `yt-dlp --js-runtimes node` path described in the README

## Security model

- Bearer token auth is optional but supported through `TRANSCRIPT_WORKER_SECRET`
- API keys for OpenAI and Deepgram are passed per request, not loaded globally in code
- Cookies file support is powerful and sensitive because it can grant access to restricted YouTube media
- The worker intentionally performs no persistence; transcript storage remains in Convex

## Failure model

- `401` for missing bearer token when auth is enabled
- `403` for invalid bearer token or bot-gated video conditions mapped from `yt-dlp`
- `413` for hard duration or size limits
- `429` for queue saturation
- `500` for remaining runtime and provider failures

## Architectural boundaries

- This repo is not the full TubeFlow app
- It does not own transcript persistence, user management, or UI state
- It should remain a focused worker rather than absorb Convex orchestration logic
