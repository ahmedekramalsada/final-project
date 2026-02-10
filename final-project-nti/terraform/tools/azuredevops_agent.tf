resource "kubernetes_namespace" "azuredevops_agents" {
  metadata { name = "azuredevops-agents" }
}

# 1. Fetch the PAT from Vault (Ensure you created this manually in Vault first)
# 1. Fetch the PAT from Vault (Ensure you created this manually in Vault first)
data "vault_kv_secret_v2" "azuredevops_pat" {
  mount = "kv"          # Adjust mount path if necessary (e.g., "secret")
  name  = "azuredevops" # Adjust secret path
}

resource "kubernetes_secret" "azuredevops_pat" {
  metadata {
    name      = "azuredevops-pat"
    namespace = kubernetes_namespace.azuredevops_agents.metadata[0].name
  }
  data = {
    personalAccessToken = data.vault_kv_secret_v2.azuredevops_pat.data["pat"]
  }
  type = "Opaque"
}


