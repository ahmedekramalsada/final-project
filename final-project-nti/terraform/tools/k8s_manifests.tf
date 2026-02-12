# Kubernetes manifests applied via Terraform-native resources.
# TargetGroupBinding is managed as a kubernetes_manifest for proper lifecycle tracking.
# KEDA ScaledJob is applied via null_resource on create only — namespace deletion handles cleanup.

# --- TargetGroupBinding: Binds NGINX Ingress to the NLB Target Group ---
resource "kubernetes_manifest" "nginx_target_group_binding" {
  manifest = {
    apiVersion = "elbv2.k8s.aws/v1beta1"
    kind       = "TargetGroupBinding"
    metadata = {
      name      = "nginx-tgb"
      namespace = "ingress-nginx"
    }
    spec = {
      serviceRef = {
        name = "nginx-ingress-nginx-controller"
        port = 80
      }
      targetGroupARN = data.terraform_remote_state.infrastructure.outputs.nlb_target_group_arn
      targetType     = "ip"
    }
  }

  depends_on = [
    helm_release.nginx,
    helm_release.aws_load_balancer_controller,
  ]
}

# --- KEDA ScaledJob for Azure DevOps Agents ---
# Applied via kubectl because KEDA CRDs are installed dynamically by the KEDA Helm release.
# On destroy, deleting the azuredevops-agents namespace cleans up these resources automatically.
resource "null_resource" "apply_keda_scaled_job" {
  triggers = {
    cluster_name  = data.terraform_remote_state.infrastructure.outputs.cluster_name
    region        = var.aws_region
    manifest_hash = filemd5("${path.module}/../../k8s/azuredevops-keda.yaml")
  }

  provisioner "local-exec" {
    command = <<EOT
      set -e
      aws eks update-kubeconfig --region ${var.aws_region} --name ${data.terraform_remote_state.infrastructure.outputs.cluster_name}

      # Create temp copy to replace placeholder
      cp ../../k8s/azuredevops-keda.yaml /tmp/azuredevops-keda.yaml
      sed -i '' "s|REPLACEMENT_IMAGE_URL|${var.azuredevops_agent_image}|g" /tmp/azuredevops-keda.yaml 2>/dev/null || \
      sed -i "s|REPLACEMENT_IMAGE_URL|${var.azuredevops_agent_image}|g" /tmp/azuredevops-keda.yaml

      kubectl apply -f /tmp/azuredevops-keda.yaml
      rm -f /tmp/azuredevops-keda.yaml
      echo "KEDA ScaledJob manifest applied."
    EOT
  }

  depends_on = [
    helm_release.keda,
    helm_release.nginx,
    kubernetes_namespace.azuredevops_agents,
  ]
}
