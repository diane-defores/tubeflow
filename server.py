from __future__ import annotations

import contextlib
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import wave
from functools import lru_cache
from pathlib import Path
from typing import Any, Literal

import requests
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel

APP_NAME = "TubeFlow Transcript Worker"

WORKER_SECRET = os.getenv("TRANSCRIPT_WORKER_SECRET")
DEFAULT_YTDLP_BIN = str(Path(sys.executable).with_name("yt-dlp"))
YTDLP_BIN = os.getenv(
    "YTDLP_BIN",
    DEFAULT_YTDLP_BIN if Path(DEFAULT_YTDLP_BIN).exists() else "yt-dlp",
)
FFMPEG_BIN = os.getenv("FFMPEG_BIN", "ffmpeg")
FFPROBE_BIN = os.getenv("FFPROBE_BIN", "ffprobe")

FASTER_WHISPER_MODEL = os.getenv("TRANSCRIPT_FASTER_WHISPER_MODEL", "small")
FASTER_WHISPER_DEVICE = os.getenv("TRANSCRIPT_FASTER_WHISPER_DEVICE", "cpu")
FASTER_WHISPER_COMPUTE_TYPE = os.getenv("TRANSCRIPT_FASTER_WHISPER_COMPUTE_TYPE", "int8")

SENSEVOICE_MODEL = os.getenv("TRANSCRIPT_SENSEVOICE_MODEL", "iic/SenseVoiceSmall")
SENSEVOICE_DEVICE = os.getenv("TRANSCRIPT_SENSEVOICE_DEVICE", "cpu")

OPENAI_MINI_RATE_PER_MIN = float(os.getenv("TRANSCRIPT_OPENAI_MINI_RATE_PER_MIN", "0.003"))
OPENAI_RATE_PER_MIN = float(os.getenv("TRANSCRIPT_OPENAI_RATE_PER_MIN", "0.006"))
DEEPGRAM_RATE_PER_MIN = float(os.getenv("TRANSCRIPT_DEEPGRAM_RATE_PER_MIN", "0.0077"))
WARN_VIDEO_DURATION_SECONDS = int(os.getenv("TRANSCRIPT_WARN_VIDEO_DURATION_SECONDS", "3600"))
WARN_AUDIO_DOWNLOAD_BYTES = int(os.getenv("TRANSCRIPT_WARN_AUDIO_DOWNLOAD_BYTES", "157286400"))
HARD_MAX_VIDEO_DURATION_SECONDS = int(os.getenv("TRANSCRIPT_HARD_MAX_VIDEO_DURATION_SECONDS", "0"))
HARD_MAX_AUDIO_DOWNLOAD_BYTES = int(os.getenv("TRANSCRIPT_HARD_MAX_AUDIO_DOWNLOAD_BYTES", "0"))
METADATA_TIMEOUT_SECONDS = int(os.getenv("TRANSCRIPT_METADATA_TIMEOUT_SECONDS", "45"))
DOWNLOAD_TIMEOUT_SECONDS = int(os.getenv("TRANSCRIPT_DOWNLOAD_TIMEOUT_SECONDS", "600"))
NORMALIZE_TIMEOUT_SECONDS = int(os.getenv("TRANSCRIPT_NORMALIZE_TIMEOUT_SECONDS", "600"))
MAX_CONCURRENT_JOBS = max(1, int(os.getenv("TRANSCRIPT_MAX_CONCURRENT_JOBS", "1")))
JOB_QUEUE_TIMEOUT_SECONDS = max(0, int(os.getenv("TRANSCRIPT_JOB_QUEUE_TIMEOUT_SECONDS", "30")))

JOB_SEMAPHORE = threading.BoundedSemaphore(value=MAX_CONCURRENT_JOBS)
ACTIVE_JOBS_LOCK = threading.Lock()
ACTIVE_JOBS = 0


class TranscribeRequest(BaseModel):
    provider: Literal[
        "youtube_captions",
        "faster_whisper",
        "sensevoice",
        "openai_mini",
        "openai",
        "deepgram",
    ]
    youtubeVideoId: str
    language: str = "en"
    apiKey: str | None = None


