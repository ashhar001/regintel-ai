data "aws_iam_policy_document" "stage5b_ecs_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "stage5b_execution" {
  name               = "${local.name_prefix}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.stage5b_ecs_assume.json

  tags = {
    Stage = "5b-production-runtime"
  }
}

resource "aws_iam_role_policy_attachment" "stage5b_execution" {
  role       = aws_iam_role.stage5b_execution.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "stage5b_task" {
  name               = "${local.name_prefix}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.stage5b_ecs_assume.json

  tags = {
    Stage = "5b-production-runtime"
  }
}

locals {
  stage5b_nova_model_arn = "arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}::foundation-model/amazon.nova-lite-v1:0"
  stage5b_kb_arn         = "arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:knowledge-base/${aws_bedrockagent_knowledge_base.this.id}"
}

data "aws_iam_policy_document" "stage5b_task" {
  statement {
    sid       = "RetrieveKnowledgeBase"
    effect    = "Allow"
    actions   = ["bedrock:Retrieve"]
    resources = [local.stage5b_kb_arn]
  }

  # AWS documents RetrieveAndGenerate as an action that currently uses Resource "*".
  statement {
    sid       = "RetrieveAndGenerate"
    effect    = "Allow"
    actions   = ["bedrock:RetrieveAndGenerate"]
    resources = ["*"]
  }

  statement {
    sid     = "InvokeModels"
    effect  = "Allow"
    actions = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
    resources = [
      local.stage5b_nova_model_arn,
      local.rerank_model_arn,
    ]
  }

  statement {
    sid       = "UseReranker"
    effect    = "Allow"
    actions   = ["bedrock:Rerank"]
    resources = ["*"]
  }

  statement {
    sid       = "ApplyRegIntelGuardrail"
    effect    = "Allow"
    actions   = ["bedrock:ApplyGuardrail"]
    resources = [aws_bedrock_guardrail.regintel.guardrail_arn]
  }

  statement {
    sid       = "DecryptGuardrailKey"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.data.arn]
  }
}

resource "aws_iam_role_policy" "stage5b_task" {
  name   = "${local.name_prefix}-ecs-bedrock"
  role   = aws_iam_role.stage5b_task.id
  policy = data.aws_iam_policy_document.stage5b_task.json
}
