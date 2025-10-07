# Base image: PaperMC from marctv
FROM marctv/minecraft-papermc-server:1.21.9

# Use root to install helper packages
USER root

# Install runtime helpers (Debian/Ubuntu)
# - curl: download artifacts at runtime
# - jq: simple JSON editing (if needed later)
# - ca-certificates: TLS for curl
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl jq ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Create directories used by our scripts
RUN mkdir -p /opt/mcsss /opt/minecraft/custom-init

# Copy runtime init + wrapper
COPY init.sh /opt/minecraft/init.sh
COPY start.sh /opt/minecraft/start.sh
RUN chmod +x /opt/minecraft/init.sh /opt/minecraft/start.sh

# -------- Default environment (override at `docker run` if needed) --------
# Java & Bedrock ports
ENV JAVA_PORT=25565 \
    BEDROCK_PORT=19132

# Idle shutdown: 15 minutes (900 seconds)
ENV MC_EMPTY_STOPPER_IDLE_SECONDS=900

# Download sources (override to pin versions)
# Geyser (Spigot) latest
ENV GEYSER_DOWNLOAD_URL="https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot"

# mcSleepingServerStarter (Linux amd64). Set to your preferred release asset.
# Example (placeholder): latest release binary URL
ENV MC_SSS_DOWNLOAD_URL="https://github.com/vincss/mcsleepingserverstarter/releases/download/v1.11.3/mcsleepingserverstarter-linux-x64"

# mcEmptyServerStopper plugin JAR (provide a stable URL to your preferred build)
# Placeholder; set your own if you have a different source
ENV MC_ESS_DOWNLOAD_URL="https://github.com/vincss/mcEmptyServerStopper/releases/download/v1.1.0/mcEmptyServerStopper-1.1.0.jar"

# Where the Paper server data lives in the marctv image
# (marctv uses /data as the persistent volume by default)
ENV MC_DATA_DIR="/data"

# Expose ports
EXPOSE 25565/tcp
EXPOSE 19132/udp

# Important: we exec the marctv entrypoint *through* mcsleepingserverstarter.
# Our wrapper first runs /opt/minecraft/init.sh (download/configure plugins),
# then launches mcsss so it can wake the Paper server when players connect.
ENTRYPOINT ["/opt/minecraft/start.sh"]
