module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.31.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Grants the Terraform executor admin permissions on the cluster
  enable_cluster_creator_admin_permissions = true

  # Enable cluster endpoint for private and public access
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access

  eks_managed_node_groups = {
    workers = {
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size

      # Labels for node identification
      labels = {
        role        = "general"
        environment = var.environment
      }

      tags = local.common_tags
    }
  }

  tags = local.common_tags
}
