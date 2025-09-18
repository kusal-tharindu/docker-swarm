#!/bin/bash

# Docker Swarm Cluster Verification Script
# This script checks if all services are working correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f "env" ]; then
    source env
elif [ -f ".env" ]; then
    source .env
else
    echo -e "${RED}Error: No environment file found. Please run from the ubuntu directory.${NC}"
    exit 1
fi

echo -e "${BLUE}=== Docker Swarm Cluster Verification ===${NC}"
echo

# Check if we can connect to manager
echo -e "${YELLOW}1. Checking connection to manager node...${NC}"
SSH_OPTS="-o StrictHostKeyChecking=no -i $SSH_PRIVATE_KEY"
if ssh $SSH_OPTS "$SSH_USER@$MANAGER_HOST" "echo 'Connection successful'" 2>/dev/null; then
    echo -e "${GREEN}✓ Connected to manager node${NC}"
else
    echo -e "${RED}✗ Cannot connect to manager node${NC}"
    echo "Please check your SSH configuration and .env file"
    exit 1
fi

echo

# Check swarm status
echo -e "${YELLOW}2. Checking swarm status...${NC}"
ssh $SSH_OPTS "$SSH_USER@$MANAGER_HOST" "docker node ls" 2>/dev/null | while read line; do
    if [[ $line == *"Ready"* ]]; then
        echo -e "${GREEN}✓ $line${NC}"
    else
        echo -e "${RED}✗ $line${NC}"
    fi
done

echo

# Check services
echo -e "${YELLOW}3. Checking services...${NC}"
ssh $SSH_OPTS "$SSH_USER@$MANAGER_HOST" "docker service ls" 2>/dev/null | while read line; do
    if [[ $line == *"1/1"* ]] || [[ $line == *"3/3"* ]]; then
        echo -e "${GREEN}✓ $line${NC}"
    else
        echo -e "${RED}✗ $line${NC}"
    fi
done

echo

# Check port mappings
echo -e "${YELLOW}4. Checking port mappings...${NC}"
ssh $SSH_OPTS "$SSH_USER@$MANAGER_HOST" "docker service ls --format 'table {{.Name}}\t{{.Ports}}'" 2>/dev/null | while read line; do
    if [[ $line == *"->"* ]]; then
        echo -e "${GREEN}✓ $line${NC}"
    else
        echo -e "${YELLOW}⚠ $line${NC}"
    fi
done

echo

# Test service accessibility
echo -e "${YELLOW}5. Testing service accessibility...${NC}"

# Test Nexus
if curl -s --connect-timeout 5 "http://$MANAGER_HOST:8081" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Nexus (port 8081) is accessible${NC}"
else
    echo -e "${RED}✗ Nexus (port 8081) is not accessible${NC}"
fi

# Test Nginx
if curl -s --connect-timeout 5 "http://$MANAGER_HOST" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Nginx (port 80) is accessible${NC}"
else
    echo -e "${RED}✗ Nginx (port 80) is not accessible${NC}"
fi

# Test Grafana
if curl -s --connect-timeout 5 "http://$MANAGER_HOST:3000" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Grafana (port 3000) is accessible${NC}"
else
    echo -e "${RED}✗ Grafana (port 3000) is not accessible${NC}"
fi

# Test Prometheus
if curl -s --connect-timeout 5 "http://$MANAGER_HOST:9090" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Prometheus (port 9090) is accessible${NC}"
else
    echo -e "${RED}✗ Prometheus (port 9090) is not accessible${NC}"
fi

echo

# Summary
echo -e "${BLUE}=== Verification Summary ===${NC}"
echo -e "Manager IP: $MANAGER_HOST"
echo -e "Worker IPs: $WORKER_HOSTS"
echo
echo -e "${GREEN}Access your services:${NC}"
echo -e "  Nexus:      http://$MANAGER_HOST:8081"
echo -e "  Nginx:      http://$MANAGER_HOST"
echo -e "  Grafana:    http://$MANAGER_HOST:3000 (admin/admin)"
echo -e "  Prometheus: http://$MANAGER_HOST:9090"
echo

echo -e "${GREEN}Verification complete!${NC}"
