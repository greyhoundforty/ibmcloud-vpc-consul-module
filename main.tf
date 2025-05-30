# Main Terraform configuration for Consul on IBM Cloud VPC
# This file serves as the entry point and includes module organization

# Create the templates directory if it doesn't exist
resource "local_file" "templates_dir" {
  content  = ""
  filename = "${path.module}/templates/.gitkeep"
}

# Create example terraform.tfvars file
resource "local_file" "terraform_tfvars_example" {
  content  = <<-EOF
# IBM Cloud Configuration
ibm_region         = "us-south"
resource_group_name = "default"

# Project Configuration
project_name = "consul-cluster"
environment  = "dev"

# Consul Configuration
consul_image_name    = "consul-1.19.1-20250530123456"  # Replace with actual image name from Packer
consul_cluster_size  = 3
consul_datacenter    = "dc1"
consul_encrypt_key   = ""  # Leave empty to auto-generate or provide base64 encoded key

# Instance Configuration
consul_instance_profile = "bx2-2x8"
ssh_key_name           = "your-ssh-key-name"  # Replace with your SSH key name

# Security Configuration
allowed_cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]

# Feature Flags
enable_ui  = true
enable_acl = true
enable_tls = true

# Tags
tags = {
  Owner = "your-name"
  Team  = "platform"
}
EOF
  filename = "${path.module}/terraform.tfvars.example"
}

# Create README file
resource "local_file" "readme" {
  content  = <<-EOF
# Consul on IBM Cloud VPC

This Terraform configuration deploys a highly available Consul cluster on IBM Cloud VPC using custom images built with Packer.

## Architecture

- **VPC**: Multi-zone VPC with subnets across 3 availability zones
- **Consul Servers**: ${var.consul_cluster_size} Consul server instances distributed across zones
- **Load Balancers**: Public LB for UI access, private LB for API access
- **Security**: Security groups with minimal required access
- **TLS**: Optional mutual TLS for secure communication
- **ACL**: Optional Access Control Lists for authorization

## Prerequisites

1. **IBM Cloud CLI** with VPC plugin
2. **Terraform** >= 1.0
3. **Packer** for building custom images
4. **SSH Key** uploaded to IBM Cloud
5. **Custom Consul Image** built using the provided Packer template

## Quick Start

1. **Build the Consul image using Packer:**
   ```bash
   export IBM_API_KEY="your-api-key"
   export IBM_REGION="us-south"
   export IBM_RESOURCE_GROUP_ID="your-resource-group-id"
   export IBM_SUBNET_ID="your-subnet-id"
   
   packer build consul-packer-template.pkr.hcl
   ```

2. **Configure Terraform variables:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

3. **Deploy the infrastructure:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Configuration

### Required Variables

- `consul_image_name`: Name of the Consul image built by Packer
- `ssh_key_name`: Name of your SSH key in IBM Cloud

### Optional Variables

- `consul_cluster_size`: Number of Consul servers (default: 3)
- `enable_ui`: Enable Consul web UI (default: true)
- `enable_acl`: Enable ACL system (default: true)
- `enable_tls`: Enable TLS encryption (default: true)

## Accessing Consul

### Web UI
If `enable_ui = true`, access the Consul UI at:
```
https://consul-ui-load-balancer-hostname
```

### API Access
Internal API endpoint for applications:
```
https://consul-api-load-balancer-hostname:8501
```

### SSH Access
Connect to Consul servers:
```bash
ssh root@<floating-ip>
```

## Security Considerations

1. **TLS**: Enable TLS for production deployments
2. **ACL**: Enable ACL system and rotate bootstrap tokens
3. **Network**: Restrict `allowed_cidr_blocks` to necessary ranges
4. **SSH**: Use bastion hosts for SSH access in production

## Monitoring

Consul provides several endpoints for monitoring:
- `/v1/status/leader`: Current leader
- `/v1/status/peers`: Cluster members
- `/v1/health/state/any`: Health checks

## Backup and Recovery

1. **Snapshots**: Use `consul snapshot save` for backups
2. **Data Directory**: `/opt/consul/data` contains Consul state
3. **Configuration**: `/opt/consul/config/consul.hcl`

## Troubleshooting

### Check Consul Status
```bash
sudo systemctl status consul
sudo journalctl -u consul -f
```

### Consul Commands
```bash
consul members
consul operator raft list-peers
consul acl token list
```

### Common Issues

1. **Bootstrap Issues**: Ensure cluster_size matches actual instances
2. **Network**: Verify security group rules allow Consul ports
3. **TLS**: Check certificate validity and CA trust

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

## Support

For issues and questions:
1. Check Consul documentation: https://consul.io/docs
2. Review IBM Cloud VPC documentation
3. Check Terraform IBM provider documentation
EOF
  filename = "${path.module}/README.md"
}

# Create .gitignore file
resource "local_file" "gitignore" {
  content  = <<-EOF
# Terraform
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
terraform.tfvars
*.tfplan

# Packer
packer_cache/
*.box

# Logs
*.log

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Secrets
*.pem
*.key
*.crt
secrets/
EOF
  filename = "${path.module}/.gitignore"
}


