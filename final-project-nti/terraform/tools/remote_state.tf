data "terraform_remote_state" "infrastructure" {
  backend = "s3"
  config = {
    bucket = "backend-s3-final-project"
    key    = "eks/terraform.tfstate"
    region = "us-east-1"
  }
}
