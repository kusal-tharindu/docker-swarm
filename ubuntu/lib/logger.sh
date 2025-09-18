#!/bin/bash

# Docker Swarm Setup Logger
# Provides comprehensive logging functionality for all scripts

# Log levels
readonly LOG_LEVEL_ERROR=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_INFO=3
readonly LOG_LEVEL_DEBUG=4

# Default log level
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# Log file paths
LOG_DIR="${LOG_DIR:-/tmp/docker-swarm-logs}"
MAIN_LOG_FILE="${LOG_DIR}/setup.log"
ERROR_LOG_FILE="${LOG_DIR}/errors.log"
DEBUG_LOG_FILE="${LOG_DIR}/debug.log"

# Colors for console output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Initialize logging
init_logging() {
    # Create log directory
    mkdir -p "$LOG_DIR"
    
    # Initialize log files
    echo "=== Docker Swarm Setup Started at $(date) ===" > "$MAIN_LOG_FILE"
    echo "=== Error Log Started at $(date) ===" > "$ERROR_LOG_FILE"
    echo "=== Debug Log Started at $(date) ===" > "$DEBUG_LOG_FILE"
    
    # Log initialization
    log_info "Logging initialized. Log directory: $LOG_DIR"
}

# Log with timestamp and level
_log() {
    local level="$1"
    local message="$2"
    local color="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] [$level] $message"
    
    # Write to main log file
    echo "$log_entry" >> "$MAIN_LOG_FILE"
    
    # Write to specific log files based on level
    case "$level" in
        "ERROR")
            echo "$log_entry" >> "$ERROR_LOG_FILE"
            ;;
        "DEBUG")
            echo "$log_entry" >> "$DEBUG_LOG_FILE"
            ;;
    esac
    
    # Console output with colors
    if [[ -t 1 ]]; then
        echo -e "${color}[$timestamp] [$level]${NC} $message"
    else
        echo "$log_entry"
    fi
}

# Log functions
log_error() {
    if [[ $LOG_LEVEL -ge $LOG_LEVEL_ERROR ]]; then
        _log "ERROR" "$1" "$RED"
    fi
}

log_warn() {
    if [[ $LOG_LEVEL -ge $LOG_LEVEL_WARN ]]; then
        _log "WARN" "$1" "$YELLOW"
    fi
}

log_info() {
    if [[ $LOG_LEVEL -ge $LOG_LEVEL_INFO ]]; then
        _log "INFO" "$1" "$GREEN"
    fi
}

log_debug() {
    if [[ $LOG_LEVEL -ge $LOG_LEVEL_DEBUG ]]; then
        _log "DEBUG" "$1" "$CYAN"
    fi
}

# Special logging functions
log_success() {
    _log "SUCCESS" "$1" "$GREEN"
}

log_step() {
    _log "STEP" "$1" "$BLUE"
}

log_section() {
    echo
    _log "SECTION" "=== $1 ===" "$PURPLE"
    echo
}

# Command execution with logging
log_exec() {
    local description="$1"
    local command="$2"
    local log_output="${3:-true}"
    
    log_info "Executing: $description"
    log_debug "Command: $command"
    
    if [[ "$log_output" == "true" ]]; then
        if eval "$command" 2>&1 | while IFS= read -r line; do
            log_debug "OUTPUT: $line"
        done; then
            log_success "Completed: $description"
            return 0
        else
            local exit_code=$?
            log_error "Failed: $description (exit code: $exit_code)"
            return $exit_code
        fi
    else
        if eval "$command" >/dev/null 2>&1; then
            log_success "Completed: $description"
            return 0
        else
            local exit_code=$?
            log_error "Failed: $description (exit code: $exit_code)"
            return $exit_code
        fi
    fi
}

# SSH command execution with logging
log_ssh_exec() {
    local host="$1"
    local description="$2"
    local command="$3"
    local ssh_opts="${4:-}"
    
    log_info "SSH to $host: $description"
    log_debug "SSH Command: ssh $ssh_opts $host '$command'"
    
    if ssh $ssh_opts "$host" "$command" 2>&1 | while IFS= read -r line; do
        log_debug "SSH OUTPUT: $line"
    done; then
        log_success "SSH completed: $description on $host"
        return 0
    else
        local exit_code=$?
        log_error "SSH failed: $description on $host (exit code: $exit_code)"
        return $exit_code
    fi
}

# Error handling
handle_error() {
    local exit_code=$1
    local error_message="${2:-Unknown error occurred}"
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "$error_message (exit code: $exit_code)"
        log_error "Check logs in $LOG_DIR for details"
        exit $exit_code
    fi
}

# Cleanup function
cleanup_logs() {
    if [[ "${CLEANUP_LOGS:-true}" == "true" ]]; then
        log_info "Cleaning up old log files..."
        find "$LOG_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null || true
    fi
}

# Log summary
log_summary() {
    local total_errors=$(grep -c "ERROR" "$ERROR_LOG_FILE" 2>/dev/null || echo "0")
    local total_warnings=$(grep -c "WARN" "$MAIN_LOG_FILE" 2>/dev/null || echo "0")
    
    log_section "Setup Summary"
    log_info "Total errors: $total_errors"
    log_info "Total warnings: $total_warnings"
    log_info "Log files location: $LOG_DIR"
    
    if [[ $total_errors -gt 0 ]]; then
        log_warn "Setup completed with errors. Check $ERROR_LOG_FILE for details."
        return 1
    else
        log_success "Setup completed successfully!"
        return 0
    fi
}

# Export functions for use in other scripts
export -f init_logging log_error log_warn log_info log_debug log_success log_step log_section
export -f log_exec log_ssh_exec handle_error cleanup_logs log_summary