def require_authorization(authorization: str | None) -> None:
    if not WORKER_SECRET:
        return
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing transcript worker bearer token.")
    token = authorization.split(" ", 1)[1]
    if token != WORKER_SECRET:
        raise HTTPException(status_code=403, detail="Invalid transcript worker bearer token.")


def ensure_binary(binary_name: str) -> str:
    if shutil.which(binary_name):
        return binary_name
    raise RuntimeError(f"Required binary '{binary_name}' is not installed on the worker.")


def youtube_watch_url(video_id: str) -> str:
    return f"https://www.youtube.com/watch?v={video_id}"


def run_command(
    command: list[str],
    cwd: str | None = None,
    timeout_seconds: int | None = None,
) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            command,
            cwd=cwd,
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout_seconds,
        )
    except subprocess.TimeoutExpired as error:
        command_name = Path(command[0]).name
        raise RuntimeError(
            f"{command_name} timed out after {timeout_seconds} seconds."
        ) from error


def parse_positive_number(value: Any) -> float | None:
    if value is None or value == "":
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        with contextlib.suppress(ValueError):
            parsed = float(value)
            if parsed > 0:
                return parsed
    return None


def format_bytes(byte_count: int) -> str:
    units = ["B", "KiB", "MiB", "GiB", "TiB"]
    size = float(byte_count)
    for unit in units:
        if size < 1024.0 or unit == units[-1]:
            return f"{size:.1f} {unit}"
        size /= 1024.0
    return f"{byte_count} B"


def threshold_enabled(value: int) -> bool:
    return value > 0


def fetch_video_metadata(youtube_video_id: str) -> dict[str, Any]:
    yt_dlp = ensure_binary(YTDLP_BIN)
    command = [
        yt_dlp,
        "--no-playlist",
        "--dump-single-json",
        "--no-download",
        "--format",
        "bestaudio/best",
        youtube_watch_url(youtube_video_id),
    ]
    result = run_command(command, timeout_seconds=METADATA_TIMEOUT_SECONDS)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "yt-dlp failed to fetch video metadata.")

    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError("yt-dlp returned invalid metadata JSON.") from error

    if not isinstance(payload, dict):
        raise RuntimeError("yt-dlp metadata payload was not an object.")
    return payload


def estimated_audio_size_bytes(metadata: dict[str, Any]) -> int | None:
    candidates: list[float | None] = [
        parse_positive_number(metadata.get("filesize")),
        parse_positive_number(metadata.get("filesize_approx")),
    ]

    for key in ("requested_downloads", "requested_formats"):
        for entry in metadata.get(key) or []:
            if isinstance(entry, dict):
                candidates.append(parse_positive_number(entry.get("filesize")))
                candidates.append(parse_positive_number(entry.get("filesize_approx")))

    format_id = metadata.get("format_id")
    if format_id and isinstance(metadata.get("formats"), list):
        for entry in metadata["formats"]:
            if not isinstance(entry, dict) or entry.get("format_id") != format_id:
                continue
            candidates.append(parse_positive_number(entry.get("filesize")))
            candidates.append(parse_positive_number(entry.get("filesize_approx")))
            break

    for candidate in candidates:
        if candidate and candidate > 0:
            return int(candidate)
    return None


