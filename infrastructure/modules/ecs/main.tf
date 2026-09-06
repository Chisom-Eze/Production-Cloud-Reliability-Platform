locals {
  name_prefix = "${var.project_name}-${var.environment}"

  api_container_name       = "api"
  nginx_container_name     = "nginx"
  worker_container_name    = "worker"
  migration_container_name = "migration"
  adot_container_name      = "adot-collector"

  api_log_group_name    = "/ecs/production-cloud-reliability/${var.environment}/api"
  nginx_log_group_name  = "/ecs/production-cloud-reliability/${var.environment}/nginx"
  worker_log_group_name = "/ecs/production-cloud-reliability/${var.environment}/worker"

  database_environment = [
    {
      name  = "RUNTIME_MODE"
      value = "cloud"
    },
    {
      name  = "DB_HOST"
      value = var.database_host
    },
    {
      name  = "DB_PORT"
      value = tostring(var.database_port)
    },
    {
      name  = "DB_NAME"
      value = var.database_name
    },
    {
      name  = "AWS_REGION"
      value = var.aws_region
    }
  ]

  database_secrets = [
    {
      name      = "DB_USERNAME"
      valueFrom = "${var.database_secret_arn}:username::"
    },
    {
      name      = "DB_PASSWORD"
      valueFrom = "${var.database_secret_arn}:password::"
    }
  ]

  worker_environment = concat(local.database_environment, [
    {
      name  = "SQS_QUEUE_URL"
      value = var.sqs_queue_url
    },
    {
      name  = "ARTIFACT_BACKEND"
      value = "s3"
    },
    {
      name  = "ARTIFACT_BUCKET_NAME"
      value = var.artifact_bucket_name
    },
    {
      name  = "JOB_PROCESSING_LEASE_SECONDS"
      value = tostring(var.job_processing_lease_seconds)
    },
    {
      name  = "OUTBOX_CLAIM_LEASE_SECONDS"
      value = tostring(var.outbox_claim_lease_seconds)
    },
    {
      name  = "SQS_VISIBILITY_TIMEOUT_SECONDS"
      value = tostring(var.sqs_visibility_timeout_seconds)
    },
    {
      name  = "SQS_VISIBILITY_HEARTBEAT_SECONDS"
      value = tostring(var.sqs_visibility_heartbeat_seconds)
    }
  ])

  api_adot_config = yamlencode({
    receivers = {
      otlp = {
        protocols = {
          grpc = {
            endpoint = "127.0.0.1:4317"
          }
        }
      }
      prometheus = {
        config = {
          scrape_configs = [
            {
              job_name        = "api"
              scrape_interval = "30s"
              static_configs = [
                {
                  targets = ["127.0.0.1:8000"]
                }
              ]
            }
          ]
        }
      }
    }
    processors = {
      memory_limiter = {
        check_interval = "1s"
        limit_mib      = 96
      }
      batch = {}
    }
    exporters = {
      awsxray = {}
      prometheusremotewrite = {
        endpoint = "${var.amp_remote_write_endpoint}api/v1/remote_write"
        auth = {
          authenticator = "sigv4auth"
        }
      }
    }
    extensions = {
      sigv4auth = {
        region  = var.aws_region
        service = "aps"
      }
    }
    service = {
      extensions = ["sigv4auth"]
      pipelines = {
        traces = {
          receivers  = ["otlp"]
          processors = ["memory_limiter", "batch"]
          exporters  = ["awsxray"]
        }
        metrics = {
          receivers  = ["prometheus"]
          processors = ["memory_limiter", "batch"]
          exporters  = ["prometheusremotewrite"]
        }
      }
    }
  })

  worker_adot_config = yamlencode({
    receivers = {
      otlp = {
        protocols = {
          grpc = {
            endpoint = "127.0.0.1:4317"
          }
        }
      }
      prometheus = {
        config = {
          scrape_configs = [
            {
              job_name        = "worker"
              scrape_interval = "30s"
              static_configs = [
                {
                  targets = ["127.0.0.1:${var.worker_metrics_port}"]
                }
              ]
            }
          ]
        }
      }
    }
    processors = {
      memory_limiter = {
        check_interval = "1s"
        limit_mib      = 96
      }
      batch = {}
    }
    exporters = {
      awsxray = {}
      prometheusremotewrite = {
        endpoint = "${var.amp_remote_write_endpoint}api/v1/remote_write"
        auth = {
          authenticator = "sigv4auth"
        }
      }
    }
    extensions = {
      sigv4auth = {
        region  = var.aws_region
        service = "aps"
      }
    }
    service = {
      extensions = ["sigv4auth"]
      pipelines = {
        traces = {
          receivers  = ["otlp"]
          processors = ["memory_limiter", "batch"]
          exporters  = ["awsxray"]
        }
        metrics = {
          receivers  = ["prometheus"]
          processors = ["memory_limiter", "batch"]
          exporters  = ["prometheusremotewrite"]
        }
      }
    }
  })
}

