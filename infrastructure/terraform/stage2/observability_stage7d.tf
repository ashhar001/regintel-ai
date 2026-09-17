locals {
  stage7d_log_group_name = aws_cloudwatch_log_group.stage5b_api.name
}

resource "aws_cloudwatch_query_definition" "stage7d_request_trace" {
  name            = "${local.name_prefix}/stage7d/request-trace"
  log_group_names = [local.stage7d_log_group_name]

  query_string = <<-QUERY
    fields @timestamp, levelname, name, message, request_id, trace_id, path, status_code, latency_ms
    | filter ispresent(request_id) or ispresent(trace_id)
    | sort @timestamp desc
    | limit 100
  QUERY
}

resource "aws_cloudwatch_query_definition" "stage7d_errors" {
  name            = "${local.name_prefix}/stage7d/errors"
  log_group_names = [local.stage7d_log_group_name]

  query_string = <<-QUERY
    fields @timestamp, levelname, name, message, request_id, trace_id, path, status_code, latency_ms
    | filter levelname = "ERROR" or status_code >= 500 or message like /failed/
    | sort @timestamp desc
    | limit 100
  QUERY
}

resource "aws_cloudwatch_query_definition" "stage7d_rag_calls" {
  name            = "${local.name_prefix}/stage7d/rag-calls"
  log_group_names = [local.stage7d_log_group_name]

  query_string = <<-QUERY
    fields @timestamp, message, request_id, trace_id, knowledge_base_id, latency_ms, citation_count, result_count, search_type, rerank
    | filter message like /bedrock_kb_/
    | sort @timestamp desc
    | limit 100
  QUERY
}

resource "aws_cloudwatch_dashboard" "stage7d_incident_diagnostics" {
  dashboard_name = "${local.name_prefix}-incident-diagnostics"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 3
        properties = {
          markdown = "# RegIntel AI — Stage 7D Incident Diagnostics\nCorrelate API Gateway X-Ray `trace_id`, application `request_id`, HTTP logs, RAG operations, and SLO signals."
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 3
        width  = 24
        height = 7
        properties = {
          title  = "Recent request and trace correlation"
          region = var.aws_region
          view   = "table"
          query  = "SOURCE '${local.stage7d_log_group_name}' | fields @timestamp, levelname, name, message, request_id, trace_id, path, status_code, latency_ms | filter ispresent(request_id) or ispresent(trace_id) | sort @timestamp desc | limit 50"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 10
        width  = 12
        height = 7
        properties = {
          title  = "Errors and failed requests"
          region = var.aws_region
          view   = "table"
          query  = "SOURCE '${local.stage7d_log_group_name}' | fields @timestamp, levelname, message, request_id, trace_id, path, status_code, latency_ms | filter levelname = 'ERROR' or status_code >= 500 or message like /failed/ | sort @timestamp desc | limit 50"
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 10
        width  = 12
        height = 7
        properties = {
          title  = "Bedrock Knowledge Base operations"
          region = var.aws_region
          view   = "table"
          query  = "SOURCE '${local.stage7d_log_group_name}' | fields @timestamp, message, request_id, trace_id, knowledge_base_id, latency_ms, citation_count, result_count, search_type, rerank | filter message like /bedrock_kb_/ | sort @timestamp desc | limit 50"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 17
        width  = 24
        height = 6
        properties = {
          title  = "RAG incident signals"
          region = var.aws_region
          period = 300
          metrics = [
            [local.stage7_metrics_namespace, "RAGLatencyMs", "Service", local.stage7_service_name, "Environment", var.environment, "Operation", "rag_query", { stat = "p95", label = "RAG p95 latency" }],
            [local.stage7_metrics_namespace, "RAGErrorCount", "Service", local.stage7_service_name, "Environment", var.environment, "Operation", "rag_query", { stat = "Sum", label = "RAG errors" }],
            [local.stage7_metrics_namespace, "HTTPErrorCount", "Service", local.stage7_service_name, "Environment", var.environment, "Operation", "http_request", { stat = "Sum", label = "HTTP 5xx" }],
          ]
        }
      }
    ]
  })
}

output "stage7d_incident_dashboard_name" {
  value       = aws_cloudwatch_dashboard.stage7d_incident_diagnostics.dashboard_name
  description = "Stage 7D request/trace incident diagnostics dashboard."
}