def evaluate_media_limits(metadata: dict[str, Any]) -> list[str]:
    warnings: list[str] = []
    duration_seconds = parse_positive_number(metadata.get("duration"))
    if (
        duration_seconds
        and threshold_enabled(HARD_MAX_VIDEO_DURATION_SECONDS)
        and duration_seconds > HARD_MAX_VIDEO_DURATION_SECONDS
    ):
        raise HTTPException(
            status_code=413,
            detail=(
                "Video duration exceeds worker limit "
                f"({int(duration_seconds)}s > {HARD_MAX_VIDEO_DURATION_SECONDS}s)."
            ),
        )
    if (
        duration_seconds
        and threshold_enabled(WARN_VIDEO_DURATION_SECONDS)
        and duration_seconds > WARN_VIDEO_DURATION_SECONDS
    ):
        warnings.append(
            "Video duration exceeds the recommended threshold "
            f"({int(duration_seconds)}s > {WARN_VIDEO_DURATION_SECONDS}s)."
        )

    estimated_size = estimated_audio_size_bytes(metadata)
    if (
        estimated_size
        and threshold_enabled(HARD_MAX_AUDIO_DOWNLOAD_BYTES)
        and estimated_size > HARD_MAX_AUDIO_DOWNLOAD_BYTES
    ):
        raise HTTPException(
            status_code=413,
            detail=(
                "Estimated audio download exceeds worker limit "
                f"({format_bytes(estimated_size)} > {format_bytes(HARD_MAX_AUDIO_DOWNLOAD_BYTES)})."
            ),
        )
    if (
        estimated_size
        and threshold_enabled(WARN_AUDIO_DOWNLOAD_BYTES)
        and estimated_size > WARN_AUDIO_DOWNLOAD_BYTES
    ):
        warnings.append(
            "Estimated audio download exceeds the recommended threshold "
            f"({format_bytes(estimated_size)} > {format_bytes(WARN_AUDIO_DOWNLOAD_BYTES)})."
        )
    return warnings


def evaluate_downloaded_audio_size(downloaded_size: int) -> list[str]:
    warnings: list[str] = []
    if (
        threshold_enabled(HARD_MAX_AUDIO_DOWNLOAD_BYTES)
        and downloaded_size > HARD_MAX_AUDIO_DOWNLOAD_BYTES
    ):
        raise HTTPException(
            status_code=413,
            detail=(
                "Downloaded audio exceeds worker limit "
                f"({format_bytes(downloaded_size)} > {format_bytes(HARD_MAX_AUDIO_DOWNLOAD_BYTES)})."
            ),
        )
    if (
        threshold_enabled(WARN_AUDIO_DOWNLOAD_BYTES)
        and downloaded_size > WARN_AUDIO_DOWNLOAD_BYTES
    ):
        warnings.append(
            "Downloaded audio exceeds the recommended threshold "
            f"({format_bytes(downloaded_size)} > {format_bytes(WARN_AUDIO_DOWNLOAD_BYTES)})."
        )
    return warnings


@contextlib.contextmanager
def reserve_job_slot():
    global ACTIVE_JOBS

    wait_started_at = time.monotonic()
    acquired = JOB_SEMAPHORE.acquire(timeout=JOB_QUEUE_TIMEOUT_SECONDS)
    if not acquired:
        raise HTTPException(
            status_code=429,
            detail=(
                "Worker is busy. "
                f"Max concurrent jobs: {MAX_CONCURRENT_JOBS}. "
                f"Queue wait timeout: {JOB_QUEUE_TIMEOUT_SECONDS}s."
            ),
        )

    with ACTIVE_JOBS_LOCK:
        ACTIVE_JOBS += 1

    try:
        wait_time_seconds = max(0.0, time.monotonic() - wait_started_at)
        yield wait_time_seconds
    finally:
        with ACTIVE_JOBS_LOCK:
            ACTIVE_JOBS -= 1
        JOB_SEMAPHORE.release()


def download_audio(youtube_video_id: str, working_dir: Path) -> tuple[Path, list[str]]:
    metadata = fetch_video_metadata(youtube_video_id)
    warnings = evaluate_media_limits(metadata)

    yt_dlp = ensure_binary(YTDLP_BIN)
    output_template = working_dir / "source.%(ext)s"
    command = [
        yt_dlp,
        "--no-playlist",
        "--js-runtimes",
        "node",
        "--format",
        "bestaudio/best",
        "--output",
        str(output_template),
        youtube_watch_url(youtube_video_id),
    ]
    result = run_command(command, timeout_seconds=DOWNLOAD_TIMEOUT_SECONDS)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "yt-dlp failed to download audio.")

    matches = sorted(working_dir.glob("source.*"))
    if not matches:
        raise RuntimeError("yt-dlp completed without producing an audio file.")

    output_path = matches[0]
    downloaded_size = output_path.stat().st_size
    warnings.extend(evaluate_downloaded_audio_size(downloaded_size))
    return output_path, warnings


