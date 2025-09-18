#!/bin/bash

# Docker Swarm Automated Setup Script
# Main orchestrator for setting up Docker Swarm cluster with comprehensive logging

set -euo pipefail

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"
readonly START_TIME="$(date +%s)"

# Load libraries
source "$SCRIPT_DIR/lib/logger.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/utils.sh"

# Initialize logging and signal handlers
init_logging
setup_signal_handlers

# Main execution
main() {
    log_section "Docker Swarm Cluster Setup"
    log_info "Starting automated setup process"
    
    # Check prerequisites
    if ! check_prerequisites; then
        log_error "Prerequisites check failed"
        exit 1
    fi
    
    # Load and validate configuration
    if ! load_config "$ENV_FILE"; then
        log_error "Failed to load configuration"
        exit 1
    fi
    
    set_defaults
    show_config
    
    if ! validate_config; then
        log_error "Configuration validation failed"
        exit 1
    fi
    
    # Setup SSH options
    SSH_OPTS="-o StrictHostKeyChecking=no -i $SSH_PRIVATE_KEY"
    
    # Execute setup steps
    log_section "Step 1: Preparing Remote Directories"
    prepare_remote_directories
    
    log_section "Step 2: Copying Scripts and Configuration"
    copy_scripts_and_config
    
    log_section "Step 3: Installing Docker"
    install_docker_on_nodes
    
    log_section "Step 4: Initializing Swarm"
    initialize_swarm_cluster
    
    log_section "Step 5: Deploying Services"
    deploy_application_stacks
    
    log_section "Step 6: Verifying Deployment"
    verify_deployment
    
    # Final summary
    local end_time="$(date +%s)"
    local duration=$((end_time - START_TIME))
    
    log_section "Setup Complete"
    log_success "Docker Swarm cluster setup completed in ${duration} seconds"
    log_info "Access your services:"
    log_info "  Nexus:      http://$MANAGER_HOST:$NEXUS_PORT"
    log_info "  Nginx:      http://$MANAGER_HOST"
    log_info "  Grafana:    http://$MANAGER_HOST:$GRAFANA_PORT (admin/admin)"
    log_info "  Prometheus: http://$MANAGER_HOST:$PROMETHEUS_PORT"
    
    log_summary
}

# Prepare remote directories on all nodes
prepare_remote_directories() {
    log_info "Creating remote directories on all nodes"
    
    local all_hosts=("$MANAGER_HOST")
    if [[ -n "${WORKER_HOSTS:-}" ]]; then
        IFS=',' read -ra workers <<< "$WORKER_HOSTS"
        all_hosts+=("${workers[@]}")
    fi
    
    for host in "${all_hosts[@]}"; do
        log_step "Preparing directories on $host"
        
        local commands=(
            "sudo mkdir -p $REMOTE_SETUP_DIR $REMOTE_DATA_DIR"
            "sudo chown -R \$(id -u):\$(id -g) $REMOTE_SETUP_DIR $REMOTE_DATA_DIR"
            "mkdir -p $REMOTE_DATA_DIR/{nexus-data,nginx/{conf.d,certs},prometheus,grafana}"
        )
        
        for cmd in "${commands[@]}"; do
            if ! log_ssh_exec "$host" "Execute: $cmd" "$cmd" "$SSH_OPTS"; then
                log_error "Failed to prepare directories on $host"
                return 1
            fi
        done
    done
    
    log_success "Remote directories prepared on all nodes"
}

