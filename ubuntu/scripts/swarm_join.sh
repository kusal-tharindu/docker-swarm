#!/bin/bash

# Docker Swarm Join Script
# Joins a worker node to the Docker Swarm cluster

set -euo pipefail

# Load libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/logger.sh"

# Initialize logging
init_logging

# Check arguments
if [[ $# -lt 2 ]]; then
    log_error "Usage: $0 <manager-addr> <worker-token>"
    log_error "  manager-addr: Manager node IP address"
    log_error "  worker-token: Worker join token"
    exit 1
fi

MANAGER_ADDR="$1"
WORKER_TOKEN="$2"

log_section "Docker Swarm Join"

# Validate arguments
log_step "Validating arguments"
if [[ -z "$MANAGER_ADDR" ]]; then
    log_error "Manager address is required"
    exit 1
fi

if [[ -z "$WORKER_TOKEN" ]]; then
    log_error "Worker token is required"
    exit 1
fi

# Validate manager address format
if ! [[ "$MANAGER_ADDR" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    log_error "Invalid manager address format: $MANAGER_ADDR"
    exit 1
fi

log_success "Arguments validated"

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
    log_info "This node is already part of a swarm"
    
    # Check if it's already connected to the correct manager
    local current_manager=$(docker info 2>/dev/null | grep "Remote Manager" | awk '{print $3}' || echo "")
    if [[ "$current_manager" == "$MANAGER_ADDR:2377" ]]; then
        log_success "Already connected to the correct manager: $MANAGER_ADDR"
        exit 0
    else
        log_warn "Connected to different manager: $current_manager"
        log_info "Leaving current swarm to join new one"
        
        if ! log_exec "Leave current swarm" "docker swarm leave"; then
            log_error "Failed to leave current swarm"
            exit 1
        fi
    fi
fi

# Test connectivity to manager
log_step "Testing connectivity to manager"
if ! test_connectivity "$MANAGER_ADDR" "2377" 10; then
    log_error "Cannot connect to manager at $MANAGER_ADDR:2377"
    log_error "Please check:"
    log_error "  - Manager is running and accessible"
    log_error "  - Firewall allows port 2377"
    log_error "  - Network connectivity is working"
    exit 1
fi
log_success "Manager connectivity verified"

# Join swarm
log_step "Joining Docker Swarm"
log_info "Manager address: $MANAGER_ADDR"
log_info "Worker token: ${WORKER_TOKEN:0:10}..."

if ! log_exec "Join swarm" "docker swarm join --token $WORKER_TOKEN $MANAGER_ADDR:2377"; then
    log_error "Failed to join Docker Swarm"
    log_error "Please check:"
    log_error "  - Worker token is valid"
    log_error "  - Manager is accessible"
    log_error "  - No firewall blocking the connection"
    exit 1
fi

log_success "Successfully joined Docker Swarm"

# Verify join
log_step "Verifying swarm membership"
if ! docker info 2>/dev/null | grep -q 'Swarm: active'; then
    log_error "Failed to verify swarm membership"
    exit 1
fi

# Show swarm information
log_info "Swarm status:"
docker info 2>/dev/null | grep -A 5 'Swarm:' | while read -r line; do
    log_info "  $line"
done

log_success "Worker node successfully joined the swarm cluster"