def normalize_audio(source_path: Path, working_dir: Path) -> Path:
    ffmpeg = ensure_binary(FFMPEG_BIN)
    target = working_dir / "normalized.wav"
    command = [
        ffmpeg,
        "-y",
        "-i",
        str(source_path),
        "-ac",
        "1",
        "-ar",
        "16000",
        str(target),
    ]
    result = run_command(command, timeout_seconds=NORMALIZE_TIMEOUT_SECONDS)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "ffmpeg failed to normalize audio.")
    return target


def audio_duration_seconds(audio_path: Path) -> float:
    with contextlib.closing(wave.open(str(audio_path), "rb")) as audio_file:
        frame_rate = audio_file.getframerate()
        frame_count = audio_file.getnframes()
        return frame_count / float(frame_rate)


def estimate_cost(duration_seconds: float, rate_per_minute: float) -> float:
    return round((duration_seconds / 60.0) * rate_per_minute, 6)


def available_local_engines() -> dict[str, bool]:
    return {
        "faster_whisper": importlib.util.find_spec("faster_whisper") is not None,
        "funasr": importlib.util.find_spec("funasr") is not None,
    }


@lru_cache(maxsize=1)
def get_faster_whisper_model():
    try:
        from faster_whisper import WhisperModel
    except ImportError as error:
        raise RuntimeError(
            "faster-whisper is not installed. Add it with pip install -r requirements.txt."
        ) from error

    return WhisperModel(
        FASTER_WHISPER_MODEL,
        device=FASTER_WHISPER_DEVICE,
        compute_type=FASTER_WHISPER_COMPUTE_TYPE,
    )


@lru_cache(maxsize=1)
def get_sensevoice_model():
    try:
        from funasr import AutoModel
    except ImportError as error:
        raise RuntimeError(
            "FunASR is not installed. Add it with pip install -r requirements.txt."
        ) from error

    return AutoModel(
        model=SENSEVOICE_MODEL,
        trust_remote_code=True,
        vad_model="fsmn-vad",
        vad_kwargs={"max_single_segment_time": 30000},
        device=SENSEVOICE_DEVICE,
    )


def transcribe_faster_whisper(audio_path: Path, language: str) -> dict[str, Any]:
    model = get_faster_whisper_model()
    segments, info = model.transcribe(
        str(audio_path),
        language=None if language == "auto" else language,
        beam_size=5,
        vad_filter=True,
        condition_on_previous_text=False,
    )

    entries = []
    for segment in list(segments):
        entries.append(
            {
                "start": float(segment.start),
                "duration": float(segment.end - segment.start),
                "text": segment.text.strip(),
            }
        )

    if not entries:
        raise RuntimeError("faster-whisper returned no transcript segments.")

    warnings: list[str] = []
    detected_language = getattr(info, "language", None)
    if detected_language and language != "auto" and detected_language != language:
        warnings.append(
            f"Requested language '{language}' but faster-whisper detected '{detected_language}'."
        )

    return {
        "entries": entries,
        "fullText": " ".join(entry["text"] for entry in entries).strip(),
        "warnings": warnings,
    }


def transcribe_sensevoice(audio_path: Path, language: str) -> dict[str, Any]:
    try:
        from funasr.utils.postprocess_utils import rich_transcription_postprocess
    except ImportError as error:
        raise RuntimeError(
            "FunASR utilities are not installed. Add them with pip install -r requirements.txt."
        ) from error

    model = get_sensevoice_model()
    result = model.generate(
        input=str(audio_path),
        cache={},
        language="auto" if language == "auto" else language,
        use_itn=True,
        batch_size_s=60,
        merge_vad=True,
        merge_length_s=15,
    )

    if not result:
        raise RuntimeError("SenseVoice returned no transcription result.")

    text = rich_transcription_postprocess(result[0]["text"]).strip()
    if not text:
        raise RuntimeError("SenseVoice returned an empty transcript.")

    duration = audio_duration_seconds(audio_path)
    return {
        "entries": [
            {
                "start": 0.0,
                "duration": duration,
                "text": text,
            }
        ],
        "fullText": text,
        "warnings": [
            "SenseVoice timestamps are currently coarse-grained in this worker.",
        ],
    }


