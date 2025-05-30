# Consul on IBM Cloud VPC - Deployment Guide

This guide provides step-by-step instructions for deploying a highly available Consul cluster on IBM Cloud VPC using Packer and Terraform.

## Prerequisites

### Required Tools
- **IBM Cloud CLI** with VPC plugin
- **Terraform** >= 1.0
- **Packer** >= 1.8
- **jq** for JSON processing
- **SSH client**

### IBM Cloud Requirements
- IBM Cloud account with VPC access
- Resource group created
- SSH key uploaded to IBM Cloud
- Sufficient quota for instances and networking resources

## Step 1: Environment Setup

### 1.1 Install Required Tools

```bash
# Install IBM Cloud CLI (macOS)
curl -fsSL https://clis.cloud.ibm.com/install/osx | sh

# Install VPC plugin
ibmcloud plugin install vpc-infrastructure

# Install Terraform
brew install terraform

# Install Packer
brew install packer
```

### 1.2 Configure IBM Cloud CLI

```bash
# Login to IBM Cloud
ibmcloud login

# Target your region and resource group
ibmcloud target -r us-south -g default

# Verify VPC access
ibmcloud is vpcs
```

### 1.3 Set Environment Variables

```bash
# Create environment file
cp .env.example .env

# Edit .env with your values
export IBM_API_KEY="your-api-key-here"
export IBM_REGION="us-south"
export IBM_RESOURCE_GROUP_ID="your-resource-group-id"
export IBM_SUBNET_ID="your-existing-subnet-id"  # Temporary for Packer

# Source environment
source .env
```

## Step 2: Build Consul Image with Packer

### 2.1 Validate Packer Template

```bash
packer validate consul-packer-template.pkr.hcl
```

### 2.2 Build the Image

```bash
# Build Consul image
make packer-build

# Or manually:
packer build consul-packer-template.pkr.hcl
```

The build process will:
- Create a temporary VPC instance
- Install Consul and dependencies
- Configure system services
- Create a custom image
- Clean up temporary resources

**Note the image name** from the output - you'll need it for Terraform.

## Step 3: Configure Terraform

### 3.1 Create terraform.tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
# IBM Cloud Configuration
ibm_region         = "us-south"
resource_group_name = "default"

# Project Configuration
project_name = "consul-prod"
environment  = "production"

# Consul Configuration
consul_image_name    = "consul-1.19.1-20250530123456"  # From Packer output
consul_cluster_size  = 3
consul_datacenter    = "dc1"
consul_encrypt_key   = ""  # Auto-generated if empty

# Instance Configuration
consul_instance_profile = "bx2-2x8"
ssh_key_name           = "my-ssh-key"

# Security Configuration
allowed_cidr_blocks = ["10.0.0.0/8"]

# Feature Flags
enable_ui  = true
enable_acl = true
enable_tls = true

# Tags
tags = {
  Owner = "platform-team"
  Environment = "production"
}
```

### 3.2 Initialize Terraform

```bash
terraform init
```

## Step 4: Deploy Infrastructure

### 4.1 Validate and Plan

```bash
# Validate configuration
make check

# Create execution plan
terraform plan -out=tfplan
```

Review the plan carefully. It should create:
- 1 VPC with 3 subnets across availability zones
- 3 Consul server instances
- Security groups with proper rules
- Load balancers for UI and API access
- TLS certificates (if enabled)
- Floating IPs (if UI enabled)

### 4.2 Apply Configuration

```bash
terraform apply tfplan
```

The deployment typically takes 10-15 minutes.

## Step 5: Verify Deployment

### 5.1 Check Terraform Outputs

```bash
terraform output
```

Key outputs:
- `consul_ui_url`: URL for web interface
- `consul_api_endpoint`: Internal API endpoint
- `consul_server_private_ips`: Private IP addresses
- `ssh_connection_commands`: SSH commands

### 5.2 Verify Consul Cluster

```bash
# Check cluster status
make consul-status

# Or manually connect to a server
ssh root@<floating-ip>
consul members
consul operator raft list-peers
```

Expected output:
```
Node                    Address           Status  Type    Build   Protocol  DC   Partition  Segment
consul-prod-consul-1    10.240.1.4:8301   alive   server  1.19.1  2         dc1  default    <all>
consul-prod-consul-2    10.240.2.4:8301   alive   server  1.19.1  2         dc1  default    <all>
consul-prod-consul-3    10.240.3.4:8301   alive   server  1.19.1  2         dc1  default    <all>
```

### 5.3 Access Consul UI

```bash
# Open UI in browser
make consul-ui

# Or get URL manually
terraform output consul_ui_url
```

## Step 6: Configure ACL System (if enabled)

### 6.1 Get Bootstrap Token

```bash
# Get bootstrap token from Terraform
terraform output -raw consul_acl_bootstrap_token

