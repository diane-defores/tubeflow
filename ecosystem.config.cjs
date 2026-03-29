module.exports = {
  apps: [
    {
      name: "transcript_worker",
      cwd: __dirname,
      script: "bash",
      args: ["-c", "export PORT=8090 && doppler run -- env PORT=8090 ./.venv/bin/python main.py"],
      env: {
        PORT: 8090,
      },
      autorestart: true,
      watch: false,
    },
  ],
};
