#!/bin/bash
set -euo pipefail

ENV_FILE=$(dirname "$0")/../env
[ -f "$ENV_FILE" ] || ENV_FILE=$(dirname "$0")/../.env
[ -f "$ENV_FILE" ] || ENV_FILE=$(dirname "$0")/../env.example
set -o allexport
source "$ENV_FILE"
set +o allexport

sudo mkdir -p \
  "$REMOTE_DATA_DIR/nexus-data" \
  "$REMOTE_DATA_DIR/nginx/conf.d" \
  "$REMOTE_DATA_DIR/nginx/certs" \
  "$REMOTE_DATA_DIR/prometheus/data" \
  "$REMOTE_DATA_DIR/grafana"

sudo chown -R $(id -u):$(id -g) "$REMOTE_DATA_DIR"

if [ ! -f "$REMOTE_DATA_DIR/prometheus/prometheus.yml" ]; then
  sudo mkdir -p "$REMOTE_DATA_DIR/prometheus"
  cp $(dirname "$0")/../stacks/monitoring/prometheus.yml "$REMOTE_DATA_DIR/prometheus/prometheus.yml"
fi


