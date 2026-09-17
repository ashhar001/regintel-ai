locals {
  stage7c_availability_slo_percent      = 99.9
  stage7c_availability_error_budget_pct = 100 - local.stage7c_availability_slo_percent
  stage7c_fast_burn_rate                = 14.4
  stage7c_slow_burn_rate                = 6.0
  stage7c_fast_burn_threshold_pct       = local.stage7c_availability_error_budget_pct * local.stage7c_fast_burn_rate
  stage7c_slow_burn_threshold_pct       = local.stage7c_availability_error_budget_pct * local.stage7c_slow_burn_rate

  stage7c_availability_windows = {
    fast_5m = {
      period        = 300
      threshold_pct = local.stage7c_fast_burn_threshold_pct
      description   = "5 minute fast-burn availability window"
    }
    fast_1h = {
      period        = 3600
      threshold_pct = local.stage7c_fast_burn_threshold_pct
      description   = "1 hour fast-burn availability window"
    }
    slow_30m = {
      period        = 1800
      threshold_pct = local.stage7c_slow_burn_threshold_pct
      description   = "30 minute slow-burn availability window"
    }
    slow_6h = {
      period        = 21600
      threshold_pct = local.stage7c_slow_burn_threshold_pct
      description   = "6 hour slow-burn availability window"
    }
  }
}

resource "aws_sns_topic" "stage7c_sre_alerts" {
  name              = "${local.name_prefix}-sre-alerts"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Stage = "7c-slo-error-budgets"
  }
}

resource "aws_cloudwatch_metric_alarm" "stage7c_availability_burn" {
  for_each = local.stage7c_availability_windows

  alarm_name          = "${local.name_prefix}-availability-burn-${replace(each.key, "_", "-")}"
  alarm_description   = "${each.value.description}; 99.9% RAG availability SLO with ${each.value.threshold_pct}% error-rate burn threshold."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = each.value.threshold_pct
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "errors"
    return_data = false

    metric {
      metric_name = "RAGErrorCount"
      namespace   = local.stage7_metrics_namespace
      period      = each.value.period
      stat        = "Sum"
      unit        = "Count"
      dimensions = merge(local.stage7_metric_dimensions, {
        Operation = "rag_query"
      })
    }
  }

  metric_query {
    id          = "requests"
    return_data = false

    metric {
      metric_name = "RAGRequestCount"
      namespace   = local.stage7_metrics_namespace
      period      = each.value.period
      stat        = "Sum"
      unit        = "Count"
      dimensions = merge(local.stage7_metric_dimensions, {
        Operation = "rag_query"
      })
    }
  }

  metric_query {
    id          = "error_rate"
    expression  = "IF(requests>0,100*errors/requests,0)"
    label       = "RAG availability error rate (%)"
    return_data = true
  }

  tags = {
    Stage = "7c-slo-error-budgets"
    SLO   = "availability"
  }
}

resource "aws_cloudwatch_composite_alarm" "stage7c_availability_fast_burn" {
  alarm_name        = "${local.name_prefix}-availability-fast-burn"
  alarm_description = "Fast availability budget burn: both 5 minute and 1 hour windows exceed 14.4x burn for the 99.9% RAG availability SLO."
  alarm_rule = join(" AND ", [
    "ALARM(\"${aws_cloudwatch_metric_alarm.stage7c_availability_burn["fast_5m"].alarm_name}\")",
    "ALARM(\"${aws_cloudwatch_metric_alarm.stage7c_availability_burn["fast_1h"].alarm_name}\")",
  ])

  alarm_actions = [aws_sns_topic.stage7c_sre_alerts.arn]
  ok_actions    = [aws_sns_topic.stage7c_sre_alerts.arn]

  tags = {
    Stage = "7c-slo-error-budgets"
    SLO   = "availability"
  }
}

