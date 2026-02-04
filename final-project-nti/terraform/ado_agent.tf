
resource "kubernetes_namespace" "ado_agents" {
  metadata {
    name = "ado-agents"
  }
}

# Data source to read the ADO PAT (must be created manually in SSM)
data "aws_ssm_parameter" "ado_pat" {
  name            = "/${var.project}/ado-pat"
  with_decryption = true
}

resource "kubernetes_secret" "ado_pat" {
  metadata {
    name      = "ado-pat"
    namespace = kubernetes_namespace.ado_agents.metadata[0].name
  }

  data = {
    personalAccessToken = data.aws_ssm_parameter.ado_pat.value
  }

  type = "Opaque"
}

resource "kubernetes_manifest" "ado_trigger_auth" {
  manifest = {
    apiVersion = "keda.sh/v1alpha1"
    kind       = "TriggerAuthentication"
    metadata = {
      name      = "pipeline-trigger-auth"
      namespace = kubernetes_namespace.ado_agents.metadata[0].name
    }
    spec = {
      secretTargetRef = [
        {
          parameter = "personalAccessToken"
          name      = "ado-pat"
          key       = "personalAccessToken"
        }
      ]
    }
  }

  depends_on = [helm_release.keda]
}

resource "kubernetes_manifest" "ado_scaled_job" {
  manifest = {
    apiVersion = "keda.sh/v1alpha1"
    kind       = "ScaledJob"
    metadata = {
      name      = "ado-agent-scaled-job"
      namespace = kubernetes_namespace.ado_agents.metadata[0].name
    }
    spec = {
      jobTargetRef = {
        template = {
          spec = {
            containers = [
              {
                name  = "ado-agent"
                image = "mcr.microsoft.com/azure-pipelines/vsts-agent:ubuntu-20.04"
                env = [
                  {
                    name  = "AZP_URL"
                    value = var.ado_org_url
                  },
                  {
                    name = "AZP_TOKEN"
                    valueFrom = {
                      secretKeyRef = {
                        name = "ado-pat"
                        key  = "personalAccessToken"
                      }
                    }
                  },
                  {
                    name  = "AZP_POOL"
                    value = var.ado_pool_name
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
            organizationURL            = var.ado_org_url
            poolName                   = var.ado_pool_name
            targetPipelinesQueueLength = "1"
          }
          authenticationRef = {
            name = "pipeline-trigger-auth"
          }
        }
      ]
    }
  }

  depends_on = [helm_release.keda, kubernetes_manifest.ado_trigger_auth]
}
