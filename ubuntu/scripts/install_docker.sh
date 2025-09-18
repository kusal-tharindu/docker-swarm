#!/bin/bash

# Docker Installation Script
# Installs Docker on Ubuntu/Debian systems with comprehensive error handling

set -euo pipefail

# Load logging library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/logger.sh"

# Initialize logging
init_logging

log_section "Docker Installation"

# Check if Docker is already installed
if command -v docker >/dev/null 2>&1; then
    local docker_version=$(docker --version 2>/dev/null || echo "unknown")
    log_info "Docker is already installed: $docker_version"
    
    # Check if Docker daemon is running
    if docker info >/dev/null 2>&1; then
        log_success "Docker daemon is running"
        exit 0
    else
        log_warn "Docker is installed but daemon is not running"
    fi
fi

# Update package index
log_step "Updating package index"
if ! log_exec "Update apt package index" "sudo apt-get update -y"; then
    log_error "Failed to update package index"
    exit 1
fi

# Install prerequisites
log_step "Installing prerequisites"
local prerequisites=("ca-certificates" "curl" "gnupg" "lsb-release")
for package in "${prerequisites[@]}"; do
    if ! log_exec "Install $package" "sudo apt-get install -y $package"; then
        log_error "Failed to install $package"
        exit 1
    fi
done

# Create Docker keyring directory
log_step "Creating Docker keyring directory"
if ! log_exec "Create keyring directory" "sudo install -m 0755 -d /etc/apt/keyrings"; then
    log_error "Failed to create keyring directory"
    exit 1
fi

# Add Docker GPG key
log_step "Adding Docker GPG key"
if ! log_exec "Add Docker GPG key" "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg"; then
    log_error "Failed to add Docker GPG key"
    exit 1
fi

# Determine Ubuntu codename
log_step "Determining Ubuntu codename"
UB_CODENAME=""

if [[ -r /etc/os-release ]]; then
    source /etc/os-release || true
    UB_CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
fi

if [[ -z "$UB_CODENAME" ]]; then
    if command -v lsb_release >/dev/null 2>&1; then
        UB_CODENAME=$(lsb_release -cs 2>/dev/null || echo "jammy")
    else
        UB_CODENAME="jammy"  # Default fallback
        log_warn "Could not determine Ubuntu codename, using default: $UB_CODENAME"
    fi
fi

log_info "Using Ubuntu codename: $UB_CODENAME"

# Add Docker repository
log_step "Adding Docker repository"
local arch=$(dpkg --print-architecture)
local repo_line="deb [arch=$arch signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $UB_CODENAME stable"

if ! echo "$repo_line" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null; then
    log_error "Failed to add Docker repository"
    exit 1
fi

# Update package index again
log_step "Updating package index with Docker repository"
if ! log_exec "Update apt with Docker repo" "sudo apt-get update -y"; then
    log_error "Failed to update package index with Docker repository"
    exit 1
fi

# Install Docker packages
log_step "Installing Docker packages"
local docker_packages=(
    "docker-ce"
    "docker-ce-cli"
    "containerd.io"
    "docker-buildx-plugin"
    "docker-compose-plugin"
)

for package in "${docker_packages[@]}"; do
    if ! log_exec "Install $package" "sudo apt-get install -y $package"; then
        log_error "Failed to install $package"
        exit 1
    fi
done

# Enable and start Docker service
log_step "Enabling and starting Docker service"
if ! log_exec "Enable Docker service" "sudo systemctl enable docker"; then
    log_warn "Failed to enable Docker service"
fi

if ! log_exec "Start Docker service" "sudo systemctl start docker"; then
    log_error "Failed to start Docker service"
    exit 1
fi

# Add user to docker group
log_step "Adding user to docker group"
if ! log_exec "Add user to docker group" "sudo usermod -aG docker $USER"; then
    log_warn "Failed to add user to docker group"
fi

# Verify Docker installation
log_step "Verifying Docker installation"
if ! log_exec "Verify Docker version" "docker --version"; then
    log_error "Docker installation verification failed"
    exit 1
fi

if ! log_exec "Verify Docker daemon" "sudo docker info >/dev/null"; then
    log_error "Docker daemon verification failed"
    exit 1
fi

# Test Docker with a simple command
log_step "Testing Docker functionality"
if ! log_exec "Test Docker" "sudo docker run --rm hello-world >/dev/null"; then
    log_warn "Docker test failed, but installation may still be functional"
fi

log_success "Docker installation completed successfully"

# Show Docker information
log_info "Docker version: $(docker --version)"
log_info "Docker Compose version: $(docker compose version 2>/dev/null || echo 'Not available')"

log_info "Note: You may need to log out and log back in for group changes to take effect"