#!/bin/bash

# Docker Swarm Configuration Management
# Handles environment variables, validation, and configuration

# Configuration file paths
CONFIG_DIR="${CONFIG_DIR:-$(dirname "$0")/../config}"
ENV_FILE="${ENV_FILE:-$(dirname "$0")/../.env}"
ENV_EXAMPLE_FILE="${ENV_EXAMPLE_FILE:-$(dirname "$0")/../env.example}"

# Default configuration values
declare -A DEFAULT_CONFIG=(
    ["SSH_USER"]="ubuntu"
    ["SSH_PRIVATE_KEY"]="~/.ssh/aws-swarm.pem"
    ["MANAGER_HOST"]=""
    ["WORKER_HOSTS"]=""
    ["MANAGER_ADVERTISE_ADDR"]=""
    ["SWARM_AUTOLOCK"]="true"
    ["OVERLAY_NETWORK_NAME"]="public"
    ["OVERLAY_NETWORK_ENCRYPTED"]="true"
    ["DEPLOY_NEXUS"]="true"
    ["DEPLOY_NGINX"]="true"
    ["DEPLOY_MONITORING"]="true"
    ["REMOTE_SETUP_DIR"]="/opt/swarm-setup"
    ["REMOTE_DATA_DIR"]="/opt/swarm-data"
    ["NEXUS_PORT"]="8081"
    ["NGINX_HTTP_PORT"]="80"
    ["NGINX_HTTPS_PORT"]="443"
    ["GRAFANA_PORT"]="3000"
    ["PROMETHEUS_PORT"]="9090"
    ["GRAFANA_ADMIN_USER"]="admin"
    ["GRAFANA_ADMIN_PASSWORD"]="admin"
    ["LOG_LEVEL"]="3"
)

# Load configuration from environment file
load_config() {
    local env_file="$1"
    
    if [[ -f "$env_file" ]]; then
        log_info "Loading configuration from $env_file"
        
        # Source the environment file
        set -a  # automatically export all variables
        source "$env_file"
        set +a
        
        log_debug "Configuration loaded successfully"
        return 0
    else
        log_error "Configuration file not found: $env_file"
        return 1
    fi
}

# Validate required configuration
validate_config() {
    local errors=0
    
    log_info "Validating configuration..."
    
    # Required fields
    local required_fields=("SSH_USER" "SSH_PRIVATE_KEY" "MANAGER_HOST" "MANAGER_ADVERTISE_ADDR")
    
    for field in "${required_fields[@]}"; do
        if [[ -z "${!field:-}" ]]; then
            log_error "Required configuration missing: $field"
            ((errors++))
        else
            log_debug "Configuration valid: $field=${!field}"
        fi
    done
    
    # Validate SSH private key file
    if [[ -n "${SSH_PRIVATE_KEY:-}" ]]; then
        local key_path="${SSH_PRIVATE_KEY/#\~/$HOME}"
        if [[ ! -f "$key_path" ]]; then
            log_error "SSH private key file not found: $key_path"
            ((errors++))
        else
            log_debug "SSH private key found: $key_path"
        fi
    fi
    
    # Validate IP addresses
    if [[ -n "${MANAGER_HOST:-}" ]]; then
        if ! validate_ip_or_hostname "$MANAGER_HOST"; then
            log_error "Invalid manager host: $MANAGER_HOST"
            ((errors++))
        fi
    fi
    
    if [[ -n "${MANAGER_ADVERTISE_ADDR:-}" ]]; then
        if ! validate_ip "$MANAGER_ADVERTISE_ADDR"; then
            log_error "Invalid manager advertise address: $MANAGER_ADVERTISE_ADDR"
            ((errors++))
        fi
    fi
    
    # Validate ports
    local port_fields=("NEXUS_PORT" "NGINX_HTTP_PORT" "NGINX_HTTPS_PORT" "GRAFANA_PORT" "PROMETHEUS_PORT")
    for field in "${port_fields[@]}"; do
        if [[ -n "${!field:-}" ]]; then
            if ! validate_port "${!field}"; then
                log_error "Invalid port for $field: ${!field}"
                ((errors++))
            fi
        fi
    done
    
    if [[ $errors -gt 0 ]]; then
        log_error "Configuration validation failed with $errors errors"
        return 1
    else
        log_success "Configuration validation passed"
        return 0
    fi
}

