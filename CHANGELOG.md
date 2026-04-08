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
- Documented the remaining YouTube extraction limitation separately from worker bootstrap health.
- Replaced the earlier blanket oversized-job rejection with a softer warning-first policy plus optional hard caps.

### Added
- Initial project setup
