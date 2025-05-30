# Example: How to use the Consul client security group for other resources
# This file shows how to attach the client security group to instances that need to connect to Consul

# Example application server that needs to connect to Consul
resource "ibm_is_instance" "app_server" {
  name           = "${local.name_prefix}-app-server"
  vpc            = ibm_is_vpc.consul.id
  zone           = local.availability_zones[0]
  profile        = "bx2-2x8"
  image          = "r006-14140f94-fcc4-11e9-96e7-a72723715315" # Ubuntu 20.04
  keys           = [data.ibm_is_ssh_key.ssh_key.id]
  resource_group = data.ibm_resource_group.group.id

  primary_network_interface {
    subnet = ibm_is_subnet.consul[local.availability_zones[0]].id
    # Attach both a custom security group AND the Consul client security group
    security_groups = [
      ibm_is_security_group.app_server.id,
      local.consul_client_security_group_id  # This allows connection to Consul
    ]
  }

  user_data = base64encode(templatefile("${path.module}/templates/app-server-userdata.tpl", {
    consul_api_endpoint = var.enable_tls ? 
      "https://${ibm_is_lb.consul_api.hostname}:${local.consul_ports.https}" : 
      "http://${ibm_is_lb.consul_api.hostname}:${local.consul_ports.http}"
    consul_datacenter = var.consul_datacenter
    enable_tls       = var.enable_tls
  }))

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-server"
    Role = "application"
  })
}

# Custom security group for the application server
resource "ibm_is_security_group" "app_server" {
  name           = "${local.name_prefix}-app-server-sg"
  vpc            = ibm_is_vpc.consul.id
  resource_group = data.ibm_resource_group.group.id
  tags           = local.common_tags
}

# Allow SSH access to app server
resource "ibm_is_security_group_rule" "app_server_ssh" {
  group     = ibm_is_security_group.app_server.id
  direction = "inbound"
  remote    = "0.0.0.0/0"

  tcp {
    port_min = 22
    port_max = 22
  }
}

# Allow HTTP traffic to app server
resource "ibm_is_security_group_rule" "app_server_http" {
  group     = ibm_is_security_group.app_server.id
  direction = "inbound"
  remote    = "0.0.0.0/0"

  tcp {
    port_min = 80
    port_max = 80
  }
}

# Allow outbound traffic from app server
resource "ibm_is_security_group_rule" "app_server_outbound" {
  group     = ibm_is_security_group.app_server.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
}

# Example user data template for app server
resource "local_file" "app_server_userdata_template" {
  content = <<-EOF
#!/bin/bash
set -e

# Variables from Terraform
CONSUL_API_ENDPOINT="${consul_api_endpoint}"
CONSUL_DATACENTER="${consul_datacenter}"
ENABLE_TLS="${enable_tls}"

# Install Consul client
cd /tmp
wget -q https://releases.hashicorp.com/consul/1.19.1/consul_1.19.1_linux_amd64.zip -O consul.zip
unzip consul.zip
sudo mv consul /usr/local/bin/
rm consul.zip

# Create consul user and directories
sudo useradd --system --home /var/lib/consul --shell /bin/false consul
sudo mkdir -p /opt/consul/config
sudo mkdir -p /var/lib/consul
sudo chown -R consul:consul /opt/consul /var/lib/consul

# Configure Consul client
cat > /opt/consul/config/consul.hcl << EOF
datacenter = "$CONSUL_DATACENTER"
data_dir = "/var/lib/consul"
log_level = "INFO"
node_name = "$(hostname)"
server = false

retry_join = ["$CONSUL_API_ENDPOINT"]

bind_addr = "{{ GetInterfaceIP \"eth0\" }}"
client_addr = "127.0.0.1"
EOF

# Add TLS configuration if enabled
if [ "$ENABLE_TLS" = "true" ]; then
cat >> /opt/consul/config/consul.hcl << EOF
tls {
  defaults {
    verify_outgoing = true
  }
}
ports {
  http = -1
  https = 8501
}
EOF
fi

# Create systemd service
cat > /etc/systemd/system/consul.service << EOF
[Unit]
Description=Consul Client
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/opt/consul/config/consul.hcl

[Service]
Type=notify
User=consul
Group=consul
ExecStart=/usr/local/bin/consul agent -config-dir=/opt/consul/config
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# Start and enable Consul client
sudo systemctl daemon-reload
sudo systemctl enable consul
sudo systemctl start consul

# Install your application here
# ...

echo "Application server setup completed successfully" | logger -t app-setup
EOF
  filename = "${path.module}/templates/app-server-userdata.tpl"
}