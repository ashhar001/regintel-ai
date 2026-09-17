provider "aws" {
  region  = var.aws_region
  profile = try(trimspace(var.aws_profile), "") != "" ? var.aws_profile : null
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Stage       = "6-cicd-bootstrap"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
