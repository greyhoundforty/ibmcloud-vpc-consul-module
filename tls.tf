# TLS Certificate Authority
resource "tls_private_key" "ca" {
  count     = var.enable_tls ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ca" {
  count           = var.enable_tls ? 1 : 0
  private_key_pem = tls_private_key.ca[0].private_key_pem

  subject {
    common_name  = "Consul CA"
    organization = var.project_name
  }

  validity_period_hours = 8760 # 1 year
  is_ca_certificate     = true

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
  ]
}

# Server certificates
resource "tls_private_key" "server" {
  count     = var.enable_tls ? var.consul_cluster_size : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "server" {
  count           = var.enable_tls ? var.consul_cluster_size : 0
  private_key_pem = tls_private_key.server[count.index].private_key_pem

  subject {
    common_name  = "server.${var.consul_datacenter}.consul"
    organization = var.project_name
  }

  dns_names = [
    "server.${var.consul_datacenter}.consul",
    "consul-${count.index}.${var.consul_datacenter}.consul",
    "localhost",
  ]

  ip_addresses = [
    "127.0.0.1",
  ]
}

resource "tls_locally_signed_cert" "server" {
  count              = var.enable_tls ? var.consul_cluster_size : 0
  cert_request_pem   = tls_cert_request.server[count.index].cert_request_pem
  ca_private_key_pem = tls_private_key.ca[0].private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca[0].cert_pem

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

# Client certificate
resource "tls_private_key" "client" {
  count     = var.enable_tls ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "client" {
  count           = var.enable_tls ? 1 : 0
  private_key_pem = tls_private_key.client[0].private_key_pem

  subject {
    common_name  = "client.${var.consul_datacenter}.consul"
    organization = var.project_name
  }

  dns_names = [
    "client.${var.consul_datacenter}.consul",
  ]
}

resource "tls_locally_signed_cert" "client" {
  count              = var.enable_tls ? 1 : 0
  cert_request_pem   = tls_cert_request.client[0].cert_request_pem
  ca_private_key_pem = tls_private_key.ca[0].private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca[0].cert_pem

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}