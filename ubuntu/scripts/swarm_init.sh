#!/bin/bash

# Docker Swarm Initialization Script
# Initializes Docker Swarm on the manager node with comprehensive error handling

set -euo pipefail

# Load libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/logger.sh"
source "$SCRIPT_DIR/../lib/config.sh"

# Load configuration
ENV_FILE="$SCRIPT_DIR/../.env"
[[ -f "$ENV_FILE" ]] || ENV_FILE="$SCRIPT_DIR/../env"
[[ -f "$ENV_FILE" ]] || ENV_FILE="$SCRIPT_DIR/../env.example"

if ! load_config "$ENV_FILE"; then
    log_error "Failed to load configuration"
    exit 1
fi

set_defaults

# Initialize logging
init_logging

log_section "Docker Swarm Initialization"

# Check if Docker is running
log_step "Checking Docker daemon"
if ! docker info >/dev/null 2>&1; then
    log_error "Docker daemon is not running"
    exit 1
fi
log_success "Docker daemon is running"

# Check if already in swarm
log_step "Checking current swarm status"
if docker info 2>/dev/null | grep -q 'Swarm: active'; then
    log_info "Docker Swarm is already active"
    
    # Check if this is the manager
    if docker info 2>/dev/null | grep -q 'Is Manager: true'; then
        log_success "This node is already a swarm manager"
        
        # Show swarm info
        log_info "Swarm information:"
        docker node ls 2>/dev/null | while read -r line; do
            log_info "  $line"
        done
        
        exit 0
    else
        log_error "This node is in a swarm but not as a manager"
        exit 1
    fi
fi

# Validate required configuration
log_step "Validating configuration"
if [[ -z "${MANAGER_ADVERTISE_ADDR:-}" ]]; then
    log_error "MANAGER_ADVERTISE_ADDR is required but not set"
    exit 1
fi

if ! validate_ip "$MANAGER_ADVERTISE_ADDR"; then
    log_error "Invalid MANAGER_ADVERTISE_ADDR: $MANAGER_ADVERTISE_ADDR"
    exit 1
fi

log_success "Configuration validated"

# Initialize swarm
log_step "Initializing Docker Swarm"
log_info "Using advertise address: $MANAGER_ADVERTISE_ADDR"

if ! log_exec "Initialize swarm" "docker swarm init --advertise-addr $MANAGER_ADVERTISE_ADDR"; then
    log_error "Failed to initialize Docker Swarm"
    exit 1
fi

log_success "Docker Swarm initialized successfully"

# Configure swarm autolock
if [[ "${SWARM_AUTOLOCK:-true}" == "true" ]]; then
    log_step "Enabling swarm autolock"
    if ! log_exec "Enable autolock" "docker swarm update --autolock=true"; then
        log_warn "Failed to enable swarm autolock"
    else
        log_success "Swarm autolock enabled"
        log_info "Save the unlock key in a secure location"
    fi
fi

# Create overlay network
log_step "Creating overlay network"
local network_name="${OVERLAY_NETWORK_NAME:-public}"

if docker network inspect "$network_name" >/dev/null 2>&1; then
    log_info "Overlay network '$network_name' already exists"
else
    local network_opts="-d overlay --attachable"
    
    if [[ "${OVERLAY_NETWORK_ENCRYPTED:-true}" == "true" ]]; then
        network_opts="$network_opts --opt encrypted"
        log_info "Creating encrypted overlay network: $network_name"
    else
        log_info "Creating overlay network: $network_name"
    fi
    
    if ! log_exec "Create overlay network" "docker network create $network_opts $network_name"; then
        log_error "Failed to create overlay network"
        exit 1
    fi
    
    log_success "Overlay network '$network_name' created successfully"
fi

# Verify swarm status
log_step "Verifying swarm status"
if ! log_exec "Check swarm status" "docker info | grep -A 10 'Swarm:'"; then
    log_error "Failed to verify swarm status"
    exit 1
fi

# Show swarm information
log_section "Swarm Information"
log_info "Manager node information:"
docker node ls 2>/dev/null | while read -r line; do
    log_info "  $line"
done

# Show join tokens
log_info "Worker join command:"
local worker_token=$(docker swarm join-token -q worker 2>/dev/null || echo "Failed to get token")
if [[ "$worker_token" != "Failed to get token" ]]; then
    log_info "  docker swarm join --token $worker_token $MANAGER_ADVERTISE_ADDR:2377"
else
    log_error "Failed to get worker join token"
fi

# Show network information
log_info "Overlay networks:"
docker network ls --filter driver=overlay | while read -r line; do
    log_info "  $line"
done

log_success "Docker Swarm initialization completed successfully"