resource "aws_ecs_cluster" "this" {
  name = local.name_prefix

  setting {
    name  = "containerInsights"
    value = var.container_insights
  }

  tags = merge(var.tags, {
    Name = local.name_prefix
  })
}

resource "aws_cloudwatch_log_group" "api" {
  name              = local.api_log_group_name
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = local.api_log_group_name
  })
}

resource "aws_cloudwatch_log_group" "nginx" {
  name              = local.nginx_log_group_name
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = local.nginx_log_group_name
  })
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = local.worker_log_group_name
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = local.worker_log_group_name
  })
}

resource "aws_ecs_task_definition" "api" {
  family                   = "${local.name_prefix}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.api_task_cpu)
  memory                   = tostring(var.api_task_memory)
  execution_role_arn       = var.api_execution_role_arn
  task_role_arn            = var.api_task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name                   = local.api_container_name
      image                  = var.api_image_uri
      essential              = true
      cpu                    = var.api_container_cpu
      readonlyRootFilesystem = false
      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
          protocol      = "tcp"
        }
      ]
      environment = concat(local.database_environment, [
        {
          name  = "OTEL_ENABLED"
          value = "true"
        },
        {
          name  = "OTEL_SERVICE_NAME"
          value = "production-cloud-reliability-api"
        },
        {
          name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
          value = "http://127.0.0.1:4317"
        },
        {
          name  = "OTEL_TRACES_SAMPLER"
          value = "parentbased_traceidratio"
        },
        {
          name  = "OTEL_TRACES_SAMPLER_ARG"
          value = tostring(var.otel_traces_sampler_arg)
        }
      ])
      secrets = local.database_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "api"
        }
      }
      healthCheck = {
        command = [
          "CMD-SHELL",
          "python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)\""
        ]
        interval    = 10
        timeout     = 3
        retries     = 3
        startPeriod = 30
      }
    },
    {
      name                   = local.nginx_container_name
      image                  = var.nginx_image_uri
      essential              = true
      cpu                    = var.nginx_container_cpu
      readonlyRootFilesystem = false
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "NGINX_LISTEN_PORT"
          value = "80"
        },
        {
          name  = "NGINX_UPSTREAM_HOST"
          value = "127.0.0.1"
        },
        {
          name  = "NGINX_UPSTREAM_PORT"
          value = "8000"
        }
      ]
      dependsOn = [
        {
          containerName = local.api_container_name
          condition     = "HEALTHY"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.nginx.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "nginx"
        }
      }
    },
    {
      name                   = local.adot_container_name
      image                  = var.adot_collector_image_uri
      essential              = false
      cpu                    = var.adot_collector_cpu
      memoryReservation      = var.adot_collector_memory_reservation
      readonlyRootFilesystem = false
      command                = ["--config=env:AOT_CONFIG_CONTENT"]
      environment = [
        {
          name  = "AOT_CONFIG_CONTENT"
          value = local.api_adot_config
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "otel"
        }
      }
    }
  ])

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-api"
  })
}

