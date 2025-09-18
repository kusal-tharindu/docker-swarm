#!/bin/bash

# Data Directories Preparation Script
# Creates and configures data directories for persistent storage

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

log_section "Data Directories Preparation"

# Define required directories
declare -A DATA_DIRS=(
    ["nexus-data"]="nexus-data"
    ["nginx-conf"]="nginx/conf.d"
    ["nginx-certs"]="nginx/certs"
    ["prometheus-data"]="prometheus/data"
    ["prometheus-config"]="prometheus"
    ["grafana-data"]="grafana"
)

# Create base data directory
log_step "Creating base data directory"
if ! create_directory "$REMOTE_DATA_DIR" "755"; then
    log_error "Failed to create base data directory: $REMOTE_DATA_DIR"
    exit 1
fi

# Create subdirectories
log_step "Creating service data directories"
for service in "${!DATA_DIRS[@]}"; do
    local dir_path="$REMOTE_DATA_DIR/${DATA_DIRS[$service]}"
    
    if ! create_directory "$dir_path" "755"; then
        log_error "Failed to create directory: $dir_path"
        exit 1
    fi
    
    log_debug "Created directory: $dir_path"
done

# Set ownership
log_step "Setting directory ownership"
if ! log_exec "Set ownership" "sudo chown -R $(id -u):$(id -g) $REMOTE_DATA_DIR"; then
    log_error "Failed to set ownership for $REMOTE_DATA_DIR"
    exit 1
fi

# Set permissions for specific services
log_step "Setting service-specific permissions"

# Nexus data directory (needs write access)
if [[ -d "$REMOTE_DATA_DIR/nexus-data" ]]; then
    if ! log_exec "Set Nexus permissions" "sudo chmod -R 777 $REMOTE_DATA_DIR/nexus-data"; then
        log_warn "Failed to set Nexus permissions"
    else
        log_debug "Set Nexus data permissions to 777"
    fi
fi

# Prometheus data directory (needs write access)
if [[ -d "$REMOTE_DATA_DIR/prometheus" ]]; then
    if ! log_exec "Set Prometheus permissions" "sudo chmod -R 777 $REMOTE_DATA_DIR/prometheus"; then
        log_warn "Failed to set Prometheus permissions"
    else
        log_debug "Set Prometheus data permissions to 777"
    fi
fi

# Grafana data directory (needs write access)
if [[ -d "$REMOTE_DATA_DIR/grafana" ]]; then
    if ! log_exec "Set Grafana permissions" "sudo chmod -R 777 $REMOTE_DATA_DIR/grafana"; then
        log_warn "Failed to set Grafana permissions"
    else
        log_debug "Set Grafana data permissions to 777"
    fi
fi

# Nginx configuration directory (needs read access)
if [[ -d "$REMOTE_DATA_DIR/nginx/conf.d" ]]; then
    if ! log_exec "Set Nginx conf permissions" "sudo chmod -R 755 $REMOTE_DATA_DIR/nginx/conf.d"; then
        log_warn "Failed to set Nginx conf permissions"
    else
        log_debug "Set Nginx conf permissions to 755"
    fi
fi

# Create Prometheus configuration file
log_step "Creating Prometheus configuration"
local prometheus_config_dir="$REMOTE_DATA_DIR/prometheus"
local prometheus_config_file="$prometheus_config_dir/prometheus.yml"

if [[ ! -f "$prometheus_config_file" ]]; then
    local source_config="$SCRIPT_DIR/../stacks/monitoring/prometheus.yml"
    
    if [[ -f "$source_config" ]]; then
        if ! log_exec "Copy Prometheus config" "cp $source_config $prometheus_config_file"; then
            log_warn "Failed to copy Prometheus configuration"
        else
            log_success "Prometheus configuration created"
        fi
    else
        log_warn "Prometheus configuration template not found: $source_config"
        
        # Create a basic Prometheus configuration
        cat > "$prometheus_config_file" << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
  
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
EOF
        
        if [[ $? -eq 0 ]]; then
            log_success "Created basic Prometheus configuration"
        else
            log_error "Failed to create Prometheus configuration"
            exit 1
        fi
    fi
else
    log_info "Prometheus configuration already exists"
fi

# Create Nginx default configuration
log_step "Creating Nginx default configuration"
local nginx_conf_dir="$REMOTE_DATA_DIR/nginx/conf.d"
local nginx_default_conf="$nginx_conf_dir/default.conf"

if [[ ! -f "$nginx_default_conf" ]]; then
    cat > "$nginx_default_conf" << 'EOF'
server {
    listen 80;
    server_name _;
    
    location / {
        return 200 'Docker Swarm Nginx is running!\n';
        add_header Content-Type text/plain;
    }
    
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF
    
    if [[ $? -eq 0 ]]; then
        log_success "Created Nginx default configuration"
    else
        log_warn "Failed to create Nginx default configuration"
    fi
else
    log_info "Nginx default configuration already exists"
fi

# Verify directory structure
log_step "Verifying directory structure"
local expected_dirs=(
    "$REMOTE_DATA_DIR/nexus-data"
    "$REMOTE_DATA_DIR/nginx/conf.d"
    "$REMOTE_DATA_DIR/nginx/certs"
    "$REMOTE_DATA_DIR/prometheus"
    "$REMOTE_DATA_DIR/grafana"
)

for dir in "${expected_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
        log_debug "✓ Directory exists: $dir"
    else
        log_error "✗ Directory missing: $dir"
        exit 1
    fi
done

# Show directory permissions
log_step "Directory permissions summary"
log_info "Data directory structure:"
find "$REMOTE_DATA_DIR" -type d -exec ls -ld {} \; | while read -r line; do
    log_info "  $line"
done

log_success "Data directories preparation completed successfully"
log_info "Data directory: $REMOTE_DATA_DIR"
log_info "All services can now use persistent storage"