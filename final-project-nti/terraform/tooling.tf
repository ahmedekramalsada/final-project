# --- Helm Provider Configuration ---
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--output", "json"]
    }
  }
}

# --- NGINX Ingress Controller ---
resource "helm_release" "nginx" {
  name             = "nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true

  depends_on = [module.eks]
}

# --- ArgoCD ---
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  depends_on = [module.eks]
}

# --- Datadog (API Key from SSM Parameter Store) ---
# NOTE: Update the SSM parameter /devops/datadog-api-key in AWS Console with your real key
# Get your API key from: https://app.datadoghq.com/account/settings#api
resource "helm_release" "datadog" {
  name             = "datadog"
  repository       = "https://helm.datadoghq.com"
  chart            = "datadog"
  namespace        = "datadog"
  create_namespace = true

  # Don't wait for pods - they won't be healthy until a valid API key is set
  wait    = false
  timeout = 600

  set_sensitive {
    name  = "datadog.apiKey"
    value = data.aws_ssm_parameter.datadog_api_key.value
  }

  depends_on = [module.eks, data.aws_ssm_parameter.datadog_api_key]
}

# --- Outputs ---
output "nginx_ingress_namespace" {
  description = "Namespace where NGINX Ingress is installed"
  value       = helm_release.nginx.namespace
}

output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = helm_release.argocd.namespace
}

output "datadog_namespace" {
  description = "Namespace where Datadog is installed"
  value       = helm_release.datadog.namespace
}
