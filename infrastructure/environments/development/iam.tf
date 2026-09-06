data "aws_caller_identity" "current" {}

locals {
  ecr_repository_arns = {
    api    = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/production-cloud-reliability-api"
    nginx  = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/production-cloud-reliability-nginx"
    worker = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/production-cloud-reliability-worker"
  }

  ecs_log_group_arns = {
    api    = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/production-cloud-reliability/${local.environment}/api"
    nginx  = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/production-cloud-reliability/${local.environment}/nginx"
    worker = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/production-cloud-reliability/${local.environment}/worker"
  }
}

module "workload_iam" {
  source = "../../modules/workload-iam"

  project_slug = "prod-cloud-reliability"
  environment  = local.environment

  job_queue_arn          = module.job_queue.queue_arn
  artifact_bucket_arn    = module.artifact_storage.bucket_arn
  artifact_object_prefix = "reports/*"
  database_secret_arn    = module.rds.master_user_secret_arn

  api_ecr_repository_arn    = local.ecr_repository_arns.api
  nginx_ecr_repository_arn  = local.ecr_repository_arns.nginx
  worker_ecr_repository_arn = local.ecr_repository_arns.worker

  api_log_group_arn    = local.ecs_log_group_arns.api
  nginx_log_group_arn  = local.ecs_log_group_arns.nginx
  worker_log_group_arn = local.ecs_log_group_arns.worker
}