# Copy scripts and configuration to all nodes
copy_scripts_and_config() {
    log_info "Copying scripts and configuration to all nodes"
    
    local all_hosts=("$MANAGER_HOST")
    if [[ -n "${WORKER_HOSTS:-}" ]]; then
        IFS=',' read -ra workers <<< "$WORKER_HOSTS"
        all_hosts+=("${workers[@]}")
    fi
    
    for host in "${all_hosts[@]}"; do
        log_step "Copying files to $host"
        
        # Copy scripts directory
        if ! rsync -avz -e "ssh $SSH_OPTS" "$SCRIPT_DIR/scripts/" "$SSH_USER@$host:$REMOTE_SETUP_DIR/scripts/"; then
            log_error "Failed to copy scripts to $host"
            return 1
        fi
        
        # Copy stacks directory
        if ! rsync -avz -e "ssh $SSH_OPTS" "$SCRIPT_DIR/stacks/" "$SSH_USER@$host:$REMOTE_SETUP_DIR/stacks/"; then
            log_error "Failed to copy stacks to $host"
            return 1
        fi
        
        # Copy environment file
        if ! scp $SSH_OPTS "$ENV_FILE" "$SSH_USER@$host:$REMOTE_SETUP_DIR/.env"; then
            log_error "Failed to copy environment file to $host"
            return 1
        fi
        
        log_debug "Files copied successfully to $host"
    done
    
    log_success "Scripts and configuration copied to all nodes"
}

# Install Docker on all nodes
install_docker_on_nodes() {
    log_info "Installing Docker on all nodes"
    
    local all_hosts=("$MANAGER_HOST")
    if [[ -n "${WORKER_HOSTS:-}" ]]; then
        IFS=',' read -ra workers <<< "$WORKER_HOSTS"
        all_hosts+=("${workers[@]}")
    fi
    
    for host in "${all_hosts[@]}"; do
        log_step "Installing Docker on $host"
        
        if ! log_ssh_exec "$host" "Install Docker" "bash $REMOTE_SETUP_DIR/scripts/install_docker.sh" "$SSH_OPTS"; then
            log_error "Failed to install Docker on $host"
            return 1
        fi
        
        # Verify Docker installation
        if ! log_ssh_exec "$host" "Verify Docker installation" "docker --version && docker info" "$SSH_OPTS"; then
            log_error "Docker verification failed on $host"
            return 1
        fi
    done
    
    log_success "Docker installed on all nodes"
}

# Initialize swarm cluster
initialize_swarm_cluster() {
    log_info "Initializing Docker Swarm cluster"
    
    # Prepare data directories on manager
    log_step "Preparing data directories on manager"
    if ! log_ssh_exec "$MANAGER_HOST" "Prepare data directories" "bash $REMOTE_SETUP_DIR/scripts/prepare_data_dirs.sh" "$SSH_OPTS"; then
        log_error "Failed to prepare data directories on manager"
        return 1
    fi
    
    # Initialize swarm on manager
    log_step "Initializing swarm on manager"
    if ! log_ssh_exec "$MANAGER_HOST" "Initialize swarm" "bash $REMOTE_SETUP_DIR/scripts/swarm_init.sh" "$SSH_OPTS"; then
        log_error "Failed to initialize swarm on manager"
        return 1
    fi
    
    # Get worker join token
    log_step "Getting worker join token"
    local worker_token
    if ! worker_token=$(ssh $SSH_OPTS "$SSH_USER@$MANAGER_HOST" "docker swarm join-token -q worker" 2>/dev/null); then
        log_error "Failed to get worker join token"
        return 1
    fi
    
    log_debug "Worker join token obtained"
    
    # Join workers to swarm
    if [[ -n "${WORKER_HOSTS:-}" ]]; then
        IFS=',' read -ra workers <<< "$WORKER_HOSTS"
        
        for host in "${workers[@]}"; do
            log_step "Joining worker $host to swarm"
            
            if ! log_ssh_exec "$host" "Join swarm" "bash $REMOTE_SETUP_DIR/scripts/swarm_join.sh $MANAGER_ADVERTISE_ADDR $worker_token" "$SSH_OPTS"; then
                log_error "Failed to join worker $host to swarm"
                return 1
            fi
        done
    fi
    
    # Verify swarm status
    log_step "Verifying swarm status"
    if ! log_ssh_exec "$MANAGER_HOST" "Check swarm status" "docker node ls" "$SSH_OPTS"; then
        log_error "Failed to verify swarm status"
        return 1
    fi
    
    log_success "Swarm cluster initialized successfully"
}

