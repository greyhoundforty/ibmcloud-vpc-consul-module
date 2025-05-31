locals {
  # Resource naming
  name_prefix = var.project_name != "" ? var.project_name : "${random_string.prefix.0.result}"
  ssh_key_ids = var.existing_ssh_key != "" ? [data.ibm_is_ssh_key.sshkey[0].id] : [ibm_is_ssh_key.generated_key[0].id]

  # Common tags
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Component   = "consul"
  })

  # IBM Cloud tags as list of strings (required format: ["key:value"])
  common_tags_list = [
    for key, value in local.common_tags : "${key}:${value}"
  ]

  zones = length(data.ibm_is_zones.regional.zones)
  vpc_zones = {
    for zone in range(local.zones) : zone => {
      zone = "${var.ibm_region}-${zone + 1}"
    }
  }

  # Consul configuration
  consul_ports = {
    http  = 8500
    https = 8501
    rpc   = 8300
    lan   = 8301
    wan   = 8302
    dns   = 8600
  }

  # Generate random encryption key if not provided
  consul_encrypt_key              = var.consul_encrypt_key != "" ? var.consul_encrypt_key : random_password.consul_encrypt_key.result
  consul_server_security_group_id = module.consul_server_sg.security_group_id
  consul_client_security_group_id = module.consul_client_sg.security_group_id
}
