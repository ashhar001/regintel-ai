resource "aws_iam_role" "github_plan" {
  name               = "${local.bootstrap_prefix}-github-plan"
  assume_role_policy = data.aws_iam_policy_document.github_plan_assume.json
}

resource "aws_iam_role_policy_attachment" "github_plan_readonly" {
  role       = aws_iam_role.github_plan.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "github_plan_extra" {
  statement {
    sid     = "TerraformStateBucketList"
    effect  = "Allow"
    actions = ["s3:ListBucket"]
    resources = [
      aws_s3_bucket.terraform_state.arn,
    ]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values = [
        var.state_key,
        "${var.state_key}.tflock",
      ]
    }

  }

  statement {
    sid    = "TerraformStateReadAndLock"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [
      "${aws_s3_bucket.terraform_state.arn}/${var.state_key}",
      "${aws_s3_bucket.terraform_state.arn}/${var.state_key}.tflock",
    ]
  }

  # Required by the OpenSearch Terraform provider to inspect the AOSS vector index.
  # Data-plane access is separately granted by a Stage 6 AOSS data-access policy.
  statement {
    sid       = "OpenSearchServerlessDataPlane"
    effect    = "Allow"
    actions   = ["aoss:APIAccessAll"]
    resources = ["*"]
  }

  statement {
    sid    = "BedrockTerraformRead"
    effect = "Allow"

    actions = [
      "bedrock:GetGuardrail",
      "bedrock:ListTagsForResource",
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:knowledge-base/*",
      "arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:guardrail/*",
    ]
  }

  statement {
    sid    = "ReadEncryptedGuardrailKey"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
    ]

    resources = [
      var.regintel_data_kms_key_arn,
    ]
  }
}

resource "aws_iam_role_policy" "github_plan_extra" {
  name   = "${local.bootstrap_prefix}-terraform-plan-extra"
  role   = aws_iam_role.github_plan.id
  policy = data.aws_iam_policy_document.github_plan_extra.json
}

resource "aws_iam_role" "github_deploy" {
  name               = "${local.bootstrap_prefix}-github-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_deploy_assume.json
}

data "aws_iam_policy_document" "github_deploy" {
  statement {
    sid       = "ECRAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "ECRApplicationImages"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeImageScanFindings",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/regintel-${var.environment}-*-api",
    ]
  }

  statement {
    sid    = "ECSDeployment"
    effect = "Allow"
    actions = [
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:DescribeTasks",
      "ecs:ListTasks",
      "ecs:RegisterTaskDefinition",
      "ecs:UpdateService",
    ]
    resources = ["*"]
  }

  statement {
    sid     = "PassRegIntelECSTaskRoles"
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/regintel-${var.environment}-*-ecs-execution",
      "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/regintel-${var.environment}-*-ecs-task",
    ]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  # Release-quality gate executes the candidate API on the GitHub runner against
  # the real Bedrock KB/Guardrail before an image is promoted to ECS.
  statement {
    sid    = "BedrockReleaseGate"
    effect = "Allow"
    actions = [
      "bedrock:ApplyGuardrail",
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:Rerank",
      "bedrock:Retrieve",
      "bedrock:RetrieveAndGenerate",
    ]
    resources = ["*"]
  }

  # Restricted to KMS keys in this AWS account. The release gate needs decrypt
  # access because the RegIntel Guardrail is encrypted with the data CMK.
  statement {
    sid     = "DecryptRegIntelGuardrail"
    effect  = "Allow"
    actions = ["kms:Decrypt"]
    resources = [
      "arn:${data.aws_partition.current.partition}:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*",
    ]
  }

}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "${local.bootstrap_prefix}-github-deploy"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy.json
}
