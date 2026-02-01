# DevOps Infrastructure - Final Project NTI

This repository contains the Terraform infrastructure code for provisioning a production-ready AWS EKS cluster with supporting services.

## 📋 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud                                   │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                         VPC (10.0.0.0/16)                         │  │
│  │                                                                    │  │
│  │   ┌─────────────────────┐     ┌─────────────────────┐            │  │
│  │   │  Public Subnet A     │     │  Public Subnet B     │           │  │
│  │   │  10.0.101.0/24       │     │  10.0.102.0/24       │           │  │
│  │   │  (us-east-1a)        │     │  (us-east-1b)        │           │  │
│  │   └─────────┬───────────┘     └─────────┬───────────┘            │  │
│  │             │         NAT Gateway        │                        │  │
│  │   ┌─────────▼───────────┐     ┌─────────▼───────────┐            │  │
│  │   │  Private Subnet A    │     │  Private Subnet B    │           │  │
│  │   │  10.0.1.0/24         │     │  10.0.2.0/24         │           │  │
│  │   │  (us-east-1a)        │     │  (us-east-1b)        │           │  │
│  │   │                      │     │                      │           │  │
│  │   │  ┌────────────────────────────────────────────┐  │           │  │
│  │   │  │           EKS Cluster (devops-cluster)     │  │           │  │
│  │   │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  │  │           │  │
│  │   │  │  │ Worker 1 │  │ Worker 2 │  │ Worker N │  │  │           │  │
│  │   │  │  │t3.medium │  │t3.medium │  │t3.medium │  │  │           │  │
│  │   │  │  └──────────┘  └──────────┘  └──────────┘  │  │           │  │
│  │   │  └────────────────────────────────────────────┘  │           │  │
│  │   └─────────────────────┘     └─────────────────────┘            │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐  │
│  │  API Gateway    │  │  SSM Parameter  │  │  CloudWatch Logs        │  │
│  │  (HTTP API)     │  │  Store          │  │  (API Gateway Logs)     │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

## 🏗️ Infrastructure Components

| Component | Description | File |
|-----------|-------------|------|
| **VPC** | Network isolation with public/private subnets across 2 AZs | `vpc.tf` |
| **EKS Cluster** | Kubernetes 1.30 cluster with managed node groups | `eks.tf` |
| **API Gateway** | HTTP API endpoint with CORS and access logging | `api_gateway.tf` |
| **NGINX Ingress** | Kubernetes ingress controller for external traffic routing | `tooling.tf` |
| **ArgoCD** | GitOps continuous deployment tool | `tooling.tf` |
| **SSM Parameters** | Secure storage for sensitive configuration (MongoDB URI) | `tooling.tf` |
| **Bastion Host** | EC2 instance for secure EKS access from private endpoint | `bastion.tf` |

## 📁 File Structure

```
terraform/
├── provider.tf       # AWS, Helm, and Kubernetes provider configuration + S3 backend + VPC + EKS
├── bastion.tf        # Bastion host for EKS cluster access
├── tooling.tf        # Helm releases (NGINX, ArgoCD)
└── main.tf           # SSM parameters and additional outputs
```

## ⚙️ Prerequisites

Before deploying this infrastructure, ensure you have:

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** >= 1.0 installed
3. **kubectl** installed for cluster access
4. **An S3 bucket** for Terraform state storage

> **⚠️ Important**: The provider configuration explicitly uses `--output json` for the `aws eks get-token` command. If you have issues, ensure your AWS CLI is up to date (`aws --version`).

## 🔧 Configuration

### Required Updates

Before running Terraform, update the following placeholders:

| File | Placeholder | Description |
|------|-------------|-------------|
| `provider.tf` | `backend-s3-final-project` | S3 bucket name for Terraform state |

### Managing Secrets with SSM Parameter Store

Sensitive values are stored securely in AWS SSM Parameter Store:

| SSM Parameter | Description | How to Update |
|---------------|-------------|---------------|
| `/devops/datadog-api-key` | Datadog API Key | AWS Console or CLI |
| `/devops/mongodb-uri` | MongoDB connection URI | AWS Console or CLI |

**To update the Datadog API key:**

```bash
# Option 1: Using AWS CLI
aws ssm put-parameter \
  --name "/devops/datadog-api-key" \
  --value "YOUR_ACTUAL_API_KEY" \
  --type SecureString \
  --overwrite

# Then restart Datadog pods to pick up new key
kubectl rollout restart deployment -n datadog

# Option 2: Using AWS Console
# 1. Go to AWS Console → Systems Manager → Parameter Store
# 2. Find /devops/datadog-api-key
# 3. Click Edit → Enter your real API key → Save
# 4. Restart pods: kubectl rollout restart deployment -n datadog
```

> 💡 **Tip**: Get your Datadog API key from: https://app.datadoghq.com/account/settings#api

## 🚀 Deployment

### Step 1: Initialize Terraform

```bash
cd terraform
terraform init
```

This will:
- Download required providers (AWS, Helm, Kubernetes)
- Initialize the S3 backend for state management
- Download required modules (VPC, EKS)

### Step 2: Plan the Deployment

