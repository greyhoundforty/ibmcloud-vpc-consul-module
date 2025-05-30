# Security group for Consul servers using IBM module
module "consul_server_sg" {
  source                       = "terraform-ibm-modules/security-group/ibm"
  version                      = "2.7.0"
  add_ibm_cloud_internal_rules = true
  security_group_name          = "${local.name_prefix}-consul-server-sg"
  vpc_id                       = ibm_is_vpc.consul.id
  resource_group               = module.resource_group.resource_group_id
  tags                         = local.common_tags

  security_group_rules = concat(
    [
      # SSH access
      {
        name      = "allow-ssh-inbound"
        direction = "inbound"
        remote    = "0.0.0.0/0"
        tcp = {
          port_min = 22
          port_max = 22
        }
      },
      # Consul RPC (8300) - Server to Server
      {
        name        = "allow-consul-rpc-inbound"
        direction   = "inbound"
        remote_type = "security_group_id"
        remote      = module.consul_server_sg.security_group_id
        tcp = {
          port_min = local.consul_ports.rpc
          port_max = local.consul_ports.rpc
        }
      },
      # Consul Serf LAN (8301) - TCP
      {
        name        = "allow-consul-serf-lan-tcp-inbound"
        direction   = "inbound"
        remote_type = "security_group_id"
        remote      = module.consul_server_sg.security_group_id
        tcp = {
          port_min = local.consul_ports.lan
          port_max = local.consul_ports.lan
        }
      },
      # Consul Serf LAN (8301) - UDP
      {
        name        = "allow-consul-serf-lan-udp-inbound"
        direction   = "inbound"
        remote_type = "security_group_id"
        remote      = module.consul_server_sg.security_group_id
        udp = {
          port_min = local.consul_ports.lan
          port_max = local.consul_ports.lan
        }
      },
      # Consul Serf WAN (8302) - TCP
      {
        name      = "allow-consul-serf-wan-tcp-inbound"
        direction = "inbound"
        remote    = "0.0.0.0/0"
        tcp = {
          port_min = local.consul_ports.wan
          port_max = local.consul_ports.wan
        }
      },
      # Consul Serf WAN (8302) - UDP
      {
        name      = "allow-consul-serf-wan-udp-inbound"
        direction = "inbound"
        remote    = "0.0.0.0/0"
        udp = {
          port_min = local.consul_ports.wan
          port_max = local.consul_ports.wan
        }
      },
      # Consul DNS (8600) - TCP
      {
        name      = "allow-consul-dns-tcp-inbound"
        direction = "inbound"
        remote    = local.vpc_cidr
        tcp = {
          port_min = local.consul_ports.dns
          port_max = local.consul_ports.dns
        }
      },
      # Consul DNS (8600) - UDP
      {
        name      = "allow-consul-dns-udp-inbound"
        direction = "inbound"
        remote    = local.vpc_cidr
        udp = {
          port_min = local.consul_ports.dns
          port_max = local.consul_ports.dns
        }
      },
      # Outbound - Allow all
      {
        name      = "allow-all-outbound"
        direction = "outbound"
        remote    = "0.0.0.0/0"
      }
    ],
    # Conditional rules for HTTP API access (when UI is enabled)
    var.enable_ui ? [
      for cidr in var.allowed_cidr_blocks : {
        name      = "allow-consul-http-from-${replace(cidr, "/", "-")}"
        direction = "inbound"
        remote    = cidr
        tcp = {
          port_min = local.consul_ports.http
          port_max = local.consul_ports.http
        }
      }
    ] : [],
    # Conditional rules for HTTPS API access (when TLS and UI are enabled)
    var.enable_tls && var.enable_ui ? [
      for cidr in var.allowed_cidr_blocks : {
        name      = "allow-consul-https-from-${replace(cidr, "/", "-")}"
        direction = "inbound"
        remote    = cidr
        tcp = {
          port_min = local.consul_ports.https
          port_max = local.consul_ports.https
        }
      }
    ] : []
  )
}

# Security group for Consul clients using IBM module
module "consul_client_sg" {
  source                       = "terraform-ibm-modules/security-group/ibm"
  version                      = "2.7.0"
  add_ibm_cloud_internal_rules = true
  security_group_name          = "${local.name_prefix}-consul-client-sg"
  vpc_id                       = ibm_is_vpc.consul.id
  resource_group               = module.resource_group.resource_group_id
  tags                         = local.common_tags

  security_group_rules = concat(
    [
      # Allow all outbound traffic
      {
        name      = "allow-all-outbound"
        direction = "outbound"
        remote    = "0.0.0.0/0"
      }
    ]
  )
}

# Additional rules for client to server communication
# These need to be added to the server security group to allow client access
module "consul_server_client_rules" {
  source                      = "terraform-ibm-modules/security-group/ibm"
  version                     = "2.7.0"
  use_existing_security_group = true
  existing_security_group_id  = module.consul_server_sg.security_group_id

  security_group_rules = concat(
    [
      # Allow clients to access HTTP API
      {
        name        = "allow-client-http-access"
        direction   = "inbound"
        remote_type = "security_group_id"
        remote      = module.consul_client_sg.security_group_id
        tcp = {
          port_min = local.consul_ports.http
          port_max = local.consul_ports.http
        }
      }
    ],
    # Conditional HTTPS access for clients when TLS is enabled
    var.enable_tls ? [
      {
        name        = "allow-client-https-access"
        direction   = "inbound"
        remote_type = "security_group_id"
        remote      = module.consul_client_sg.security_group_id
        tcp = {
          port_min = local.consul_ports.https
          port_max = local.consul_ports.https
        }
      }
    ] : []
  )

  depends_on = [
    module.consul_server_sg,
    module.consul_client_sg
  ]
}

# # Local values for security group IDs to maintain compatibility with existing code
# locals {

# }