resource "kubernetes_namespace" "azuredevops_agents" {
  metadata { name = "azuredevops-agents" }
}

# 1. Fetch the PAT from SSM (Ensure you created this manually in AWS first)
data "aws_ssm_parameter" "azuredevops_pat" {
  name            = "/${var.project}/azuredevops-pat"
  with_decryption = true
}

resource "kubernetes_secret" "azuredevops_pat" {
  metadata {
    name      = "azuredevops-pat"
    namespace = kubernetes_namespace.azuredevops_agents.metadata[0].name
  }
  data = {
    personalAccessToken = data.aws_ssm_parameter.azuredevops_pat.value
  }
  type = "Opaque"
}

resource "kubernetes_manifest" "azuredevops_trigger_auth" {
  manifest = {
    apiVersion = "keda.sh/v1alpha1"
    kind       = "TriggerAuthentication"
    metadata = {
      name      = "azuredevops-trigger-auth"
      namespace = kubernetes_namespace.azuredevops_agents.metadata[0].name
    }
    spec = {
      secretTargetRef = [{
        parameter = "personalAccessToken"
        name      = "azuredevops-pat"
        key       = "personalAccessToken"
      }]
    }
  }
}

# 2. ScaledJob Configuration
resource "kubernetes_manifest" "azuredevops_scaled_job" {
  manifest = {
    apiVersion = "keda.sh/v1alpha1"
    kind       = "ScaledJob"
    metadata = {
      name      = "azuredevops-agent-scaled-job"
      namespace = kubernetes_namespace.azuredevops_agents.metadata[0].name
    }
    spec = {
      jobTargetRef = {
        template = {
          spec = {
            containers = [{
              name = "azuredevops-agent"
              # Use custom agent image from ECR (build from agent/Dockerfile)
              image = "${aws_ecr_repository.agent_repo.repository_url}:latest"
              env = [
                { name = "AZP_URL", value = var.azuredevops_org_url },
                { name = "AZP_POOL", value = var.azuredevops_pool_name },
                { name = "AZP_TOKEN", valueFrom = { secretKeyRef = { name = "azuredevops-pat", key = "personalAccessToken" } } }
              ]
            }]
            restartPolicy = "Never"
          }
        }
      }
      pollingInterval = 30
      maxReplicaCount = 10
      triggers = [{
        type = "azure-pipelines"
        metadata = {
          organizationUrl            = var.azuredevops_org_url
          poolName                   = var.azuredevops_pool_name
          targetPipelinesQueueLength = "1"
        }
        authenticationRef = { name = "azuredevops-trigger-auth" }
      }]
    }
  }
}
