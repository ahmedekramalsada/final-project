# This resource handles applying additional Kubernetes manifests that are not managed by Helm.
# It uses local-exec to run kubectl commands within the Terraform context, leveraging the existing AWS credentials.

resource "null_resource" "apply_k8s_manifests" {
  # Trigger re-run if the target group ARN changes or on every apply if desired (using timestamp)
  triggers = {
    target_group_arn = data.terraform_remote_state.infrastructure.outputs.nlb_target_group_arn
    cluster_name     = data.terraform_remote_state.infrastructure.outputs.cluster_name
    region           = var.aws_region
  }

  provisioner "local-exec" {
    command = <<EOT
      set -e
      
      # Update kubeconfig to connect to the EKS cluster
      aws eks update-kubeconfig --region ${var.aws_region} --name ${data.terraform_remote_state.infrastructure.outputs.cluster_name}
      
      # Define paths relative to the terraform/tools directory (where this runs)
      MANIFEST_DIR="../../k8s"
      
      echo "Applying manifests from $MANIFEST_DIR..."
      
      # Create temp copies so we don't modify source files
      cp $MANIFEST_DIR/azuredevops-keda.yaml /tmp/azuredevops-keda.yaml
      cp $MANIFEST_DIR/nginx-tgb.yaml /tmp/nginx-tgb.yaml
      
      # Replace placeholders in temp copies
      sed -i '' "s|REPLACEMENT_IMAGE_URL|mcr.microsoft.com/azure-pipelines/vsts-agent:ubuntu-20.04|g" /tmp/azuredevops-keda.yaml 2>/dev/null || \
      sed -i "s|REPLACEMENT_IMAGE_URL|mcr.microsoft.com/azure-pipelines/vsts-agent:ubuntu-20.04|g" /tmp/azuredevops-keda.yaml
      
      TARGET_GROUP_ARN="${data.terraform_remote_state.infrastructure.outputs.nlb_target_group_arn}"
      if [ -n "$TARGET_GROUP_ARN" ]; then
        echo "Updating Target Group ARN in nginx-tgb.yaml..."
        sed -i '' "s|TARGET_GROUP_ARN_PLACEHOLDER|$TARGET_GROUP_ARN|g" /tmp/nginx-tgb.yaml 2>/dev/null || \
        sed -i "s|TARGET_GROUP_ARN_PLACEHOLDER|$TARGET_GROUP_ARN|g" /tmp/nginx-tgb.yaml
      else
        echo "Warning: No Target Group ARN available."
      fi
      
      # Apply manifests from temp copies
      kubectl apply -f /tmp/azuredevops-keda.yaml
      kubectl apply -f /tmp/nginx-tgb.yaml
      
      # Clean up temp files
      rm -f /tmp/azuredevops-keda.yaml /tmp/nginx-tgb.yaml
      
      echo "Manifests applied successfully."
    EOT
  }

  # Clean up K8s resources on destroy
  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      set -e
      
      aws eks update-kubeconfig --region ${self.triggers.region} --name ${self.triggers.cluster_name} 2>/dev/null || true
      
      MANIFEST_DIR="../../k8s"
      
      echo "Deleting K8s manifests..."
      kubectl delete -f $MANIFEST_DIR/nginx-tgb.yaml --ignore-not-found=true 2>/dev/null || true
      kubectl delete -f $MANIFEST_DIR/azuredevops-keda.yaml --ignore-not-found=true 2>/dev/null || true
      
      echo "Manifests deleted successfully."
    EOT
  }

  depends_on = [
    helm_release.aws_load_balancer_controller,
    helm_release.keda,
    helm_release.nginx,
    kubernetes_namespace.azuredevops_agents
  ]
}
