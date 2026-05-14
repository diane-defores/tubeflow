---
artifact: documentation
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "replayglowz_lab"
created: "2026-04-26"
updated: "2026-05-10"
status: "reviewed"
source_skill: sf-docs
scope: "file"
owner: "Diane"
confidence: "high"
risk_level: "medium"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "ReplayGlowz Convex app"
  - "YouTube"
  - "OpenAI Audio Transcriptions API"
  - "Deepgram API"
depends_on:
  - "README.md"
  - "server.py"
  - ".env.example"
  - "ecosystem.config.cjs"
  - "Dockerfile"
supersedes: []
evidence:
  - "README.md"
  - "main.py"
  - "server.py"
  - ".env.example"
  - "requirements.in"
  - "requirements.lock"
  - "ecosystem.config.cjs"
  - "Dockerfile"
next_step: "rg -n '^(def |class |@app\\.|async def )' server.py"
---

# AGENT

## Mission

`replayglowz_lab` is a dedicated transcript worker for ReplayGlowz. Its job is to accept a transcription request from the main app, fetch and normalize YouTube audio, run one transcription provider, and return normalized transcript data plus warnings and optional cost estimates.

## Source of truth

- Runtime entrypoints: `main.py`, `server.py`
- Operator-facing setup: `README.md`, `.env.example`
- Direct Python dependency source: `requirements.in`
- Reproducible Python install lock: `requirements.lock`
- Deployment surfaces: `Dockerfile`, `ecosystem.config.cjs`

## Working rules for future agents

- Treat `server.py` as the canonical implementation. The README is descriptive, not authoritative.
- Do not route `youtube_captions` into this worker. The worker explicitly rejects that provider because Convex handles it directly.
- Preserve the request contract returned by `POST /transcribe`: `entries`, `fullText`, `estimatedCostUsd`, `warnings`.
- Preserve the preflight pipeline: metadata fetch, limit evaluation, download, normalization, provider execution.
- Keep concurrency behavior intact unless the caller explicitly wants queueing semantics changed. The worker uses a bounded semaphore and returns `429` when saturated.
- Treat auth and cookies as security-sensitive. `TRANSCRIPT_WORKER_SECRET` protects the worker, and `YTDLP_COOKIES_FILE` can unlock bot-gated videos.
- Change direct Python dependencies in `requirements.in`, regenerate `requirements.lock` with pip-tools hash mode, and keep Docker installs on `pip install --require-hashes -r requirements.lock`.

## Mental model

1. Convex sends a POST request to the worker.
2. The worker validates bearer auth when configured.
3. The worker reserves a concurrency slot.
4. `yt-dlp` fetches metadata and downloads best audio.
5. `ffmpeg` converts audio to mono 16 kHz WAV.
6. One provider produces transcript text and segments.
7. The worker returns normalized JSON for Convex to persist.

## High-value edit zones

- Provider behavior and response shaping: `transcribe_*` functions in `server.py`
- Media safety and operational limits: `evaluate_media_limits`, `evaluate_downloaded_audio_size`, `reserve_job_slot`
- Deployment/runtime config: `.env.example`, `ecosystem.config.cjs`, `Dockerfile`
- Dependency source and lock: `requirements.in`, `requirements.lock`

## Constraints

- The worker depends on external binaries: `yt-dlp`, `ffmpeg`, `ffprobe`
- Local engines are optional imports and are loaded lazily
- OpenAI and Deepgram paths require per-request API keys
- The worker is intentionally narrow: two HTTP endpoints and one job at a time by default

## Safe change checklist

- If you add a provider, update `TranscribeRequest`, `transcribe_with_provider`, docs, and expected env/config.
- If you change output fields, coordinate with the Convex caller first.
- If you change binary paths or env names, update both `.env.example` and deployment docs.
- If you change rate math or warnings, keep returned data machine-readable and backwards compatible where possible.
