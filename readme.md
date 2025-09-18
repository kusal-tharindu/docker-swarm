Docker Swarm Automated Setup (Ubuntu)

Quick start

1) Copy env template and edit values
   cp ubuntu/.env.example ubuntu/.env
   vim ubuntu/.env

2) Run orchestrator from your machine with SSH access
   bash ubuntu/run_all.sh

What it does

- Installs Docker on manager and worker
- Initializes Swarm on manager and joins worker
- Deploys stacks:
  - Nexus 3 (as artifact repo, can host Docker registry)
  - Nginx (ingress placeholder on ports 80/443)
  - Monitoring: Prometheus, Grafana, cAdvisor, Node Exporter

Requirements

- SSH access to both nodes with sudo rights
- Ports open between nodes: 2377/tcp, 7946/tcp+udp, 4789/udp
- Your machine has ssh and rsync

Next steps

- Configure Nexus repositories via UI at http://<MANAGER_IP>:8081
- Add routing rules to Nginx as you add services
 