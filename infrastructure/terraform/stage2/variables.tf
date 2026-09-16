variable "aws_region" {
  description = "AWS region for the Stage 2 RAG foundation."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Optional local AWS CLI profile. Leave null in CI/CD when using workload identity."
  type        = string
  default     = null
}

variable "project_name" {
  description = "Project name used in resource names and tags."
  type        = string
  default     = "regintel-ai"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"
}

variable "embedding_model_id" {
  description = "Amazon Bedrock embedding model used by the knowledge base."
  type        = string
  default     = "amazon.titan-embed-text-v2:0"
}

variable "embedding_dimensions" {
  description = "Embedding dimensions. Titan Text Embeddings V2 supports 1024, 512, or 256."
  type        = number
  default     = 1024

  validation {
    condition     = contains([1024, 512, 256], var.embedding_dimensions)
    error_message = "embedding_dimensions must be one of 1024, 512, or 256."
  }
}

variable "chunk_max_tokens" {
  description = "Stage 2 baseline fixed-size chunk length. We will benchmark alternatives later."
  type        = number
  default     = 512
}

variable "chunk_overlap_percentage" {
  description = "Overlap between adjacent fixed-size chunks."
  type        = number
  default     = 15
}

variable "aoss_admin_principal_arn" {
  description = "Optional IAM user/role ARN granted OpenSearch Serverless data-plane access for Terraform index provisioning. Required when the caller identity is an STS session whose underlying IAM role ARN cannot be inferred safely."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}

variable "ingestion_max_document_bytes" {
  description = "Maximum Stage 3 source document size. Bedrock S3 knowledge-base documents support up to 50 MB."
  type        = number
  default     = 52428800
}

variable "ingestion_supported_extensions" {
  description = "Document extensions accepted by the Stage 3 manifest validator."
  type        = list(string)

  default = [
    ".txt",
    ".md",
    ".html",
    ".doc",
    ".docx",
    ".csv",
    ".xls",
    ".xlsx",
    ".pdf"
  ]
}

variable "ingestion_poll_seconds" {
  description = "Seconds between Bedrock ingestion job status checks."
  type        = number
  default     = 10
}

variable "stage5_monthly_budget_usd" {
  description = "Optional monthly AWS cost budget for the development account."
  type        = number
  default     = 50
}

variable "stage5_budget_alert_email" {
  description = "Optional email address for AWS Budget alerts. Leave null to create no budget notification."
  type        = string
  default     = null
  nullable    = true
}

variable "stage5_enable_budget" {
  description = "Create a monthly AWS cost budget. This is account-level, so keep disabled if the account is shared."
  type        = bool
  default     = false
}