def transcribe_openai(audio_path: Path, language: str, api_key: str, model_name: str, rate: float) -> dict[str, Any]:
    with audio_path.open("rb") as audio_file:
        files = {
            "file": (audio_path.name, audio_file, "audio/wav"),
        }
        data: list[tuple[str, str]] = [
            ("model", model_name),
            ("response_format", "verbose_json"),
            ("timestamp_granularities[]", "segment"),
        ]
        if language != "auto":
            data.append(("language", language))

        response = requests.post(
            "https://api.openai.com/v1/audio/transcriptions",
            headers={"Authorization": f"Bearer {api_key}"},
            data=data,
            files=files,
            timeout=600,
        )

    if response.status_code >= 400:
        raise RuntimeError(response.text or "OpenAI transcription failed.")

    payload = response.json()
    segments = payload.get("segments") or []
    entries = [
        {
            "start": float(segment.get("start", 0.0)),
            "duration": float(segment.get("end", 0.0)) - float(segment.get("start", 0.0)),
            "text": (segment.get("text") or "").strip(),
        }
        for segment in segments
        if segment.get("text")
    ]

    if not entries:
        duration = audio_duration_seconds(audio_path)
        text = (payload.get("text") or "").strip()
        if not text:
            raise RuntimeError("OpenAI returned no transcript.")
        entries = [{"start": 0.0, "duration": duration, "text": text}]

    duration = audio_duration_seconds(audio_path)
    return {
        "entries": entries,
        "fullText": (payload.get("text") or " ".join(entry["text"] for entry in entries)).strip(),
        "estimatedCostUsd": estimate_cost(duration, rate),
        "warnings": [],
    }


def transcribe_deepgram(audio_path: Path, language: str, api_key: str) -> dict[str, Any]:
    params = {
        "model": "nova-3",
        "smart_format": "true",
        "utterances": "true",
        "diarize": "true",
    }
    if language != "auto":
        params["language"] = language

    with audio_path.open("rb") as audio_file:
        response = requests.post(
            "https://api.deepgram.com/v1/listen",
            params=params,
            headers={
                "Authorization": f"Token {api_key}",
                "Content-Type": "audio/wav",
            },
            data=audio_file,
            timeout=600,
        )

    if response.status_code >= 400:
        raise RuntimeError(response.text or "Deepgram transcription failed.")

    payload = response.json()
    alternatives = (
        payload.get("results", {})
        .get("channels", [{}])[0]
        .get("alternatives", [{}])[0]
    )
    utterances = alternatives.get("utterances") or []
    entries = [
        {
            "start": float(utterance.get("start", 0.0)),
            "duration": float(utterance.get("end", 0.0)) - float(utterance.get("start", 0.0)),
            "text": (utterance.get("transcript") or "").strip(),
            **({"speaker": str(utterance["speaker"])} if "speaker" in utterance else {}),
        }
        for utterance in utterances
        if utterance.get("transcript")
    ]

    if not entries:
        duration = audio_duration_seconds(audio_path)
        text = (alternatives.get("transcript") or "").strip()
        if not text:
            raise RuntimeError("Deepgram returned no transcript.")
        entries = [{"start": 0.0, "duration": duration, "text": text}]

    duration = audio_duration_seconds(audio_path)
    return {
        "entries": entries,
        "fullText": (alternatives.get("transcript") or " ".join(entry["text"] for entry in entries)).strip(),
        "estimatedCostUsd": estimate_cost(duration, DEEPGRAM_RATE_PER_MIN),
        "warnings": [],
    }


