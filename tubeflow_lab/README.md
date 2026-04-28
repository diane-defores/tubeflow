# Transcript Worker

This worker is the piece that does the heavy transcript work outside of Convex.

## What it does

When TubeFlow asks for a transcript from a provider that needs audio processing, the worker:

1. receives a `/transcribe` request from Convex
2. downloads the audio for the YouTube video with `yt-dlp`
3. normalizes the audio with `ffmpeg`
4. runs one provider:
   - `faster_whisper`
   - `sensevoice`
   - `openai_mini`
   - `openai`
   - `deepgram`
5. returns normalized transcript segments back to Convex

Before the download starts, the worker now runs a metadata preflight with
`yt-dlp --dump-single-json`, adds warnings for oversized jobs, and only rejects
them when an optional hard limit is configured.

Convex then stores the version, marks the job as completed, and the app UI updates in realtime.

## Why a worker exists

Convex is excellent for orchestration, database state, and realtime UI updates.
It is not the right place to:

- run `yt-dlp`
- run `ffmpeg`
- hold large speech models in memory
- spend long CPU/GPU time on transcription

So the worker is a separate service that does the heavy work, while Convex stays the coordinator.

## Architecture

Flow:

1. User clicks transcript / regenerate in the app.
2. Convex decides which provider to use.
3. If the provider is `youtube_captions`, Convex handles it directly.
4. If the provider needs audio, Convex sends a POST request to this worker.
5. The worker returns:
   - `entries`
   - `fullText`
   - `estimatedCostUsd`
   - `warnings`
6. Convex stores the transcript version and updates the active transcript.

This means the worker is the "transcription engine", and Convex is the "traffic controller".

## Endpoints

### `GET /health`

Returns whether the worker is up and whether the required binaries/packages are available.
It also exposes the active warning thresholds, hard limits, and concurrency settings.

### `POST /transcribe`

Expected JSON body:

```json
{
  "provider": "faster_whisper",
  "youtubeVideoId": "dQw4w9WgXcQ",
  "language": "en",
  "apiKey": null
}
```

If `TRANSCRIPT_WORKER_SECRET` is configured, send:

```txt
Authorization: Bearer <secret>
```

## Local development

Requirements:

- Flox
- Node.js available on the host for `yt-dlp --js-runtimes node`

Install dependencies with Flox:

```bash
cd /home/claude/tubeflow_lab
flox activate -- bash -lc '
  python -m venv .venv
  ./.venv/bin/python -m pip install -U pip
  ./.venv/bin/python -m pip install -r requirements.txt
'
```

Run:

```bash
cd /home/claude/tubeflow_lab
cp .env.example .env
set -a
source .env
set +a
flox activate -- ./.venv/bin/python server.py
```

The worker listens on `http://localhost:8090` by default.

If you run it under PM2 / ShipFlow, the worker also accepts the generic `PORT`
environment variable and can be started with:

```bash
cd /home/claude/tubeflow_lab
flox activate -- ./.venv/bin/python main.py
```

Quick verification:

```bash
curl http://localhost:8090/health
```

You should see:

- `"ok": true`
- `binaries.yt_dlp: true`
- `binaries.ffmpeg: true`
- `binaries.ffprobe: true`
- `limits.warnVideoDurationSeconds`
- `limits.warnAudioDownloadBytes`
- `limits.maxConcurrentJobs`

## Runtime policy

The worker is designed to stay configurable rather than blindly reject every
large video. The default setup warns on big jobs, limits how many jobs run at
the same time, and only hard-rejects media when you explicitly set a hard cap.

Default thresholds:

- `TRANSCRIPT_WARN_VIDEO_DURATION_SECONDS=3600`
- `TRANSCRIPT_WARN_AUDIO_DOWNLOAD_BYTES=157286400` (`150 MiB`)
- `TRANSCRIPT_HARD_MAX_VIDEO_DURATION_SECONDS=0` (`0` disables the hard cap)
- `TRANSCRIPT_HARD_MAX_AUDIO_DOWNLOAD_BYTES=0` (`0` disables the hard cap)
- `TRANSCRIPT_METADATA_TIMEOUT_SECONDS=45`
- `TRANSCRIPT_DOWNLOAD_TIMEOUT_SECONDS=600`
- `TRANSCRIPT_NORMALIZE_TIMEOUT_SECONDS=600`
- `TRANSCRIPT_MAX_CONCURRENT_JOBS=1`
- `TRANSCRIPT_JOB_QUEUE_TIMEOUT_SECONDS=30`

Behavior:

- metadata is fetched first so the worker can warn early on long or large jobs
- if you set a hard duration or size cap, the worker returns `413` only when
  that hard cap is exceeded
- after download, the worker checks the actual file size again and can add a
  warning or reject if a hard cap is configured
- only `TRANSCRIPT_MAX_CONCURRENT_JOBS` jobs run at once
- additional jobs wait up to `TRANSCRIPT_JOB_QUEUE_TIMEOUT_SECONDS` and then
  receive `429` if the worker is still saturated

Recommended tuning:

