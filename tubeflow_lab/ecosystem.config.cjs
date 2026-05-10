module.exports = {
  apps: [{
    name: "tubeflow_lab",
    cwd: __dirname,
    script: "bash",
    args: [
      "-lc",
      "export PORT=8090 && export PATH=\"$PWD/.venv/bin:$PATH\" && export FFMPEG_BIN=\"$PWD/.flox/run/aarch64-linux.tubeflow-lab.dev/bin/ffmpeg\" && export FFPROBE_BIN=\"$PWD/.flox/run/aarch64-linux.tubeflow-lab.dev/bin/ffprobe\" && set -a && [ -f .env ] && source .env && set +a || true && exec ./.venv/bin/python main.py",
    ],
    env: {
      PORT: 8090
    },
    autorestart: true,
    watch: false
  }]
};