```bash
terraform plan
```

Review the planned changes to ensure everything looks correct.

### Step 3: Apply the Configuration

```bash
terraform apply --auto-approve
```

> ⚠️ **Note**: The full deployment takes approximately 15-20 minutes, primarily due to EKS cluster creation.

### Step 4: Access Cluster via Bastion Host

The EKS cluster uses a **private endpoint only** for enhanced security. You must access it through the bastion host.

**SSH into the bastion host:**

```bash
# Get the SSH command from Terraform outputs
terraform output bastion_ssh_command

# Or use this directly (replace IP with your bastion IP):
ssh -i ~/.ssh/terraform-key ec2-user@<BASTION_PUBLIC_IP>
```

**Configure kubectl on the bastion:**

```bash
# On the bastion host, run:
./configure-eks.sh

# Or manually:
aws eks update-kubeconfig --region us-east-1 --name devops-cluster
kubectl get nodes
```

**Alternative: Use AWS SSM Session Manager (no SSH key required):**

```bash
# Get instance ID from Terraform
terraform output bastion_instance_id

# Start session
aws ssm start-session --target <INSTANCE_ID>
```

## 📤 Outputs

After successful deployment, Terraform will output:

| Output | Description |
|--------|-------------|
| `gateway_url` | API Gateway endpoint URL |
| `cluster_endpoint` | EKS cluster API endpoint |
| `cluster_name` | Kubernetes cluster name |
| `cluster_security_group_id` | Security group ID for the cluster |
| `nginx_ingress_namespace` | Namespace where NGINX Ingress is installed |
| `argocd_namespace` | Namespace where ArgoCD is installed |
| `bastion_public_ip` | Public IP address of the bastion host |
| `bastion_ssh_command` | Ready-to-use SSH command for bastion access |
| `bastion_instance_id` | Instance ID for SSM Session Manager |

## 🔐 Security Considerations

- **Private EKS Endpoint**: Cluster API is only accessible from within the VPC
- **Bastion Host**: Secure jump box for cluster access with SSH and SSM Session Manager
- **Private Subnets**: EKS worker nodes run in private subnets
- **NAT Gateway**: Outbound internet access for private subnets
- **SSM SecureString**: Sensitive data (MongoDB URI) stored encrypted
- **IAM**: Cluster creator automatically gets admin permissions

## 📊 Monitoring & Observability

- **CloudWatch Logs**: API Gateway access logs with 30-day retention
- **NGINX Metrics**: Ingress controller metrics enabled for Prometheus scraping
- **Datadog**: (Optional) SSM parameter prepared for Datadog integration

## 💡 Best Practices Implemented

1. **Version Pinning**: All modules and Helm charts have pinned versions for reproducibility
2. **Resource Tagging**: All resources tagged with Environment, Project, and ManagedBy
3. **Multi-AZ Deployment**: VPC and EKS span 2 Availability Zones for high availability
4. **Explicit Dependencies**: Helm releases depend on EKS module completion
5. **CORS Configuration**: API Gateway configured with proper CORS for web applications
6. **AWS CLI JSON Output**: Provider uses `--output json` for compatibility with all AWS CLI configurations

## 🛠️ Troubleshooting

### Invalid Character Error During `terraform init`

If you encounter an error like:

```
Error: Invalid character
The ";" character is not valid. Use newlines to separate arguments and blocks, and commas to separate items in collection values.
```

**Solution**: HCL (HashiCorp Configuration Language) uses **commas** or **newlines** to separate attributes, not semicolons. Update the syntax:

```hcl
# ❌ Wrong
aws = { source = "hashicorp/aws"; version = "~> 5.0" }

# ✅ Correct
aws = { source = "hashicorp/aws", version = "~> 5.0" }
```

### kubectl Timeout from Bastion Host

If you get timeout errors like:

```
dial tcp 10.0.x.x:443: i/o timeout
```

**Cause**: The EKS cluster security group isn't allowing traffic from the bastion host.

**Solution**: Ensure the security group rule in `bastion.tf` is applied:

```hcl
resource "aws_security_group_rule" "bastion_to_eks" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks.cluster_security_group_id
  source_security_group_id = aws_security_group.bastion.id
}
```

Then run `terraform apply` to apply the rule.

## 🧹 Cleanup

To destroy all resources:

```bash
terraform destroy --auto-approve
```

> ⚠️ **Warning**: This will delete all infrastructure including the EKS cluster and data.

## 📝 Suggestions for Improvement

1. **Enable Cluster Autoscaler**: Add the Kubernetes Cluster Autoscaler for dynamic node scaling
2. **Add Monitoring Stack**: Deploy Prometheus + Grafana via Helm for comprehensive monitoring
3. **Implement AWS WAF**: Add Web Application Firewall in front of the API Gateway
4. **Enable VPC Flow Logs**: For network traffic analysis and security auditing
5. **Add Secrets Management**: Consider AWS Secrets Manager or HashiCorp Vault for secrets rotation
6. **Implement Backup Strategy**: Configure Velero for Kubernetes backup and disaster recovery

## 📄 License

This project is part of the DevOps Final Project NTI infrastructure.
