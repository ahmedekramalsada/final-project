# Fetch secrets from Vault
data "vault_kv_secret_v2" "app_secrets" {
  mount = "kv"
  name  = "app"
}

# Create Kubernetes Secret for MongoDB
resource "kubernetes_secret" "mongodb_secret" {
  metadata {
    name = "mongodb-secret"
  }

  data = {
    uri = data.vault_kv_secret_v2.app_secrets.data["mongodb_uri"]
  }

  type = "Opaque"

  depends_on = [module.eks]
}
