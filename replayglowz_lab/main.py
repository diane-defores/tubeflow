from server import app


if __name__ == "__main__":
    import uvicorn
    import os

    host = os.getenv("TRANSCRIPT_WORKER_HOST", "0.0.0.0")
    port = int(os.getenv("TRANSCRIPT_WORKER_PORT") or os.getenv("PORT", "8090"))
    reload_enabled = os.getenv("TRANSCRIPT_WORKER_RELOAD", "false").lower() == "true"

    uvicorn.run(app, host=host, port=port, reload=reload_enabled)
