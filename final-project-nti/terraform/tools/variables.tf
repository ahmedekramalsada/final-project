variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name for resource naming and tagging"
  type        = string
  default     = "devops-infrastructure"
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

#------------------------------------------------------------------------------
# Tooling Configuration
#------------------------------------------------------------------------------

variable "enable_nginx_ingress" {
  description = "Enable NGINX Ingress Controller deployment"
  type        = bool
  default     = true
}

variable "nginx_chart_version" {
  description = "Helm chart version for NGINX Ingress Controller"
  type        = string
  default     = "4.9.0"
}

variable "enable_argocd" {
  description = "Enable ArgoCD deployment"
  type        = bool
  default     = true
}

variable "argocd_chart_version" {
  description = "Helm chart version for ArgoCD"
  type        = string
  default     = "5.53.0"
}

#------------------------------------------------------------------------------
# Azure DevOps Configuration
#------------------------------------------------------------------------------

variable "azuredevops_org_url" {
  description = "URL of the Azure DevOps organization"
  type        = string
  default     = "https://dev.azure.com/aekram2"
}

variable "azuredevops_pool_name" {
  description = "Name of the Agent Pool in Azure DevOps"
  type        = string
  default     = "self-hosted-k8s"
}
