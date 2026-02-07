# Project Documentation & Breakdown

## 1. Project Overview
This project is a complete DevOps showcase implementing a Three-Tier Architecture using **AWS EKS (Elastic Kubernetes Service)**, **Terraform (Infrastructure as Code)**, and **Azure DevOps (CI/CD)**. It demonstrates a full software delivery lifecycle from code commit to production deployment, including infrastructure provisioning, security scanning, and GitOps-based CD.

### Core Technologies
*   **Compute**: AWS EKS (Kubernetes)
*   **IaC**: Terraform (Modularized)
*   **CI/CD**: Azure DevOps Pipelines
*   **GitOps**: ArgoCD
*   **Container Registry**: AWS ECR
*   **Security & Auth**: AWS Cognito, SonarQube, Trivy
*   **Networking**: AWS VPC, API Gateway, NGINX Ingress
*   **Tooling**: HashiCorp Vault, Sonatype Nexus, KEDA

---

## 2. Component Analysis

### A. Application (`/app`)
*   **What it is**: A simple Node.js/Express.js web application.
*   **Key Files**:
    *   `server.js`: The entry point. It sets up an Express server listening on port 3000 and exposes a generic "Hello World" endpoint.
    *   `package.json`: Manages dependencies (`express`, `mongoose`) and scripts (`npm start`).
    *   `Dockerfile`: (Implied) Used to containerize this application.
*   **Why we use it**: To serve as a sample workload to demonstrate the CI/CD pipeline and deployment capabilities.
*   **How to use**: Local run via `npm start`. In production, it runs as a Docker container in K8s.

### B. Kubernetes Manifests (`/k8s`)
*   **What it is**: YAML configurations defining how the app runs in the cluster.
*   **Key Files**:
    *   `deployment.yaml`: Defines a Kubernetes **Deployment** with 2 replicas. It pulls the image from ECR, sets resource limits (requests/limits), and configures liveness/readiness probes for high availability.
    *   `service.yaml`: Defines a **Service** (ClusterIP) to expose the app internally and an **Ingress** resource to expose it externally via the NGINX Ingress Controller.
    *   `argocd-app.yaml`: An **Application** CRD for ArgoCD. This tells ArgoCD to watch this Git repository and sync changes to the cluster automatically (GitOps).
*   **Why we use it**: To declaratively manage the application state in Kubernetes, ensuring consistency and simplified rollbacks.

### C. CI/CD Pipelines (`/pipelines`)
*   **What it is**: Automation definitions for Azure DevOps.
*   **Key Files**:
    *   `application-pipeline.yml`:
        *   **Triggers**: Changes in `app/`.
        *   **Flow**: SonarQube Analysis -> Build Docker Image -> Push to ECR -> Trivy Security Scan -> Publish Manifests.
        *   **Purpose**: Ensures code quality and security before delivering the artifact.
    *   `infrastructure-pipeline.yml`:
        *   **Triggers**: Changes in `terraform/infrastructure/`.
        *   **Flow**: Terraform Init -> Validate -> Plan -> Apply.
        *   **Purpose**: Automates the provisioning of AWS resources (VPC, EKS, etc.).
    *   `tools-pipeline.yml`:
        *   **Triggers**: Changes in `terraform/tools/`.
        *   **Flow**: Terraform Init -> Plan -> Apply.
        *   **Purpose**: Deploys Helm charts for tooling (Nginx, ArgoCD, SonarQube) *after* the base infra is ready.

### D. Infrastructure (`/terraform/infrastructure`)
*   **What it is**: Terraform code for the base AWS environment.
*   **Key Files**:
    *   `vpc.tf`: Creates the Virtual Private Cloud with public/private subnets and NAT Gateways. Foundation of the network.
    *   `eks.tf`: Provisions the EKS Cluster and Worker Node Groups.
    *   `ecr.tf`: Creates Elastic Container Registries for the App and the Build Agent.
    *   `api_gateway.tf`: Sets up an AWS HTTP API Gateway as the entry point, integrated with Cognito for authentication.
    *   `Cognito.tf`: Manages User Pools to secure access to the application.
    *   `bastion.tf`: A secure EC2 "jump box" to allow administrators to SSH in and run `kubectl` commands.
    *   `azuredevops_agent.tf` & `keda.tf`: Deploys self-hosted Azure DevOps agents into the cluster that auto-scale using KEDA based on workload.
    *   `provider.tf`, `variables.tf`: Configuration for AWS provider and input variables.

### E. Tooling (`/terraform/tools`)
*   **What it is**: Terraform code to deploy operational tools via Helm.
*   **Key Files**:
    *   `tooling.tf`: Contains `helm_release` resources for:
        *   **NGINX Ingress**: Traffic management.
        *   **ArgoCD**: GitOps operator.
        *   **SonarQube**: Code quality dashboard.
        *   **Nexus**: Artifact storage.
        *   **Vault**: Secrets management.
    *   **Load Balancing**: All these tools are configured as `type: LoadBalancer` in their respective Helm charts, which automatically provisions AWS Elastic Load Balancers (ELBs) for external access.
    *   `remote_state.tf`: Configures backend state storage.

---

## 3. Workflow & Usage

### 1. The Deployment Workflow
1.  **Infrastructure Setup**: Run the `Infrastructure Pipeline` to create VPC, EKS, and ECR.
2.  **Tooling Setup**: Run the `Tools Pipeline` to install ArgoCD and Nginx into the EKS cluster.
3.  **Application Deployment**:
    *   Developer pushes code to `app/`.
    *   `Application Pipeline` builds image, pushes to ECR.
    *   Pipeline (or image updater) updates the image tag in `k8s/deployment.yaml`.
    *   ArgoCD detects the change in Git and syncs (deploys) the new image to the cluster.

### 2. How to Access
*   **App URL**: Accessible via the NGINX Ingress LoadBalancer DNS name.
*   **Platform Tools**: Each tool (ArgoCD, SonarQube, etc.) provides a unique LoadBalancer DNS URL found in the `kubectl get svc` output.
*   **Bastion**: SSH into the public IP (output from Terraform) to debug cluster issues.

## 4. Best Practices & Suggestions

### Current Best Practices Implemented
*   **Modular Architecture**: Separation of App, Infra, and Tools.
*   **GitOps**: Using ArgoCD for application state management.
*   **Security**: Scans (SonarQube, Trivy) in pipeline; Private subnets for nodes; Cognito for Auth.
*   **Scalability**: KEDA for scaling build agents; HPA/VPA (implied capability of K8s).

### Suggestions for Improvement
1.  **API Gateway Integration**: The `api_gateway.tf` uses a placeholder IP (`1.1.1.1`). **Fix**: Use a Network Load Balancer (NLB) for Ingress and point API Gateway to the NLB's DNS name or ARN dynamically.
2.  **Secret Management**:
    *   Currently, some secrets are manually assumed in SSM.
    *   **Recommendation**: Integrate "External Secrets Operator" in K8s to fetch SSM parameters directly as K8s secrets, avoiding manual variable passing in Terraform.
3.  **State Management**:
    *   Ensure DynamoDB locking is enabled for Terraform state to prevent concurrent modifications.
4.  **Pipeline Templates**:
    *   Extract common steps (like "Build and Push") into Azure DevOps Templates to reduce code duplication across pipelines.
