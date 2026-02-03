#------------------------------------------------------------------------------
# VPC Outputs
#------------------------------------------------------------------------------

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

#------------------------------------------------------------------------------
# EKS Outputs
#------------------------------------------------------------------------------

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

#------------------------------------------------------------------------------
# API Gateway Outputs
#------------------------------------------------------------------------------

output "gateway_url" {
  description = "API Gateway endpoint URL"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "gateway_id" {
  description = "API Gateway ID"
  value       = aws_apigatewayv2_api.main.id
}

#------------------------------------------------------------------------------
# Tooling Outputs
#------------------------------------------------------------------------------

output "nginx_ingress_namespace" {
  description = "Namespace where NGINX Ingress is installed"
  value       = var.enable_nginx_ingress ? helm_release.nginx[0].namespace : null
}

output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = var.enable_argocd ? helm_release.argocd[0].namespace : null
}

#------------------------------------------------------------------------------
# Kubectl Configuration
#------------------------------------------------------------------------------

output "configure_kubectl" {
  description = "Command to configure kubectl for the cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
