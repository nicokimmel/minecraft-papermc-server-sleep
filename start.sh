#!/usr/bin/env bash
set -euo pipefail

# --- Run runtime initialization (downloads, config) ---
/opt/minecraft/init.sh

# --- Ensure dockeruser:dockergroup exist (idempotent) ---
PUID="${PUID:-1001}"
PGID="${PGID:-1001}"

# Create group if missing
if ! getent group dockergroup >/dev/null 2>&1; then
  groupadd -g "${PGID}" dockergroup || true
fi

# Create user if missing (no home, nologin shell)
if ! id -u dockeruser >/dev/null 2>&1; then
  useradd -u "${PUID}" -g dockergroup -M -s /usr/sbin/nologin dockeruser || true
fi

# --- Launch mcsleepingserverstarter as PID 1 ---
JAVA_PORT="${JAVA_PORT:-25565}"
BEDROCK_PORT="${BEDROCK_PORT:-19132}"

MC_SSS_BIN="/opt/mcsss/mcsleepingserverstarter"
if [[ ! -x "${MC_SSS_BIN}" ]]; then
  echo "[ERROR] mcsleepingserverstarter binary not found or not executable at ${MC_SSS_BIN}" >&2
  exit 1
fi

# --- Write minimal sleepingSettings.yml (no defaults) or patch existing ---
if [[ ! -f "${MCSS_SETTINGS}" ]]; then
  cat > "${MCSS_SETTINGS}" <<EOF
serverPort: ${MC_PORT}
bedrockPort: ${BEDROCK_PORT}
minecraftCommand: "/opt/minecraft/docker-entrypoint.sh"
minecraftWorkingDirectory: "/"
EOF
  echo "[start] Wrote minimal ${MCSS_SETTINGS}"
else
  # Update only the keys we care about, leave everything else untouched.
  # serverPort
  if grep -q '^[[:space:]]*serverPort:' "${MCSS_SETTINGS}"; then
    sed -i "s/^\s*serverPort:\s*.*/serverPort: ${MC_PORT}/" "${MCSS_SETTINGS}"
  else
    printf 'serverPort: %s\n' "${MC_PORT}" >> "${MCSS_SETTINGS}"
  fi
  # bedrockPort
  if grep -q '^[[:space:]]*bedrockPort:' "${MCSS_SETTINGS}"; then
    sed -i "s/^\s*bedrockPort:\s*.*/bedrockPort: ${BEDROCK_PORT}/" "${MCSS_SETTINGS}"
  else
    printf 'bedrockPort: %s\n' "${BEDROCK_PORT}" >> "${MCSS_SETTINGS}"
  fi
  # minecraftCommand
  if grep -q '^[[:space:]]*minecraftCommand:' "${MCSS_SETTINGS}"; then
    sed -i 's#^\s*minecraftCommand:.*#minecraftCommand: "/opt/minecraft/docker-entrypoint.sh"#' "${MCSS_SETTINGS}"
  else
    printf 'minecraftCommand: "/opt/minecraft/docker-entrypoint.sh"\n' >> "${MCSS_SETTINGS}"
  fi
  # minecraftWorkingDirectory
  if grep -q '^[[:space:]]*minecraftWorkingDirectory:' "${MCSS_SETTINGS}"; then
    sed -i 's#^\s*minecraftWorkingDirectory:.*#minecraftWorkingDirectory: "/"#' "${MCSS_SETTINGS}"
  else
    printf 'minecraftWorkingDirectory: "/"\n' >> "${MCSS_SETTINGS}"
  fi
  echo "[start] Patched ${MCSS_SETTINGS} (ports/command/workingDirectory)."
fi

exec "${MC_SSS_BIN}" -config /opt/mcsss/config.json
