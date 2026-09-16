output "stage5b_ecr_repository_url" {
  value       = aws_ecr_repository.stage5b_api.repository_url
  description = "Push the RegIntel API Docker image here before enabling the ECS service."
}

output "stage5b_api_base_url" {
  value       = "https://${aws_api_gateway_rest_api.stage5b.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.stage5b.stage_name}"
  description = "Public WAF-protected API Gateway base URL. /health is public; /v1/* requires Cognito."
}

output "stage5b_cognito_user_pool_id" {
  value       = aws_cognito_user_pool.stage5b.id
  description = "Cognito user pool used by the API Gateway authorizer."
}

output "stage5b_cognito_app_client_id" {
  value       = aws_cognito_user_pool_client.stage5b.id
  description = "Public Cognito application client ID for CLI/browser authentication."
}

output "stage5b_ecs_cluster_name" {
  value       = aws_ecs_cluster.stage5b.name
  description = "ECS cluster hosting the RegIntel API."
}

output "stage5b_ecs_service_name" {
  value       = try(aws_ecs_service.stage5b_api[0].name, null)
  description = "ECS service name; null during the bootstrap-only apply."
}

output "stage5b_internal_nlb_dns" {
  value       = aws_lb.stage5b.dns_name
  description = "Private NLB DNS name used only through API Gateway VPC Link."
}

output "stage5b_vpc_id" {
  value       = aws_vpc.stage5b.id
  description = "Private application VPC."
}

output "stage5b_runtime_dashboard_name" {
  value       = aws_cloudwatch_dashboard.stage5b_runtime.dashboard_name
  description = "CloudWatch dashboard for API Gateway, NLB, and ECS runtime metrics."
}
