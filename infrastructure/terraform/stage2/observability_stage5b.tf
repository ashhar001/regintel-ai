resource "aws_cloudwatch_metric_alarm" "stage5b_api_5xx" {
  alarm_name          = "${local.name_prefix}-api-5xx"
  alarm_description   = "API Gateway is returning 5xx responses."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.stage5b.name
    Stage   = aws_api_gateway_stage.stage5b.stage_name
  }
}

resource "aws_cloudwatch_metric_alarm" "stage5b_unhealthy_targets" {
  count = var.stage5b_runtime_enabled ? 1 : 0

  alarm_name          = "${local.name_prefix}-unhealthy-api-targets"
  alarm_description   = "One or more RegIntel Fargate targets are unhealthy."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/NetworkELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "breaching"

  dimensions = {
    LoadBalancer = aws_lb.stage5b.arn_suffix
    TargetGroup  = aws_lb_target_group.stage5b.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "stage5b_ecs_cpu" {
  count = var.stage5b_runtime_enabled ? 1 : 0

  alarm_name          = "${local.name_prefix}-ecs-high-cpu"
  alarm_description   = "RegIntel API average CPU is above 80 percent."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.stage5b.name
    ServiceName = aws_ecs_service.stage5b_api[0].name
  }
}

resource "aws_cloudwatch_dashboard" "stage5b_runtime" {
  dashboard_name = "${local.name_prefix}-runtime"

  dashboard_body = jsonencode({
    widgets = concat(
      [
        {
          type   = "text"
          x      = 0
          y      = 0
          width  = 24
          height = 2
          properties = {
            markdown = "# RegIntel AI — Production Runtime\nAPI Gateway, WAF, ECS/Fargate, and internal NLB."
          }
        },
        {
          type   = "metric"
          x      = 0
          y      = 2
          width  = 12
          height = 6
          properties = {
            title  = "API Gateway latency and errors"
            region = var.aws_region
            period = 300
            metrics = [
              ["AWS/ApiGateway", "Latency", "ApiName", aws_api_gateway_rest_api.stage5b.name, "Stage", aws_api_gateway_stage.stage5b.stage_name, { stat = "Average" }],
              [".", "5XXError", ".", ".", ".", ".", { stat = "Sum" }],
              [".", "4XXError", ".", ".", ".", ".", { stat = "Sum" }],
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
            title  = "NLB target health"
            region = var.aws_region
            period = 60
            metrics = [
              ["AWS/NetworkELB", "HealthyHostCount", "LoadBalancer", aws_lb.stage5b.arn_suffix, "TargetGroup", aws_lb_target_group.stage5b.arn_suffix, { stat = "Average" }],
              [".", "UnHealthyHostCount", ".", ".", ".", ".", { stat = "Maximum" }],
            ]
          }
        }
      ],
      var.stage5b_runtime_enabled ? [
        {
          type   = "metric"
          x      = 0
          y      = 8
          width  = 24
          height = 6
          properties = {
            title  = "ECS service utilization"
            region = var.aws_region
            period = 60
            metrics = [
              ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.stage5b.name, "ServiceName", aws_ecs_service.stage5b_api[0].name, { stat = "Average" }],
              [".", "MemoryUtilization", ".", ".", ".", ".", { stat = "Average" }],
            ]
          }
        }
      ] : []
    )
  })
}
