module "resource_group" {
  source                       = "terraform-ibm-modules/resource-group/ibm"
  version                      = "1.2.0" # Replace "X.X.X" with a release version to lock into a specific release
  existing_resource_group_name = var.existing_resource_group
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
  public_key     = tls_private_key.ssh.0.public_key_openssh
  resource_group = module.resource_group.resource_group_id
  tags           = local.common_tags
}

# Write private key to file if it was generated
resource "null_resource" "create_private_key" {
  count = var.existing_ssh_key != "" ? 0 : 1
  provisioner "local-exec" {
    command = <<-EOT
      echo '${tls_private_key.ssh.0.private_key_pem}' > ./'${local.name_prefix}'.pem
      chmod 400 ./'${local.name_prefix}'.pem
    EOT
  }
}

# VPC
resource "ibm_is_vpc" "consul" {
  name                        = "${local.name_prefix}-vpc"
  resource_group              = module.resource_group.resource_group_id
  address_prefix_management   = "manual"
  default_network_acl_name    = "${local.name_prefix}-default-nacl"
  default_security_group_name = "${local.name_prefix}-default-sg"
  default_routing_table_name  = "${local.name_prefix}-default-rt"
  tags                        = local.common_tags
}

# Address prefixes for each zone
resource "ibm_is_vpc_address_prefix" "consul" {
  for_each = local.subnet_cidrs

  name = "${local.name_prefix}-prefix-${each.key}"
  vpc  = ibm_is_vpc.consul.id
  zone = each.key
  cidr = each.value
}

# Subnets
resource "ibm_is_subnet" "consul" {
  for_each = local.subnet_cidrs

  name            = "${local.name_prefix}-subnet-${each.key}"
  vpc             = ibm_is_vpc.consul.id
  zone            = each.key
  ipv4_cidr_block = each.value
  resource_group  = module.resource_group.resource_group_id
  public_gateway  = ibm_is_public_gateway.consul[each.key].id
  tags            = local.common_tags

  depends_on = [ibm_is_vpc_address_prefix.consul]
}

# Public gateways for internet access
resource "ibm_is_public_gateway" "consul" {
  for_each = toset(local.availability_zones)

  name           = "${local.name_prefix}-pgw-${each.key}"
  vpc            = ibm_is_vpc.consul.id
  zone           = each.key
  resource_group = module.resource_group.resource_group_id
  tags           = local.common_tags
}