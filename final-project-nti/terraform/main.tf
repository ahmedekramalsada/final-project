# --- SSM Parameters ---

# Create SSM Parameter for MongoDB URI
resource "aws_ssm_parameter" "mongo_uri" {
  name  = "/devops/mongodb-uri"
  type  = "SecureString"
  value = "placeholder" # Update this manually in AWS Console

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Name        = "mongodb-uri"
    Environment = "dev"
    Project     = "devops-final"
  }
}

# Create SSM Parameter for Datadog API Key
resource "aws_ssm_parameter" "datadog_api_key" {
  name  = "/devops/datadog-api-key"
  type  = "SecureString"
  value = "placeholder" # Update this manually in AWS Console with your real key

  lifecycle {
    ignore_changes = [value] # Prevents Terraform from overwriting manual updates
  }

  tags = {
    Name        = "datadog-api-key"
    Environment = "dev"
    Project     = "devops-final"
  }
}

# Data source to read the Datadog API key (after manual update)
data "aws_ssm_parameter" "datadog_api_key" {
  name            = aws_ssm_parameter.datadog_api_key.name
  with_decryption = true

  depends_on = [aws_ssm_parameter.datadog_api_key]
}

# --- Outputs ---
output "api_gateway_url" {
  value = aws_apigatewayv2_api.main.api_endpoint
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "ssm_datadog_api_key_name" {
  description = "SSM Parameter name for Datadog API Key - update this in AWS Console"
  value       = aws_ssm_parameter.datadog_api_key.name
}