# Or connect to first server and check
ssh root@<first-server-ip>
cat /opt/consul/bootstrap.json
```

### 6.2 Create Additional Policies and Tokens

```bash
# Connect to Consul server
ssh root@<server-ip>

# Set bootstrap token
export CONSUL_HTTP_TOKEN="<bootstrap-token>"

# Create operator policy
consul acl policy create \
  -name "operator-policy" \
  -description "Policy for operators" \
  -rules @- << 'EOF'
node_prefix "" {
  policy = "write"
}
service_prefix "" {
  policy = "write"
}
acl = "write"
operator = "write"
EOF

# Create operator token
consul acl token create \
  -description "Operator token" \
  -policy-name "operator-policy"
```

## Step 7: Configure TLS (if enabled)

### 7.1 Get TLS Certificates

```bash
# Get CA certificate
terraform output -raw consul_ca_cert > consul-ca.pem

# Get client certificate and key
terraform output -raw consul_client_cert > consul-client.pem
terraform output -raw consul_client_key > consul-client-key.pem
```

### 7.2 Configure Local Consul CLI

```bash
# Set environment variables for local CLI
export CONSUL_HTTP_ADDR="https://$(terraform output -raw consul_api_endpoint)"
export CONSUL_CACERT="consul-ca.pem"
export CONSUL_CLIENT_CERT="consul-client.pem"
export CONSUL_CLIENT_KEY="consul-client-key.pem"
export CONSUL_HTTP_TOKEN="<your-token>"

# Test connection
consul members
```

## Step 8: Post-Deployment Configuration

### 8.1 Configure DNS Forwarding (Optional)

To use Consul DNS from other instances:

```bash
# Add to /etc/systemd/resolved.conf
[Resolve]
DNS=<consul-server-ip>:8600
Domains=~consul

# Restart systemd-resolved
systemctl restart systemd-resolved
```

### 8.2 Set Up Monitoring

Add monitoring for Consul health endpoints:
- `http://consul-api:8500/v1/status/leader`
- `http://consul-api:8500/v1/health/state/any`

### 8.3 Configure Backup

Set up automated backups:

```bash
# Create backup script
cat > /usr/local/bin/consul-backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/consul/backups"
DATE=$(date +%Y%m%d-%H%M%S)
mkdir -p $BACKUP_DIR

consul snapshot save $BACKUP_DIR/consul-$DATE.snap
find $BACKUP_DIR -name "consul-*.snap" -mtime +7 -delete
EOF

chmod +x /usr/local/bin/consul-backup.sh

# Add cron job
echo "0 2 * * * /usr/local/bin/consul-backup.sh" | crontab -
```

## Troubleshooting

### Common Issues

#### 1. Bootstrap Issues
**Problem**: Cluster fails to bootstrap
**Solution**: 
- Check cluster_size matches actual instances
- Verify retry_join configuration
- Check security group rules

#### 2. Network Connectivity
**Problem**: Servers can't communicate
**Solution**:
- Verify security group rules allow Consul ports
- Check subnet routing and ACLs
- Ensure instances are in correct subnets

#### 3. TLS Issues
**Problem**: TLS certificate errors
**Solution**:
- Verify certificate validity
- Check CA trust chain
- Ensure proper DNS names in certificates

#### 4. ACL Issues
**Problem**: Permission denied errors
**Solution**:
- Verify token has required permissions
- Check policy definitions
- Ensure token is properly configured

### Debug Commands

```bash
# Check Consul logs
journalctl -u consul -f

# Check cluster health
consul operator raft list-peers
consul members

# Check ACL status
consul acl token list

# Test TLS
openssl s_client -connect <consul-ip>:8501 -cert consul-client.pem -key consul-client-key.pem -CAfile consul-ca.pem
```

## Maintenance

### Scaling the Cluster

To add servers (ensure odd number):

```bash
# Update terraform.tfvars
consul_cluster_size = 5

# Apply changes
terraform plan
terraform apply
```

### Updating Consul

1. Build new image with Packer
2. Update `consul_image_name` in terraform.tfvars
3. Apply changes gradually (rolling update)

### Backup and Restore

```bash
# Create backup
make backup-consul

# Restore from backup
consul snapshot restore <backup-file>
```

## Security Best Practices

1. **Enable TLS** for all communication
2. **Enable ACL** system with proper policies
3. **Restrict network access** to necessary sources
4. **Use bastion hosts** for SSH access
5. **Rotate encryption keys** regularly
6. **Monitor and audit** access logs
7. **Keep software updated** with latest security patches

## Cost Optimization

1. **Right-size instances** based on workload
2. **Use private load balancers** when possible
3. **Schedule non-prod environments** to stop during off-hours
4. **Monitor resource usage** and adjust accordingly

## Support

For issues and questions:
- Check [Consul documentation](https://consul.io/docs)
- Review [IBM Cloud VPC documentation](https://cloud.ibm.com/docs/vpc)
- Consult [Terraform IBM provider docs](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs)