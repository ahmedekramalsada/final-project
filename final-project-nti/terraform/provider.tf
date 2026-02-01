# --- 1. Providers and Backend ---
terraform {
  required_providers {
    aws  = { source = "hashicorp/aws", version = "~> 5.0" }
    helm = { source = "hashicorp/helm", version = "~> 2.12" }
  }
  # Note: Add your S3 bucket name here for remote state
  backend "s3" {
    bucket = "backend-s3-final-project"
    key    = "state/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" { region = "us-east-1" }

# --- 2. Network (VPC, Subnets, IGW, NAT) --- [cite: 5-9]
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.1"
  name    = "devops-vpc"
  cidr    = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
  public_subnet_tags = { "kubernetes.io/role/elb" = 1 }
}

# --- 3. EKS Cluster and Node Groups --- [cite: 11-13]
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.0.0"

  cluster_name    = "devops-cluster"
  cluster_version = "1.30"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets

  # Enable public access for Terraform/local kubectl, keep private access for bastion
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    main = {
      instance_types = ["t3.medium"]
      min_size       = 2, max_size = 3, desired_size = 2
    }
  }
}

# --- 4. API Gateway --- [cite: 14]
resource "aws_apigatewayv2_api" "main" {
  name          = "devops-gateway"
  protocol_type = "HTTP"
}
