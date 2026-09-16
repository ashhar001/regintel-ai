provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile != null && trimspace(var.aws_profile) != "" ? var.aws_profile : null

  default_tags {
    tags = merge(
      {
        Project     = var.project_name
        Environment = var.environment
        ManagedBy   = "Terraform"
        Stage       = "2-rag-foundation"
      },
      var.tags,
    )
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

provider "opensearch" {
  url                   = aws_opensearchserverless_collection.vector.collection_endpoint
  aws_region            = var.aws_region
  aws_profile           = var.aws_profile != null && trimspace(var.aws_profile) != "" ? var.aws_profile : null
  aws_signature_service = "aoss"
  sign_aws_requests     = true
  healthcheck           = false
}
