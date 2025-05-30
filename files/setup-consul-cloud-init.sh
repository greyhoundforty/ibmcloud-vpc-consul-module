#!/bin/bash
set -e

# This script is executed by cloud-init on every instance boot
# It performs any dynamic configuration that wasn't done during image build

CONSUL_CONFIG_DIR="/opt/consul/config"
CONSUL_LOG_FILE="/var/log/consul-setup.log"

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$CONSUL_LOG_FILE"
}

log "Starting Consul cloud-init setup..."

# Get instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/metadata/v1/instance/id 2>/dev/null || echo "unknown")
INSTANCE_NAME=$(curl -s http://169.254.169.254/metadata/v1/instance/name 2>/dev/null || hostname)
PRIVATE_IP=$(curl -s http://169.254.169.254/metadata/v1/instance/network_interfaces/0/ipv4/address 2>/dev/null || hostname -I | awk '{print $1}')

log "Instance ID: $INSTANCE_ID"
log "Instance Name: $INSTANCE_NAME"
log "Private IP: $PRIVATE_IP"

# Wait for Consul service to be available
log "Waiting for Consul service to be ready..."
sleep 30

# Check if Consul is running
if systemctl is-active --quiet consul; then
    log "Consul service is running"
    
    # Wait for Consul to be responsive
    for i in {1..30}; do
        if consul version >/dev/null 2>&1; then
            log "Consul is responsive"
            break
        fi
        log "Waiting for Consul to become responsive... (attempt $i/30)"
        sleep 10
    done
    
    # Log cluster status
    consul members 2>/dev/null | tee -a "$CONSUL_LOG_FILE" || log "Unable to get cluster members"
    
else
    log "ERROR: Consul service is not running"
    systemctl status consul | tee -a "$CONSUL_LOG_FILE"
    exit 1
fi

# Set up log rotation for Consul
cat > /etc/logrotate.d/consul << 'EOF'
/var/log/consul/*.log {
    daily
    missingok
    rotate 30
    compress
    notifempty
    create 0644 consul consul
    postrotate
        systemctl reload consul > /dev/null 2>&1 || true
    endscript
}
EOF

# Ensure proper file permissions
chown -R consul:consul /opt/consul
chmod -R 755 /opt/consul/bin
chmod 644 /opt/consul/config/*.hcl

log "Consul cloud-init setup completed successfully"