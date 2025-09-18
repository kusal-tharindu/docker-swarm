# Docker Swarm Automated Setup (Ubuntu)

A comprehensive, production-ready Docker Swarm cluster setup with automated deployment of Nexus, Nginx, Prometheus, and Grafana services.

## 🏗️ Architecture

- **Manager Node**: Controls the swarm and runs all services
- **Worker Nodes**: Join the swarm for distributed workloads
- **Services**: Nexus (registry), Nginx (ingress), Prometheus + Grafana (monitoring)
- **Logging**: Comprehensive logging system with multiple log levels
- **Error Handling**: Robust error handling and recovery mechanisms

## 📁 Project Structure

```
ubuntu/
├── README.md                 # This file
├── SETUP.md                 # Complete setup guide
├── VERIFICATION.md          # Verification guide
├── REFACTORING_SUMMARY.md   # Refactoring details
├── run_all.sh               # Main setup orchestrator
├── verify_setup.sh          # Comprehensive verification script
├── env.example              # Environment configuration template
├── lib/                     # Shared libraries
│   ├── logger.sh            # Logging system
│   ├── config.sh            # Configuration management
│   └── utils.sh             # Utility functions
├── scripts/                 # Setup scripts
│   ├── install_docker.sh    # Docker installation
│   ├── swarm_init.sh        # Swarm initialization
│   ├── swarm_join.sh        # Worker joining
│   └── prepare_data_dirs.sh # Data directory setup
└── stacks/                  # Docker Compose stacks
    ├── nexus/               # Nexus repository
    ├── nginx/               # Nginx ingress
    └── monitoring/          # Prometheus + Grafana
```

## 🚀 Quick Start

### 1. Prerequisites

- AWS EC2 instances (Ubuntu 20.04+)
- SSH access with sudo rights
- Security groups allowing required ports
- Basic command line knowledge

### 2. Configuration

```bash
# Copy and edit configuration
cp env.example .env
vim .env
```

Update the following values in `.env`:
- `MANAGER_HOST`: Your manager node's public IP
- `WORKER_HOSTS`: Comma-separated list of worker IPs
- `MANAGER_ADVERTISE_ADDR`: Manager's private IP
- `SSH_PRIVATE_KEY`: Path to your SSH key file

### 3. Run Setup

```bash
# Make scripts executable
chmod +x *.sh scripts/*.sh lib/*.sh

# Run the complete setup
./run_all.sh
```

### 4. Verify Setup

```bash
# Run comprehensive verification
./verify_setup.sh
```

## 🔧 Features

### Comprehensive Logging
- **Multiple Log Levels**: ERROR, WARN, INFO, DEBUG
- **Structured Logging**: Timestamps, levels, and context
- **Log Files**: Separate files for errors, debug, and main logs
- **Console Output**: Colored output for better readability

### Robust Error Handling
- **Validation**: Configuration and prerequisite validation
- **Recovery**: Automatic retry and recovery mechanisms
- **Cleanup**: Proper cleanup on failure
- **Signal Handling**: Graceful shutdown on interruption

### Configuration Management
- **Environment Variables**: Centralized configuration
- **Validation**: Comprehensive configuration validation
- **Defaults**: Sensible default values
- **Templates**: Easy-to-use configuration templates

### Service Management
- **Health Checks**: Service readiness verification
- **Port Mapping**: Automatic port configuration
- **Data Persistence**: Proper data directory setup
- **Security**: Secure defaults and permissions

## 📊 Monitoring and Logging

### Log Files
- **Main Log**: `/tmp/docker-swarm-logs/setup.log`
- **Error Log**: `/tmp/docker-swarm-logs/errors.log`
- **Debug Log**: `/tmp/docker-swarm-logs/debug.log`

### Log Levels
- **ERROR (1)**: Critical errors that stop execution
- **WARN (2)**: Warnings that don't stop execution
- **INFO (3)**: General information (default)
- **DEBUG (4)**: Detailed debugging information

### Service Monitoring
- **Prometheus**: Metrics collection at port 9090
- **Grafana**: Monitoring dashboards at port 3000
- **cAdvisor**: Container metrics collection
- **Node Exporter**: Host metrics collection

## 🌐 Service Access

After successful setup:

- **Nexus Repository**: http://your-manager-ip:8081
- **Nginx Web Server**: http://your-manager-ip
- **Grafana Dashboard**: http://your-manager-ip:3000 (admin/admin)
- **Prometheus Metrics**: http://your-manager-ip:9090

## 🔍 Troubleshooting

### Common Issues

**SSH Connection Failed**
```bash
# Check SSH key permissions
chmod 600 ~/.ssh/your-key.pem

# Test SSH connection
ssh -i ~/.ssh/your-key.pem ubuntu@your-manager-ip
```

**Services Not Accessible**
```bash
# Check service status
docker service ls

# Check service logs
docker service logs <service-name>

# Check port mappings
docker service inspect <service-name>
```

**Configuration Issues**
```bash
# Validate configuration
source lib/config.sh
validate_config

# Check environment variables
env | grep -E "(SSH_|MANAGER_|WORKER_)"
```

### Debug Mode

Run with debug logging:
```bash
LOG_LEVEL=4 ./run_all.sh
```

### Verification

Run comprehensive verification:
```bash
./verify_setup.sh
```

## 📝 Configuration Reference

### Required Variables
- `SSH_USER`: SSH username (default: ubuntu)
- `SSH_PRIVATE_KEY`: Path to SSH private key
- `MANAGER_HOST`: Manager node public IP
- `MANAGER_ADVERTISE_ADDR`: Manager node private IP

### Optional Variables
- `WORKER_HOSTS`: Comma-separated worker IPs
- `SWARM_AUTOLOCK`: Enable swarm autolock (default: true)
- `DEPLOY_NEXUS`: Deploy Nexus stack (default: true)
- `DEPLOY_NGINX`: Deploy Nginx stack (default: true)
- `DEPLOY_MONITORING`: Deploy monitoring stack (default: true)
- `LOG_LEVEL`: Logging level 1-4 (default: 3)

## 🔒 Security Considerations

- **SSH Keys**: Use proper SSH key authentication
- **Firewall**: Configure security groups appropriately
- **Passwords**: Change default passwords in production
- **TLS**: Configure SSL/TLS certificates for production
- **Updates**: Regular security updates recommended

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

- **Documentation**: Check the main README.md
- **Issues**: Open an issue in the repository
- **Logs**: Check log files for detailed error information
- **Verification**: Run `./verify_setup.sh` for diagnostics
