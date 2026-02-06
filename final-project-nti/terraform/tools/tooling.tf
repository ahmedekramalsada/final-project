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

}

# MongoDB URI (Externally Managed in SSM)
data "aws_ssm_parameter" "mongo_uri" {
  name            = "/${var.project}/mongodb-uri"
  with_decryption = true
}

# Datadog API Key (Externally Managed in SSM)
data "aws_ssm_parameter" "datadog_api_key" {
  name            = "/${var.project}/datadog-api-key"
  with_decryption = true
}


# --- SonarQube (Code Quality Scanner) ---
resource "helm_release" "sonarqube" {
  name             = "sonarqube"
  repository       = "https://SonarSource.github.io/helm-charts-sonarqube"
  chart            = "sonarqube"
  namespace        = "tooling"
  create_namespace = true

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  # SonarQube requires significant memory; t3.medium is the minimum
  set {
    name  = "resources.requests.memory"
    value = "2Gi"
  }
}

# --- Sonatype Nexus (Artifact Repository) ---
resource "helm_release" "nexus" {
  name             = "nexus"
  repository       = "https://sonatype.github.io/helm3-charts/"
  chart            = "nexus-repository-manager"
  namespace        = "tooling"
  create_namespace = true

  set {
    name  = "nexus.service.type"
    value = "LoadBalancer"
  }
}
