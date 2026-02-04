
resource "kubernetes_namespace" "azuredevops_agents" {
  metadata {
    name = "azuredevops-agents"
  }
}

# Data source to read the Azure DevOps PAT (must be created manually in SSM)
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
      secretTargetRef = [
        {
          parameter = "personalAccessToken"
          name      = "azuredevops-pat"
          key       = "personalAccessToken"
        }
      ]
    }
  }

  depends_on = [helm_release.keda]
}

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
            containers = [
              {
                name  = "azuredevops-agent"
                image = "mcr.microsoft.com/azure-pipelines/vsts-agent:ubuntu-20.04"
                env = [
                  {
                    name  = "AZP_URL"
                    value = var.azuredevops_org_url
                  },
                  {
                    name = "AZP_TOKEN"
                    valueFrom = {
                      secretKeyRef = {
                        name = "azuredevops-pat"
                        key  = "personalAccessToken"
                      }
                    }
                  },
                  {
                    name  = "AZP_POOL"
                    value = var.azuredevops_pool_name
                  },
                  {
                    name = "AZP_AGENT_NAME"
                    valueFrom = {
                      fieldRef = {
                        fieldPath = "metadata.name"
                      }
                    }
                  }
                ]
              }
            ]
            restartPolicy = "Never"
          }
        }
      }
      pollingInterval            = 30
      successfulJobsHistoryLimit = 5
      failedJobsHistoryLimit     = 5
      maxReplicaCount            = 10
      scalingStrategy = {
        strategy = "default"
      }
      triggers = [
        {
          type = "azure-pipelines"
          metadata = {
            organizationURL            = var.azuredevops_org_url
            poolName                   = var.azuredevops_pool_name
            targetPipelinesQueueLength = "1"
          }
          authenticationRef = {
            name = "azuredevops-trigger-auth"
          }
        }
      ]
    }
  }

  depends_on = [helm_release.keda, kubernetes_manifest.azuredevops_trigger_auth]
}
