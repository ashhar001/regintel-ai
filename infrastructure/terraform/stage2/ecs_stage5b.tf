locals {
  stage5b_nlb_name = substr("${local.name_prefix}-api-nlb", 0, 32)
  stage5b_tg_name  = substr("${local.name_prefix}-api-tg", 0, 32)
  stage5b_image    = "${aws_ecr_repository.stage5b_api.repository_url}:${var.stage5b_image_tag}"
}

resource "aws_cloudwatch_log_group" "stage5b_api" {
  name              = "/ecs/${local.name_prefix}/api"
  retention_in_days = 14

  tags = {
    Stage = "5b-production-runtime"
  }
}

resource "aws_ecs_cluster" "stage5b" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Stage = "5b-production-runtime"
  }
}

resource "aws_lb" "stage5b" {
  name                             = local.stage5b_nlb_name
  internal                         = true
  load_balancer_type               = "network"
  subnets                          = aws_subnet.stage5b_private[*].id
  enable_cross_zone_load_balancing = true

  tags = {
    Stage = "5b-production-runtime"
  }
}

resource "aws_lb_target_group" "stage5b" {
  name        = local.stage5b_tg_name
  port        = 8000
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = aws_vpc.stage5b.id

  deregistration_delay = 30

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/health"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200-399"
  }

  tags = {
    Stage = "5b-production-runtime"
  }
}

resource "aws_lb_listener" "stage5b" {
  load_balancer_arn = aws_lb.stage5b.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stage5b.arn
  }
}

resource "aws_ecs_task_definition" "stage5b_api" {
  family                   = "${local.name_prefix}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.stage5b_task_cpu)
  memory                   = tostring(var.stage5b_task_memory)
  execution_role_arn       = aws_iam_role.stage5b_execution.arn
  task_role_arn            = aws_iam_role.stage5b_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "regintel-api"
      image     = local.stage5b_image
      essential = true

      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "APP_ENV", value = var.environment },
        { name = "LOG_LEVEL", value = "INFO" },
        { name = "AWS_REGION", value = var.aws_region },
        { name = "BEDROCK_MODEL_ID", value = "amazon.nova-lite-v1:0" },
        { name = "BEDROCK_KNOWLEDGE_BASE_ID", value = aws_bedrockagent_knowledge_base.this.id },
        { name = "BEDROCK_RAG_MODEL_ARN", value = local.stage5b_nova_model_arn },
        { name = "BEDROCK_RERANK_MODEL_ARN", value = local.rerank_model_arn },
        { name = "BEDROCK_GUARDRAIL_ID", value = aws_bedrock_guardrail.regintel.guardrail_id },
        { name = "BEDROCK_GUARDRAIL_VERSION", value = aws_bedrock_guardrail_version.regintel.version },
      ]

      healthCheck = {
        command = [
          "CMD-SHELL",
          "python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)\" || exit 1",
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 20
      }

      linuxParameters = {
        initProcessEnabled = true
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.stage5b_api.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "api"
        }
      }
    }
  ])

  tags = {
    Stage = "5b-production-runtime"
  }

  depends_on = [
    aws_iam_role_policy_attachment.stage5b_execution,
    aws_iam_role_policy.stage5b_task,
  ]
}

resource "aws_ecs_service" "stage5b_api" {
  count = var.stage5b_runtime_enabled ? 1 : 0

  name            = "${local.name_prefix}-api"
  cluster         = aws_ecs_cluster.stage5b.id
  task_definition = aws_ecs_task_definition.stage5b_api.arn
  desired_count   = var.stage5b_desired_count
  launch_type     = "FARGATE"

  platform_version = "LATEST"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = aws_subnet.stage5b_private[*].id
    security_groups  = [aws_security_group.stage5b_ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.stage5b.arn
    container_name   = "regintel-api"
    container_port   = 8000
  }

  health_check_grace_period_seconds = 60
  enable_execute_command            = false

  lifecycle {
    # desired_count is controlled by autoscaling; task_definition revisions are
    # promoted by the Stage 6 GitHub deployment pipeline.
    ignore_changes = [desired_count, task_definition]
  }

  depends_on = [
    aws_lb_listener.stage5b,
    aws_vpc_endpoint.stage5b_interface,
    aws_vpc_endpoint.stage5b_s3,
  ]

  tags = {
    Stage = "5b-production-runtime"
  }
}

resource "aws_appautoscaling_target" "stage5b_api" {
  count = var.stage5b_runtime_enabled ? 1 : 0

  max_capacity       = var.stage5b_max_capacity
  min_capacity       = var.stage5b_min_capacity
  resource_id        = "service/${aws_ecs_cluster.stage5b.name}/${aws_ecs_service.stage5b_api[0].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "stage5b_cpu" {
  count = var.stage5b_runtime_enabled ? 1 : 0

  name               = "${local.name_prefix}-cpu-target"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.stage5b_api[0].resource_id
  scalable_dimension = aws_appautoscaling_target.stage5b_api[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.stage5b_api[0].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.stage5b_cpu_target
    scale_in_cooldown  = 120
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
