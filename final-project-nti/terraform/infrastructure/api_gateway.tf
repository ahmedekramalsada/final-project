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

# Integration with the EKS cluster Ingress LoadBalancer
resource "aws_apigatewayv2_integration" "eks_ingress" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"

  # Note: The URI should be the external DNS name of the NGINX Ingress LoadBalancer.
  # Since this varies, a variable or a manual update after deployment is recommended.
  # Use VPC Link for private integration with the NLB
  integration_uri = aws_lb_listener.ingress_80.arn
  connection_type = "VPC_LINK"
  connection_id   = aws_apigatewayv2_vpc_link.eks.id
}

resource "aws_apigatewayv2_vpc_link" "eks" {
  name               = "${var.project}-vpc-link"
  security_group_ids = []
  subnet_ids         = module.vpc.private_subnets

  tags = local.common_tags
}


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

# CloudWatch Log Group for API Gateway access logs
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.api_gateway_name}"
  retention_in_days = var.api_gateway_log_retention_days

  tags = local.common_tags
}

# 3. API Gateway Authorizer (The Security Guard)
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

# 4. Route (Protected by Cognito)
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.eks_ingress.id}"

  # Protect the route with Cognito
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

