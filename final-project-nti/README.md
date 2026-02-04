# DevOps Infrastructure Project

This project provisions a comprehensive Kubernetes infrastructure on AWS using Terraform. It includes an EKS cluster, NGINX Ingress, ArgoCD for GitOps, and ephemeral Azure DevOps agents managed by KEDA.

## Architecture Guidelines

-   **Cloud Provider**: AWS (us-east-1)
-   **Orchestrator**: Amazon EKS (v1.30)
-   **Networking**: Custom VPC with public/private subnets and NAT Gateways.
-   **CI/CD**:
    -   **Azure DevOps**: Ephemeral agents running on EKS. The agents are "self-hosted" but spin up on-demand using KEDA (Kubernetes Event-driven Autoscaling).
    -   **ArgoCD**: Continuous Deployment for Kubernetes manifests.
-   **Monitoring**: Datadog (integrated via secrets).
-   **Secrets Management**:
    -   We use **AWS Systems Manager (SSM) Parameter Store** to hold sensitive values.
    -   Terraform allows you to reference these secrets without storing them in your state file.
    -   **IMPORTANT**: You must create these secrets manually.

## Prerequisites

Before you begin, ensure you have the following tools installed:

1.  **Terraform** (>= 1.0)
2.  **AWS CLI** (v2, configured with `aws configure`)
3.  **kubectl** (for interacting with the cluster)

## Step 1: Secret Configuration (CRITICALLY IMPORTANT)

This project uses a "Security First" approach. Terraform **does not create** secrets. It only reads them. You **MUST** manually create the following parameters in AWS SSM Parameter Store before running Terraform. This ensures secrets persist even if you destroy the infrastructure.

### 1.1 Azure DevOps Personal Access Token (PAT)
Required for the ephemeral agents to register with your organization. This token must have **Agent Pools (Read & Manage)** scope.

```bash
aws ssm put-parameter \
    --name "/devops-infrastructure/azuredevops-pat" \
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
export TF_VAR_azuredevops_org_url="https://dev.azure.com/YOUR_ORG"

# Azure DevOps Agent Pool Name (Default: self-hosted-k8s)
# You must create this pool in Azure DevOps -> Project Settings -> Agent Pools first!
export TF_VAR_azuredevops_pool_name="my-k8s-pool"
```

## Step 3: Deployment

Navigate to the `terraform` directory and run:

```bash
cd terraform

# Initialize Terraform (downloads providers)
terraform init

# Validate configuration (checks for syntax errors)
terraform validate

# Plan and Apply (provisions resources)
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

### Docker Image Build & Push
The project includes an ECR repository and an Azure Pipeline configuration to automate the image lifecycle.

1.  **ECR Repository**: Created via Terraform (`ecr.tf`). The URL is available in Terraform outputs.
2.  **Azure Pipeline**: `azure-pipelines.yml` is configured to:
    -   Login to AWS ECR using the self-hosted agent's credentials.
    -   Build the Docker image from `final-project-nti/app`.
    -   Push the image with tags `latest` and the Build ID.

### Ephemeral Azure DevOps Agents
The agents are configured as a **KEDA ScaledJob** in the `azuredevops-agents` namespace. They use a **custom Docker image** stored in ECR.

#### Building the Agent Image (One-Time Setup)
Before agents can scale, you must build and push the custom agent image:

```bash
# Get ECR login
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(terraform output -raw agent_ecr_repository_url)

# Build the agent image
cd ../agent
docker build -t azp-agent .

# Tag and push to ECR
docker tag azp-agent:latest $(terraform output -raw agent_ecr_repository_url):latest
docker push $(terraform output -raw agent_ecr_repository_url):latest
```

#### How Scaling Works
1.  **Idle State**: Run `kubectl get pods -n azuredevops-agents`. You should see **0 agents**.
2.  **Trigger**: Queue a pipeline in Azure DevOps targeting your pool (`self-hosted-k8s`).
3.  **Active**: KEDA detects the queued job and creates a pod (e.g., `azuredevops-agent-scaled-job-xyz`).
4.  **Finish**: The pod processes the job and terminates immediately after completion.

**Troubleshooting Agents**:
-   **Agents not scaling?** Check KEDA logs: `kubectl logs -n keda -l app=keda-operator`
-   **Authentication failed?** Verify your PAT in SSM is correct and explicitly has "Agent Pools (Read & Manage)" permission.
-   **Namespace events**: `kubectl get events -n azuredevops-agents`

### ArgoCD
ArgoCD is installed in the `argocd` namespace for GitOps application delivery.

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