resource "aws_ecs_task_definition" "worker" {
  family                   = "${local.name_prefix}-worker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.worker_task_cpu)
  memory                   = tostring(var.worker_task_memory)
  execution_role_arn       = var.worker_execution_role_arn
  task_role_arn            = var.worker_task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name                   = local.worker_container_name
      image                  = var.worker_image_uri
      essential              = true
      cpu                    = var.worker_container_cpu
      readonlyRootFilesystem = false
      stopTimeout            = 120
      environment = concat(local.worker_environment, [
        {
          name  = "METRICS_ENABLED"
          value = "true"
        },
        {
          name  = "WORKER_METRICS_HOST"
          value = "127.0.0.1"
        },
        {
          name  = "WORKER_METRICS_PORT"
          value = tostring(var.worker_metrics_port)
        },
        {
          name  = "OTEL_ENABLED"
          value = "true"
        },
        {
          name  = "OTEL_SERVICE_NAME"
          value = "production-cloud-reliability-worker"
        },
        {
          name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
          value = "http://127.0.0.1:4317"
        },
        {
          name  = "OTEL_TRACES_SAMPLER"
          value = "parentbased_traceidratio"
        },
        {
          name  = "OTEL_TRACES_SAMPLER_ARG"
          value = tostring(var.otel_traces_sampler_arg)
        }
      ])
      secrets = local.database_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.worker.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "worker"
        }
      }
    },
    {
      name                   = local.adot_container_name
      image                  = var.adot_collector_image_uri
      essential              = false
      cpu                    = var.adot_collector_cpu
      memoryReservation      = var.adot_collector_memory_reservation
      readonlyRootFilesystem = false
      command                = ["--config=env:AOT_CONFIG_CONTENT"]
      environment = [
        {
          name  = "AOT_CONFIG_CONTENT"
          value = local.worker_adot_config
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.worker.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "otel"
        }
      }
    }
  ])

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-worker"
  })
}

resource "aws_ecs_task_definition" "migration" {
  family                   = "${local.name_prefix}-migration"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.migration_task_cpu)
  memory                   = tostring(var.migration_task_memory)
  execution_role_arn       = var.api_execution_role_arn
  task_role_arn            = var.api_task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name                   = local.migration_container_name
      image                  = var.api_image_uri
      essential              = true
      readonlyRootFilesystem = false
      command                = ["python", "-m", "application.migrations"]
      environment            = local.database_environment
      secrets                = local.database_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "migration"
        }
      }
    }
  ])

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-migration"
  })
}

resource "aws_ecs_service" "api" {
  name             = "${local.name_prefix}-api"
  cluster          = aws_ecs_cluster.this.id
  task_definition  = aws_ecs_task_definition.api.arn
  desired_count    = var.api_desired_count
  launch_type      = "FARGATE"
  platform_version = var.platform_version

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60
  enable_ecs_managed_tags            = true
  propagate_tags                     = "SERVICE"
  enable_execute_command             = false

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_controller {
    type = "ECS"
  }

  network_configuration {
    subnets          = var.application_subnet_ids
    security_groups  = [var.api_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.api_target_group_arn
    container_name   = local.nginx_container_name
    container_port   = 80
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-api"
  })

  lifecycle {
    ignore_changes = [desired_count]
  }
}

resource "aws_ecs_service" "worker" {
  name             = "${local.name_prefix}-worker"
  cluster          = aws_ecs_cluster.this.id
  task_definition  = aws_ecs_task_definition.worker.arn
  desired_count    = var.worker_desired_count
  launch_type      = "FARGATE"
  platform_version = var.platform_version

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  enable_ecs_managed_tags            = true
  propagate_tags                     = "SERVICE"
  enable_execute_command             = false

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_controller {
    type = "ECS"
  }

  network_configuration {
    subnets          = var.application_subnet_ids
    security_groups  = [var.worker_security_group_id]
    assign_public_ip = false
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-worker"
  })

  lifecycle {
    ignore_changes = [desired_count]
  }
}
