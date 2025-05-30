#!/bin/bash
set -e

# Default configuration
CONSUL_CONFIG_DIR="/opt/consul/config"
CONSUL_DATA_DIR="/opt/consul/data"
CONSUL_BIN="/opt/consul/bin/consul"

# Source environment variables if they exist
if [ -f /etc/environment ]; then
    set -a
    source /etc/environment
    set +a
fi

# Ensure data directory exists and has proper permissions
mkdir -p "$CONSUL_DATA_DIR"
chown consul:consul "$CONSUL_DATA_DIR"

# Check if configuration file exists
if [ ! -f "$CONSUL_CONFIG_DIR/consul.hcl" ]; then
    echo "ERROR: Consul configuration file not found at $CONSUL_CONFIG_DIR/consul.hcl"
    exit 1
fi

# Validate configuration
echo "Validating Consul configuration..."
"$CONSUL_BIN" validate "$CONSUL_CONFIG_DIR"

# Start Consul with configuration
echo "Starting Consul..."
exec "$CONSUL_BIN" agent -config-dir="$CONSUL_CONFIG_DIR"