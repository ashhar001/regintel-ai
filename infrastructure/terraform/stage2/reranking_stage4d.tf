locals {
  rerank_model_id  = "cohere.rerank-v3-5:0"
  rerank_model_arn = "arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}::foundation-model/${local.rerank_model_id}"
}

data "aws_iam_policy_document" "kb_rerank" {
  statement {
    sid       = "RerankKnowledgeBaseResults"
    effect    = "Allow"
    actions   = ["bedrock:Rerank"]
    resources = ["*"]
  }

  statement {
    sid     = "InvokeReranker"
    effect  = "Allow"
    actions = ["bedrock:InvokeModel"]
    resources = [
      local.rerank_model_arn,
    ]
  }
}

resource "aws_iam_role_policy" "kb_rerank" {
  name   = "${local.name_prefix}-kb-rerank"
  role   = aws_iam_role.knowledge_base.id
  policy = data.aws_iam_policy_document.kb_rerank.json
}

output "rerank_model_arn" {
  value       = local.rerank_model_arn
  description = "Cohere Rerank 3.5 model ARN used for Stage 4D reranking in us-east-1."
}
