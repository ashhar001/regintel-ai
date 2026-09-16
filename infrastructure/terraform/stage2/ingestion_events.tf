resource "aws_s3_bucket_notification" "raw_eventbridge" {
  bucket      = aws_s3_bucket.raw.id
  eventbridge = true
}

resource "aws_cloudwatch_event_rule" "ingestion_manifest" {
  name        = "${local.name_prefix}-manifest-created"
  description = "Route RegIntel ingestion manifests to the ingestion queue"

  event_pattern = jsonencode({
    source        = ["aws.s3"]
    "detail-type" = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.raw.id]
      }
      object = {
        key = [{ wildcard = "incoming/manifests/*.manifest.json" }]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "ingestion_queue" {
  rule      = aws_cloudwatch_event_rule.ingestion_manifest.name
  target_id = "ingestion-sqs"
  arn       = aws_sqs_queue.ingestion.arn
}

data "aws_iam_policy_document" "ingestion_queue" {
  statement {
    sid     = "AllowEventBridge"
    effect  = "Allow"
    actions = ["sqs:SendMessage"]
    resources = [
      aws_sqs_queue.ingestion.arn,
    ]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.ingestion_manifest.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "ingestion" {
  queue_url = aws_sqs_queue.ingestion.id
  policy    = data.aws_iam_policy_document.ingestion_queue.json
}

data "aws_iam_policy_document" "pipes_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["pipes.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ingestion_pipe" {
  name               = "${local.name_prefix}-ingestion-pipe"
  assume_role_policy = data.aws_iam_policy_document.pipes_assume_role.json
}

resource "aws_iam_role_policy" "ingestion_pipe" {
  name = "${local.name_prefix}-ingestion-pipe"
  role = aws_iam_role.ingestion_pipe.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ConsumeQueue"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.ingestion.arn
      },
      {
        Sid      = "StartWorkflow"
        Effect   = "Allow"
        Action   = ["states:StartExecution"]
        Resource = aws_sfn_state_machine.ingestion.arn
      },
      {
        Sid    = "WritePipeLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.ingestion_pipe.arn}:*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "ingestion_pipe" {
  name              = "/aws/vendedlogs/pipes/${local.name_prefix}-ingestion"
  retention_in_days = 30
}

resource "aws_pipes_pipe" "ingestion" {
  name     = "${local.name_prefix}-ingestion"
  role_arn = aws_iam_role.ingestion_pipe.arn
  source   = aws_sqs_queue.ingestion.arn
  target   = aws_sfn_state_machine.ingestion.arn

  source_parameters {
    sqs_queue_parameters {
      batch_size                         = 1
      maximum_batching_window_in_seconds = 0
    }
  }

  target_parameters {
    input_template = <<-EOT
      {"event": <$.body>}
    EOT

    step_function_state_machine_parameters {
      invocation_type = "FIRE_AND_FORGET"
    }
  }

  log_configuration {
    level                  = "ERROR"
    include_execution_data = ["ALL"]

    cloudwatch_logs_log_destination {
      log_group_arn = aws_cloudwatch_log_group.ingestion_pipe.arn
    }
  }

  depends_on = [
    aws_iam_role_policy.ingestion_pipe,
    aws_sqs_queue_policy.ingestion,
  ]
}
