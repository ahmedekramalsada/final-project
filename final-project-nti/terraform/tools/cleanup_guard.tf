resource "null_resource" "lb_cleanup_guard" {
  # This resource must be destroyed BEFORE the controller, but AFTER the apps.
  # So: Apps depend on Guard. Guard depends on Controller.
  depends_on = [helm_release.aws_load_balancer_controller]

  triggers = {
    cluster_name = data.terraform_remote_state.infrastructure.outputs.cluster_name
    region       = var.aws_region
    script_hash  = filemd5("${path.module}/../../scripts/lb_cleanup_destroy.sh")
  }

  provisioner "local-exec" {
    when    = destroy
    command = "chmod +x ${path.module}/../../scripts/lb_cleanup_destroy.sh && ${path.module}/../../scripts/lb_cleanup_destroy.sh ${self.triggers.region} ${self.triggers.cluster_name}"
  }
}
