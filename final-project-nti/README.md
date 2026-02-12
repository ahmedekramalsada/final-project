# DevOps Infrastructure & Tooling Project

## Overview
This project provisions a comprehensive mock enterprise infrastructure on AWS using Terraform and Kubernetes. It features a secure, centralized access pattern where all services are exposed via a single **API Gateway** endpoint, authenticated by **Cognito**.

## Architecture
- **Infrastructure**: AWS VPC, EKS Cluster, Network Load Balancer (NLB), API Gateway, Cognito User Pool.
- **Tools**: ArgoCD (GitOps), SonarQube (Code Quality), Nexus (Artifact Registry), Datadog (Monitoring), KEDA (Autoscaling).
- **Security**: 
  - Single Entry Point: API Gateway.
  - Authentication: Cognito JWT Authorizer.
  - Secrets: HashiCorp Vault.
  - Traffic Flow: User -> API Gateway -> VPC Link -> NLB -> Ingress Nginx -> Service (App/Tools).

## Project Structure

```
├── terraform/
│   ├── infrastructure/     # VPC, EKS, NLB, API Gateway, Cognito, Secrets
│   └── tools/              # Helm releases (ArgoCD, SonarQube, NGINX, Datadog, KEDA), IAM, K8s manifests
├── pipelines/
│   ├── infrastructure-pipeline.yml   # Terraform apply/destroy for infra
│   ├── tools-pipeline.yml            # Terraform apply/destroy for tools
│   ├── destroy-pipeline.yml          # Ordered destroy: Tools → Infrastructure
│   └── application-pipeline.yml      # CI: build, scan, push, deploy via ArgoCD
├── k8s/                    # Kubernetes manifests (Deployment, Service, Ingress, KEDA, TGB)
├── scripts/                # Standalone utility scripts (not used by Terraform)
└── app/                    # Application source code
```

## Terraform Dependency & Destroy Order

### Infrastructure Layer (`terraform/infrastructure`)
Resources are created/destroyed in proper dependency order:
- **VPC** → **EKS** → **NLB** → **API Gateway** → **Cognito** → **Secrets**

### Tools Layer (`terraform/tools`)
Destroy ordering handled by pure Terraform dependency graph (no scripts):
- **Apps** (NGINX, ArgoCD, SonarQube, Datadog) depend on **AWS LB Controller**
- Terraform destroys in reverse: apps first, then LB controller, then IAM
- K8s TargetGroupBinding is a native `kubernetes_manifest` — tracked by Terraform state
- KEDA ScaledJob cleanup is handled by namespace deletion

### Destroy Pipeline
The `destroy-pipeline.yml` runs a **two-stage** ordered destroy:
1. **Stage 1**: Destroy Tools (Helm releases, K8s resources, IAM)
2. **Stage 2**: Destroy Infrastructure (API Gateway, NLB, EKS, VPC) — only after Tools succeeds

## Access Information

### API Gateway Endpoint (Single URL for all services)
**URL**: `https://3ig6d5ivqd.execute-api.us-east-1.amazonaws.com/`

### Routes
| Service | Route | Auth Required |
|---------|-------|---------------|
| Application | `/` | Yes (Cognito JWT) |
| ArgoCD | `/argocd` | Yes (Cognito JWT) |
| SonarQube | `/sonarqube` | Yes (Cognito JWT) |

### Credentials
- **Cognito Admin User**: `admin@devops.com` / `Admin@123!`
- **SonarQube**: `admin` / `admin123`
- **ArgoCD**: `admin` / (Initial password is the server pod name, retrieve via `kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d`)

## How to Run

### 1. Pipelines
Four workflows are defined in Azure DevOps:
- `infrastructure-pipeline.yml`: Provisions AWS Infra (VPC, EKS, API Gateway). Toggle `apply`/`destroy` via parameters. Includes init, validate, plan (apply only), and apply/destroy steps.
- `tools-pipeline.yml`: Deploys Helm charts (ArgoCD, SonarQube, etc.). Toggle `apply`/`destroy`. Includes init, validate, and apply/destroy steps.
- `destroy-pipeline.yml`: **Ordered full teardown** — destroys tools first, then infrastructure.
- `application-pipeline.yml`: CI pipeline for the app. Builds Docker image, pushes to Nexus, scans with Trivy, and updates K8s manifests for ArgoCD.

### 2. Manual Verification
To access the services, you need a **Bearer Token** from Cognito.

**Get Token:**
```bash
aws cognito-idp initiate-auth --client-id 4q4lpke3400gk5o3hj5gtivvd5 --auth-flow USER_PASSWORD_AUTH --auth-parameters USERNAME=admin@devops.com,PASSWORD='Admin@123!' --region us-east-1
```
Use the `AccessToken` or `IdToken` in the `Authorization` header.

**Access via Browser:**
Use a browser extension like "ModHeader" to add `Authorization: <your_token>` and navigate to the API Gateway URL.

**Access via Curl:**
```bash
curl -H "Authorization: <your_token>" https://3ig6d5ivqd.execute-api.us-east-1.amazonaws.com/
```

## Best Practices Applied
- **No script-based destroy**: All destroy ordering handled by Terraform dependency graph
- **Timeouts**: All Helm releases have `timeout = 600` for reliability
- **Vault provider aligned**: Both infra and tools use `~> 4.0`
- **Pipeline validation**: Both pipelines include `terraform validate` step
- **Gitignore**: Comprehensive exclusions for `.terraform/`, state files, and secrets
- **Native K8s resources**: TargetGroupBinding managed as `kubernetes_manifest` instead of `null_resource`
- **File naming**: Terraform files use lowercase convention

## Infrastructure as Code
- **Terraform**: `terraform/infrastructure` and `terraform/tools`.
- **State**: Stored in S3 `backend-s3-final-project`.
- **Provider Versions**: AWS `~> 5.0`, Helm `~> 2.12`, Kubernetes `~> 2.25`, Vault `~> 4.0`.
