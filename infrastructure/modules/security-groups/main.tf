locals {
  name_prefix = "${var.project_display_name}-${var.environment}"
}

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb"
  description = "Security group for the internet-facing application load balancer."
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-alb"
  }
}

resource "aws_security_group" "api" {
  name        = "${local.name_prefix}-api"
  description = "Security group for API ECS tasks running Nginx and FastAPI."
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-api"
  }
}

resource "aws_security_group" "worker" {
  name        = "${local.name_prefix}-worker"
  description = "Security group for worker ECS tasks."
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-worker"
  }
}

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds"
  description = "Security group for PostgreSQL RDS."
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-rds"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http_from_ipv4" {
  for_each = toset(var.alb_ingress_ipv4_cidrs)

  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP traffic from approved IPv4 clients."
  cidr_ipv4         = each.value
  from_port         = var.alb_listener_port
  ip_protocol       = "tcp"
  to_port           = var.alb_listener_port
}

resource "aws_vpc_security_group_ingress_rule" "alb_https_from_ipv4" {
  for_each = toset(var.alb_ingress_ipv4_cidrs)

  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTPS traffic from approved IPv4 clients."
  cidr_ipv4         = each.value
  from_port         = var.alb_https_listener_port
  ip_protocol       = "tcp"
  to_port           = var.alb_https_listener_port
}

resource "aws_vpc_security_group_egress_rule" "alb_http_to_api" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Allow ALB HTTP egress to API tasks."
  referenced_security_group_id = aws_security_group.api.id
  from_port                    = var.api_ingress_port
  ip_protocol                  = "tcp"
  to_port                      = var.api_ingress_port
}

resource "aws_vpc_security_group_ingress_rule" "api_http_from_alb" {
  security_group_id            = aws_security_group.api.id
  description                  = "Allow API HTTP ingress only from the ALB."
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.api_ingress_port
  ip_protocol                  = "tcp"
  to_port                      = var.api_ingress_port
}

resource "aws_vpc_security_group_egress_rule" "api_https_to_ipv4" {
  security_group_id = aws_security_group.api.id
  description       = "Allow API HTTPS egress through NAT for AWS APIs and permitted external dependencies."
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = var.workload_https_egress_port
  ip_protocol       = "tcp"
  to_port           = var.workload_https_egress_port
}

resource "aws_vpc_security_group_egress_rule" "worker_https_to_ipv4" {
  security_group_id = aws_security_group.worker.id
  description       = "Allow worker HTTPS egress through NAT for AWS APIs and permitted external dependencies."
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = var.workload_https_egress_port
  ip_protocol       = "tcp"
  to_port           = var.workload_https_egress_port
}

resource "aws_vpc_security_group_egress_rule" "api_postgresql_to_rds" {
  security_group_id            = aws_security_group.api.id
  description                  = "Allow API PostgreSQL egress to RDS."
  referenced_security_group_id = aws_security_group.rds.id
  from_port                    = var.database_port
  ip_protocol                  = "tcp"
  to_port                      = var.database_port
}

resource "aws_vpc_security_group_egress_rule" "worker_postgresql_to_rds" {
  security_group_id            = aws_security_group.worker.id
  description                  = "Allow worker PostgreSQL egress to RDS."
  referenced_security_group_id = aws_security_group.rds.id
  from_port                    = var.database_port
  ip_protocol                  = "tcp"
  to_port                      = var.database_port
}

resource "aws_vpc_security_group_ingress_rule" "rds_postgresql_from_api" {
  security_group_id            = aws_security_group.rds.id
  description                  = "Allow PostgreSQL from API tasks."
  referenced_security_group_id = aws_security_group.api.id
  from_port                    = var.database_port
  ip_protocol                  = "tcp"
  to_port                      = var.database_port
}

resource "aws_vpc_security_group_ingress_rule" "rds_postgresql_from_worker" {
  security_group_id            = aws_security_group.rds.id
  description                  = "Allow PostgreSQL from worker tasks."
  referenced_security_group_id = aws_security_group.worker.id
  from_port                    = var.database_port
  ip_protocol                  = "tcp"
  to_port                      = var.database_port
}
