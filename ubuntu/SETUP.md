# Docker Swarm Cluster Setup Guide

This guide will help you set up a complete Docker Swarm cluster with Nexus, Nginx, Prometheus, and Grafana on AWS EC2 instances.

## 🏗️ Architecture Overview

- **1 Manager Node**: Controls the swarm and runs all services
- **Multiple Worker Nodes**: Join the swarm for distributed workloads
- **Services Deployed**:
  - Nexus Repository (Private Docker registry)
  - Nginx (Ingress and load balancing)
  - Prometheus + Grafana (Monitoring stack)
  - cAdvisor + Node Exporter (Metrics collection)

## 📋 Prerequisites

### AWS EC2 Instances
- **Manager Node**: 1x EC2 instance (t3.medium or larger recommended)
- **Worker Nodes**: 1+ EC2 instances (t3.small or larger)
- **Security Groups**: Allow SSH (22), HTTP (80), HTTPS (443), and custom ports (8081, 3000, 9090)
- **Key Pair**: Download your `.pem` file for SSH access

### Local Machine Requirements
- SSH client
- Git (to clone this repository)
- Basic terminal/command line knowledge

## 🚀 Quick Setup (5 Steps)

### Step 1: Launch EC2 Instances
1. Launch EC2 instances in the same VPC and subnet
2. Note down the **Public IPs** and **Private IPs** of all instances
3. Download your `.pem` key file to `~/.ssh/` directory

### Step 2: Configure SSH Access
On each EC2 instance, run these commands to enable passwordless sudo:

```bash
# Connect to each instance
ssh -i ~/.ssh/your-key.pem ubuntu@<instance-public-ip>

# Enable passwordless sudo
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ubuntu
sudo chmod 440 /etc/sudoers.d/ubuntu
```

### Step 3: Clone and Configure
```bash
# Clone this repository
git clone <your-github-repo-url>
cd docker-swarm/ubuntu

# Copy and edit the environment file
cp env.example .env
```

### Step 4: Edit Configuration File
Open `.env` file and update these values:

```bash
# SSH Configuration
SSH_USER=ubuntu
SSH_PRIVATE_KEY=~/.ssh/your-key.pem

# Instance IPs (replace with your actual IPs)
MANAGER_HOST=3.91.14.150
WORKER_HOSTS=10.0.1.100,10.0.1.101

# Manager's private IP for swarm communication
MANAGER_ADVERTISE_ADDR=10.0.1.50

# Service Ports (optional - defaults are fine)
NEXUS_PORT=8081
GRAFANA_PORT=3000
PROMETHEUS_PORT=9090
NGINX_HTTP_PORT=80
NGINX_HTTPS_PORT=443
```

### Step 5: Run Automated Setup
```bash
# Make scripts executable
chmod +x run_all.sh scripts/*.sh

# Run the complete setup (this will take 5-10 minutes)
./run_all.sh
```

## ✅ What the Setup Does

The automated script will:
1. **Install Docker** on all nodes
2. **Initialize Swarm** on the manager node
3. **Join workers** to the swarm
4. **Create data directories** for persistent storage
5. **Deploy all services** (Nexus, Nginx, Prometheus, Grafana)
6. **Configure networking** for external access

## 🌐 Access Your Services

After setup completes, you can access:

- **Nexus Repository**: http://your-manager-ip:8081
- **Nginx Web Server**: http://your-manager-ip
- **Grafana Dashboard**: http://your-manager-ip:3000 (admin/admin)
- **Prometheus Metrics**: http://your-manager-ip:9090

## 🔧 Troubleshooting

### Common Issues

**SSH Connection Failed**
- Verify your `.pem` file path and permissions
- Check security group allows SSH (port 22)
- Ensure instance is running

**Services Not Accessible**
- Check security groups allow required ports
- Verify services are running: `docker service ls`
- Check logs: `docker service logs <service-name>`

**Permission Denied**
- Ensure passwordless sudo is configured
- Check file permissions: `chmod +x scripts/*.sh`

### Getting Help

If you encounter issues:
1. Check the setup logs in `run.log`
2. Verify your `.env` configuration
3. Ensure all prerequisites are met
4. Check AWS security group settings

## 📁 File Structure

```
ubuntu/
├── README.md              # Detailed technical documentation
├── SETUP.md               # This setup guide
├── VERIFICATION.md        # Verification guide
├── REFACTORING_SUMMARY.md # Refactoring details
├── .env                   # Your configuration file
├── run_all.sh             # Main setup script
├── verify_setup.sh        # Verification script
├── env.example            # Configuration template
├── lib/                   # Shared libraries
│   ├── logger.sh          # Logging system
│   ├── config.sh          # Configuration management
│   └── utils.sh           # Utility functions
├── scripts/
│   ├── install_docker.sh  # Docker installation
│   ├── swarm_init.sh      # Swarm initialization
│   ├── swarm_join.sh      # Worker joining
│   └── prepare_data_dirs.sh # Data directory setup
└── stacks/
    ├── nexus/             # Nexus repository stack
    ├── nginx/             # Nginx ingress stack
    └── monitoring/        # Prometheus + Grafana stack
```

## 🎯 Next Steps

1. **Verify Setup**: Run the verification script (see VERIFICATION.md)
2. **Configure Monitoring**: Set up Grafana dashboards
3. **Use Nexus**: Push/pull Docker images to your private registry
4. **Scale Services**: Add more worker nodes as needed

## 🔒 Security Notes

- Change default passwords in production
- Configure proper SSL/TLS certificates
- Set up proper firewall rules
- Regular security updates recommended

---

**Need Help?** Check the verification guide or open an issue in this repository.
