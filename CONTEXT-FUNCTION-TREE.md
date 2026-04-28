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
  - "FastAPI"
  - "yt-dlp"
  - "ffmpeg"
  - "OpenAI Audio Transcriptions API"
  - "Deepgram API"
depends_on:
  - "server.py"
  - "main.py"
supersedes: []
evidence:
  - "server.py"
  - "main.py"
next_step: "sed -n '1,260p' CONTEXT-FUNCTION-TREE.md"
---

# CONTEXT FUNCTION TREE

## Entry points

- `main.py`
  - imports `app` from `server`
  - reads host, port, reload env vars
  - starts `uvicorn.run(app, ...)`
- `server.py`
  - defines `app = FastAPI(title=APP_NAME)`
  - can also start Uvicorn directly under `__main__`

## HTTP surface

- `health()`
  - calls `_cookies_health_info()`
  - calls `available_local_engines()`
  - reads binary availability and runtime limits
- `transcribe(payload, authorization)`
  - calls `require_authorization()`
  - uses `reserve_job_slot()`
  - calls `download_audio()`
  - calls `normalize_audio()`
  - calls `transcribe_with_provider()`
  - merges warnings
  - maps known failures to `HTTPException`

## Request pipeline helpers

- `require_authorization(authorization)`
  - enforces bearer token when `TRANSCRIPT_WORKER_SECRET` is set
- `reserve_job_slot()`
  - acquires `JOB_SEMAPHORE`
  - increments/decrements `ACTIVE_JOBS`
  - emits structured logs
- `download_audio(youtube_video_id, working_dir)`
  - calls `fetch_video_metadata()`
  - calls `evaluate_media_limits()`
  - calls `_ytdlp_base_args()`
  - calls `run_command()` for `yt-dlp`
  - calls `evaluate_downloaded_audio_size()`
- `normalize_audio(source_path, working_dir)`
  - calls `ensure_binary()`
  - calls `run_command()` for `ffmpeg`

## Metadata and size evaluation

- `fetch_video_metadata(youtube_video_id)`
  - builds a `yt-dlp --dump-single-json` command
  - calls `run_command()`
  - calls `_classify_ytdlp_error()` on failure
- `estimated_audio_size_bytes(metadata)`
  - calls `parse_positive_number()` repeatedly across metadata candidates
- `evaluate_media_limits(metadata)`
  - calls `parse_positive_number()`
  - calls `threshold_enabled()`
  - calls `estimated_audio_size_bytes()`
  - calls `format_bytes()` for messages
- `evaluate_downloaded_audio_size(downloaded_size)`
  - calls `threshold_enabled()`
  - calls `format_bytes()` for messages

## Provider dispatch

- `transcribe_with_provider(provider, audio_path, language, api_key)`
  - `faster_whisper` -> `transcribe_faster_whisper()`
  - `sensevoice` -> `transcribe_sensevoice()`
  - `openai_mini` -> `transcribe_openai(..., "gpt-4o-mini-transcribe", OPENAI_MINI_RATE_PER_MIN)`
  - `openai` -> `transcribe_openai(..., "gpt-4o-transcribe", OPENAI_RATE_PER_MIN)`
  - `deepgram` -> `transcribe_deepgram()`

## Provider implementations

- `transcribe_faster_whisper(audio_path, language)`
  - calls `get_faster_whisper_model()`
  - reads model segments
  - returns per-segment entries and warning on language mismatch
- `transcribe_sensevoice(audio_path, language)`
  - imports `rich_transcription_postprocess`
  - calls `get_sensevoice_model()`
  - calls `audio_duration_seconds()`
  - returns a single coarse-grained entry
- `transcribe_openai(audio_path, language, api_key, model_name, rate)`
  - posts multipart audio to OpenAI
  - calls `audio_duration_seconds()` for fallback duration and cost
  - calls `estimate_cost()`
- `transcribe_deepgram(audio_path, language, api_key)`
  - posts WAV audio to Deepgram
  - calls `audio_duration_seconds()` for fallback duration and cost
  - calls `estimate_cost()`

## Model/binary utilities

- `get_faster_whisper_model()`
  - lazy imports `WhisperModel`
  - cached with `@lru_cache(maxsize=1)`
- `get_sensevoice_model()`
  - lazy imports `AutoModel`
  - cached with `@lru_cache(maxsize=1)`
- `available_local_engines()`
  - checks import availability for `faster_whisper` and `funasr`
- `ensure_binary(binary_name)`
  - validates the binary is present in `PATH`
- `_ytdlp_base_args()`
  - assembles shared `yt-dlp` arguments
  - conditionally injects cookies

## Cross-cutting helpers

- `_JsonFormatter.format(record)` builds structured JSON logs
- `_log(level, msg, **data)` emits logger records with attached metadata
- `run_command(command, cwd, timeout_seconds)` wraps `subprocess.run` and normalizes timeout failures
- `_classify_ytdlp_error(stderr, fallback_message, video_id)` maps common `yt-dlp` failures to clearer exceptions
- `_cookies_health_info()` reports whether the cookies file is present and stale
- `youtube_watch_url(video_id)` builds the YouTube watch URL
- `audio_duration_seconds(audio_path)` reads WAV duration with `wave`
- `estimate_cost(duration_seconds, rate_per_minute)` computes estimated provider cost
- `parse_positive_number(value)` normalizes numeric metadata values
- `format_bytes(byte_count)` produces human-readable byte values
- `threshold_enabled(value)` treats positive integers as enabled thresholds
