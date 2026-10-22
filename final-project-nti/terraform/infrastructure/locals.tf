locals {
  # Common tags applied to all resources
  common_tags = merge(
    {
      Environment = var.environment
      Project     = var.project
      ManagedBy   = "terraform"
    },
    var.additional_tags
  )

  # Naming prefix for resources
  name_prefix = "${var.project}-${var.environment}"

  # EKS node group configuration
  node_group_config = {
    workers = {
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size

      labels = {
        role        = "general"
        environment = var.environment
      }

      tags = local.common_tags
    }
  }

  # Subnet tags for EKS load balancer discovery
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}
