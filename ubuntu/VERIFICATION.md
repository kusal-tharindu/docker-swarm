# Docker Swarm Cluster Verification Guide

This guide helps you verify that your Docker Swarm cluster is working correctly after setup.

## 🔍 Quick Health Check

### 1. Check Cluster Status
```bash
# Connect to your manager node
ssh -i ~/.ssh/your-key.pem ubuntu@<manager-ip>

# Check swarm status
docker node ls
```
**Expected Output:**
```
ID                            HOSTNAME            STATUS              AVAILABILITY        MANAGER STATUS      ENGINE VERSION
abc123...def456 *             ip-192-168-1-9      Ready               Active              Leader              24.0.7
xyz789...uvw012               ip-192-168-1-10     Ready               Active                                  24.0.7
```

### 2. Check All Services
```bash
# List all running services
docker service ls
```
**Expected Output:**
```
NAME                       MODE         REPLICAS            IMAGE
monitoring_cadvisor        global       3/3                 gcr.io/cadvisor/cadvisor:latest
monitoring_grafana         replicated   1/1                 grafana/grafana:latest
monitoring_node-exporter   global       3/3                 prom/node-exporter:latest
monitoring_prom            replicated   1/1                 prom/prometheus:latest
nexus_nexus                replicated   1/1                 sonatype/nexus3:latest
nginx_nginx                replicated   1/1                 nginx:stable
```

### 3. Check Port Mappings
```bash
# Check which ports are exposed
docker service ls --format "table {{.Name}}\t{{.Ports}}"
```
**Expected Output:**
```
NAME                       PORTS
monitoring_grafana         *:3000->3000/tcp
monitoring_prom            *:9090->9090/tcp
nexus_nexus                *:8081->8081/tcp
nginx_nginx                *:80->80/tcp, *:443->443/tcp
```

## 🌐 Service Accessibility Tests

### 1. Test Nexus Repository
```bash
# From your local machine
curl -I http://<manager-ip>:8081
```
**Expected:** HTTP 200 response with HTML content

**Web Access:** Open http://<manager-ip>:8081 in browser
- Should see Nexus login page
- Default admin password is in container logs

### 2. Test Nginx Web Server
```bash
# From your local machine
curl http://<manager-ip>
```
**Expected:** "ok" response or default Nginx page

**Web Access:** Open http://<manager-ip> in browser
- Should see a simple web page

### 3. Test Grafana Dashboard
```bash
# From your local machine
curl -I http://<manager-ip>:3000
```
**Expected:** HTTP 200 response

**Web Access:** Open http://<manager-ip>:3000 in browser
- Login: admin/admin
- Should see Grafana dashboard

### 4. Test Prometheus Metrics
```bash
# From your local machine
curl http://<manager-ip>:9090
```
**Expected:** HTML page with Prometheus interface

**Web Access:** Open http://<manager-ip>:9090 in browser
- Should see Prometheus query interface

## 🔧 Detailed Verification Commands

### Check Container Health
```bash
# Check all running containers
docker ps

# Check specific service logs
docker service logs monitoring_grafana
docker service logs monitoring_prom
docker service logs nexus_nexus
docker service logs nginx_nginx
```

### Check Resource Usage
```bash
# Check system resources
docker stats --no-stream

# Check disk usage
df -h

# Check memory usage
free -h
```

### Check Network Connectivity
```bash
# Check if ports are listening
netstat -tulpn | grep -E ":(80|443|8081|3000|9090)"

# Test internal connectivity
docker exec $(docker ps -q --filter name=nginx) curl -s http://localhost
```

## 🚨 Troubleshooting Common Issues

### Issue: Services Not Accessible Externally

**Check Security Groups:**
- Ensure AWS security groups allow inbound traffic on ports 80, 443, 8081, 3000, 9090
- Verify source is 0.0.0.0/0 for testing

**Check Service Status:**
```bash
# Check if services are running
docker service ls

# Check service details
docker service inspect <service-name>
```

### Issue: Services Show 0/1 Replicas

**Check Logs:**
```bash
# Check service logs for errors
docker service logs <service-name>

# Check container logs
docker logs <container-id>
```

**Common Causes:**
- Missing data directories
- Permission issues
- Resource constraints

### Issue: Port Not Mapped

**Check Port Configuration:**
```bash
# Check service port mapping
docker service inspect <service-name> --format "{{.Spec.EndpointSpec.Ports}}"

# If empty, recreate service with explicit ports
docker service create --name <service-name> --publish <port>:<port> <image>
```

### Issue: Permission Denied

**Fix Data Directory Permissions:**
```bash
# Fix permissions for all data directories
sudo chmod -R 777 /opt/swarm-data/
```

## 📊 Monitoring Verification

### 1. Check Prometheus Targets
1. Open http://<manager-ip>:9090
2. Go to Status → Targets
3. Verify all targets are UP (green)

### 2. Check Grafana Data Sources
1. Open http://<manager-ip>:3000
2. Login with admin/admin
3. Go to Configuration → Data Sources
4. Verify Prometheus is configured and accessible

### 3. Check Metrics Collection
```bash
# Check if metrics are being collected
curl http://<manager-ip>:9090/api/v1/targets | jq '.data.activeTargets[].health'
```

## ✅ Success Checklist

- [ ] All nodes show "Ready" status in `docker node ls`
- [ ] All services show 1/1 or 3/3 replicas in `docker service ls`
- [ ] Port mappings are visible in service list
- [ ] Nexus is accessible at :8081
- [ ] Nginx is accessible at :80
- [ ] Grafana is accessible at :3000
- [ ] Prometheus is accessible at :9090
- [ ] No error messages in service logs
- [ ] All security group ports are open

## 🆘 Getting Help

If verification fails:

1. **Check Logs:** Look at `run.log` for setup errors
2. **Verify Configuration:** Ensure `.env` file is correct
3. **Check Prerequisites:** Verify all requirements are met
4. **Review Security Groups:** Ensure ports are open
5. **Check Resources:** Ensure instances have enough CPU/memory

## 🔄 Re-running Setup

If you need to start over:

```bash
# Clean up existing services
docker stack rm monitoring nexus nginx

# Leave swarm (on all nodes)
docker swarm leave --force

# Re-run setup
./run_all.sh
```

## 📁 File Structure

```
ubuntu/
├── README.md              # Detailed technical documentation
├── SETUP.md               # Setup guide
├── VERIFICATION.md        # This verification guide
├── REFACTORING_SUMMARY.md # Refactoring details
├── run_all.sh             # Main setup script
├── verify_setup.sh        # Automated verification script
├── env.example            # Configuration template
├── lib/                   # Shared libraries
├── scripts/               # Setup scripts
└── stacks/                # Docker Compose stacks
```

---

**Need More Help?** Check the setup guide or open an issue in this repository.
