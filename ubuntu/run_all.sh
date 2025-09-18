#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ENV_FILE="$SCRIPT_DIR/.env"
[ -f "$ENV_FILE" ] || ENV_FILE="$SCRIPT_DIR/env"
[ -f "$ENV_FILE" ] || ENV_FILE="$SCRIPT_DIR/env.example"
set -o allexport
source "$ENV_FILE"
set +o allexport

ssh_cmd() {
  local host="$1"; shift
  ssh -i "$SSH_PRIVATE_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$host" "$@"
}

scp_to() {
  local host="$1"; shift
  scp -i "$SSH_PRIVATE_KEY" -o StrictHostKeyChecking=no -r "$@" "$SSH_USER@$host:$REMOTE_SETUP_DIR/"
}

prepare_remote_dirs() {
  IFS=',' read -ra WORKERS <<< "${WORKER_HOSTS}"
  for host in "$MANAGER_HOST" "${WORKERS[@]}"; do
    ssh_cmd "$host" "sudo mkdir -p $REMOTE_SETUP_DIR $REMOTE_DATA_DIR && sudo chown -R \$(id -u):\$(id -g) $REMOTE_SETUP_DIR $REMOTE_DATA_DIR"
  done
}

copy_scripts() {
  IFS=',' read -ra WORKERS <<< "${WORKER_HOSTS}"
  for host in "$MANAGER_HOST" "${WORKERS[@]}"; do
    scp_to "$host" "$SCRIPT_DIR/scripts"
    scp_to "$host" "$SCRIPT_DIR/stacks"
    scp_to "$host" "$ENV_FILE"
  done
}

install_docker() {
  IFS=',' read -ra WORKERS <<< "${WORKER_HOSTS}"
  for host in "$MANAGER_HOST" "${WORKERS[@]}"; do
    ssh_cmd "$host" "bash $REMOTE_SETUP_DIR/scripts/install_docker.sh"
  done
}

init_swarm() {
  ssh_cmd "$MANAGER_HOST" "bash $REMOTE_SETUP_DIR/scripts/prepare_data_dirs.sh"
  ssh_cmd "$MANAGER_HOST" "bash $REMOTE_SETUP_DIR/scripts/swarm_init.sh"
  worker_token=$(ssh_cmd "$MANAGER_HOST" "docker swarm join-token -q worker")
  IFS=',' read -ra WORKERS <<< "${WORKER_HOSTS}"
  for host in "${WORKERS[@]}"; do
    ssh_cmd "$host" "bash $REMOTE_SETUP_DIR/scripts/swarm_join.sh $MANAGER_ADVERTISE_ADDR $worker_token"
  done
}

deploy_stacks() {
  if [ "${DEPLOY_NEXUS}" = "true" ]; then
    ssh_cmd "$MANAGER_HOST" "docker stack deploy -c $REMOTE_SETUP_DIR/stacks/nexus/docker-compose.yml nexus"
  fi
  if [ "${DEPLOY_NGINX}" = "true" ]; then
    ssh_cmd "$MANAGER_HOST" "docker stack deploy -c $REMOTE_SETUP_DIR/stacks/nginx/docker-compose.yml nginx"
  fi
  if [ "${DEPLOY_MONITORING}" = "true" ]; then
    ssh_cmd "$MANAGER_HOST" "docker stack deploy -c $REMOTE_SETUP_DIR/stacks/monitoring/docker-compose.yml monitoring"
  fi
}

main() {
  prepare_remote_dirs
  copy_scripts
  install_docker
  init_swarm
  deploy_stacks
  echo "All done. Access: Nexus http://$MANAGER_HOST:$NEXUS_PORT, Grafana http://$MANAGER_HOST:$GRAFANA_PORT"
}

main "$@"


