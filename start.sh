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
MC_SSS_SETTINGS="${MC_DATA_DIR}/sleepingSettings.yml"

if [[ ! -x "${MC_SSS_BIN}" ]]; then
  echo "[ERROR] mcsleepingserverstarter binary not found or not executable at ${MC_SSS_BIN}" >&2
  exit 1
fi

# --- Write minimal sleepingSettings.yml (no defaults) or patch existing ---
if [[ ! -f "${MC_SSS_SETTINGS}" ]]; then
  cat > "${MC_SSS_SETTINGS}" <<EOF
serverPort: ${JAVA_PORT}
bedrockPort: ${BEDROCK_PORT}
minecraftCommand: "/opt/minecraft/docker-entrypoint.sh"
minecraftWorkingDirectory: "/"
EOF
  echo "[start] Wrote minimal ${MC_SSS_SETTINGS}"
else
  # Update only the keys we care about, leave everything else untouched.
  # serverPort
  if grep -q '^[[:space:]]*serverPort:' "${MC_SSS_SETTINGS}"; then
    sed -i "s/^\s*serverPort:\s*.*/serverPort: ${JAVA_PORT}/" "${MC_SSS_SETTINGS}"
  else
    printf 'serverPort: %s\n' "${JAVA_PORT}" >> "${MC_SSS_SETTINGS}"
  fi
  # bedrockPort
  if grep -q '^[[:space:]]*bedrockPort:' "${MC_SSS_SETTINGS}"; then
    sed -i "s/^\s*bedrockPort:\s*.*/bedrockPort: ${BEDROCK_PORT}/" "${MC_SSS_SETTINGS}"
  else
    printf 'bedrockPort: %s\n' "${BEDROCK_PORT}" >> "${MC_SSS_SETTINGS}"
  fi
  # minecraftCommand
  if grep -q '^[[:space:]]*minecraftCommand:' "${MC_SSS_SETTINGS}"; then
    sed -i 's#^\s*minecraftCommand:.*#minecraftCommand: "/opt/minecraft/docker-entrypoint.sh"#' "${MC_SSS_SETTINGS}"
  else
    printf 'minecraftCommand: "/opt/minecraft/docker-entrypoint.sh"\n' >> "${MC_SSS_SETTINGS}"
  fi
  # minecraftWorkingDirectory
  if grep -q '^[[:space:]]*minecraftWorkingDirectory:' "${MC_SSS_SETTINGS}"; then
    sed -i 's#^\s*minecraftWorkingDirectory:.*#minecraftWorkingDirectory: "/"#' "${MC_SSS_SETTINGS}"
  else
    printf 'minecraftWorkingDirectory: "/"\n' >> "${MC_SSS_SETTINGS}"
  fi
  echo "[start] Patched ${MC_SSS_SETTINGS} (ports/command/workingDirectory)."
fi

exec "${MC_SSS_BIN}" -config /opt/mcsss/config.json
