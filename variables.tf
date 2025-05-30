variable "ibm_region" {
  description = "IBM Cloud region to deploy resources"
  type        = string
  default     = "us-south"
}

variable "existing_resource_group" {
  description = "Name of the IBM Cloud resource group"
  type        = string
  default     = "defult"
}

variable "project_name" {
  description = "Name of the project - used for resource naming"
  type        = string
  default     = "consul-cluster"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "base_image_name" {
  description = "Name of the default base image for Consul servers"
  type        = string
}

variable "consul_cluster_size" {
  description = "Number of Consul server instances"
  type        = number
  default     = 3
  validation {
    condition     = var.consul_cluster_size >= 3 && var.consul_cluster_size <= 7 && var.consul_cluster_size % 2 == 1
    error_message = "Consul cluster size must be an odd number between 3 and 7."
  }
}

variable "consul_instance_profile" {
  description = "Instance profile for Consul servers"
  type        = string
  default     = "bx2-2x8"
}

variable "consul_datacenter" {
  description = "Consul datacenter name"
  type        = string
  default     = "dc1"
}

variable "consul_encrypt_key" {
  description = "Consul gossip encryption key (base64 encoded)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "existing_ssh_key" {
  description = "Name of an existing SSH key to use for instances. If not provided, a new key will be generated."
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access Consul UI"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "enable_ui" {
  description = "Enable Consul UI"
  type        = bool
  default     = true
}

variable "enable_acl" {
  description = "Enable Consul ACL system"
  type        = bool
  default     = true
}

variable "enable_tls" {
  description = "Enable TLS for Consul communication"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}