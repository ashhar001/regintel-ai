data "aws_iam_policy_document" "sfn_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ingestion_sfn" {
  name               = "${local.name_prefix}-ingestion-sfn"
  assume_role_policy = data.aws_iam_policy_document.sfn_assume_role.json
}

resource "aws_iam_role_policy" "ingestion_sfn" {
  name = "${local.name_prefix}-ingestion-sfn"
  role = aws_iam_role.ingestion_sfn.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InvokeIngestionLambdas"
        Effect = "Allow"
        Action = ["lambda:InvokeFunction"]
        Resource = [
          aws_lambda_function.validate_manifest.arn,
          aws_lambda_function.promote_document.arn,
          aws_lambda_function.update_status.arn
        ]
      },
      {
        Sid    = "ManageKnowledgeBaseIngestion"
        Effect = "Allow"
        Action = [
          "bedrock:StartIngestionJob",
          "bedrock:GetIngestionJob"
        ]
        Resource = aws_bedrockagent_knowledge_base.this.arn
      },
      {
        Sid      = "SendWorkflowFailures"
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.workflow_failures.arn
      },
      {
        Sid    = "XRayTracing"
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets"
        ]
        Resource = "*"
      },
      {
        Sid    = "StepFunctionsLogging"
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "ingestion_sfn" {
  name              = "/aws/vendedlogs/states/${local.name_prefix}-ingestion"
  retention_in_days = 30
}

resource "aws_sfn_state_machine" "ingestion" {
  name     = "${local.name_prefix}-ingestion"
  role_arn = aws_iam_role.ingestion_sfn.arn
  type     = "STANDARD"

  logging_configuration {
    include_execution_data = true
    level                  = "ERROR"
    log_destination        = "${aws_cloudwatch_log_group.ingestion_sfn.arn}:*"
  }

  tracing_configuration {
    enabled = true
  }

  definition = jsonencode({
    Comment        = "RegIntel production document ingestion workflow"
    StartAt        = "NormalizePipeInput"
    TimeoutSeconds = 1800
    States = {
      NormalizePipeInput = {
        Type = "Pass"
        Parameters = {
          "event.$" = "$[0].event"
        }
        Next = "ValidateManifest"
      }
      ValidateManifest = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.validate_manifest.arn
          "Payload.$"  = "$.event"
        }
        ResultSelector = {
          "prepared.$" = "$.Payload"
        }
        ResultPath = "$.validation"
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
          IntervalSeconds = 2
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "SendValidationFailure"
        }]
        Next = "AlreadyProcessed"
      }
      AlreadyProcessed = {
        Type = "Choice"
        Choices = [{
          Variable      = "$.validation.prepared.duplicate"
          BooleanEquals = true
          Next          = "DuplicateComplete"
        }]
        Default = "PromoteDocument"
      }
      DuplicateComplete = {
        Type = "Succeed"
      }
      PromoteDocument = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.promote_document.arn
          "Payload.$"  = "$.validation.prepared"
        }
        ResultSelector = {
          "prepared.$" = "$.Payload"
        }
        ResultPath = "$.promotion"
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
          IntervalSeconds = 2
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "MarkWorkflowFailed"
        }]
        Next = "StartIngestionJob"
      }
      StartIngestionJob = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::aws-sdk:bedrockagent:startIngestionJob"
        Parameters = {
          KnowledgeBaseId = aws_bedrockagent_knowledge_base.this.id
          DataSourceId    = aws_bedrockagent_data_source.s3.data_source_id
          "ClientToken.$" = "$.promotion.prepared.ingestion_token"
          "Description.$" = "States.Format('RegIntel automated ingestion for {}', $.promotion.prepared.document_id)"
        }
        ResultPath = "$.bedrock"
        Retry = [{
          ErrorEquals = [
            "BedrockAgent.ConflictException",
            "BedrockAgent.ThrottlingException",
            "BedrockAgent.InternalServerException"
          ]
          IntervalSeconds = 10
          MaxAttempts     = 30
          BackoffRate     = 1.2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "MarkWorkflowFailed"
        }]
        Next = "WaitForIngestion"
      }
      WaitForIngestion = {
        Type    = "Wait"
        Seconds = var.ingestion_poll_seconds
        Next    = "GetIngestionJob"
      }
      GetIngestionJob = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::aws-sdk:bedrockagent:getIngestionJob"
        Parameters = {
          KnowledgeBaseId    = aws_bedrockagent_knowledge_base.this.id
          DataSourceId       = aws_bedrockagent_data_source.s3.data_source_id
          "IngestionJobId.$" = "$.bedrock.IngestionJob.IngestionJobId"
        }
        ResultPath = "$.poll"
        Retry = [{
          ErrorEquals     = ["BedrockAgent.ThrottlingException", "BedrockAgent.InternalServerException"]
          IntervalSeconds = 5
          MaxAttempts     = 5
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "MarkWorkflowFailed"
        }]
        Next = "IngestionStatus"
      }
      IngestionStatus = {
        Type = "Choice"
        Choices = [
          {
            Variable     = "$.poll.IngestionJob.Status"
            StringEquals = "COMPLETE"
            Next         = "MarkIndexed"
          },
          {
            Variable     = "$.poll.IngestionJob.Status"
            StringEquals = "FAILED"
            Next         = "MarkIngestionFailed"
          },
          {
            Variable     = "$.poll.IngestionJob.Status"
            StringEquals = "STOPPED"
            Next         = "MarkIngestionFailed"
          }
        ]
        Default = "WaitForIngestion"
      }
      MarkIndexed = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.update_status.arn
          Payload = {
            "ingestion_fingerprint.$" = "$.promotion.prepared.ingestion_fingerprint"
            status                    = "INDEXED"
            "ingestion_job_id.$"      = "$.bedrock.IngestionJob.IngestionJobId"
            "details.$"               = "$.poll"
          }
        }
        ResultPath = "$.final"
        Next       = "Success"
      }
      Success = {
        Type = "Succeed"
      }
      MarkIngestionFailed = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.update_status.arn
          Payload = {
            "ingestion_fingerprint.$" = "$.promotion.prepared.ingestion_fingerprint"
            status                    = "FAILED"
            "ingestion_job_id.$"      = "$.bedrock.IngestionJob.IngestionJobId"
            "details.$"               = "$.poll"
          }
        }
        ResultPath = "$.failure_status"
        Next       = "SendWorkflowFailure"
      }
      MarkWorkflowFailed = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.update_status.arn
          Payload = {
            "ingestion_fingerprint.$" = "$.validation.prepared.ingestion_fingerprint"
            status                    = "FAILED"
            "details.$"               = "$.error"
          }
        }
        ResultPath = "$.failure_status"
        Next       = "SendWorkflowFailure"
      }
      SendValidationFailure = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::sqs:sendMessage"
        Parameters = {
          QueueUrl        = aws_sqs_queue.workflow_failures.id
          "MessageBody.$" = "States.JsonToString($)"
        }
        Next = "WorkflowFailed"
      }
      SendWorkflowFailure = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::sqs:sendMessage"
        Parameters = {
          QueueUrl        = aws_sqs_queue.workflow_failures.id
          "MessageBody.$" = "States.JsonToString($)"
        }
        Next = "WorkflowFailed"
      }
      WorkflowFailed = {
        Type  = "Fail"
        Error = "RegIntelIngestionFailed"
        Cause = "Document ingestion workflow failed; inspect workflow failure queue and execution logs."
      }
    }
  })
}
