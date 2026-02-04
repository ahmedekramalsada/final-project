

# 2. Run the "Once-Off" Registration Job
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
          # Use the latest image to satisfy the version demand
          image = "mcr.microsoft.com/azure-pipelines/vsts-agent:ubuntu-22.04"

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

