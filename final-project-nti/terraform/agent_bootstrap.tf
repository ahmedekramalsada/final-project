resource "kubernetes_job" "agent_bootstrap" {
  metadata {
    name      = "azdevops-agent-bootstrap"
    namespace = "azuredevops-agents"
  }

  spec {
    template {
      metadata {
        labels = {
          app = "agent-bootstrap"
        }
      }
      spec {
        container {
          name = "bootstrap-agent"
          # Using the custom ECR image we built to avoid ImagePullBackOff
          image = "${aws_ecr_repository.agent_repo.repository_url}:latest"

          env {
            name  = "AZP_URL"
            value = var.azuredevops_org_url
          }
          env {
            name  = "AZP_POOL"
            value = var.azuredevops_pool_name
          }
          env {
            name  = "AZP_TOKEN"
            value = data.aws_ssm_parameter.azuredevops_pat.value
          }

          # This flag is the key: it registers and then exits
          args = ["--once"]
        }
        restart_policy = "Never"
      }
    }

    # Clean up the job metadata after 1 hour to keep the cluster clean
    ttl_seconds_after_finished = 3600
  }

  # Ensure the namespace and cluster are ready first
  depends_on = [kubernetes_namespace.azuredevops_agents]
}