- if you want to allow 10h videos, keep the hard caps at `0`, increase the
  warning thresholds, and keep concurrency low
- if the server is small, keep `TRANSCRIPT_MAX_CONCURRENT_JOBS=1`
- if the server has headroom, raise concurrency carefully and watch memory and CPU

## Docker

Build:

```bash
cd /home/claude/tubeflow_lab
docker build -t tubeflow-transcript-worker .
```

Run:

```bash
docker run --rm -p 8090:8090 \
  -e TRANSCRIPT_WORKER_SECRET=change-me \
  -e TRANSCRIPT_FASTER_WHISPER_MODEL=small \
  tubeflow-transcript-worker
```

If you deploy to a cloud container platform, keep the same contract:

- expose port `8090` or map your platform port to `TRANSCRIPT_WORKER_PORT`
- persist the environment variables from `.env.example`
- keep the worker reachable from Convex over HTTPS
- set a strong `TRANSCRIPT_WORKER_SECRET`

## Deploy on the current server with PM2

Recommended architecture on the current server:

- keep the main TubeFlow app as its own PM2 environment
- run the transcript worker as a second PM2 environment from `tubeflow_lab`
- publish it through your existing reverse proxy on its own path or subdomain

### Server prerequisites

The supported server setup is Flox-managed:

- `python312Full`
- `ffmpeg_8`
- `zlib`
- `gcc`
- `pkg-config`

`yt-dlp` is installed from `requirements.txt`, and the worker enables
`--js-runtimes node` for YouTube extraction.

### Start the worker with PM2

Create the virtualenv once from the Flox Python runtime:

```bash
cd /home/claude/tubeflow_lab
flox activate -- bash -lc '
  python -m venv .venv
  ./.venv/bin/python -m pip install -U pip
  ./.venv/bin/python -m pip install -r requirements.txt
'
```

Then start it with the provided PM2 config:

```bash
cd /home/claude/tubeflow_lab
pm2 start ecosystem.config.cjs
pm2 save
```

Because PM2 exports `PORT`, the worker will bind to the configured port automatically.
The checked-in PM2 config also points `FFMPEG_BIN` and `FFPROBE_BIN` at the
Flox-provided binaries.

### Environment variables for the worker process

At minimum, set:

- `TRANSCRIPT_WORKER_SECRET`
- optionally `TRANSCRIPT_FASTER_WHISPER_MODEL=small`
- optionally `TRANSCRIPT_WORKER_HOST=0.0.0.0`
- optionally:
  - `TRANSCRIPT_WARN_VIDEO_DURATION_SECONDS`
  - `TRANSCRIPT_WARN_AUDIO_DOWNLOAD_BYTES`
  - `TRANSCRIPT_HARD_MAX_VIDEO_DURATION_SECONDS`
  - `TRANSCRIPT_HARD_MAX_AUDIO_DOWNLOAD_BYTES`
  - `TRANSCRIPT_METADATA_TIMEOUT_SECONDS`
  - `TRANSCRIPT_DOWNLOAD_TIMEOUT_SECONDS`
  - `TRANSCRIPT_NORMALIZE_TIMEOUT_SECONDS`
  - `TRANSCRIPT_MAX_CONCURRENT_JOBS`
  - `TRANSCRIPT_JOB_QUEUE_TIMEOUT_SECONDS`

The provided PM2 config no longer requires Doppler. It loads `.env` directly if
present and otherwise starts with defaults.

### Publish through the existing Caddy / ShipFlow setup

Two workable options:

- path-based:
  `https://your-domain/transcript_worker`
- subdomain-based:
  `https://transcript.your-domain`

Path-based is the easiest if you want to reuse ShipFlow's current route model.

If you use the path-based route, set in Convex:

```txt
TRANSCRIPT_WORKER_URL=https://your-domain/transcript_worker
```

Convex will call:

- `https://your-domain/transcript_worker/health`
- `https://your-domain/transcript_worker/transcribe`

### Convex variables to set after the worker is reachable

- `TRANSCRIPT_WORKER_URL`
- `TRANSCRIPT_WORKER_SECRET`
- `TRANSCRIPT_SECRET_ENCRYPTION_KEY`

Use the exact same `TRANSCRIPT_WORKER_SECRET` value in both Convex and the
worker process.

## Connect it to Convex

Set these Convex environment variables:

- `TRANSCRIPT_WORKER_URL`
  Example: `http://localhost:8090`
- `TRANSCRIPT_WORKER_SECRET`
  Same bearer token as the worker
- `TRANSCRIPT_SECRET_ENCRYPTION_KEY`
  Used by Convex to encrypt user OpenAI / Deepgram keys

Recommended value rules:

- `TRANSCRIPT_WORKER_URL`
  Use the public base URL only, with no trailing slash. Example: `https://transcript-worker.example.com`
- `TRANSCRIPT_WORKER_SECRET`
  Must exactly match the worker's bearer token
- `TRANSCRIPT_SECRET_ENCRYPTION_KEY`
  Use a long random secret and keep it stable across deployments, or saved user provider keys will become undecryptable

