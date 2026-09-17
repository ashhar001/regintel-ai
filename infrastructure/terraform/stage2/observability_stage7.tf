locals {
  stage7_metrics_namespace = "RegIntel/RAG"
  stage7_service_name      = "regintel-api"
  stage7_metric_dimensions = {
    Service     = local.stage7_service_name
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "stage7_rag_errors" {
  alarm_name          = "${local.name_prefix}-rag-errors"
  alarm_description   = "RegIntel RAG requests are returning application-level errors."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RAGErrorCount"
  namespace           = local.stage7_metrics_namespace
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = merge(local.stage7_metric_dimensions, {
    Operation = "rag_query"
  })
}

resource "aws_cloudwatch_metric_alarm" "stage7_rag_p95_latency" {
  alarm_name          = "${local.name_prefix}-rag-p95-latency"
  alarm_description   = "RegIntel RAG p95 latency is above the 5 second service objective."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RAGLatencyMs"
  namespace           = local.stage7_metrics_namespace
  period              = 300
  extended_statistic  = "p95"
  threshold           = 5000
  treat_missing_data  = "notBreaching"

  dimensions = merge(local.stage7_metric_dimensions, {
    Operation = "rag_query"
  })
}

resource "aws_cloudwatch_metric_alarm" "stage7_http_errors" {
  alarm_name          = "${local.name_prefix}-http-errors"
  alarm_description   = "RegIntel API is returning HTTP 5xx responses."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPErrorCount"
  namespace           = local.stage7_metrics_namespace
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = merge(local.stage7_metric_dimensions, {
    Operation = "http_request"
  })
}

resource "aws_cloudwatch_dashboard" "stage7_sre" {
  dashboard_name = "${local.name_prefix}-sre"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "# RegIntel AI — Stage 7 SRE\nApplication SLO signals emitted through CloudWatch Embedded Metric Format."
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 12
        height = 6
        properties = {
          title  = "RAG request volume and errors"
          region = var.aws_region
          period = 300
          metrics = [
            [local.stage7_metrics_namespace, "RAGRequestCount", "Service", local.stage7_service_name, "Environment", var.environment, "Operation", "rag_query", { stat = "Sum" }],
            [".", "RAGErrorCount", ".", ".", ".", ".", ".", ".", { stat = "Sum" }],
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
          title  = "RAG latency p50 / p95 / p99"
          region = var.aws_region
          period = 300
          metrics = [
            [local.stage7_metrics_namespace, "RAGLatencyMs", "Service", local.stage7_service_name, "Environment", var.environment, "Operation", "rag_query", { stat = "p50", label = "p50" }],
            [local.stage7_metrics_namespace, "RAGLatencyMs", "Service", local.stage7_service_name, "Environment", var.environment, "Operation", "rag_query", { stat = "p95", label = "p95" }],
            [local.stage7_metrics_namespace, "RAGLatencyMs", "Service", local.stage7_service_name, "Environment", var.environment, "Operation", "rag_query", { stat = "p99", label = "p99" }],
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
          title  = "Retrieval latency and result count"
          region = var.aws_region
          period = 300
          metrics = [
            [local.stage7_metrics_namespace, "RetrievalLatencyMs", "Service", local.stage7_service_name, "Environment", var.environment, "Operation", "rag_retrieve", { stat = "p95" }],
            [".", "RetrievalResultCount", ".", ".", ".", ".", ".", ".", { stat = "Average" }],
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
          title  = "Citations and Guardrail interventions"
          region = var.aws_region
          period = 300
          metrics = [
            [local.stage7_metrics_namespace, "CitationCount", "Service", local.stage7_service_name, "Environment", var.environment, "Operation", "rag_query", { stat = "Average" }],
            [".", "GuardrailBlockedCount", ".", ".", ".", ".", ".", ".", { stat = "Sum" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 14
        width  = 24
        height = 6
        properties = {
          title  = "HTTP request latency and 5xx errors"
          region = var.aws_region
          period = 300
          metrics = [
            [local.stage7_metrics_namespace, "HTTPLatencyMs", "Service", local.stage7_service_name, "Environment", var.environment, "Operation", "http_request", { stat = "p95" }],
            [".", "HTTPErrorCount", ".", ".", ".", ".", ".", ".", { stat = "Sum" }],
            [".", "HTTPRequestCount", ".", ".", ".", ".", ".", ".", { stat = "Sum" }],
          ]
        }
      }
    ]
  })
}

output "stage7_sre_dashboard_name" {
  value       = aws_cloudwatch_dashboard.stage7_sre.dashboard_name
  description = "Stage 7 application SRE dashboard."
}
