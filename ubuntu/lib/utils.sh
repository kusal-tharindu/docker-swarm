#!/bin/bash

# Docker Swarm Utilities
# Common utility functions used across all scripts

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if running as root
is_root() {
    [[ $EUID -eq 0 ]]
}

# Check if running on supported OS
check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                log_debug "Detected OS: $PRETTY_NAME"
                return 0
                ;;
            *)
                log_warn "Unsupported OS: $PRETTY_NAME"
                return 1
                ;;
        esac
    else
        log_error "Cannot determine OS"
        return 1
    fi
}

# Wait for service to be ready
wait_for_service() {
    local service_name="$1"
    local max_attempts="${2:-30}"
    local delay="${3:-2}"
    
    log_info "Waiting for $service_name to be ready..."
    
    for ((i=1; i<=max_attempts; i++)); do
        if docker service ls --format "{{.Name}}" | grep -q "^$service_name$"; then
            local replicas=$(docker service ls --format "{{.Replicas}}" --filter name="$service_name")
            if [[ "$replicas" == *"1/1"* ]] || [[ "$replicas" == *"3/3"* ]]; then
                log_success "$service_name is ready"
                return 0
            fi
        fi
        
        log_debug "Attempt $i/$max_attempts: $service_name not ready yet"
        sleep "$delay"
    done
    
    log_error "$service_name failed to become ready after $max_attempts attempts"
    return 1
}

# Check if port is in use
is_port_in_use() {
    local port="$1"
    
    if command_exists netstat; then
        netstat -tuln | grep -q ":$port "
    elif command_exists ss; then
        ss -tuln | grep -q ":$port "
    else
        log_warn "Cannot check port usage (netstat/ss not available)"
        return 1
    fi
}

# Get available port
get_available_port() {
    local start_port="${1:-8000}"
    local end_port="${2:-9000}"
    
    for ((port=start_port; port<=end_port; port++)); do
        if ! is_port_in_use "$port"; then
            echo "$port"
            return 0
        fi
    done
    
    log_error "No available ports found in range $start_port-$end_port"
    return 1
}

# Create directory with proper permissions
create_directory() {
    local dir_path="$1"
    local permissions="${2:-755}"
    local owner="${3:-}"
    
    if [[ ! -d "$dir_path" ]]; then
        log_info "Creating directory: $dir_path"
        if mkdir -p "$dir_path"; then
            chmod "$permissions" "$dir_path"
            if [[ -n "$owner" ]]; then
                chown "$owner" "$dir_path"
            fi
            log_success "Directory created: $dir_path"
            return 0
        else
            log_error "Failed to create directory: $dir_path"
            return 1
        fi
    else
        log_debug "Directory already exists: $dir_path"
        return 0
    fi
}

# Backup file
backup_file() {
    local file_path="$1"
    local backup_dir="${2:-$(dirname "$file_path")/backups}"
    
    if [[ -f "$file_path" ]]; then
        local backup_name="$(basename "$file_path").$(date +%Y%m%d_%H%M%S).bak"
        local backup_path="$backup_dir/$backup_name"
        
        create_directory "$backup_dir"
        
        if cp "$file_path" "$backup_path"; then
            log_info "File backed up: $file_path -> $backup_path"
            return 0
        else
            log_error "Failed to backup file: $file_path"
            return 1
        fi
    else
        log_warn "File not found for backup: $file_path"
        return 1
    fi
}

# Generate random password
generate_password() {
    local length="${1:-16}"
    
    if command_exists openssl; then
        openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
    elif command_exists pwgen; then
        pwgen -s "$length" 1
    else
        # Fallback to /dev/urandom
        tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
    fi
}

# Test network connectivity
test_connectivity() {
    local host="$1"
    local port="${2:-80}"
    local timeout="${3:-5}"
    
    if command_exists nc; then
        nc -z -w"$timeout" "$host" "$port" 2>/dev/null
    elif command_exists telnet; then
        timeout "$timeout" telnet "$host" "$port" </dev/null >/dev/null 2>&1
    else
        log_warn "Cannot test connectivity (nc/telnet not available)"
        return 1
    fi
}

# Get system information
get_system_info() {
    log_section "System Information"
    
    # OS Information
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        log_info "OS: $PRETTY_NAME"
        log_info "Version: $VERSION"
    fi
    
    # Kernel
    log_info "Kernel: $(uname -r)"
    
    # Architecture
    log_info "Architecture: $(uname -m)"
    
    # Memory
    if command_exists free; then
        local memory=$(free -h | awk '/^Mem:/ {print $2}')
        log_info "Memory: $memory"
    fi
    
    # Disk space
    if command_exists df; then
        local disk=$(df -h / | awk 'NR==2 {print $4}')
        log_info "Available disk space: $disk"
    fi
    
    # Docker version
    if command_exists docker; then
        local docker_version=$(docker --version 2>/dev/null || echo "Not installed")
        log_info "Docker: $docker_version"
    fi
}

# Cleanup function
cleanup() {
    local exit_code=$1
    
    log_info "Cleaning up..."
    
    # Remove temporary files
    if [[ -d "/tmp/docker-swarm-tmp" ]]; then
        rm -rf "/tmp/docker-swarm-tmp"
        log_debug "Removed temporary directory"
    fi
    
    # Log cleanup
    cleanup_logs
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "Cleanup completed successfully"
    else
        log_warn "Cleanup completed with exit code: $exit_code"
    fi
}

# Setup signal handlers
setup_signal_handlers() {
    trap 'cleanup $?' EXIT
    trap 'log_error "Script interrupted by user"; exit 130' INT TERM
}

# Check prerequisites
check_prerequisites() {
    local missing_tools=()
    
    log_info "Checking prerequisites..."
    
    # Required tools
    local required_tools=("ssh" "rsync" "curl")
    
    for tool in "${required_tools[@]}"; do
        if command_exists "$tool"; then
            log_debug "Found: $tool"
        else
            missing_tools+=("$tool")
            log_error "Missing required tool: $tool"
        fi
    done
    
    # Optional tools
    local optional_tools=("jq" "netstat" "ss" "nc" "telnet")
    
    for tool in "${optional_tools[@]}"; do
        if command_exists "$tool"; then
            log_debug "Found optional tool: $tool"
        else
            log_warn "Optional tool not found: $tool"
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install the missing tools and try again"
        return 1
    fi
    
    log_success "All prerequisites met"
    return 0
}

# Export functions
export -f command_exists is_root check_os wait_for_service is_port_in_use
export -f get_available_port create_directory backup_file generate_password
export -f test_connectivity get_system_info cleanup setup_signal_handlers
export -f check_prerequisites
