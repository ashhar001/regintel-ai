data "aws_iam_policy_document" "kb_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:knowledge-base/*"
      ]
    }
  }
}

resource "aws_iam_role" "knowledge_base" {
  name               = "${local.name_prefix}-kb-role"
  assume_role_policy = data.aws_iam_policy_document.kb_assume_role.json
}

data "aws_iam_policy_document" "kb_base" {
  statement {
    sid     = "InvokeEmbeddingModel"
    effect  = "Allow"
    actions = ["bedrock:InvokeModel"]
    resources = [
      local.embedding_model_arn,
    ]
  }

  statement {
    sid     = "ListSourceBucket"
    effect  = "Allow"
    actions = ["s3:ListBucket"]
    resources = [
      aws_s3_bucket.raw.arn,
    ]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["documents/*"]
    }
  }

  statement {
    sid     = "ReadSourceDocuments"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    resources = [
      "${aws_s3_bucket.raw.arn}/documents/*",
    ]
  }

  statement {
    sid     = "DecryptSourceDocuments"
    effect  = "Allow"
    actions = ["kms:Decrypt", "kms:DescribeKey"]
    resources = [
      aws_kms_key.data.arn,
    ]
  }
}

resource "aws_iam_role_policy" "kb_base" {
  name   = "${local.name_prefix}-kb-base"
  role   = aws_iam_role.knowledge_base.id
  policy = data.aws_iam_policy_document.kb_base.json
}

data "aws_iam_policy_document" "kb_aoss" {
  statement {
    sid     = "AccessVectorCollection"
    effect  = "Allow"
    actions = ["aoss:APIAccessAll"]
    resources = [
      aws_opensearchserverless_collection.vector.arn,
    ]
  }
}

resource "aws_iam_role_policy" "kb_aoss" {
  name   = "${local.name_prefix}-kb-aoss"
  role   = aws_iam_role.knowledge_base.id
  policy = data.aws_iam_policy_document.kb_aoss.json
}
