# DevOps Infrastructure Project

This project provisions a comprehensive Kubernetes infrastructure on AWS using Terraform. It includes an EKS cluster, NGINX Ingress, ArgoCD for GitOps, and ephemeral Azure DevOps agents managed by KEDA.

## Architecture Highlights

-   **Cloud Provider**: AWS (us-east-1)
-   **Orchestrator**: Amazon EKS (v1.30)
-   **Networking**: Custom VPC with public/private subnets and NAT Gateways.
-   **CI/CD**:
    -   **Azure DevOps**: Ephemeral agents running on EKS (autoscale 0 -> N).
    -   **ArgoCD**: Continuous Deployment for Kubernetes manifests.
-   **Monitoring**: Datadog (integrated via secrets).
-   **Security**: All sensitive secrets are managed externally via **AWS SSM Parameter Store** and are **NOT** stored in Terraform state.

## Prerequisites

Before you begin, ensure you have the following tools installed:

1.  **Terraform** (>= 1.0)
2.  **AWS CLI** (v2, configured with `aws configure`)
3.  **kubectl** (for interacting with the cluster)

## Step 1: Secret Configuration (CRITICALLY IMPORTANT)

This project uses a "Security First" approach. Terraform **does not create** secrets. It only reads them. You **MUST** manually create the following parameters in AWS SSM Parameter Store before running Terraform. This ensures secrets persist even if you destroy the infrastructure.

### 1.1 Azure DevOps Personal Access Token (PAT)
Required for the ephemeral agents to register with your organization.
*Scope required: Agent Pools (Read & Manage)*

```bash
aws ssm put-parameter \
    --name "/devops-infrastructure/ado-pat" \
    --value "YOUR_AZURE_DEVOPS_PAT" \
    --type "SecureString" \
    --region us-east-1
```

### 1.2 MongoDB Connection URI
Required for the application to connect to the database.

```bash
aws ssm put-parameter \
    --name "/devops-infrastructure/mongodb-uri" \
    --value "mongodb+srv://user:password@cluster..." \
    --type "SecureString" \
    --region us-east-1
```

### 1.3 Datadog API Key
Required for the Datadog Agent (if installed).

```bash
aws ssm put-parameter \
    --name "/devops-infrastructure/datadog-api-key" \
    --value "YOUR_DATADOG_API_KEY" \
    --type "SecureString" \
    --region us-east-1
```

## Step 2: Configure Variables

You can configure the project using environment variables or a `terraform.tfvars` file.

**Required Environment Variables:**
```bash
# Azure DevOps Organization URL
export TF_VAR_ado_org_url="https://dev.azure.com/YOUR_ORG"

# Azure DevOps Agent Pool Name (Default: self-hosted-k8s)
# You must create this pool in ADO first!
export TF_VAR_ado_pool_name="my-k8s-pool"
```

## Step 3: Deployment

Navigate to the `terraform` directory and run:

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan and Apply
terraform apply --auto-approve
```

## Step 4: Accessing the Cluster

After deployment, update your local `kubectl` configuration:

```bash
aws eks update-kubeconfig --region us-east-1 --name devops-cluster
```

Verify access:
```bash
kubectl get nodes
```

## Usage Guides

### Ephemeral Azure DevOps Agents
The agents are configured as a **KEDA ScaledJob**.
1.  **Idle State**: You will see **0 agents** running in the `ado-agents` namespace.
2.  **Trigger**: Queue a pipeline in Azure DevOps targeting your pool (`my-k8s-pool`).
3.  **Active**: KEDA detects the job and launches a pod.
4.  **Finish**: The pod runs the job and terminates immediately.

**Troubleshooting Agents**:
```bash
# Check KEDA logs if agents don't start
kubectl logs -n keda -l app=keda-operator
```

### ArgoCD
ArgoCD is installed in the `argocd` namespace.
-   **Retrieve Admin Password**:
    ```bash
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
    ```
-   **Access UI**: Port-forward the service:
    ```bash
    kubectl port-forward svc/argocd-server -n argocd 8080:443
    ```
    Open `https://localhost:8080`.

## Clean Up

To destroy the infrastructure (this will **NOT** delete your manual secrets in SSM):

```bash
terraform destroy --auto-approve
```