resource "aws_cloudwatch_composite_alarm" "stage7c_availability_slow_burn" {
  alarm_name        = "${local.name_prefix}-availability-slow-burn"
  alarm_description = "Slow availability budget burn: both 30 minute and 6 hour windows exceed 6x burn for the 99.9% RAG availability SLO."
  alarm_rule = join(" AND ", [
    "ALARM(\"${aws_cloudwatch_metric_alarm.stage7c_availability_burn["slow_30m"].alarm_name}\")",
    "ALARM(\"${aws_cloudwatch_metric_alarm.stage7c_availability_burn["slow_6h"].alarm_name}\")",
  ])

  alarm_actions = [aws_sns_topic.stage7c_sre_alerts.arn]
  ok_actions    = [aws_sns_topic.stage7c_sre_alerts.arn]

  tags = {
    Stage = "7c-slo-error-budgets"
    SLO   = "availability"
  }
}

resource "aws_cloudwatch_dashboard" "stage7c_slo" {
  dashboard_name = "${local.name_prefix}-slo"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 3
        properties = {
          markdown = "# RegIntel AI — Stage 7C SLOs\n**Availability:** 99.9% successful RAG queries (0.1% error budget).  \\n**Latency:** p95 RAG query latency < 5 seconds.  \\nFast burn = 14.4x budget; slow burn = 6x budget."
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 3
        width  = 12
        height = 6
        properties = {
          title  = "RAG availability error rate (%)"
          region = var.aws_region
          period = 300
          metrics = [
            [{ expression = "IF(requests>0,100*errors/requests,0)", label = "Error rate %", id = "error_rate" }],
            [local.stage7_metrics_namespace, "RAGErrorCount", "Service", local.stage7_service_name, "Environment", var.environment, "Operation", "rag_query", { stat = "Sum", id = "errors", visible = false }],
            [".", "RAGRequestCount", ".", ".", ".", ".", ".", ".", { stat = "Sum", id = "requests", visible = false }],
          ]
          annotations = {
            horizontal = [
              { label = "99.9% SLO budget", value = local.stage7c_availability_error_budget_pct },
              { label = "14.4x fast burn", value = local.stage7c_fast_burn_threshold_pct },
              { label = "6x slow burn", value = local.stage7c_slow_burn_threshold_pct },
            ]
          }
          yAxis = {
            left = { min = 0 }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 3
        width  = 12
        height = 6
        properties = {
          title  = "RAG latency objective"
          region = var.aws_region
          period = 300
          metrics = [
            [local.stage7_metrics_namespace, "RAGLatencyMs", "Service", local.stage7_service_name, "Environment", var.environment, "Operation", "rag_query", { stat = "p50", label = "p50" }],
            [local.stage7_metrics_namespace, "RAGLatencyMs", "Service", local.stage7_service_name, "Environment", var.environment, "Operation", "rag_query", { stat = "p95", label = "p95" }],
            [local.stage7_metrics_namespace, "RAGLatencyMs", "Service", local.stage7_service_name, "Environment", var.environment, "Operation", "rag_query", { stat = "p99", label = "p99" }],
          ]
          annotations = {
            horizontal = [
              { label = "p95 objective 5s", value = 5000 },
            ]
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 9
        width  = 24
        height = 6
        properties = {
          title  = "RAG traffic and application errors"
          region = var.aws_region
          period = 300
          metrics = [
            [local.stage7_metrics_namespace, "RAGRequestCount", "Service", local.stage7_service_name, "Environment", var.environment, "Operation", "rag_query", { stat = "Sum", label = "Requests" }],
            [".", "RAGErrorCount", ".", ".", ".", ".", ".", ".", { stat = "Sum", label = "Errors" }],
          ]
        }
      }
    ]
  })
}

output "stage7c_slo_dashboard_name" {
  value       = aws_cloudwatch_dashboard.stage7c_slo.dashboard_name
  description = "Stage 7C SLO and error-budget dashboard."
}

output "stage7c_sre_alerts_topic_arn" {
  value       = aws_sns_topic.stage7c_sre_alerts.arn
  description = "SNS topic used by Stage 7C composite SLO burn alarms."
}
