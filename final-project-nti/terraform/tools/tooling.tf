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

# --- HashiCorp Vault (Secrets Management) ---
resource "helm_release" "vault" {
  name             = "vault"
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  namespace        = "tooling"
  create_namespace = true

  set {
    name  = "ui.enabled"
    value = "true"
  }

  set {
    name  = "ui.service.type"
    value = "LoadBalancer"
  }
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

resource "aws_iam_role" "lb_controller" {
  name               = "${var.project}-lb-controller-role"
  assume_role_policy = data.aws_iam_policy_document.lb_controller_assume.json
}

resource "aws_iam_role_policy_attachment" "lb_controller_attach" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLoadBalancerControllerIAMPolicy"
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
}

# --- TargetGroupBinding (Connects NGINX to Static Infra NLB) ---
resource "kubernetes_manifest" "nginx_tgb" {
  manifest = {
    apiVersion = "elbv2.k8s.aws/v1beta1"
    kind       = "TargetGroupBinding"
    metadata = {
      name      = "nginx-tgb"
      namespace = "ingress-nginx"
    }
    spec = {
      serviceRef = {
        name = "nginx-ingress-nginx-controller" # Check exact service name from Helm chart
        port = 80
      }
      targetGroupARN = data.terraform_remote_state.infrastructure.outputs.nlb_target_group_arn
      targetType     = "ip"
    }
  }

  depends_on = [helm_release.nginx, helm_release.aws_load_balancer_controller]
}
