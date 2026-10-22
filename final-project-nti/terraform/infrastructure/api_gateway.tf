resource "aws_apigatewayv2_api" "main" {
  name          = var.api_gateway_name
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }

  tags = local.common_tags
}

# --- VPC Link for private integration with EKS NLB ---
resource "aws_apigatewayv2_vpc_link" "eks" {
  name               = "${var.project}-vpc-link"
  security_group_ids = [module.eks.cluster_security_group_id]
  subnet_ids         = module.vpc.private_subnets

  tags = local.common_tags

  depends_on = [module.vpc, module.eks]
}

# --- Single integration: VPC Link → NLB ---
resource "aws_apigatewayv2_integration" "nlb" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = aws_lb_listener.ingress_80.arn
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.eks.id
}

# --- Cognito JWT Authorizer ---
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.main.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-authorizer"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.client.id]
    issuer   = "https://${aws_cognito_user_pool.main.endpoint}"
  }
}

# --- Default Stage (auto-deploy) ---
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseLength = "$context.responseLength"
    })
  }

  tags = local.common_tags
}

# --- CloudWatch Log Group ---
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.api_gateway_name}"
  retention_in_days = var.api_gateway_log_retention_days

  tags = local.common_tags
}

# ============================================================================
# ROUTES — All protected by Cognito, all forwarded to NLB → Ingress
# ============================================================================

# 1. Default catch-all route → App
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.nlb.id}"

  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# 2. ArgoCD route
resource "aws_apigatewayv2_route" "argocd" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /argocd/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.nlb.id}"

  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# 3. ArgoCD root path (without trailing proxy)
resource "aws_apigatewayv2_route" "argocd_root" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /argocd"
  target    = "integrations/${aws_apigatewayv2_integration.nlb.id}"

  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# 4. SonarQube route
resource "aws_apigatewayv2_route" "sonarqube" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /sonarqube/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.nlb.id}"

  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# 5. SonarQube root path
resource "aws_apigatewayv2_route" "sonarqube_root" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /sonarqube"
  target    = "integrations/${aws_apigatewayv2_integration.nlb.id}"

  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}
