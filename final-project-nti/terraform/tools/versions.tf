terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "backend-s3-final-project"
    key    = "tools/terraform.tfstate"
    region = "us-east-1"
  }
}
