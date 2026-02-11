# DevOps Infrastructure Project

This project provisions a complete AWS infrastructure with EKS, sets up a 3-stage deployment pipeline using Azure DevOps, and deploys a sample application with ArgoCD.

### 📚 Detailed Documentation
**[Click here for a comprehensive breakdown of every file and component in this project](./PROJECT_BREAKDOWN.md)**.
This document explains "what it is, what it does, and why we use it" for every element in the codebase.

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

### 1. Infra Pipeline (`pipelines/infrastructure-pipeline.yml`)
*   **Stage**: **Infra**
*   **Directory**: `terraform/infrastructure/`
*   **Goal**: Provisions the base AWS environment and essential networking/compute components.
*   **Components**:
    *   **VPC & Subnets**: Networking foundation.
    *   **EKS**: Kubernetes Cluster.
    *   **Cognito**: User Authentication.
    *   **API Gateway**, **Agents**.
    *   **Nexus**: Application Artifact Repository (replacing ECR).
    *   **Vault**: Secrets Management (replacing SSM).

### 2. Platform Pipeline (`pipelines/tools-pipeline.yml`)
*   **Stage**: **Platform**
*   **Directory**: `terraform/tools/`
*   **Goal**: Installs shared cluster services and platform tools.
*   **Dependency**: Runs after Infra pipeline; reads `infrastructure` state.
*   **Components**:
    *   **ArgoCD**: GitOps Continuous Delivery.
    *   **Sonatype Nexus**: Artifact Repository.
    *   **HashiCorp Vault**: Secrets Management.
    *   **SonarQube**: Code Quality Scanner.
    *   **Nginx Ingress Controller**: Traffic routing.

### 3. CI/CD Pipeline (`pipelines/application-pipeline.yml`)
*   **Stage**: **CI/CD**
*   **Directory**: `pipelines/` & `app/`
*   **Goal**: Builds, secures, and deploys the application.
*   **Flow**:
    1.  **CI (Continuous Integration)**:
        *   **Image Build**: Docker build.
        *   **Trivy Scan**: Container image security scan.
        *   **SAST**: SonarQube static analysis.
        *   **Image Push**: Push to Nexus.
    2.  **CD (Continuous Delivery)**:
        *   **ArgoCD**: Syncs changes to the cluster (GitOps).

## Networking & Load Balancing

This project uses a multi-layered networking approach to ensure high availability and secure access:

- **AWS Load Balancers**:
    - **Static NLB**: Provisioned in the `infrastructure` pipeline. This remains static regardless of cluster changes.
    - **NGINX Ingress Controller**: Configured in `tools` to bind to the static NLB Target Group.
    - **Platform Tools**: ArgoCD, SonarQube, etc., are exposed via their own Load Balancers.
- **Traffic Routing**: External traffic hits the Load Balancer, which routes to the NGINX Ingress Controller, which then forwards traffic to the appropriate `ClusterIP` service based on the hostname/path.
- **API Gateway**: Provides an additional layer of management and security (via Cognito) for programmatic access.

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
    
    # 1. Create terraform.tfvars with your Vault credentials
    # vault_addr = "http://..."
    # vault_token = "hvs..."
    
    # 2. Import the existing IAM role (if it exists)
    terraform import aws_iam_role.lb_controller devops-infrastructure-lb-controller-role
    
    # 3. Apply
    terraform apply
    ```
    *Note: This requires the infrastructure to be applied first.*

3.  **Deploy Application**:
    *   **Cluster Tools**: ArgoCD, KEDA, Nginx, and other platform tools are installed via Terraform Helm releases.
    *   **AWS Load Balancer Controller**: Properly configured with IAM permissions to manage ELBs/NLBs.
    *   **Application Workload**: Push changes to trigger the application pipeline, which uses ArgoCD for GitOps deployment.

## Secret Management
Sensitive values (e.g., Datadog API Key, Azure DevOps PAT) are managed via **HashiCorp Vault**. 
The `tools` directory uses a `terraform.tfvars` file (gitignored) to store the Vault address and token for local execution.

## Troubleshooting
If you encounter `EntityAlreadyExists` for the LB controller role, ensure you have imported the existing role into your state:
`terraform import aws_iam_role.lb_controller devops-infrastructure-lb-controller-role`

If you encounter `Unsupported attribute` errors in `tools` regarding `oidc_provider_arn`, it means your infrastructure state is incomplete. Run `terraform apply` in `terraform/infrastructure` to fix it.

If you encounter `Client.Timeout` or `context deadline exceeded` errors during `tools` application:
1. Run `aws eks update-kubeconfig --name devops-cluster --region us-east-1`
2. Run `terraform refresh` in `terraform/tools` to update the state with the correct cluster endpoint.

If terraform destroy gets stuck on a subnet (e.g. `module.vpc.aws_subnet.private[0]`):
1. Verify the subnet is already deleted in AWS console or CLI.
2. Run `terraform state rm 'module.vpc.aws_subnet.private[0]'` to remove it from state.
