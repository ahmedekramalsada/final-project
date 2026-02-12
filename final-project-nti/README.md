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
Three workflows are defined in Azure DevOps:
- `infrastructure-pipeline.yml`: Provisions AWS Infra (VPC, EKS, API Gateway). Toggle `apply`/`destroy` via parameters.
- `tools-pipeline.yml`: Deploys Helm charts (ArgoCD, SonarQube, etc.). Toggle `apply`/`destroy`.
- `application-pipeline.yml`: CI pipeline for the app. Builds Docker image, pushes to Nexus, scans with Trivy, and updates K8s manifests.

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

## Deployment Status
- **Application**: Currently using a placeholder `nginx` image for verification. Run the `application-pipeline` to deploy the actual app.
- **K8s Manifests**: Located in `k8s/` and managed via ArgoCD (or applied via Tools pipeline).

## Infrastructure as Code
- **Terraform**: `terraform/infrastructure` and `terraform/tools`.
- **State**: Stored in S3 `backend-s3-final-project`.
