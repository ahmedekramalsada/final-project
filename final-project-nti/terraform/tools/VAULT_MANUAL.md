# Manual Vault Setup Instructions

Run the following commands in your terminal to populate the required secrets in Vault.

## 1. Prerequisites
Ensure you are logged in to Vault:
```bash
export VAULT_ADDR="http://<YOUR_VAULT_IP>:8200"
export VAULT_TOKEN="<YOUR_VAULT_TOKEN>"
vault login $VAULT_TOKEN
```

## 2. Secrets to Add

### Nexus Credentials
Used by the pipeline to push Docker images.
```bash
# Replace 'admin' and 'your_password' with actual values
vault kv put kv/nexus username="admin" password="your_nexus_password"
```

### SonarQube Token
Used by the pipeline for code analysis.
```bash
# Replace with your generated SonarQube token
vault kv put kv/sonarqube token="your_sonar_token" admin_password="admin"
```

### App Secrets (MongoDB)
Used by the application to connect to the database.
```bash
# Replace with your actual MongoDB URI
vault kv put kv/app mongodb_uri="mongodb://username:password@host:port/db"
```

### Azure DevOps PAT (If not already added)
Used by the build agents.
```bash
vault kv put kv/azuredevops pat="your_personal_access_token"
```

### Datadog Credentials
Used by the Datadog Agent to send metrics and logs.
```bash
# Replace with your actual Datadog keys
vault kv put kv/datadog api_key="<YOUR_API_KEY>" app_key="<YOUR_APP_KEY>"
```

## 3. Verification
Check if secrets are added correctly:
```bash
vault kv get kv/nexus
vault kv get kv/sonarqube
vault kv get kv/app
vault kv get kv/azuredevops
vault kv get kv/datadog
```
