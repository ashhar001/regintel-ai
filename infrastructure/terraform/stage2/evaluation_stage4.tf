locals {
  rag_evaluation_model_arns = [
    "arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}::foundation-model/amazon.nova-pro-v1:0",
    "arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}::foundation-model/amazon.nova-lite-v1:0",
  ]

  knowledge_base_arn = "arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:knowledge-base/${aws_bedrockagent_knowledge_base.this.id}"
}

resource "aws_iam_role" "bedrock_rag_evaluation" {
  name = "${local.name_prefix}-rag-evaluation"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBedrockEvaluationJobs"
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:evaluation-job/*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "bedrock_rag_evaluation" {
  name = "${local.name_prefix}-rag-evaluation"
  role = aws_iam_role.bedrock_rag_evaluation.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EvaluationBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:AbortMultipartUpload",
          "s3:ListBucketMultipartUploads",
        ]
        Resource = [
          aws_s3_bucket.evaluation.arn,
          "${aws_s3_bucket.evaluation.arn}/*",
        ]
      },
      {
        Sid    = "EvaluationBucketKms"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey",
        ]
        Resource = [aws_kms_key.data.arn]
      },
      {
        Sid    = "EvaluationModels"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:CreateModelInvocationJob",
          "bedrock:StopModelInvocationJob",
          "bedrock:GetProvisionedModelThroughput",
          "bedrock:GetInferenceProfile",
          "bedrock:GetImportedModel",
        ]
        Resource = local.rag_evaluation_model_arns
      },
      {
        Sid    = "EvaluateKnowledgeBase"
        Effect = "Allow"
        Action = [
          "bedrock:Retrieve",
          "bedrock:RetrieveAndGenerate",
        ]
        Resource = [local.knowledge_base_arn]
      },
    ]
  })
}

output "rag_evaluation_role_arn" {
  description = "IAM role assumed by Amazon Bedrock RAG evaluation jobs."
  value       = aws_iam_role.bedrock_rag_evaluation.arn
}
