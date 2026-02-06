# DevOps Infrastructure Project

This project provisions a complete AWS infrastructure with EKS, sets up a 3-stage deployment pipeline using Azure DevOps, and deploys a sample application with ArgoCD.

## Directory Structure

We adhere to a layered architecture to separate concerns:

```text
/
├── terraform/
│   ├── infrastructure/   # Base Infrastructure (VPC, EKS, ECR)
│   └── tools/            # Cluster Tools (Nginx, ArgoCD, Agents) - Depends on Infrastructure
├── pipelines/            # Azure DevOps Pipeline Definitions
│   ├── infrastructure-pipeline.yml
│   ├── tools-pipeline.yml
│   └── application-pipeline.yml
├── k8s/                  # Kubernetes Manifests for the Application
└── app/                  # Application Source Code
```

## Pipelines

### 1. Infrastructure Pipeline (`pipelines/infrastructure-pipeline.yml`)
*   **Goal**: Provisions the base AWS environment and essential system components.
*   **Triggers**: Changes to `terraform/infrastructure/`.
*   **Key Resources**: VPC, EKS Cluster, ECR Repositories, KEDA, Azure DevOps Agents.

### 2. Tools Pipeline (`pipelines/tools-pipeline.yml`)
*   **Goal**: Installs shared cluster services.
*   **Triggers**: Changes to `terraform/tools/`.
*   **Dependency**: Reads `infrastructure` state to configure the Kubernetes provider.
*   **Key Resources**: Nginx Ingress, ArgoCD.

### 3. Application Pipeline (`pipelines/application-pipeline.yml`)
*   **Goal**: Builds and deploys the application.
*   **Triggers**: Changes to `app/`.
*   **Steps**: Build Docker Image -> Push to ECR -> Update Manifests -> ArgoCD Sync.

## Getting Started

### Prerequisites
*   AWS CLI configured.
*   Terraform installed (`>= 1.0`).
*   Azure DevOps Project created.
*   S3 Bucket for Terraform Backend: `backend-s3-final-project`.

### Local Development

1.  **Deploy Infrastructure**:
    ```bash
    cd terraform/infrastructure
    terraform init
    terraform apply
    ```

2.  **Deploy Tools**:
    ```bash
    cd ../tools
    terraform init
    terraform apply
    ```
    *Note: This requires the infrastructure to be applied first.*

3.  **Deploy Application**:
    *   Push changes to the repository to trigger the pipeline, or apply manifests manually via `kubectl` or ArgoCD.

## Secret Management
Sensitive values (e.g., Datadog API Key, Azure DevOps PAT) are managed via AWS SSM Parameter Store and referenced in Terraform.

## Current Infrastructure Snapshot (as of Feb 2026)
- **Active Compute**: 1x `t3.micro` EC2 in `us-east-1` (Azure DevOps Agent).
- **Storage**: S3 bucket `backend-s3-final-project` for state management.
- **Networking**: Default VPCs available in `us-east-1` and `eu-north-1`. All custom infrastructure cleaned up.
