resource "aws_cloudwatch_metric_alarm" "bedrock_server_errors" {
  alarm_name          = "${local.name_prefix}-bedrock-server-errors"
  alarm_description   = "Amazon Bedrock model invocations are returning server-side errors."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "InvocationServerErrors"
  namespace           = "AWS/Bedrock"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    ModelId = "amazon.nova-lite-v1:0"
  }
}

resource "aws_cloudwatch_metric_alarm" "bedrock_throttles" {
  alarm_name          = "${local.name_prefix}-bedrock-throttles"
  alarm_description   = "Amazon Bedrock model invocations are being throttled."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "InvocationThrottles"
  namespace           = "AWS/Bedrock"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    ModelId = "amazon.nova-lite-v1:0"
  }
}

resource "aws_cloudwatch_dashboard" "regintel" {
  dashboard_name = "${local.name_prefix}-rag-operations"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "# RegIntel AI — RAG Operations\nBedrock runtime, guardrails, ingestion health, and failure queues."
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 12
        height = 6
        properties = {
          title  = "Bedrock invocation latency"
          region = var.aws_region
          period = 300
          stat   = "Average"
          metrics = [
            ["AWS/Bedrock", "InvocationLatency", "ModelId", "amazon.nova-lite-v1:0"]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 2
        width  = 12
        height = 6
        properties = {
          title  = "Bedrock tokens"
          region = var.aws_region
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/Bedrock", "InputTokenCount", "ModelId", "amazon.nova-lite-v1:0"],
            [".", "OutputTokenCount", ".", "."]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 12
        height = 6
        properties = {
          title  = "Bedrock errors / throttles"
          region = var.aws_region
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/Bedrock", "InvocationClientErrors", "ModelId", "amazon.nova-lite-v1:0"],
            [".", "InvocationServerErrors", ".", "."],
            [".", "InvocationThrottles", ".", "."]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 8
        width  = 12
        height = 6
        properties = {
          title  = "Guardrail interventions"
          region = var.aws_region
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/Bedrock/Guardrails", "InvocationsIntervened", "GuardrailArn", aws_bedrock_guardrail.regintel.guardrail_arn, "GuardrailVersion", aws_bedrock_guardrail_version.regintel.version]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 14
        width  = 12
        height = 6
        properties = {
          title  = "Ingestion workflow"
          region = var.aws_region
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/States", "ExecutionsSucceeded", "StateMachineArn", aws_sfn_state_machine.ingestion.arn],
            [".", "ExecutionsFailed", ".", "."]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 14
        width  = 12
        height = 6
        properties = {
          title  = "Failure queues"
          region = var.aws_region
          period = 300
          stat   = "Maximum"
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.ingestion_dlq.name],
            [".", ".", ".", aws_sqs_queue.workflow_failures.name]
          ]
        }
      }
    ]
  })
}

output "cloudwatch_dashboard_name" {
  value       = aws_cloudwatch_dashboard.regintel.dashboard_name
  description = "Stage 5 CloudWatch operations dashboard."
}
