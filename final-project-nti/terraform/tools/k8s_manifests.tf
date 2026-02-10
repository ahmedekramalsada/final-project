# Kubernetes Manifests managed via Terraform for better consistency and to avoid pipeline service connection issues.

# KEDA Trigger Authentication for Azure DevOps
resource "kubernetes_manifest" "azuredevops_trigger_auth" {
  manifest = {
    apiVersion = "keda.sh/v1alpha1"
    kind       = "TriggerAuthentication"
    metadata = {
      name      = "azuredevops-trigger-auth"
      namespace = "azuredevops-agents"
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
}

# KEDA ScaledJob for Azure DevOps Agents
resource "kubernetes_manifest" "azuredevops_agent_scaled_job" {
  manifest = {
    apiVersion = "keda.sh/v1alpha1"
    kind       = "ScaledJob"
    metadata = {
      name      = "azuredevops-agent-scaled-job"
      namespace = "azuredevops-agents"
    }
    spec = {
      jobTargetRef = {
        template = {
          spec = {
            containers = [
              {
                name  = "azuredevops-agent"
                image = var.azuredevops_agent_image
                env = [
                  {
                    name  = "AZP_URL"
                    value = var.azuredevops_org_url
                  },
                  {
                    name  = "AZP_POOL"
                    value = var.azuredevops_pool_name
                  },
                  {
                    name = "AZP_TOKEN"
                    valueFrom = {
                      secretKeyRef = {
                        name = "azuredevops-pat"
                        key  = "personalAccessToken"
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
      pollingInterval = 30
      maxReplicaCount = 10
      triggers = [
        {
          type = "azure-pipelines"
          metadata = {
            organizationUrl            = var.azuredevops_org_url
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

  depends_on = [kubernetes_manifest.azuredevops_trigger_auth]
}

# Target Group Binding for NGINX Ingress
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
        name = "nginx-ingress-nginx-controller"
        port = 80
      }
      targetGroupARN = data.terraform_remote_state.infrastructure.outputs.nlb_target_group_arn
      targetType     = "ip"
    }
  }

  # Ensure NGINX Helm release is created first
  depends_on = [helm_release.nginx]
}
