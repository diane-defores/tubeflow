# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [2026-04-08]

### Changed
- Moved the worker runtime to a Flox-managed Python 3.12 + FFmpeg 8 environment.
- Updated PM2 startup to load `.env` directly and use the rebuilt local virtualenv.
- Pinned `yt-dlp` to `2026.3.17` and made the worker prefer the local binary.
- Added configurable warning thresholds, optional hard caps, and command timeouts before the worker accepts a heavy transcription job.
- Added configurable worker concurrency and queue wait controls so large jobs can be allowed without running too many in parallel.

### Fixed
- Restored worker health so `yt_dlp`, `ffmpeg`, `ffprobe`, `faster_whisper`, and `funasr` load correctly.
- Rebuilt PyAV against the active Flox FFmpeg toolchain to fix local transcription imports.
- Replaced the earlier blanket oversized-job rejection with a softer warning-first policy plus optional hard caps.
- Enabled yt-dlp JS challenge solver (`--js-runtimes node --remote-components ejs:github`) on both metadata and download calls to fix YouTube anti-bot extraction failures.

### Added
- Structured error classification for yt-dlp failures: bot-gated videos now return HTTP 403 with actionable guidance instead of a generic 500.
- Optional `YTDLP_COOKIES_FILE` env var for authenticating yt-dlp against bot-gated or age-restricted videos.
- Cookie freshness monitoring in `/health`: reports `ytdlpCookies.ageDays` and `stale` status based on `YTDLP_COOKIES_MAX_AGE_DAYS` threshold.
- Initial project setup
