resource "aws_ecr_repository" "app_repo" {
  name                 = "final-project-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "final-project-app"
    Environment = "production"
  }
}
resource "aws_ecr_repository" "agent_repo" {
  name                 = "azp-agent"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "azp-agent"
    Environment = "production"
  }
}

