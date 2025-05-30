output "vpc_id" {
  description = "ID of the VPC"
  value       = ibm_is_vpc.consul.id
}

output "vpc_crn" {
  description = "CRN of the VPC"
  value       = ibm_is_vpc.consul.crn
}

output "subnet_ids" {
  description = "IDs of the subnets"
  value       = { for k, v in ibm_is_subnet.consul : k => v.id }
}

output "consul_server_ids" {
  description = "IDs of the Consul server instances"
  value       = ibm_is_instance.consul_server[*].id
}

output "consul_server_private_ips" {
  description = "Private IP addresses of Consul servers"
  value       = ibm_is_instance.consul_server[*].primary_network_interface[0].primary_ipv4_address
}

output "consul_server_public_ips" {
  description = "Public IP addresses of Consul servers (if floating IPs are enabled)"
  value       = var.enable_ui ? ibm_is_floating_ip.consul_server[*].address : []
}

output "consul_ui_url" {
  description = "URL for Consul UI (if enabled)"
  value = var.enable_ui ? (
    var.enable_tls ?
    "https://${ibm_is_lb.consul_ui[0].hostname}" :
    "http://${ibm_is_lb.consul_ui[0].hostname}"
  ) : null
}

# output "consul_api_endpoint" {
#   description = "Internal API endpoint for Consul cluster"
#   value = var.enable_tls ? 
#     "https://${ibm_is_lb.consul_api.hostname}:${local.consul_ports.https}" : 
#     "http://${ibm_is_lb.consul_api.hostname}:${local.consul_ports.http}"
# }

output "consul_datacenter" {
  description = "Consul datacenter name"
  value       = var.consul_datacenter
}

output "consul_encrypt_key" {
  description = "Consul gossip encryption key"
  value       = local.consul_encrypt_key
  sensitive   = true
}

output "consul_acl_bootstrap_token" {
  description = "Consul ACL bootstrap token (if ACL is enabled)"
  value       = var.enable_acl ? random_password.consul_acl_token[0].result : null
  sensitive   = true
}

output "consul_ca_cert" {
  description = "Consul CA certificate (if TLS is enabled)"
  value       = var.enable_tls ? tls_self_signed_cert.ca[0].cert_pem : null
  sensitive   = true
}

output "consul_client_cert" {
  description = "Consul client certificate (if TLS is enabled)"
  value       = var.enable_tls ? tls_locally_signed_cert.client[0].cert_pem : null
  sensitive   = true
}

output "consul_client_key" {
  description = "Consul client private key (if TLS is enabled)"
  value       = var.enable_tls ? tls_private_key.client[0].private_key_pem : null
  sensitive   = true
}

output "security_group_consul_server_id" {
  description = "ID of the Consul server security group"
  value       = ibm_is_security_group.consul_server.id
}

output "security_group_consul_client_id" {
  description = "ID of the Consul client security group"
  value       = ibm_is_security_group.consul_client.id
}

output "ssh_connection_commands" {
  description = "SSH commands to connect to Consul servers"
  value = var.enable_ui ? [
    for i, ip in ibm_is_floating_ip.consul_server[*].address :
    "ssh root@${ip}"
  ] : []
}