#!/bin/bash
# Runs as root on every boot of the Google Compute Engine VM that deploy.sh creates: installs Docker, fetches the game, builds the
# server image and runs it (restarting on reboot). The settings come from the instance's metadata (see deploy.sh).
set -euo pipefail

meta() {  # meta KEY [DEFAULT]
  local v
  v=$(curl -sf -H 'Metadata-Flavor: Google' "http://metadata.google.internal/computeMetadata/v1/instance/attributes/$1" || true)
  echo "${v:-${2:-}}"
}

REPO=$(meta skyrunner-repo)
REF=$(meta skyrunner-ref main)
if [ -z "$REPO" ]; then echo "skyrunner-repo metadata is not set" >&2; exit 1; fi

if ! command -v docker >/dev/null; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io git ca-certificates
  systemctl enable --now docker
fi

mkdir -p /opt/skyrunner /var/lib/skyrunner
if [ ! -d /opt/skyrunner/.git ]; then git clone "$REPO" /opt/skyrunner; fi
cd /opt/skyrunner
git fetch --all --quiet
git checkout --quiet "$REF"
git pull --quiet --ff-only || true

# rebuild only when the checked-out commit changed
HEAD_NOW=$(git rev-parse HEAD)
if [ "$(cat /var/lib/skyrunner/built 2>/dev/null || true)" != "$HEAD_NOW" ] || ! docker image inspect skyrunner-server >/dev/null 2>&1; then
  docker build -t skyrunner-server -f deploy/Dockerfile .
  echo "$HEAD_NOW" > /var/lib/skyrunner/built
fi

docker rm -f skyrunner >/dev/null 2>&1 || true
docker run -d --name skyrunner --restart unless-stopped --stop-timeout 30 \
  -p 47800:47800/tcp \
  -v /var/lib/skyrunner:/data \
  -e SKYRUNNER_NAME="$(meta skyrunner-name 'Skyrunner server')" \
  -e SKYRUNNER_MODE="$(meta skyrunner-mode coop)" \
  -e SKYRUNNER_UNLOCKS="$(meta skyrunner-unlocks open)" \
  -e SKYRUNNER_PASSWORD="$(meta skyrunner-password)" \
  -e SKYRUNNER_MAX_PLAYERS="$(meta skyrunner-max-players 16)" \
  -e SKYRUNNER_SEED="$(meta skyrunner-seed 1)" \
  skyrunner-server
echo "skyrunner server started: $(docker ps --filter name=skyrunner --format '{{.Status}}')"