# Validate IP address or hostname
validate_ip_or_hostname() {
    local input="$1"
    
    # Check if it's a valid IP address
    if validate_ip "$input"; then
        return 0
    fi
    
    # Check if it's a valid hostname
    if [[ "$input" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        return 0
    fi
    
    return 1
}

# Validate IP address
validate_ip() {
    local ip="$1"
    
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        local IFS='.'
        local -a ip_parts=($ip)
        
        for part in "${ip_parts[@]}"; do
            if [[ $part -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    fi
    
    return 1
}

# Validate port number
validate_port() {
    local port="$1"
    
    if [[ "$port" =~ ^[0-9]+$ ]] && [[ $port -ge 1 ]] && [[ $port -le 65535 ]]; then
        return 0
    fi
    
    return 1
}

# Set default values for missing configuration
set_defaults() {
    log_info "Setting default configuration values..."
    
    for key in "${!DEFAULT_CONFIG[@]}"; do
        if [[ -z "${!key:-}" ]]; then
            export "$key"="${DEFAULT_CONFIG[$key]}"
            log_debug "Set default for $key: ${DEFAULT_CONFIG[$key]}"
        fi
    done
}

# Generate configuration template
generate_config_template() {
    local output_file="$1"
    
    log_info "Generating configuration template: $output_file"
    
    cat > "$output_file" << 'EOF'
#!/bin/bash
# Docker Swarm Configuration File
# Copy this file to .env and update the values

############################
# SSH and nodes
############################
SSH_USER=ubuntu
SSH_PRIVATE_KEY=~/.ssh/aws-swarm.pem

# Manager and worker IPs or hostnames
MANAGER_HOST=<manager-public-ip>
WORKER_HOSTS=<worker1-public-ip>,<worker2-public-ip>

# Swarm advertise address (manager)
MANAGER_ADVERTISE_ADDR=<manager-private-ip> # e.g., 10.0.1.23

############################
# Swarm settings (secure defaults)
############################
SWARM_AUTOLOCK=true
OVERLAY_NETWORK_NAME=public
OVERLAY_NETWORK_ENCRYPTED=true

############################
# Stacks toggles
############################
DEPLOY_NEXUS=true
DEPLOY_NGINX=true
DEPLOY_MONITORING=true

############################
# Paths on remote nodes (will be created)
############################
REMOTE_SETUP_DIR=/opt/swarm-setup
REMOTE_DATA_DIR=/opt/swarm-data

############################
# Published ports
############################
NEXUS_PORT=8081
NGINX_HTTP_PORT=80
NGINX_HTTPS_PORT=443
GRAFANA_PORT=3000
PROMETHEUS_PORT=9090

############################
# Grafana admin
############################
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin

############################
# Logging
############################
LOG_LEVEL=3  # 1=ERROR, 2=WARN, 3=INFO, 4=DEBUG
EOF

    chmod +x "$output_file"
    log_success "Configuration template generated: $output_file"
}

# Display current configuration
show_config() {
    log_section "Current Configuration"
    
    local config_vars=(
        "SSH_USER" "SSH_PRIVATE_KEY" "MANAGER_HOST" "WORKER_HOSTS"
        "MANAGER_ADVERTISE_ADDR" "SWARM_AUTOLOCK" "OVERLAY_NETWORK_NAME"
        "DEPLOY_NEXUS" "DEPLOY_NGINX" "DEPLOY_MONITORING"
        "REMOTE_SETUP_DIR" "REMOTE_DATA_DIR"
        "NEXUS_PORT" "NGINX_HTTP_PORT" "NGINX_HTTPS_PORT"
        "GRAFANA_PORT" "PROMETHEUS_PORT" "LOG_LEVEL"
    )
    
    for var in "${config_vars[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            log_info "$var=${!var}"
        fi
    done
}

# Export functions
export -f load_config validate_config validate_ip_or_hostname validate_ip validate_port
export -f set_defaults generate_config_template show_config