## Troubleshooting

If the worker returns `413`, the job exceeded a configured hard duration or
hard audio-size cap.

If the worker returns `429`, all worker slots are busy and the request waited
longer than `TRANSCRIPT_JOB_QUEUE_TIMEOUT_SECONDS`.

If `yt-dlp` starts failing with messages such as `Sign in to confirm you're not a bot`,
the worker runtime is healthy but the target video is blocked by YouTube's
extraction checks. In that case you need a separate mitigation strategy such as
cookies, a different extraction path, or a fallback provider.

## End-to-end setup flow

Use this order so the system comes up cleanly:

1. Deploy Convex and the app normally.
2. Deploy the transcript worker as a separate service.
3. Verify the worker directly with `GET /health`.
4. Add `TRANSCRIPT_WORKER_URL`, `TRANSCRIPT_WORKER_SECRET`, and `TRANSCRIPT_SECRET_ENCRYPTION_KEY` to Convex.
5. Redeploy Convex if needed so the new env vars are picked up.
6. Open the TubeFlow app and confirm local worker-backed providers are shown as available.
7. Save an OpenAI or Deepgram key in the UI if you want to use premium providers.
8. Run one transcript generation from the app and confirm a transcript version is created.

## Deployment verification checklist

### 1. Healthcheck the worker

Without auth:

```bash
curl https://your-worker-host/health
```

Expected result:

- `ok` is `true`
- required binaries are present
- local Python packages report as installed when you intend to use them

### 2. Verify worker auth

If `TRANSCRIPT_WORKER_SECRET` is set, this request should fail:

```bash
curl -X POST https://your-worker-host/transcribe \
  -H 'Content-Type: application/json' \
  -d '{"provider":"faster_whisper","youtubeVideoId":"dQw4w9WgXcQ","language":"en"}'
```

The same request with the correct bearer token should reach the transcription logic:

```bash
curl -X POST https://your-worker-host/transcribe \
  -H 'Authorization: Bearer change-me' \
  -H 'Content-Type: application/json' \
  -d '{"provider":"faster_whisper","youtubeVideoId":"dQw4w9WgXcQ","language":"en"}'
```

That request may still fail for video/provider reasons, but it should no longer fail with `401` or `403`.

### 3. Verify Convex sees the worker

Once `TRANSCRIPT_WORKER_URL` is set in Convex:

- `faster_whisper` and `sensevoice` should become available in the provider catalog
- `openai_mini`, `openai`, and `deepgram` additionally require a user API key saved in TubeFlow

If the worker URL is missing, worker-backed providers remain unavailable by design.

### 4. Verify user-key flows

Premium providers require user secrets saved through the app:

- `openai_mini` and `openai` use the user's stored OpenAI key
- `deepgram` uses the user's stored Deepgram key

Those keys are encrypted in Convex using `TRANSCRIPT_SECRET_ENCRYPTION_KEY`.

### 5. Verify one real transcript job

From the app:

1. Open a video.
2. Trigger transcript generation.
3. Confirm TubeFlow first attempts `youtube_captions` when enabled.
4. Confirm fallback reaches the selected worker-backed provider when captions are unavailable.
5. Confirm a transcript version is stored and can be activated from the UI.

## Common failure cases

- `Local transcript worker is not configured.`
  `TRANSCRIPT_WORKER_URL` is missing in Convex.
- `Missing transcript worker bearer token.` / `Invalid transcript worker bearer token.`
  The worker secret does not match between Convex and the worker service.
- `Missing TRANSCRIPT_SECRET_ENCRYPTION_KEY environment variable.`
  Convex cannot encrypt or decrypt saved provider API keys.
- `Required binary 'ffmpeg' is not installed on the worker.`
  The worker image/runtime is missing required system dependencies.
- `ERROR: [youtube] ... Sign in to confirm you’re not a bot.`
  This is a YouTube/`yt-dlp` extraction block, not a worker bootstrap issue.
  Retry with another video or provide cookies if you need bot-gated videos.
- `Missing openai API key for transcript provider openai.` or similar
  The user has not saved the provider key in TubeFlow yet.

## Provider notes

- `faster_whisper`
  - default local provider
  - best v1 tradeoff for cost and quality
- `sensevoice`
  - alternative local provider
  - current worker returns coarse timestamps
- `openai_mini` / `openai`
  - require a user API key saved in TubeFlow
- `deepgram`
  - requires a user API key saved in TubeFlow

## Important product note

For non-technical users, this worker should generally run in the cloud and be operated by TubeFlow.
That way:

- users do not install models
- users do not install `ffmpeg`
- users do not configure Python
- the app "just works"

Running the worker on a user's own machine is possible, but that is better treated as an advanced/self-hosted mode.

## Current runtime note

As of 2026-04-06, the validated server setup is:

- Flox environment with Python 3.12 and FFmpeg 8
- local `.venv` built from the Flox interpreter
- PM2 launching `main.py` through that `.venv`

The worker healthcheck is green in this configuration. End-to-end transcript
success still depends on whether `yt-dlp` can fetch the target YouTube video.
