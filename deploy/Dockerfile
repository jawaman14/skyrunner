# The Skyrunner dedicated server, headless, from source.
#
#   docker build -t skyrunner-server -f deploy/Dockerfile .
#   docker run -d --name skyrunner -p 47800:47800 -v skyrunner-data:/data -e SKYRUNNER_PASSWORD=secret skyrunner-server
#
# Every server option is an environment variable (SKYRUNNER_PORT, SKYRUNNER_MODE, SKYRUNNER_UNLOCKS, SKYRUNNER_PASSWORD, ...; see
# docs/SERVER.md) or a flag after the image name. The game is saved to /data (mount a volume there to keep it).
FROM debian:bookworm-slim

ARG GODOT_VERSION=4.7.2-stable

# the shared libraries the Godot binary links against (it opens no window here, but it still loads them)
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl unzip \
        libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 libxext6 libxrender1 libxfixes3 libxkbcommon0 \
        libgl1 libasound2 libfontconfig1 libdbus-1-3 libudev1 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -sSL -o /tmp/godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip" \
    && unzip -oq /tmp/godot.zip -d /tmp \
    && mv /tmp/Godot_v${GODOT_VERSION}_linux.x86_64 /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm /tmp/godot.zip

RUN useradd --create-home --shell /usr/sbin/nologin skyrunner && mkdir /data && chown skyrunner /data
COPY --chown=skyrunner . /app
USER skyrunner
WORKDIR /app

# builds the class cache the scripts need (the first run of any Godot project)
RUN godot --headless --path /app --import > /dev/null 2>&1 || true

VOLUME /data
EXPOSE 47800/tcp
ENV SKYRUNNER_SAVE=/data/dedicated.json SKYRUNNER_STOP_FILE=/data/stop

ENTRYPOINT ["/app/deploy/entrypoint.sh"]
