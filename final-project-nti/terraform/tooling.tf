# NGINX Ingress Controller for routing external traffic
resource "helm_release" "nginx" {
  count = var.enable_nginx_ingress ? 1 : 0

  name             = "nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = var.nginx_chart_version

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }

  depends_on = [module.eks]
}

# ArgoCD for GitOps-based continuous deployment
resource "helm_release" "argocd" {
  count = var.enable_argocd ? 1 : 0

  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = var.argocd_chart_version

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  depends_on = [module.eks]
}

# MongoDB URI stored securely in AWS SSM Parameter Store
resource "aws_ssm_parameter" "mongo_uri" {
  name        = "/${var.project}/mongodb-uri"
  description = "MongoDB connection URI for the application"
  type        = "SecureString"
  value       = var.mongodb_uri

  lifecycle {
    ignore_changes = [value] # Prevents Terraform from overwriting manual updates
  }

  tags = local.common_tags
}

# Datadog API Key stored securely in AWS SSM Parameter Store
resource "aws_ssm_parameter" "datadog_api_key" {
  name        = "/${var.project}/datadog-api-key"
  description = "Datadog API key for monitoring"
  type        = "SecureString"
  value       = var.datadog_api_key

  lifecycle {
    ignore_changes = [value] # Prevents Terraform from overwriting manual updates
  }

  tags = local.common_tags
}

# Data source to read the Datadog API key (after manual update)
data "aws_ssm_parameter" "datadog_api_key" {
  name            = aws_ssm_parameter.datadog_api_key.name
  with_decryption = true

  depends_on = [aws_ssm_parameter.datadog_api_key]
}
