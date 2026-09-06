locals {
  ecs_cluster_name      = "${local.project_name}-${local.environment}"
  api_service_name      = "${local.project_name}-${local.environment}-api"
  worker_service_name   = "${local.project_name}-${local.environment}-worker"
  api_log_group_name    = "/ecs/production-cloud-reliability/${local.environment}/api"
  nginx_log_group_name  = "/ecs/production-cloud-reliability/${local.environment}/nginx"
  worker_log_group_name = "/ecs/production-cloud-reliability/${local.environment}/worker"
}

module "observability" {
  source = "../../modules/observability"

  project_name = local.project_name
  environment  = local.environment
  aws_region   = var.aws_region
  tags         = local.standard_tags

  api_task_role_name    = module.workload_iam.api_task_role_name
  worker_task_role_name = module.workload_iam.worker_task_role_name

  alb_arn          = module.alb.alb_arn
  target_group_arn = module.alb.target_group_arn
  rds_identifier   = module.rds.identifier
  queue_name       = module.job_queue.queue_name
  dlq_name         = module.job_queue.dlq_name

  ecs_cluster_name      = local.ecs_cluster_name
  api_service_name      = local.api_service_name
  worker_service_name   = local.worker_service_name
  api_log_group_name    = local.api_log_group_name
  nginx_log_group_name  = local.nginx_log_group_name
  worker_log_group_name = local.worker_log_group_name

  api_5xx_error_rate_alarm_percent       = var.api_5xx_error_rate_alarm_percent
  api_p95_latency_alarm_seconds          = var.api_p95_latency_alarm_seconds
  queue_oldest_message_age_alarm_seconds = var.queue_oldest_message_age_alarm_seconds
  rds_cpu_alarm_percent                  = var.rds_cpu_alarm_percent
  rds_free_storage_alarm_bytes           = var.rds_free_storage_alarm_bytes
}
