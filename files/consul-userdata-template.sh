#!/bin/bash
set -e

# Variables from Terraform
CONSUL_DATACENTER="${consul_datacenter}"
CONSUL_ENCRYPT_KEY="${consul_encrypt_key}"
CONSUL_CLUSTER_SIZE="${consul_cluster_size}"
CONSUL_SERVER_INDEX="${consul_server_index}"
CONSUL_REGION="${consul_region}"
ENABLE_UI="${enable_ui}"
ENABLE_ACL="${enable_acl}"
ENABLE_TLS="${enable_tls}"
ACL_BOOTSTRAP_TOKEN="${acl_bootstrap_token}"

# Get instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/metadata/v1/instance/id)
INSTANCE_NAME=$(curl -s http://169.254.169.254/metadata/v1/instance/name)
PRIVATE_IP=$(curl -s http://169.254.169.254/metadata/v1/instance/network_interfaces/0/ipv4/address)

# Create Consul configuration
cat > /opt/consul/config/consul.hcl << EOF
datacenter = "$CONSUL_DATACENTER"
data_dir = "/opt/consul/data"
log_level = "INFO"
node_name = "$INSTANCE_NAME"
server = true
bootstrap_expect = $CONSUL_CLUSTER_SIZE

bind_addr = "$PRIVATE_IP"
client_addr = "0.0.0.0"

ui_config {
  enabled = $ENABLE_UI
}

connect {
  enabled = true
}

ports {
  grpc = 8502
}

retry_join = [
  "provider=ibmcloud-vpc tag_key=Role tag_value=consul-server region=$CONSUL_REGION"
]

encrypt = "$CONSUL_ENCRYPT_KEY"

EOF

# Add ACL configuration if enabled
if [ "$ENABLE_ACL" = "true" ]; then
cat >> /opt/consul/config/consul.hcl << EOF
acl {
  enabled = true
  default_policy = "deny"
  enable_token_persistence = true
}

EOF
fi

# Add TLS configuration if enabled
if [ "$ENABLE_TLS" = "true" ]; then
  # Write TLS certificates
  echo "${ca_cert}" | base64 -d > /opt/consul/tls/ca.pem
  echo "${server_cert}" | base64 -d > /opt/consul/tls/server.pem
  echo "${server_key}" | base64 -d > /opt/consul/tls/server-key.pem
  
  # Set proper permissions
  chown consul:consul /opt/consul/tls/*.pem
  chmod 600 /opt/consul/tls/server-key.pem
  chmod 644 /opt/consul/tls/ca.pem /opt/consul/tls/server.pem

cat >> /opt/consul/config/consul.hcl << EOF
tls {
  defaults {
    ca_file = "/opt/consul/tls/ca.pem"
    cert_file = "/opt/consul/tls/server.pem"
    key_file = "/opt/consul/tls/server-key.pem"
    verify_incoming = true
    verify_outgoing = true
    verify_server_hostname = true
  }
  internal_rpc {
    verify_server_hostname = true
  }
}

ports {
  http = -1
  https = 8501
}

EOF
fi

# Set ownership
chown consul:consul /opt/consul/config/consul.hcl

# Start Consul service
systemctl enable consul
systemctl start consul

# Wait for Consul to be ready
sleep 30

# Bootstrap ACL system if this is the first server and ACL is enabled
if [ "$ENABLE_ACL" = "true" ] && [ "$CONSUL_SERVER_INDEX" = "0" ]; then
  # Wait for cluster to be ready
  sleep 60
  
  # Bootstrap ACL system
  consul acl bootstrap -format=json > /opt/consul/bootstrap.json || true
  
  # Set the bootstrap token as the master token
  if [ -f /opt/consul/bootstrap.json ]; then
    BOOTSTRAP_TOKEN=$(jq -r '.SecretID' /opt/consul/bootstrap.json)
    echo "CONSUL_HTTP_TOKEN=$BOOTSTRAP_TOKEN" >> /etc/environment
    export CONSUL_HTTP_TOKEN=$BOOTSTRAP_TOKEN
    
    # Create a policy for agents
    consul acl policy create \
      -name "agent-policy" \
      -description "Policy for Consul agents" \
      -rules @- << 'POLICY_EOF'
node_prefix "" {
  policy = "write"
}
service_prefix "" {
  policy = "read"
}
POLICY_EOF

    # Create a token for agents
    consul acl token create \
      -description "Agent token" \
      -policy-name "agent-policy" \
      -format=json > /opt/consul/agent-token.json
      
    AGENT_TOKEN=$(jq -r '.SecretID' /opt/consul/agent-token.json)
    consul acl set-agent-token agent "$AGENT_TOKEN"
  fi
fi

# Enable and start dnsmasq
systemctl enable dnsmasq
systemctl start dnsmasq

# Log completion
echo "Consul server setup completed successfully" | logger -t consul-setup