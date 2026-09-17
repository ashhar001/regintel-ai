locals {
  bootstrap_prefix = "regintel-${var.environment}"

  normalized_project = lower(replace(var.project_name, "_", "-"))
  state_bucket_name = coalesce(
    var.state_bucket_name,
    "${local.normalized_project}-${var.environment}-${data.aws_caller_identity.current.account_id}-tfstate",
  )

  github_repo = "${var.github_owner}/${var.github_repository}"
  github_oidc_provider_arn = coalesce(
    var.github_oidc_provider_arn,
    try(aws_iam_openid_connect_provider.github[0].arn, null),
  )

  github_oidc_subject_repo = (
    var.github_owner_id != null && var.github_repository_id != null
    ? "repo:${var.github_owner}@${var.github_owner_id}/${var.github_repository}@${var.github_repository_id}"
    : "repo:${local.github_repo}"
  )
}

