# PaperMC (marctv) + Sleep (Java+Bedrock) + Auto-Shutdown (15m) + Geyser
FROM marctv/minecraft-papermc-server:1.21.9

ARG MCSSS_URL="https://github.com/vincss/mcsleepingserverstarter/releases/download/v1.11.3/mcsleepingserverstarter-linux-x64"
ARG MCESS_URL="https://github.com/vincss/mcEmptyServerStopper/releases/download/v1.1.0/mcEmptyServerStopper-1.1.0.jar"
ARG GEYSER_URL="https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot"

USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates jq \
 && rm -rf /var/lib/apt/lists/*

# Install mcsleepingserverstarter
RUN curl -fsSL "$MCSSS_URL" -o /usr/local/bin/mcsss && chmod +x /usr/local/bin/mcsss

# Plugins
RUN mkdir -p /data/plugins \
 && curl -fsSL "$MCESS_URL" -o /data/plugins/mcEmptyServerStopper.jar \
 && curl -fsSL "$GEYSER_URL" -o /data/plugins/Geyser-Spigot.jar

# mcEmptyServerStopper: shutdown after 900s idle
RUN mkdir -p /data/plugins/mcEmptyServerStopper \
 && cat > /data/plugins/mcEmptyServerStopper/config.yml <<'YAML'
enabled: true
empty_seconds: 900
announce:
  enabled: true
  interval_seconds: 60
  message: "Server empty - shutdown in {time_left}s."
YAML

# mcsleepingserverstarter: listen on Java(25565/TCP) & Bedrock(19132/UDP)
RUN mkdir -p /opt/mcsss \
 && cat > /opt/mcsss/mcsss.yaml <<'YAML'
java:
  enabled: true
  listen_address: "0.0.0.0"
  port: 25565
  motd: "Server sleeping... ping to wake"
  fake_players: 0
bedrock:
  enabled: true
  listen_address: "0.0.0.0"
  port: 19132
process:
  start_command: ["/start"]
  start_grace_seconds: 20
logging:
  level: "info"
YAML

# Minimal Geyser config (Bedrock on 19132/UDP, proxy to local Java)
RUN mkdir -p /data/plugins/Geyser-Spigot \
 && cat > /data/plugins/Geyser-Spigot/config.yml <<'YAML'
bedrock:
  address: 0.0.0.0
  port: 19132
  clone-remote-port: false
remote:
  address: 127.0.0.1
  port: 25565
  auth-type: online
general:
  passthrough-motd: true
  passthrough-player-counts: true
YAML

# Entrypoint: run mcsss (starts Paper via /start on demand)
RUN cat > /usr/local/bin/docker-entrypoint-mcsss.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p /data
exec /usr/local/bin/mcsss --config /opt/mcsss/mcsss.yaml
BASH
RUN chmod +x /usr/local/bin/docker-entrypoint-mcsss.sh

EXPOSE 25565/tcp
EXPOSE 19132/udp

ENV EULA=TRUE MEMORY=4G TYPE=PAPER

RUN if id minecraft >/dev/null 2>&1; then chown -R minecraft:minecraft /data /opt/mcsss; fi
USER minecraft

ENTRYPOINT ["/usr/local/bin/docker-entrypoint-mcsss.sh"]
