# Default Consul configuration
# This file will be overridden by cloud-init during instance startup

datacenter = "dc1"
data_dir = "/opt/consul/data"
log_level = "INFO"
node_name = "consul-node"
server = true

bind_addr = "{{ GetInterfaceIP \"eth0\" }}"
client_addr = "0.0.0.0"

ui_config {
  enabled = true
}

connect {
  enabled = true
}

ports {
  grpc = 8502
}

# Performance settings
performance {
  raft_multiplier = 1
}

# Default retry join - will be overridden by cloud-init
retry_join = []