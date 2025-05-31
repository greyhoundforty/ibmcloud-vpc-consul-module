module "resource_group" {
  source                       = "terraform-ibm-modules/resource-group/ibm"
  version                      = "1.2.0"
  existing_resource_group_name = var.existing_resource_group
}

# Generate a random string if a project prefix was not provided
resource "random_string" "prefix" {
  count   = var.project_name != "" ? 0 : 1
  length  = 4
  special = false
  upper   = false
  numeric = false
}

# Generate a new SSH key if one was not provided
resource "tls_private_key" "ssh" {
  count     = var.existing_ssh_key != "" ? 0 : 1
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Add a new SSH key to the region if one was created
resource "ibm_is_ssh_key" "generated_key" {
  count          = var.existing_ssh_key != "" ? 0 : 1
  name           = "${local.name_prefix}-${var.ibm_region}-key"
  public_key     = tls_private_key.ssh[0].public_key_openssh
  resource_group = module.resource_group.resource_group_id
  tags           = local.common_tags_list
}

# Write private key to file if it was generated
resource "null_resource" "create_private_key" {
  count = var.existing_ssh_key != "" ? 0 : 1
  provisioner "local-exec" {
    command = <<-EOT
      echo '${tls_private_key.ssh[0].private_key_pem}' > ./'${local.name_prefix}'.pem
      chmod 400 ./'${local.name_prefix}'.pem
    EOT
  }
}

module "vpc" {
  source                      = "terraform-ibm-modules/vpc/ibm//modules/vpc"
  version                     = "1.5.1"
  create_vpc                  = true
  vpc_name                    = "${local.name_prefix}-vpc"
  resource_group_id           = module.resource_group.resource_group_id
  default_address_prefix      = var.default_address_prefix
  default_network_acl_name    = "${local.name_prefix}-default-network-acl"
  default_security_group_name = "${local.name_prefix}-default-security-group"
  default_routing_table_name  = "${local.name_prefix}-default-routing-table"
  vpc_tags                    = local.common_tags_list
  locations                   = [local.vpc_zones[0].zone, local.vpc_zones[1].zone, local.vpc_zones[2].zone]
  number_of_addresses         = "128"
  create_gateway              = true
  subnet_name_prefix          = "${local.name_prefix}-consul-subnet"
  public_gateway_name_prefix  = "${local.name_prefix}-pubgw"
  gateway_tags                = local.common_tags_list
}