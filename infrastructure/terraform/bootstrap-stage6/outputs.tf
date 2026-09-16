output "terraform_state_bucket" {
  value       = aws_s3_bucket.terraform_state.id
  description = "Versioned S3 bucket used by the main Terraform stack."
}

output "terraform_state_key" {
  value       = var.state_key
  description = "S3 object key used by the main Terraform state."
}

output "github_oidc_provider_arn" {
  value       = local.github_oidc_provider_arn
  description = "GitHub Actions OIDC provider ARN."
}

output "github_terraform_plan_role_arn" {
  value       = aws_iam_role.github_plan.arn
  description = "OIDC role used by pull-request Terraform plan jobs."
}

output "github_deploy_role_arn" {
  value       = aws_iam_role.github_deploy.arn
  description = "OIDC role used by protected application deployment jobs."
}
