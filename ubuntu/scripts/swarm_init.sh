#!/bin/bash
set -euo pipefail

# Load env if present
ENV_FILE=$(dirname "$0")/../env
[ -f "$ENV_FILE" ] || ENV_FILE=$(dirname "$0")/../.env
[ -f "$ENV_FILE" ] || ENV_FILE=$(dirname "$0")/../env.example
set -o allexport
source "$ENV_FILE"
set +o allexport

if ! docker info 2>/dev/null | grep -q 'Swarm: active'; then
  docker swarm init --advertise-addr "$MANAGER_ADVERTISE_ADDR"
fi

if [ "${SWARM_AUTOLOCK}" = "true" ]; then
  docker swarm update --autolock=true || true
fi

# Create overlay network
if ! docker network inspect "$OVERLAY_NETWORK_NAME" >/dev/null 2>&1; then
  if [ "${OVERLAY_NETWORK_ENCRYPTED}" = "true" ]; then
    docker network create -d overlay --attachable --opt encrypted "$OVERLAY_NETWORK_NAME"
  else
    docker network create -d overlay --attachable "$OVERLAY_NETWORK_NAME"
  fi
fi


