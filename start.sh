#!/usr/bin/env bash
set -euo pipefail

# --- Run runtime initialization (downloads, config) ---
/opt/minecraft/init.sh

# --- Launch mcsleepingserverstarter as PID 1 ---
# Notes:
# - We let mcsss listen on Java TCP and Bedrock UDP.
# - On incoming connection, mcsss will execute the marctv entrypoint
#   which starts PaperMC inside the same container.
# - If mcEmptyServerStopper stops the server after idle, mcsss keeps listening.

JAVA_PORT="${JAVA_PORT:-25565}"
BEDROCK_PORT="${BEDROCK_PORT:-19132}"

MC_SSS_BIN="/opt/mcsss/mcsleepingserverstarter"
if [[ ! -x "${MC_SSS_BIN}" ]]; then
  echo "[ERROR] mcsleepingserverstarter binary not found or not executable at ${MC_SSS_BIN}" >&2
  exit 1
fi

# Build a minimal config file for mcsss
cat >/opt/mcsss/config.json <<EOF
{
  "server": {
    "startCommand": "/opt/minecraft/docker-entrypoint.sh",
    "workingDirectory": "/",
    "env": {}
  },
  "listeners": [
    { "type": "java", "listen": "0.0.0.0:${JAVA_PORT}" },
    { "type": "bedrock", "listen": "0.0.0.0:${BEDROCK_PORT}/udp" }
  ],
  "log": { "level": "info" }
}
EOF

exec "${MC_SSS_BIN}" -config /opt/mcsss/config.json
