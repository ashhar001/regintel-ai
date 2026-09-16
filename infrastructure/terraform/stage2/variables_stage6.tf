variable "stage6_ci_role_arn" {
  description = "GitHub Terraform-plan role granted read-only AOSS data-plane access."
  type        = string
  default     = null
}
