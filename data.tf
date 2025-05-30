data "ibm_is_ssh_key" "sshkey" {
  count = var.existing_ssh_key != "" ? 1 : 0
  name  = var.existing_ssh_key
}

data "ibm_is_image" "consul" {
  name = var.base_image_name
}

data "ibm_is_zones" "regional" {
  region = var.ibm_region
}
