module "ecs" {
  source = "../../modules/ecs"

  project_name = local.project_name
  environment  = local.environment
  aws_region   = var.aws_region
  tags         = local.standard_tags

  container_insights = "enhanced"

  api_image_uri             = var.api_image_uri
  nginx_image_uri           = var.nginx_image_uri
  worker_image_uri          = var.worker_image_uri
  adot_collector_image_uri  = var.adot_collector_image_uri
  amp_remote_write_endpoint = module.observability.workspace_prometheus_endpoint

  application_subnet_ids   = values(module.vpc.application_private_subnet_ids)
  api_security_group_id    = module.security_groups.api_security_group_id
  worker_security_group_id = module.security_groups.worker_security_group_id
  api_target_group_arn     = module.alb.target_group_arn

  api_execution_role_arn    = module.workload_iam.api_execution_role_arn
  api_task_role_arn         = module.workload_iam.api_task_role_arn
  worker_execution_role_arn = module.workload_iam.worker_execution_role_arn
  worker_task_role_arn      = module.workload_iam.worker_task_role_arn

  database_host       = module.rds.address
  database_port       = module.rds.port
  database_name       = module.rds.db_name
  database_secret_arn = module.rds.master_user_secret_arn

  sqs_queue_url        = module.job_queue.queue_url
  artifact_bucket_name = module.artifact_storage.bucket_name

  api_desired_count    = var.api_desired_count
  worker_desired_count = var.worker_desired_count

  api_task_cpu                      = var.api_task_cpu
  api_task_memory                   = var.api_task_memory
  worker_task_cpu                   = var.worker_task_cpu
  worker_task_memory                = var.worker_task_memory
  migration_task_cpu                = var.migration_task_cpu
  migration_task_memory             = var.migration_task_memory
  adot_collector_cpu                = var.adot_collector_cpu
  adot_collector_memory_reservation = var.adot_collector_memory_reservation

  log_retention_days               = 7
  platform_version                 = "LATEST"
  job_processing_lease_seconds     = 120
  outbox_claim_lease_seconds       = 120
  sqs_visibility_timeout_seconds   = 60
  sqs_visibility_heartbeat_seconds = 30
  otel_traces_sampler_arg          = var.otel_traces_sampler_arg
  worker_metrics_port              = 9464

  depends_on = [module.alb]
}
