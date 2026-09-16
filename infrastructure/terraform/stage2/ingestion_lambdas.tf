data "archive_file" "validate_manifest" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda/validate_manifest"
  output_path = "${path.module}/.validate_manifest.zip"
}

data "archive_file" "promote_document" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda/promote_document"
  output_path = "${path.module}/.promote_document.zip"
}

data "archive_file" "update_status" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda/update_status"
  output_path = "${path.module}/.update_status.zip"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ingestion_lambda" {
  name               = "${local.name_prefix}-ingestion-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ingestion_lambda_logs" {
  role       = aws_iam_role.ingestion_lambda.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "ingestion_lambda" {
  name = "${local.name_prefix}-ingestion-lambda"
  role = aws_iam_role.ingestion_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadIncomingAndWriteDocuments"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetObjectTagging",
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.raw.arn}/incoming/*",
          "${aws_s3_bucket.raw.arn}/documents/*"
        ]
      },
      {
        Sid    = "TrackIngestion"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.ingestion.arn
      },
      {
        Sid    = "UseDataKey"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.data.arn
      }
    ]
  })
}

resource "aws_lambda_function" "validate_manifest" {
  function_name = "${local.name_prefix}-validate-manifest"
  role          = aws_iam_role.ingestion_lambda.arn
  runtime       = "python3.12"
  handler       = "handler.lambda_handler"
  timeout       = 120
  memory_size   = 512

  filename         = data.archive_file.validate_manifest.output_path
  source_code_hash = data.archive_file.validate_manifest.output_base64sha256

  environment {
    variables = {
      INGESTION_TABLE_NAME = aws_dynamodb_table.ingestion.name
      MAX_DOCUMENT_BYTES   = tostring(var.ingestion_max_document_bytes)
      SUPPORTED_EXTENSIONS = join(",", var.ingestion_supported_extensions)
    }
  }
}

resource "aws_lambda_function" "promote_document" {
  function_name = "${local.name_prefix}-promote-document"
  role          = aws_iam_role.ingestion_lambda.arn
  runtime       = "python3.12"
  handler       = "handler.lambda_handler"
  timeout       = 120
  memory_size   = 512

  filename         = data.archive_file.promote_document.output_path
  source_code_hash = data.archive_file.promote_document.output_base64sha256

  environment {
    variables = {
      INGESTION_TABLE_NAME = aws_dynamodb_table.ingestion.name
    }
  }
}

resource "aws_lambda_function" "update_status" {
  function_name = "${local.name_prefix}-update-status"
  role          = aws_iam_role.ingestion_lambda.arn
  runtime       = "python3.12"
  handler       = "handler.lambda_handler"
  timeout       = 30
  memory_size   = 256

  filename         = data.archive_file.update_status.output_path
  source_code_hash = data.archive_file.update_status.output_base64sha256

  environment {
    variables = {
      INGESTION_TABLE_NAME = aws_dynamodb_table.ingestion.name
    }
  }
}
