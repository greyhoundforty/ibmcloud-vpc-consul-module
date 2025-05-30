# Consul server instances
resource "ibm_is_instance" "consul_server" {
  count          = var.consul_cluster_size
  name           = "${local.name_prefix}-consul-${count.index + 1}"
  vpc            = ibm_is_vpc.consul.id
  zone           = local.availability_zones[count.index % length(local.availability_zones)]
  profile        = var.consul_instance_profile
  image          = data.ibm_is_image.consul.id
  keys           = [data.ibm_is_ssh_key.ssh_key.id]
  resource_group = module.resource_group.resource_group_id
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-consul-${count.index + 1}"
    Role = "consul-server"
  })

  primary_network_interface {
    subnet          = ibm_is_subnet.consul[local.availability_zones[count.index % length(local.availability_zones)]].id
    security_groups = [local.consul_server_security_group_id]
  }

  user_data = base64encode(templatefile("${path.module}/templates/consul-server-userdata.tpl", {
    consul_datacenter   = var.consul_datacenter
    consul_encrypt_key  = local.consul_encrypt_key
    consul_cluster_size = var.consul_cluster_size
    consul_server_index = count.index
    consul_region       = var.ibm_region
    enable_ui           = var.enable_ui
    enable_acl          = var.enable_acl
    enable_tls          = var.enable_tls
    acl_bootstrap_token = var.enable_acl ? random_password.consul_acl_token[0].result : ""
    ca_cert             = var.enable_tls ? base64encode(tls_self_signed_cert.ca[0].cert_pem) : ""
    server_cert         = var.enable_tls ? base64encode(tls_locally_signed_cert.server[count.index].cert_pem) : ""
    server_key          = var.enable_tls ? base64encode(tls_private_key.server[count.index].private_key_pem) : ""
    retry_join_addresses = [
      for i in range(var.consul_cluster_size) :
      "provider=ibmcloud-vpc tag_key=Role tag_value=consul-server region=${var.ibm_region}"
    ]
  }))

  lifecycle {
    create_before_destroy = true
  }
}

# Floating IPs for Consul servers (optional, for external access)
resource "ibm_is_floating_ip" "consul_server" {
  count          = var.enable_ui ? var.consul_cluster_size : 0
  name           = "${local.name_prefix}-consul-${count.index + 1}-fip"
  target         = ibm_is_instance.consul_server[count.index].primary_network_interface[0].id
  resource_group = module.resource_group.resource_group_id
  tags           = local.common_tags
}

# Load balancer for Consul UI (optional)
resource "ibm_is_lb" "consul_ui" {
  count          = var.enable_ui ? 1 : 0
  name           = "${local.name_prefix}-consul-ui-lb"
  subnets        = [for subnet in ibm_is_subnet.consul : subnet.id]
  type           = "public"
  resource_group = module.resource_group.resource_group_id
  tags           = local.common_tags
}

resource "ibm_is_lb_pool" "consul_ui" {
  count          = var.enable_ui ? 1 : 0
  name           = "${local.name_prefix}-consul-ui-pool"
  lb             = ibm_is_lb.consul_ui[0].id
  algorithm      = "round_robin"
  protocol       = var.enable_tls ? "https" : "http"
  health_delay   = 10
  health_retries = 3
  health_timeout = 5
  health_type    = var.enable_tls ? "https" : "http"
  health_url     = "/v1/status/leader"
}

resource "ibm_is_lb_pool_member" "consul_ui" {
  count          = var.enable_ui ? var.consul_cluster_size : 0
  lb             = ibm_is_lb.consul_ui[0].id
  pool           = ibm_is_lb_pool.consul_ui[0].pool_id
  port           = var.enable_tls ? local.consul_ports.https : local.consul_ports.http
  target_address = ibm_is_instance.consul_server[count.index].primary_network_interface[0].primary_ipv4_address
  weight         = 100
}

resource "ibm_is_lb_listener" "consul_ui" {
  count        = var.enable_ui ? 1 : 0
  lb           = ibm_is_lb.consul_ui[0].id
  default_pool = ibm_is_lb_pool.consul_ui[0].pool_id
  port         = var.enable_tls ? 443 : 80
  protocol     = var.enable_tls ? "https" : "http"
}

# Internal load balancer for Consul API
resource "ibm_is_lb" "consul_api" {
  name           = "${local.name_prefix}-consul-api-lb"
  subnets        = [for subnet in ibm_is_subnet.consul : subnet.id]
  type           = "private"
  resource_group = module.resource_group.resource_group_id
  tags           = local.common_tags
}

resource "ibm_is_lb_pool" "consul_api" {
  name               = "${local.name_prefix}-consul-api-pool"
  lb                 = ibm_is_lb.consul_api.id
  algorithm          = "round_robin"
  protocol           = var.enable_tls ? "https" : "http"
  health_delay       = 10
  health_retries     = 3
  health_timeout     = 5
  health_type        = var.enable_tls ? "https" : "http"
  health_monitor_url = "/v1/status/leader"
}

resource "ibm_is_lb_pool_member" "consul_api" {
  count          = var.consul_cluster_size
  lb             = ibm_is_lb.consul_api.id
  pool           = ibm_is_lb_pool.consul_api.pool_id
  port           = var.enable_tls ? local.consul_ports.https : local.consul_ports.http
  target_address = ibm_is_instance.consul_server[count.index].primary_network_interface[0].primary_ipv4_address
  weight         = 100
}

resource "ibm_is_lb_listener" "consul_api" {
  lb           = ibm_is_lb.consul_api.id
  default_pool = ibm_is_lb_pool.consul_api.pool_id
  port         = var.enable_tls ? local.consul_ports.https : local.consul_ports.http
  protocol     = var.enable_tls ? "https" : "http"
}