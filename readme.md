# Docker Swarm Automated Setup

A complete Docker Swarm cluster setup with Nexus, Nginx, Prometheus, and Grafana for AWS EC2 instances.

## 📚 Documentation

- **[ubuntu/SETUP.md](ubuntu/SETUP.md)** - Complete setup guide for non-technical users
- **[ubuntu/VERIFICATION.md](ubuntu/VERIFICATION.md)** - How to verify everything is working correctly
- **[ubuntu/README.md](ubuntu/README.md)** - Detailed technical documentation

## 🚀 Quick Start

1. **Navigate to ubuntu directory**:
   ```bash
   cd ubuntu
   ```

2. **Setup**: Follow the [SETUP.md](ubuntu/SETUP.md) guide
3. **Verify**: Run the verification script:
   ```bash
   ./verify_setup.sh
   ```

## 🏗️ What It Deploys

- **Docker Swarm Cluster** (1 manager + multiple workers)
- **Nexus Repository** - Private Docker registry
- **Nginx Ingress** - Load balancer and reverse proxy
- **Prometheus + Grafana** - Monitoring and observability
- **cAdvisor + Node Exporter** - Container and host metrics

## 🌐 Access Your Services

After setup, access your services at:
- **Nexus**: http://your-manager-ip:8081
- **Nginx**: http://your-manager-ip
- **Grafana**: http://your-manager-ip:3000 (admin/admin)
- **Prometheus**: http://your-manager-ip:9090

## 📁 Project Structure

```
docker-swarm/
├── readme.md             # This file
└── ubuntu/               # Main project directory
    ├── README.md         # Detailed technical documentation
    ├── SETUP.md          # Complete setup guide
    ├── VERIFICATION.md   # Verification guide
    ├── REFACTORING_SUMMARY.md # Refactoring details
    ├── verify_setup.sh   # Automated verification script
    ├── run_all.sh        # Main setup script
    ├── env.example       # Environment template
    ├── lib/              # Shared libraries
    ├── scripts/          # Setup scripts
    └── stacks/           # Docker Compose stacks
```

## 🔧 Requirements

- AWS EC2 instances (Ubuntu 20.04+)
- SSH access with sudo rights
- Security groups allowing required ports
- Basic command line knowledge

## 🆘 Need Help?

1. Check the [ubuntu/SETUP.md](ubuntu/SETUP.md) for detailed instructions
2. Run `cd ubuntu && ./verify_setup.sh` to diagnose issues
3. Review [ubuntu/VERIFICATION.md](ubuntu/VERIFICATION.md) for troubleshooting
4. Open an issue in this repository
 

 docker-swarm/
├── readme.md                    # Main project overview
└── ubuntu/                      # Main project directory
    ├── README.md                # Detailed technical documentation
    ├── SETUP.md                 # Complete setup guide
    ├── VERIFICATION.md          # Verification guide
    ├── REFACTORING_SUMMARY.md   # Refactoring details
    ├── run_all.sh               # Main setup orchestrator
    ├── verify_setup.sh          # Verification script
    ├── env.example              # Configuration template
    ├── .env                     # Your configuration file
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