def transcribe_with_provider(provider: str, audio_path: Path, language: str, api_key: str | None) -> dict[str, Any]:
    if provider == "faster_whisper":
        return transcribe_faster_whisper(audio_path, language)
    if provider == "sensevoice":
        return transcribe_sensevoice(audio_path, language)
    if provider == "openai_mini":
        if not api_key:
            raise RuntimeError("OpenAI API key is required for openai_mini.")
        return transcribe_openai(
            audio_path,
            language,
            api_key,
            model_name="gpt-4o-mini-transcribe",
            rate=OPENAI_MINI_RATE_PER_MIN,
        )
    if provider == "openai":
        if not api_key:
            raise RuntimeError("OpenAI API key is required for openai.")
        return transcribe_openai(
            audio_path,
            language,
            api_key,
            model_name="gpt-4o-transcribe",
            rate=OPENAI_RATE_PER_MIN,
        )
    if provider == "deepgram":
        if not api_key:
            raise RuntimeError("Deepgram API key is required for deepgram.")
        return transcribe_deepgram(audio_path, language, api_key)
    raise RuntimeError(f"Unsupported worker provider '{provider}'.")


app = FastAPI(title=APP_NAME)


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "ok": True,
        "service": APP_NAME,
        "workerSecretConfigured": bool(WORKER_SECRET),
        "binaries": {
          "yt_dlp": shutil.which(YTDLP_BIN) is not None,
          "ffmpeg": shutil.which(FFMPEG_BIN) is not None,
          "ffprobe": shutil.which(FFPROBE_BIN) is not None,
        },
        "limits": {
            "warnVideoDurationSeconds": WARN_VIDEO_DURATION_SECONDS,
            "warnAudioDownloadBytes": WARN_AUDIO_DOWNLOAD_BYTES,
            "hardMaxVideoDurationSeconds": HARD_MAX_VIDEO_DURATION_SECONDS,
            "hardMaxAudioDownloadBytes": HARD_MAX_AUDIO_DOWNLOAD_BYTES,
            "maxConcurrentJobs": MAX_CONCURRENT_JOBS,
            "jobQueueTimeoutSeconds": JOB_QUEUE_TIMEOUT_SECONDS,
        },
        "activeJobs": ACTIVE_JOBS,
        "pythonPackages": available_local_engines(),
    }


@app.post("/transcribe")
def transcribe(
    payload: TranscribeRequest,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    require_authorization(authorization)

    if payload.provider == "youtube_captions":
        raise HTTPException(
            status_code=400,
            detail="youtube_captions should be handled directly by Convex, not the worker.",
        )

    try:
        with reserve_job_slot() as queue_wait_seconds:
            with tempfile.TemporaryDirectory(prefix="tubeflow-transcript-") as temp_dir:
                working_dir = Path(temp_dir)
                source_audio, preflight_warnings = download_audio(
                    payload.youtubeVideoId,
                    working_dir,
                )
                normalized_audio = normalize_audio(source_audio, working_dir)
                result = transcribe_with_provider(
                    payload.provider,
                    normalized_audio,
                    payload.language,
                    payload.apiKey,
                )
                warnings = list(preflight_warnings)
                warnings.extend(result.get("warnings", []))
                if queue_wait_seconds > 0.5:
                    warnings.append(
                        f"Job waited {queue_wait_seconds:.1f}s for worker capacity before starting."
                    )
                return {
                    "entries": result["entries"],
                    "fullText": result["fullText"],
                    "estimatedCostUsd": result.get("estimatedCostUsd"),
                    "warnings": warnings,
                }
    except HTTPException:
        raise
    except Exception as error:
        raise HTTPException(status_code=500, detail=str(error)) from error


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        app,
        host=os.getenv("TRANSCRIPT_WORKER_HOST", "0.0.0.0"),
        port=int(os.getenv("TRANSCRIPT_WORKER_PORT") or os.getenv("PORT", "8090")),
        reload=os.getenv("TRANSCRIPT_WORKER_RELOAD", "false").lower() == "true",
    )