# Deploy application stacks
deploy_application_stacks() {
    log_info "Deploying application stacks"
    
    # Deploy Nexus
    if [[ "${DEPLOY_NEXUS:-true}" == "true" ]]; then
        log_step "Deploying Nexus stack"
        if ! log_ssh_exec "$MANAGER_HOST" "Deploy Nexus" "docker stack deploy -c $REMOTE_SETUP_DIR/stacks/nexus/docker-compose.yml nexus" "$SSH_OPTS"; then
            log_error "Failed to deploy Nexus stack"
            return 1
        fi
        
        # Wait for Nexus to be ready
        if ! wait_for_service "nexus_nexus"; then
            log_error "Nexus service failed to become ready"
            return 1
        fi
    fi
    
    # Deploy Nginx
    if [[ "${DEPLOY_NGINX:-true}" == "true" ]]; then
        log_step "Deploying Nginx stack"
        if ! log_ssh_exec "$MANAGER_HOST" "Deploy Nginx" "docker stack deploy -c $REMOTE_SETUP_DIR/stacks/nginx/docker-compose.yml nginx" "$SSH_OPTS"; then
            log_error "Failed to deploy Nginx stack"
            return 1
        fi
        
        # Wait for Nginx to be ready
        if ! wait_for_service "nginx_nginx"; then
            log_error "Nginx service failed to become ready"
            return 1
        fi
    fi
    
    # Deploy Monitoring
    if [[ "${DEPLOY_MONITORING:-true}" == "true" ]]; then
        log_step "Deploying Monitoring stack"
        if ! log_ssh_exec "$MANAGER_HOST" "Deploy Monitoring" "docker stack deploy -c $REMOTE_SETUP_DIR/stacks/monitoring/docker-compose.yml monitoring" "$SSH_OPTS"; then
            log_error "Failed to deploy Monitoring stack"
            return 1
        fi
        
        # Wait for monitoring services to be ready
        local monitoring_services=("monitoring_grafana" "monitoring_prom")
        for service in "${monitoring_services[@]}"; do
            if ! wait_for_service "$service"; then
                log_warn "$service failed to become ready"
            fi
        done
    fi
    
    log_success "Application stacks deployed successfully"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment"
    
    # Check swarm status
    log_step "Checking swarm status"
    if ! log_ssh_exec "$MANAGER_HOST" "Check swarm nodes" "docker node ls" "$SSH_OPTS"; then
        log_warn "Failed to check swarm status"
    fi
    
    # Check services
    log_step "Checking services"
    if ! log_ssh_exec "$MANAGER_HOST" "Check services" "docker service ls" "$SSH_OPTS"; then
        log_warn "Failed to check services"
    fi
    
    # Test service accessibility
    log_step "Testing service accessibility"
    
    local services=(
        "Nexus:$NEXUS_PORT"
        "Nginx:80"
        "Grafana:$GRAFANA_PORT"
        "Prometheus:$PROMETHEUS_PORT"
    )
    
    for service_info in "${services[@]}"; do
        IFS=':' read -r service_name port <<< "$service_info"
        
        if test_connectivity "$MANAGER_HOST" "$port" 5; then
            log_success "$service_name is accessible on port $port"
        else
            log_warn "$service_name is not accessible on port $port"
        fi
    done
    
    log_success "Deployment verification completed"
}

# Error handling
handle_error() {
    local exit_code=$1
    local line_number=$2
    
    log_error "Script failed at line $line_number with exit code $exit_code"
    log_error "Check logs in $LOG_DIR for details"
    
    # Show recent errors
    if [[ -f "$ERROR_LOG_FILE" ]]; then
        log_error "Recent errors:"
        tail -5 "$ERROR_LOG_FILE" | while read -r line; do
            log_error "  $line"
        done
    fi
    
    exit $exit_code
}

# Set error trap
trap 'handle_error $? $LINENO' ERR

# Run main function
main "$@"