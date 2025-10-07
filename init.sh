#!/usr/bin/env bash
set -euo pipefail

# ------------------------------
# Runtime installer & configurator
# This script runs on *container start* (not build) so that
# volumes mounted on /data won't wipe installed plugins/configs.
# ------------------------------

# ---- Vars & paths ----
MC_DATA_DIR="${MC_DATA_DIR:-/data}"
PLUGINS_DIR="${MC_DATA_DIR}/plugins"
GEYSER_DIR="${PLUGINS_DIR}/Geyser-Spigot"
GEYSER_CONFIG="${GEYSER_DIR}/config.yml"

JAVA_PORT="${JAVA_PORT:-25565}"
BEDROCK_PORT="${BEDROCK_PORT:-19132}"

MC_ESS_IDLE_SECONDS="${MC_ESS_IDLE_SECONDS:-900}"

GEYSER_DOWNLOAD_URL="${GEYSER_DOWNLOAD_URL:-}"
MC_SSS_DOWNLOAD_URL="${MC_SSS_DOWNLOAD_URL:-}"
MC_ESS_DOWNLOAD_URL="${MC_ESS_DOWNLOAD_URL:-}"

mkdir -p "${PLUGINS_DIR}" "${GEYSER_DIR}" /opt/mcsss

echo "[init] Using data dir: ${MC_DATA_DIR}"
echo "[init] Java port: ${JAVA_PORT} | Bedrock port (UDP): ${BEDROCK_PORT}"
echo "[init] Idle stop after: ${MC_ESS_IDLE_SECONDS}s"

# ---- Helper: safe curl download ----
download() {
  local url="$1"
  local out="$2"
  if [[ -z "${url}" ]]; then
    echo "[init] Skipping download for ${out} (URL empty)."
    return 1
  fi
  echo "[init] Downloading ${out} from ${url}"
  curl -fsSL "${url}" -o "${out}"
}

# 1) Install/Update mcsleepingserverstarter (binary)
if [[ ! -x /opt/mcsss/mcsleepingserverstarter ]]; then
  download "${MC_SSS_DOWNLOAD_URL}" "/opt/mcsss/mcsleepingserverstarter" || true
  if [[ -f /opt/mcsss/mcsleepingserverstarter ]]; then
    chmod +x /opt/mcsss/mcsleepingserverstarter
    echo "[init] Installed mcsleepingserverstarter -> /opt/mcsss/mcsleepingserverstarter"
  else
    echo "[init][WARN] mcsleepingserverstarter not installed (missing URL or download failed)."
  fi
else
  echo "[init] mcsleepingserverstarter already present."
fi

# 2) Install/Update Geyser plugin
if [[ ! -f "${PLUGINS_DIR}/Geyser-Spigot.jar" ]]; then
  download "${GEYSER_DOWNLOAD_URL}" "${PLUGINS_DIR}/Geyser-Spigot.jar" || true
  if [[ -f "${PLUGINS_DIR}/Geyser-Spigot.jar" ]]; then
    echo "[init] Installed Geyser plugin."
  else
    echo "[init][WARN] Geyser plugin not installed (missing URL or download failed)."
  fi
else
  echo "[init] Geyser plugin already present."
fi

# 3) Install/Update mcEmptyServerStopper plugin
if [[ ! -f "${PLUGINS_DIR}/mcEmptyServerStopper.jar" ]]; then
  download "${MC_ESS_DOWNLOAD_URL}" "${PLUGINS_DIR}/mcEmptyServerStopper.jar" || true
  if [[ -f "${PLUGINS_DIR}/mcEmptyServerStopper.jar" ]]; then
    echo "[init] Installed mcEmptyServerStopper plugin."
  else
    echo "[init][WARN] mcEmptyServerStopper not installed (missing URL or download failed)."
  fi
else
  echo "[init] mcEmptyServerStopper plugin already present."
fi

# 4) Configure mcEmptyServerStopper (idle shutdown after X seconds)
#    Many plugins generate their config on first run; we seed a minimal config if absent.
MC_ESS_DIR="${MC_DATA_DIR}/plugins/EmptyServerStopper"
MC_ESS_CONFIG="${MC_ESS_DIR}/config.yml"

mkdir -p "${MC_ESS_DIR}"
if [[ ! -f "${MC_ESS_CONFIG}" ]]; then
  cat >"${MC_ESS_CONFIG}" <<EOF
empty-timeout-seconds: ${MC_ESS_IDLE_SECONDS}
broadcast-warning: true
warn-interval-seconds: 60
EOF
  echo "[init] Wrote mcEmptyServerStopper config (${MC_ESS_IDLE_SECONDS}s idle)."
else
  echo "[init] mcEmptyServerStopper config already present."
fi

# 5) Configure Geyser minimal config so Bedrock clients can join when server is running.
#    If Geyser already created its config, we only ensure core ports are set.
if [[ ! -f "${GEYSER_CONFIG}" ]]; then
  cat >"${GEYSER_CONFIG}" <<EOF
bedrock:
  address: 0.0.0.0
  port: ${BEDROCK_PORT}
  clone-remote-port: false
remote:
  address: 127.0.0.1
  port: ${JAVA_PORT}
  auth-type: online
advanced:
  debug-mode: false
EOF
  echo "[init] Wrote minimal Geyser config."
else
  # Best-effort in-place port enforcement (no yq to keep deps minimal)
  sed -i "s/^\(\s*port:\s*\).*/\1${BEDROCK_PORT}/" "${GEYSER_CONFIG}" || true
  echo "[init] Ensured Bedrock port in existing Geyser config."
fi

# 6) Ensure server.properties reflects the desired Java port (if file exists)
SERVER_PROPERTIES="${MC_DATA_DIR}/server.properties"
if [[ -f "${SERVER_PROPERTIES}" ]]; then
  sed -i "s/^server-port=.*/server-port=${JAVA_PORT}/" "${SERVER_PROPERTIES}" || echo "server-port=${JAVA_PORT}" >> "${SERVER_PROPERTIES}"
  # Enable query to improve Bedrock discovery via Geyser (optional)
  grep -q "^enable-query=" "${SERVER_PROPERTIES}" && sed -i "s/^enable-query=.*/enable-query=true/" "${SERVER_PROPERTIES}" || echo "enable-query=true" >> "${SERVER_PROPERTIES}"
  echo "[init] Updated server.properties (port/query)."
fi

echo "[init] Done."
