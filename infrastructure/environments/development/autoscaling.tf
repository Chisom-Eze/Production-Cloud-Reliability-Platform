module "ecs_autoscaling" {
  source = "../../modules/ecs-autoscaling"

  cluster_name        = module.ecs.cluster_name
  api_service_name    = module.ecs.api_service_name
  worker_service_name = module.ecs.worker_service_name
  queue_name          = module.job_queue.queue_name

  api_min_capacity    = var.api_min_capacity
  api_max_capacity    = var.api_max_capacity
  worker_min_capacity = var.worker_min_capacity
  worker_max_capacity = var.worker_max_capacity

  api_cpu_target_percent    = var.api_cpu_target_percent
  api_memory_target_percent = var.api_memory_target_percent

  worker_backlog_per_task_target = var.worker_backlog_per_task_target

  api_scale_out_cooldown_seconds    = var.api_scale_out_cooldown_seconds
  api_scale_in_cooldown_seconds     = var.api_scale_in_cooldown_seconds
  worker_scale_out_cooldown_seconds = var.worker_scale_out_cooldown_seconds
  worker_scale_in_cooldown_seconds  = var.worker_scale_in_cooldown_seconds
}
