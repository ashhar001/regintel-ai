resource "aws_cloudwatch_metric_alarm" "ingestion_dlq" {
  alarm_name          = "${local.name_prefix}-ingestion-dlq-not-empty"
  alarm_description   = "Ingress messages are failing EventBridge Pipes delivery."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.ingestion_dlq.name
  }
}

resource "aws_cloudwatch_metric_alarm" "workflow_failures" {
  alarm_name          = "${local.name_prefix}-workflow-failures-not-empty"
  alarm_description   = "RegIntel ingestion workflows have emitted failure records."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.workflow_failures.name
  }
}

resource "aws_cloudwatch_metric_alarm" "state_machine_failed" {
  alarm_name          = "${local.name_prefix}-sfn-executions-failed"
  alarm_description   = "A RegIntel document ingestion execution failed."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.ingestion.arn
  }
}
