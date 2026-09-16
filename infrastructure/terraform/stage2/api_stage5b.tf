resource "aws_api_gateway_rest_api" "stage5b" {
  name        = "${local.name_prefix}-api"
  description = "Authenticated RegIntel production API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Stage = "5b-production-runtime"
  }
}

resource "aws_api_gateway_vpc_link" "stage5b" {
  name        = "${local.name_prefix}-vpc-link"
  description = "Private API Gateway connection to the internal RegIntel NLB"
  target_arns = [aws_lb.stage5b.arn]

  tags = {
    Stage = "5b-production-runtime"
  }
}

resource "aws_api_gateway_authorizer" "stage5b" {
  name            = "${local.name_prefix}-cognito"
  rest_api_id     = aws_api_gateway_rest_api.stage5b.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [aws_cognito_user_pool.stage5b.arn]
  identity_source = "method.request.header.Authorization"
}

resource "aws_api_gateway_resource" "stage5b_health" {
  rest_api_id = aws_api_gateway_rest_api.stage5b.id
  parent_id   = aws_api_gateway_rest_api.stage5b.root_resource_id
  path_part   = "health"
}

resource "aws_api_gateway_method" "stage5b_health" {
  rest_api_id   = aws_api_gateway_rest_api.stage5b.id
  resource_id   = aws_api_gateway_resource.stage5b_health.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "stage5b_health" {
  rest_api_id             = aws_api_gateway_rest_api.stage5b.id
  resource_id             = aws_api_gateway_resource.stage5b_health.id
  http_method             = aws_api_gateway_method.stage5b_health.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "GET"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.stage5b.id
  uri                     = "http://${aws_lb.stage5b.dns_name}/health"
}

resource "aws_api_gateway_resource" "stage5b_v1" {
  rest_api_id = aws_api_gateway_rest_api.stage5b.id
  parent_id   = aws_api_gateway_rest_api.stage5b.root_resource_id
  path_part   = "v1"
}

resource "aws_api_gateway_resource" "stage5b_proxy" {
  rest_api_id = aws_api_gateway_rest_api.stage5b.id
  parent_id   = aws_api_gateway_resource.stage5b_v1.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "stage5b_proxy" {
  rest_api_id   = aws_api_gateway_rest_api.stage5b.id
  resource_id   = aws_api_gateway_resource.stage5b_proxy.id
  http_method   = "ANY"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.stage5b.id

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "stage5b_proxy" {
  rest_api_id             = aws_api_gateway_rest_api.stage5b.id
  resource_id             = aws_api_gateway_resource.stage5b_proxy.id
  http_method             = aws_api_gateway_method.stage5b_proxy.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.stage5b.id
  uri                     = "http://${aws_lb.stage5b.dns_name}/v1/{proxy}"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

resource "aws_api_gateway_deployment" "stage5b" {
  rest_api_id = aws_api_gateway_rest_api.stage5b.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.stage5b_health.id,
      aws_api_gateway_resource.stage5b_proxy.id,
      aws_api_gateway_method.stage5b_health.id,
      aws_api_gateway_method.stage5b_proxy.id,
      aws_api_gateway_integration.stage5b_health.id,
      aws_api_gateway_integration.stage5b_proxy.id,
      aws_api_gateway_authorizer.stage5b.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.stage5b_health,
    aws_api_gateway_integration.stage5b_proxy,
  ]
}

resource "aws_api_gateway_stage" "stage5b" {
  rest_api_id   = aws_api_gateway_rest_api.stage5b.id
  deployment_id = aws_api_gateway_deployment.stage5b.id
  stage_name    = var.stage5b_api_stage_name

  tags = {
    Stage = "5b-production-runtime"
  }
}

resource "aws_api_gateway_method_settings" "stage5b" {
  rest_api_id = aws_api_gateway_rest_api.stage5b.id
  stage_name  = aws_api_gateway_stage.stage5b.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled        = true
    data_trace_enabled     = false
    logging_level          = "OFF"
    throttling_burst_limit = 50
    throttling_rate_limit  = 25
  }
}
