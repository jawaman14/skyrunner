#!/bin/bash
# Creates a Skyrunner dedicated server on Google Compute Engine: a static IP, a firewall rule for TCP 47800, and a small VM that builds
# and runs the server container on boot (startup.sh).
#
#   PROJECT=my-gcp-project REPO=https://github.com/you/skyrunner.git PASSWORD=secret ./deploy/gcp/deploy.sh
#
# Optional: ZONE (us-central1-a), NAME (skyrunner), MACHINE (e2-small), MODE (coop|versus|police), UNLOCKS (open|story), REF (main),
#           ALLOW_FROM (a CIDR to restrict who can connect: 203.0.113.0/24; default anyone), MAX_PLAYERS, SEED.
# A private repository needs a URL the VM can clone (a deploy token in the URL, or copy the project up with `gcloud compute scp`).
# Needs the gcloud CLI, logged in (`gcloud auth login`), with billing on for the project.
set -euo pipefail

: "${PROJECT:?set PROJECT to your Google Cloud project id}"
: "${REPO:?set REPO to the git URL of the project}"
ZONE="${ZONE:-us-central1-a}"
REGION="${ZONE%-*}"
NAME="${NAME:-skyrunner}"
MACHINE="${MACHINE:-e2-small}"
MODE="${MODE:-coop}"
UNLOCKS="${UNLOCKS:-open}"
REF="${REF:-main}"
ALLOW_FROM="${ALLOW_FROM:-0.0.0.0/0}"
PASSWORD="${PASSWORD:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ -z "$PASSWORD" ]; then echo "warning: no PASSWORD set: anyone who finds the address can join" >&2; fi

gcloud config set project "$PROJECT" >/dev/null
gcloud services enable compute.googleapis.com

if ! gcloud compute addresses describe "$NAME-ip" --region "$REGION" >/dev/null 2>&1; then
  gcloud compute addresses create "$NAME-ip" --region "$REGION"
fi
IP=$(gcloud compute addresses describe "$NAME-ip" --region "$REGION" --format='get(address)')

if ! gcloud compute firewall-rules describe "$NAME-allow" >/dev/null 2>&1; then
  gcloud compute firewall-rules create "$NAME-allow" --direction INGRESS --allow tcp:47800 \
    --source-ranges "$ALLOW_FROM" --target-tags "$NAME"
fi

gcloud compute instances create "$NAME" --zone "$ZONE" --machine-type "$MACHINE" \
  --image-family debian-12 --image-project debian-cloud --boot-disk-size 20GB \
  --tags "$NAME" --address "$IP" \
  --metadata-from-file startup-script="$HERE/startup.sh" \
  --metadata "skyrunner-repo=$REPO,skyrunner-ref=$REF,skyrunner-mode=$MODE,skyrunner-unlocks=$UNLOCKS,skyrunner-password=$PASSWORD,skyrunner-max-players=${MAX_PLAYERS:-16},skyrunner-seed=${SEED:-1},skyrunner-name=${SERVER_NAME:-Skyrunner server}"

echo
echo "Created $NAME at $IP. The first boot installs Docker and builds the image (a few minutes); watch it with:"
echo "  gcloud compute instances get-serial-port-output $NAME --zone $ZONE | tail"
echo "Then join with:   skyrunner --connect ${PASSWORD:+$PASSWORD@}$IP:47800 --role boss"
echo "Update later:     gcloud compute ssh $NAME --zone $ZONE --command 'sudo google_metadata_script_runner startup'"
echo "Stop billing:     gcloud compute instances delete $NAME --zone $ZONE   (and: gcloud compute addresses delete $NAME-ip --region $REGION)"
