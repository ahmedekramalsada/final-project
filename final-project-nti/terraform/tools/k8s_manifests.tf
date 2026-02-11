# This resource handles applying additional Kubernetes manifests that are not managed by Helm.
# It uses local-exec to run kubectl commands within the Terraform context, leveraging the existing AWS credentials.

resource "null_resource" "apply_k8s_manifests" {
  # Trigger re-run if the target group ARN changes or on every apply if desired (using timestamp)
  triggers = {
    target_group_arn = data.terraform_remote_state.infrastructure.outputs.nlb_target_group_arn
    # Uncomment the line below to force run on every apply
    # always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<EOT
      set -e
      
      # Update kubeconfig to connect to the EKS cluster
      aws eks update-kubeconfig --region ${var.aws_region} --name ${data.terraform_remote_state.infrastructure.outputs.cluster_name}
      
      # Define paths relative to the terraform/tools directory (where this runs)
      # The repo structure is:
      # root
      #   |-- k8s/
      #   |-- terraform/
      #         |-- tools/
      
      MANIFEST_DIR="../../k8s"
      
      echo "Applying manifests from $MANIFEST_DIR..."
      
      # Replace placeholders in manifests
      sed -i "s|REPLACEMENT_IMAGE_URL|mcr.microsoft.com/azure-pipelines/vsts-agent:ubuntu-20.04|g" $MANIFEST_DIR/azuredevops-keda.yaml
      
      TARGET_GROUP_ARN="${data.terraform_remote_state.infrastructure.outputs.nlb_target_group_arn}"
      if [ -n "$TARGET_GROUP_ARN" ]; then
        echo "Updating Target Group ARN in nginx-tgb.yaml..."
        sed -i "s|TARGET_GROUP_ARN_PLACEHOLDER|$TARGET_GROUP_ARN|g" $MANIFEST_DIR/nginx-tgb.yaml
      else
        echo "Warning: No Target Group ARN available."
      fi
      
      # Apply manifests
      kubectl apply -f $MANIFEST_DIR/azuredevops-keda.yaml
      kubectl apply -f $MANIFEST_DIR/nginx-tgb.yaml
      
      echo "Manifests applied successfully."
    EOT
  }

  depends_on = [
    helm_release.aws_load_balancer_controller,
    helm_release.keda,
    kubernetes_namespace.azuredevops_agents
  ]
}
