#!/bin/bash
set -euo pipefail

MANAGER_ADDR=${1:?manager advertise addr required}
WORKER_TOKEN=${2:?worker token required}

if docker info 2>/dev/null | grep -q 'Swarm: active'; then
  exit 0
fi

docker swarm join --token "$WORKER_TOKEN" "$MANAGER_ADDR:2377"


