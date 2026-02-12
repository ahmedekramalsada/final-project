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
    name  = "controller.service.enabled"
    value = "true"
  }

  set {
    name  = "controller.service.type"
    value = "NodePort"
  }

  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }

  depends_on = [helm_release.aws_load_balancer_controller]
}

# ArgoCD for GitOps-based continuous deployment
# Service type: ClusterIP — accessed via Ingress → NLB → API Gateway
resource "helm_release" "argocd" {
  count = var.enable_argocd ? 1 : 0

  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = var.argocd_chart_version

  # ClusterIP only — routed through Ingress
  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  # Run insecure (no TLS termination at ArgoCD — NLB/Ingress handles it)
  set {
    name  = "server.insecure"
    value = "true"
  }

  # Set the base URL path for ArgoCD behind reverse proxy
  set {
    name  = "server.basehref"
    value = "/argocd"
  }

  set {
    name  = "server.rootpath"
    value = "/argocd"
  }

  depends_on = [helm_release.aws_load_balancer_controller]
}


# --- SonarQube (Code Quality Scanner) ---
# Service type: ClusterIP — accessed via Ingress → NLB → API Gateway
resource "helm_release" "sonarqube" {
  count = var.enable_sonarqube ? 1 : 0

  name             = "sonarqube"
  repository       = "https://sonarsource.github.io/helm-chart-sonarqube"
  chart            = "sonarqube"
  namespace        = "tooling"
  create_namespace = true

  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  # Set context path for SonarQube behind reverse proxy
  set {
    name  = "sonarProperties.sonar\\.web\\.context"
    value = "/sonarqube"
  }

  set {
    name  = "monitoringPasscode"
    value = "admin123" # Change this to a secure value
  }

  set {
    name  = "community.enabled"
    value = "true"
  }

  # SonarQube requires significant memory; t3.medium is the minimum
  set {
    name  = "resources.requests.memory"
    value = "2Gi"
  }

  depends_on = [helm_release.aws_load_balancer_controller]
}


# --- AWS Load Balancer Controller (Required for NLB) ---

data "aws_iam_policy_document" "lb_controller_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [data.terraform_remote_state.infrastructure.outputs.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(data.terraform_remote_state.infrastructure.outputs.oidc_provider_arn, "/^(.*provider/)/", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_policy" "lb_controller_policy" {
  name        = "${var.project}-lb-controller-policy"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/iam_policy.json")
}

resource "aws_iam_role" "lb_controller" {
  name               = "${var.project}-lb-controller-role"
  assume_role_policy = data.aws_iam_policy_document.lb_controller_assume.json
}

resource "aws_iam_role_policy_attachment" "lb_controller_attach" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller_policy.arn
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = data.terraform_remote_state.infrastructure.outputs.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.lb_controller.arn
  }

  depends_on = [aws_iam_role_policy_attachment.lb_controller_attach]
}


# --- Datadog Agent ---
data "vault_kv_secret_v2" "datadog" {
  count = var.enable_datadog ? 1 : 0
  mount = "kv"
  name  = "datadog"
}

resource "helm_release" "datadog" {
  count = var.enable_datadog ? 1 : 0

  name             = "datadog"
  repository       = "https://helm.datadoghq.com"
  chart            = "datadog"
  version          = "3.19.1"
  namespace        = "datadog"
  create_namespace = true

  set {
    name  = "datadog.apiKey"
    value = data.vault_kv_secret_v2.datadog[0].data["api_key"]
  }

  set {
    name  = "datadog.appKey"
    value = data.vault_kv_secret_v2.datadog[0].data["app_key"]
  }

  set {
    name  = "datadog.logs.enabled"
    value = "true"
  }

  set {
    name  = "datadog.logs.containerCollectAll"
    value = "true"
  }

  set {
    name  = "datadog.processAgent.enabled"
    value = "true"
  }

  set {
    name  = "clusterAgent.enabled"
    value = "true"
  }

  set {
    name  = "datadog.kubeStateMetricsEnabled"
    value = "true"
  }

  depends_on = [helm_release.aws_load_balancer_controller]
}
