variable "aws_region" {
  type        = string
  description = "AWS region hosting RegIntel."
  default     = "us-east-1"
}

variable "aws_profile" {
  type        = string
  description = "Optional local AWS profile used only while bootstrapping from a workstation."
  default     = null
}

variable "project_name" {
  type        = string
  description = "Project name used in bootstrap resource names."
  default     = "regintel-ai"
}

variable "environment" {
  type        = string
  description = "Environment name."
  default     = "dev"
}

variable "github_owner" {
  type        = string
  description = "GitHub organization or username that owns the repository."
}

variable "github_repository" {
  type        = string
  description = "GitHub repository name only, without owner."
}

variable "github_branch" {
  type        = string
  description = "Protected deployment branch."
  default     = "main"
}

variable "github_environment" {
  type        = string
  description = "GitHub Environment used for protected production deployments."
  default     = "production"
}

variable "github_oidc_provider_arn" {
  type        = string
  description = "Existing GitHub Actions OIDC provider ARN. Leave null to create one."
  default     = null
}

variable "state_bucket_name" {
  type        = string
  description = "Optional explicit Terraform state bucket name."
  default     = null
}

variable "state_key" {
  type        = string
  description = "Remote-state object key for the main RegIntel stack."
  default     = "regintel/stage2/terraform.tfstate"
}

variable "github_owner_id" {
  type        = string
  description = "Stable numeric GitHub owner/user/organization ID used in customized OIDC subject claims."
  default     = null
}

variable "github_repository_id" {
  type        = string
  description = "Stable numeric GitHub repository ID used in customized OIDC subject claims."
  default     = null
}
