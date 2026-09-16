resource "aws_wafv2_web_acl" "stage5b" {
  name        = "${local.name_prefix}-api-waf"
  description = "Managed-rule and rate-limit protection for the RegIntel REST API"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedCommonRules"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "PerIpRateLimit"
    priority = 20

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.stage5b_waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-api-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Stage = "5b-production-runtime"
  }
}

resource "aws_wafv2_web_acl_association" "stage5b" {
  resource_arn = "arn:${data.aws_partition.current.partition}:apigateway:${var.aws_region}::/restapis/${aws_api_gateway_rest_api.stage5b.id}/stages/${aws_api_gateway_stage.stage5b.stage_name}"
  web_acl_arn  = aws_wafv2_web_acl.stage5b.arn

  depends_on = [aws_api_gateway_stage.stage5b]
}
