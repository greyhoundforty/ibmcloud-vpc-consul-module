locals {
  # Resource naming
  name_prefix = "${var.project_name}-${var.environment}"
  ssh_key_ids = var.existing_ssh_key != "" ? [data.ibm_is_ssh_key.sshkey[0].id] : [ibm_is_ssh_key.generated_key[0].id]


  # Network configuration
  vpc_cidr = "10.240.0.0/16"
  availability_zones = [
    "${var.ibm_region}-1",
    "${var.ibm_region}-2",
    "${var.ibm_region}-3"
  ]

  # Subnet CIDRs
  subnet_cidrs = {
    "${var.ibm_region}-1" = "10.240.1.0/24"
    "${var.ibm_region}-2" = "10.240.2.0/24"
    "${var.ibm_region}-3" = "10.240.3.0/24"
  }

  # Common tags
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Component   = "consul"
  })

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
