locals {
  api_resource_id    = "service/${var.cluster_name}/${var.api_service_name}"
  worker_resource_id = "service/${var.cluster_name}/${var.worker_service_name}"
}

resource "aws_appautoscaling_target" "api" {
  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"
  resource_id        = local.api_resource_id
  min_capacity       = var.api_min_capacity
  max_capacity       = var.api_max_capacity
}

resource "aws_appautoscaling_target" "worker" {
  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"
  resource_id        = local.worker_resource_id
  min_capacity       = var.worker_min_capacity
  max_capacity       = var.worker_max_capacity
}

resource "aws_appautoscaling_policy" "api_cpu" {
  name               = "${var.api_service_name}-cpu-target-tracking"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api.resource_id
  scalable_dimension = aws_appautoscaling_target.api.scalable_dimension
  service_namespace  = aws_appautoscaling_target.api.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.api_cpu_target_percent
    scale_out_cooldown = var.api_scale_out_cooldown_seconds
    scale_in_cooldown  = var.api_scale_in_cooldown_seconds

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_appautoscaling_policy" "api_memory" {
  name               = "${var.api_service_name}-memory-target-tracking"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api.resource_id
  scalable_dimension = aws_appautoscaling_target.api.scalable_dimension
  service_namespace  = aws_appautoscaling_target.api.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.api_memory_target_percent
    scale_out_cooldown = var.api_scale_out_cooldown_seconds
    scale_in_cooldown  = var.api_scale_in_cooldown_seconds

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}

resource "aws_appautoscaling_policy" "worker_backlog" {
  name               = "${var.worker_service_name}-backlog-per-task-target-tracking"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.worker.resource_id
  scalable_dimension = aws_appautoscaling_target.worker.scalable_dimension
  service_namespace  = aws_appautoscaling_target.worker.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.worker_backlog_per_task_target
    scale_out_cooldown = var.worker_scale_out_cooldown_seconds
    scale_in_cooldown  = var.worker_scale_in_cooldown_seconds

    customized_metric_specification {
      metrics {
        id          = "m1"
        label       = "sqs_visible_messages"
        return_data = false

        metric_stat {
          stat = "Average"

          metric {
            namespace   = "AWS/SQS"
            metric_name = "ApproximateNumberOfMessagesVisible"

            dimensions {
              name  = "QueueName"
              value = var.queue_name
            }
          }
        }
      }

      metrics {
        id          = "m2"
        label       = "worker_running_task_count"
        return_data = false

        metric_stat {
          stat = "Average"

          metric {
            namespace   = "ECS/ContainerInsights"
            metric_name = "RunningTaskCount"

            dimensions {
              name  = "ClusterName"
              value = var.cluster_name
            }

            dimensions {
              name  = "ServiceName"
              value = var.worker_service_name
            }
          }
        }
      }

      metrics {
        id          = "e1"
        expression  = "m1 / m2"
        label       = "worker_backlog_per_task"
        return_data = true
      }
    }
  }
}
