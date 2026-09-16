data "aws_availability_zones" "stage5b" {
  state = "available"
}

resource "aws_vpc" "stage5b" {
  cidr_block           = var.stage5b_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name  = "${local.name_prefix}-runtime-vpc"
    Stage = "5b-production-runtime"
  }
}

resource "aws_subnet" "stage5b_private" {
  count = 2

  vpc_id                  = aws_vpc.stage5b.id
  cidr_block              = var.stage5b_private_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.stage5b.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name  = "${local.name_prefix}-private-${count.index + 1}"
    Stage = "5b-production-runtime"
  }
}

resource "aws_route_table" "stage5b_private" {
  count = 2

  vpc_id = aws_vpc.stage5b.id

  tags = {
    Name  = "${local.name_prefix}-private-rt-${count.index + 1}"
    Stage = "5b-production-runtime"
  }
}

resource "aws_route_table_association" "stage5b_private" {
  count = 2

  subnet_id      = aws_subnet.stage5b_private[count.index].id
  route_table_id = aws_route_table.stage5b_private[count.index].id
}

resource "aws_security_group" "stage5b_endpoints" {
  name        = "${local.name_prefix}-vpce-sg"
  description = "HTTPS from private RegIntel runtime tasks to interface VPC endpoints"
  vpc_id      = aws_vpc.stage5b.id

  ingress {
    description = "HTTPS from runtime VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.stage5b_vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "${local.name_prefix}-vpce-sg"
    Stage = "5b-production-runtime"
  }
}

resource "aws_security_group" "stage5b_ecs" {
  name        = "${local.name_prefix}-ecs-sg"
  description = "Private RegIntel API tasks"
  vpc_id      = aws_vpc.stage5b.id

  ingress {
    description = "API traffic from private VPC through the internal NLB"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = [var.stage5b_vpc_cidr]
  }

  # There is no internet/NAT route. HTTPS egress can reach only configured VPC
  # endpoints plus AWS services reachable through the S3 gateway endpoint.
  egress {
    description = "HTTPS to AWS private endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "${local.name_prefix}-ecs-sg"
    Stage = "5b-production-runtime"
  }
}

locals {
  stage5b_interface_endpoints = toset([
    "ecr.api",
    "ecr.dkr",
    "logs",
    "bedrock-runtime",
    "bedrock-agent-runtime",
  ])
}

resource "aws_vpc_endpoint" "stage5b_interface" {
  for_each = local.stage5b_interface_endpoints

  vpc_id              = aws_vpc.stage5b.id
  service_name        = "com.amazonaws.${var.aws_region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.stage5b_private[*].id
  security_group_ids  = [aws_security_group.stage5b_endpoints.id]

  tags = {
    Name  = "${local.name_prefix}-${replace(each.value, ".", "-")}-vpce"
    Stage = "5b-production-runtime"
  }
}

resource "aws_vpc_endpoint" "stage5b_s3" {
  vpc_id            = aws_vpc.stage5b.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.stage5b_private[*].id

  tags = {
    Name  = "${local.name_prefix}-s3-vpce"
    Stage = "5b-production-runtime"
  }
}
