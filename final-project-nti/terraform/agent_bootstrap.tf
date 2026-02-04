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
          name  = "bootstrap-agent"
          image = "ubuntu:22.04"

          command = ["/bin/bash", "-c"]
          args = [
            <<-EOT
            set -e
            export DEBIAN_FRONTEND=noninteractive
            apt-get update
            apt-get install -y --no-install-recommends \
                curl \
                jq \
                git \
                libicu70 \
                libssl3 \
                ca-certificates \
                tar \
                iputils-ping \
                procps

            mkdir -p /azp
            cd /azp

            echo "Fetching latest agent version from Azure DevOps..."
            AZP_AGENT_RESPONSE=$(curl -LsS \
              -u user:$${AZP_TOKEN} \
              -H 'Accept:application/json;' \
              "$${AZP_URL}/_apis/distributedtask/packages/agent?platform=linux-x64&top=1")
            
            AZP_AGENT_PACKAGE_LATEST_URL=$(echo "$AZP_AGENT_RESPONSE" | jq -r '.value[0].downloadUrl')
            
            echo "Downloading and extracting agent..."
            curl -LsS "$$AZP_AGENT_PACKAGE_LATEST_URL" | tar -xz

            echo "Configuring the agent..."
            ./config.sh --unattended \
              --url "$${AZP_URL}" \
              --auth pat \
              --token "$${AZP_TOKEN}" \
              --pool "$${AZP_POOL}" \
              --agent "bootstrap-$$(hostname)" \
              --replace \
              --acceptTeeEula

            echo "Running the agent registration (--once)..."
            ./run.sh --once
            EOT
          ]

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
        }
        restart_policy = "Never"
      }
    }

    ttl_seconds_after_finished = 3600
  }

  depends_on = [kubernetes_namespace.azuredevops_agents]
}
