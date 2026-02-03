# DevOps Infrastructure - Final Project NTI

Production-ready AWS EKS cluster with ArgoCD and NGINX Ingress, built with Terraform best practices.

## 📁 File Structure

```
terraform/
├── versions.tf               # Terraform and provider version constraints
├── variables.tf              # All input variables with validation
├── locals.tf                 # Common tags and computed values
├── outputs.tf                # All output values
├── terraform.tfvars.example  # Example variable values
├── provider.tf               # Provider configurations
├── vpc.tf                    # VPC module
├── eks.tf                    # EKS cluster module
├── api_gateway.tf            # HTTP API Gateway
└── tooling.tf                # Helm releases (NGINX, ArgoCD)
```

## 🏗️ Infrastructure Components

| Component | Description |
|-----------|-------------|
| **VPC** | Multi-AZ with public/private subnets, NAT gateway |
| **EKS Cluster** | Kubernetes 1.30 with managed node groups |
| **API Gateway** | HTTP API with CORS and CloudWatch logging |
| **NGINX Ingress** | Kubernetes ingress controller (optional) |
| **ArgoCD** | GitOps continuous deployment (optional) |

## ⚙️ Prerequisites

- AWS CLI configured with credentials
- Terraform >= 1.0
- kubectl
- S3 bucket for Terraform state

## 🚀 Quick Start

```bash
cd terraform

# Copy and customize variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Deploy
terraform init
terraform plan
terraform apply
```

## 📋 Configuration

### Key Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `us-east-1` | AWS region |
| `environment` | `production` | Environment name |
| `cluster_name` | `devops-cluster` | EKS cluster name |
| `cluster_version` | `1.30` | Kubernetes version |
| `node_instance_types` | `["t3.medium"]` | Node instance types |
| `node_desired_size` | `2` | Desired node count |
| `enable_nginx_ingress` | `true` | Deploy NGINX |
| `enable_argocd` | `true` | Deploy ArgoCD |

See `terraform.tfvars.example` for all available options.

## 📤 Outputs

After deployment:

```bash
# Configure kubectl
$(terraform output -raw configure_kubectl)

# Get cluster endpoint
terraform output cluster_endpoint

# Get API Gateway URL
terraform output gateway_url
```

## 🧹 Cleanup

```bash
terraform destroy --auto-approve
```

## 💡 Best Practices Applied

- ✅ Separated version constraints (`versions.tf`)
- ✅ Centralized variables with validation
- ✅ Common tags via locals
- ✅ Conditional resource creation
- ✅ Sensitive data marked appropriately
- ✅ Consolidated outputs with descriptions
