# Fetch secrets from Vault
# data "vault_kv_secret_v2" "db_creds" {
#   mount = "kv"            # Adjust mount path if necessary (e.g., "secret")
#   name  = "production/db" # Adjust secret path
# }

# Example output for debugging (Removed in production)
# output "db_username_debug" {
#   value = data.vault_kv_secret_v2.db_creds.data["username"]
#   sensitive = true
# }
