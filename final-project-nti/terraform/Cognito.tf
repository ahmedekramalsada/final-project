# --- Cognito User Pool ---
resource "aws_cognito_user_pool" "main" {
  name = "${var.project}-user-pool"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  tags = local.common_tags
}

# --- Cognito User Pool Client ---
resource "aws_cognito_user_pool_client" "client" {
  name         = "${var.project}-app-client"
  user_pool_id = aws_cognito_user_pool.main.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  prevent_user_existence_errors = "ENABLED"
}

# --- Cognito User Pool Domain ---
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project}-auth-domain"
  user_pool_id = aws_cognito_user_pool.main.id
}
