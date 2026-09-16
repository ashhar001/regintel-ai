variable "stage5b_runtime_enabled" {
  description = "Create the ECS service after an image has been pushed to ECR. Keep false for the bootstrap apply."
  type        = bool
  default     = false
}

variable "stage5b_image_tag" {
  description = "Immutable ECR image tag deployed by the ECS task definition."
  type        = string
  default     = "stage5b"
}

variable "stage5b_vpc_cidr" {
  description = "CIDR for the private RegIntel runtime VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "stage5b_private_subnet_cidrs" {
  description = "Two private subnet CIDRs used by ECS, the internal NLB, and interface endpoints."
  type        = list(string)
  default     = ["10.40.1.0/24", "10.40.2.0/24"]

  validation {
    condition     = length(var.stage5b_private_subnet_cidrs) == 2
    error_message = "stage5b_private_subnet_cidrs must contain exactly two CIDRs."
  }
}

variable "stage5b_api_stage_name" {
  description = "API Gateway REST API deployment stage name."
  type        = string
  default     = "prod"
}

variable "stage5b_task_cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 512
}

variable "stage5b_task_memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 1024
}

variable "stage5b_desired_count" {
  description = "Desired Fargate task count when runtime is enabled. Use 1 in dev and 2+ for production HA."
  type        = number
  default     = 1
}

variable "stage5b_min_capacity" {
  description = "Minimum ECS service task count for autoscaling."
  type        = number
  default     = 1
}

variable "stage5b_max_capacity" {
  description = "Maximum ECS service task count for autoscaling."
  type        = number
  default     = 4
}

variable "stage5b_cpu_target" {
  description = "Target average ECS CPU utilization percentage."
  type        = number
  default     = 60
}

variable "stage5b_waf_rate_limit" {
  description = "Per-IP AWS WAF request threshold for the rate-based rule."
  type        = number
  default     = 1000
}
