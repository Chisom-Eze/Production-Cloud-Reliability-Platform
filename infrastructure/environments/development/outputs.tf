output "vpc_id" {
  description = "Development VPC ID."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "Development VPC CIDR block."
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "Development public subnet IDs keyed by availability zone."
  value       = module.vpc.public_subnet_ids
}

output "application_private_subnet_ids" {
  description = "Development application-private subnet IDs keyed by availability zone."
  value       = module.vpc.application_private_subnet_ids
}

output "database_private_subnet_ids" {
  description = "Development database-private subnet IDs keyed by availability zone."
  value       = module.vpc.database_private_subnet_ids
}

output "public_subnet_cidr_blocks" {
  description = "Development public subnet CIDR blocks keyed by availability zone."
  value       = module.vpc.public_subnet_cidr_blocks
}

output "application_private_subnet_cidr_blocks" {
  description = "Development application-private subnet CIDR blocks keyed by availability zone."
  value       = module.vpc.application_private_subnet_cidr_blocks
}

output "database_private_subnet_cidr_blocks" {
  description = "Development database-private subnet CIDR blocks keyed by availability zone."
  value       = module.vpc.database_private_subnet_cidr_blocks
}

output "internet_gateway_id" {
  description = "Development Internet Gateway ID."
  value       = module.vpc.internet_gateway_id
}

output "nat_gateway_ids" {
  description = "Development NAT Gateway IDs keyed by availability zone."
  value       = module.vpc.nat_gateway_ids
}

output "public_route_table_id" {
  description = "Development public route table ID."
  value       = module.vpc.public_route_table_id
}

output "application_private_route_table_ids" {
  description = "Development application-private route table IDs keyed by availability zone."
  value       = module.vpc.application_private_route_table_ids
}

output "database_private_route_table_ids" {
  description = "Development database-private route table IDs keyed by availability zone."
  value       = module.vpc.database_private_route_table_ids
}

output "alb_security_group_id" {
  description = "Development ALB security group ID."
  value       = module.security_groups.alb_security_group_id
}

output "api_security_group_id" {
  description = "Development API ECS task security group ID."
  value       = module.security_groups.api_security_group_id
}

output "worker_security_group_id" {
  description = "Development worker ECS task security group ID."
  value       = module.security_groups.worker_security_group_id
}

output "rds_security_group_id" {
  description = "Development RDS security group ID."
  value       = module.security_groups.rds_security_group_id
}

output "rds_identifier" {
  description = "Development RDS instance identifier."
  value       = module.rds.identifier
}

output "rds_arn" {
  description = "Development RDS instance ARN."
  value       = module.rds.arn
}

output "rds_address" {
  description = "Development RDS instance DNS address."
  value       = module.rds.address
}

output "rds_endpoint" {
  description = "Development RDS instance endpoint including port."
  value       = module.rds.endpoint
}

output "rds_port" {
  description = "Development RDS listener port."
  value       = module.rds.port
}

output "rds_db_name" {
  description = "Development initial database name."
  value       = module.rds.db_name
}

output "rds_db_subnet_group_name" {
  description = "Development RDS DB subnet group name."
  value       = module.rds.db_subnet_group_name
}

output "rds_master_user_secret_arn" {
  description = "Development RDS-managed master user secret ARN."
  value       = module.rds.master_user_secret_arn
  sensitive   = true
}

output "rds_enhanced_monitoring_role_arn" {
  description = "Development RDS Enhanced Monitoring IAM role ARN."
  value       = module.rds.enhanced_monitoring_role_arn
}

output "job_queue_id" {
  description = "Development jobs SQS queue URL."
  value       = module.job_queue.queue_id
}

output "job_queue_url" {
  description = "Development jobs SQS queue URL."
  value       = module.job_queue.queue_url
}

output "job_queue_arn" {
  description = "Development jobs SQS queue ARN."
  value       = module.job_queue.queue_arn
}

output "job_queue_name" {
  description = "Development jobs SQS queue name."
  value       = module.job_queue.queue_name
}

output "job_queue_dlq_id" {
  description = "Development jobs DLQ URL."
  value       = module.job_queue.dlq_id
}

output "job_queue_dlq_url" {
  description = "Development jobs DLQ URL."
  value       = module.job_queue.dlq_url
}

output "job_queue_dlq_arn" {
  description = "Development jobs DLQ ARN."
  value       = module.job_queue.dlq_arn
}

output "job_queue_dlq_name" {
  description = "Development jobs DLQ name."
  value       = module.job_queue.dlq_name
}

output "artifact_bucket_id" {
  description = "Development artifact S3 bucket ID."
  value       = module.artifact_storage.bucket_id
}

output "artifact_bucket_name" {
  description = "Development artifact S3 bucket name."
  value       = module.artifact_storage.bucket_name
}

output "artifact_bucket_arn" {
  description = "Development artifact S3 bucket ARN."
  value       = module.artifact_storage.bucket_arn
}

output "artifact_bucket_regional_domain_name" {
  description = "Development artifact S3 bucket regional domain name."
  value       = module.artifact_storage.bucket_regional_domain_name
}

output "api_execution_role_arn" {
  description = "Development API ECS execution role ARN."
  value       = module.workload_iam.api_execution_role_arn
}

output "api_execution_role_name" {
  description = "Development API ECS execution role name."
  value       = module.workload_iam.api_execution_role_name
}

output "api_task_role_arn" {
  description = "Development API ECS task role ARN."
  value       = module.workload_iam.api_task_role_arn
}

output "api_task_role_name" {
  description = "Development API ECS task role name."
  value       = module.workload_iam.api_task_role_name
}

output "worker_execution_role_arn" {
  description = "Development worker ECS execution role ARN."
  value       = module.workload_iam.worker_execution_role_arn
}

output "worker_execution_role_name" {
  description = "Development worker ECS execution role name."
  value       = module.workload_iam.worker_execution_role_name
}

output "worker_task_role_arn" {
  description = "Development worker ECS task role ARN."
  value       = module.workload_iam.worker_task_role_arn
}

output "worker_task_role_name" {
  description = "Development worker ECS task role name."
  value       = module.workload_iam.worker_task_role_name
}

output "application_domain_name" {
  description = "Development application domain name."
  value       = var.application_domain_name
}

output "acm_certificate_arn" {
  description = "Development validated ACM certificate ARN."
  value       = module.acm_dns.certificate_arn
}

output "alb_arn" {
  description = "Development application load balancer ARN."
  value       = module.alb.alb_arn
}

output "alb_dns_name" {
  description = "Development application load balancer DNS name."
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Development application load balancer hosted zone ID."
  value       = module.alb.alb_zone_id
}

output "api_target_group_arn" {
  description = "Development API target group ARN."
  value       = module.alb.target_group_arn
}

output "api_target_group_name" {
  description = "Development API target group name."
  value       = module.alb.target_group_name
}

output "https_listener_arn" {
  description = "Development HTTPS listener ARN."
  value       = module.alb.https_listener_arn
}

output "alb_access_log_bucket_name" {
  description = "Development ALB access-log bucket name."
  value       = module.alb.access_log_bucket_name
}

output "alb_access_log_bucket_arn" {
  description = "Development ALB access-log bucket ARN."
  value       = module.alb.access_log_bucket_arn
}

output "waf_web_acl_id" {
  description = "Development WAFv2 Web ACL ID."
  value       = module.waf.web_acl_id
}

output "waf_web_acl_arn" {
  description = "Development WAFv2 Web ACL ARN."
  value       = module.waf.web_acl_arn
}

output "waf_web_acl_name" {
  description = "Development WAFv2 Web ACL name."
  value       = module.waf.web_acl_name
}

output "waf_log_group_name" {
  description = "Development WAF CloudWatch log group name."
  value       = module.waf.log_group_name
}

output "waf_log_group_arn" {
  description = "Development WAF CloudWatch log group ARN."
  value       = module.waf.log_group_arn
}

output "ecs_cluster_id" {
  description = "Development ECS cluster ID."
  value       = module.ecs.cluster_id
}

output "ecs_cluster_arn" {
  description = "Development ECS cluster ARN."
  value       = module.ecs.cluster_arn
}

output "ecs_cluster_name" {
  description = "Development ECS cluster name."
  value       = module.ecs.cluster_name
}

output "api_task_definition_arn" {
  description = "Development API task definition ARN."
  value       = module.ecs.api_task_definition_arn
}

output "api_task_definition_family" {
  description = "Development API task definition family."
  value       = module.ecs.api_task_definition_family
}

output "api_service_name" {
  description = "Development API ECS service name."
  value       = module.ecs.api_service_name
}

output "api_service_id" {
  description = "Development API ECS service ID."
  value       = module.ecs.api_service_id
}

output "worker_task_definition_arn" {
  description = "Development worker task definition ARN."
  value       = module.ecs.worker_task_definition_arn
}

output "worker_task_definition_family" {
  description = "Development worker task definition family."
  value       = module.ecs.worker_task_definition_family
}

output "worker_service_name" {
  description = "Development worker ECS service name."
  value       = module.ecs.worker_service_name
}

output "worker_service_id" {
  description = "Development worker ECS service ID."
  value       = module.ecs.worker_service_id
}

output "migration_task_definition_arn" {
  description = "Development migration task definition ARN."
  value       = module.ecs.migration_task_definition_arn
}

output "migration_task_definition_family" {
  description = "Development migration task definition family."
  value       = module.ecs.migration_task_definition_family
}

output "api_log_group_name" {
  description = "Development API CloudWatch log group name."
  value       = module.ecs.api_log_group_name
}

output "api_log_group_arn" {
  description = "Development API CloudWatch log group ARN."
  value       = module.ecs.api_log_group_arn
}

output "nginx_log_group_name" {
  description = "Development Nginx CloudWatch log group name."
  value       = module.ecs.nginx_log_group_name
}

output "nginx_log_group_arn" {
  description = "Development Nginx CloudWatch log group ARN."
  value       = module.ecs.nginx_log_group_arn
}

output "worker_log_group_name" {
  description = "Development worker CloudWatch log group name."
  value       = module.ecs.worker_log_group_name
}

output "worker_log_group_arn" {
  description = "Development worker CloudWatch log group ARN."
  value       = module.ecs.worker_log_group_arn
}

output "api_scalable_target_resource_id" {
  description = "Development API scalable target resource ID."
  value       = module.ecs_autoscaling.api_scalable_target_resource_id
}

output "api_scalable_target_min_capacity" {
  description = "Development API scalable target minimum capacity."
  value       = module.ecs_autoscaling.api_scalable_target_min_capacity
}

output "api_scalable_target_max_capacity" {
  description = "Development API scalable target maximum capacity."
  value       = module.ecs_autoscaling.api_scalable_target_max_capacity
}

output "worker_scalable_target_resource_id" {
  description = "Development worker scalable target resource ID."
  value       = module.ecs_autoscaling.worker_scalable_target_resource_id
}

output "worker_scalable_target_min_capacity" {
  description = "Development worker scalable target minimum capacity."
  value       = module.ecs_autoscaling.worker_scalable_target_min_capacity
}

output "worker_scalable_target_max_capacity" {
  description = "Development worker scalable target maximum capacity."
  value       = module.ecs_autoscaling.worker_scalable_target_max_capacity
}

output "api_cpu_policy_name" {
  description = "Development API CPU autoscaling policy name."
  value       = module.ecs_autoscaling.api_cpu_policy_name
}

output "api_cpu_policy_arn" {
  description = "Development API CPU autoscaling policy ARN."
  value       = module.ecs_autoscaling.api_cpu_policy_arn
}

output "api_memory_policy_name" {
  description = "Development API memory autoscaling policy name."
  value       = module.ecs_autoscaling.api_memory_policy_name
}

output "api_memory_policy_arn" {
  description = "Development API memory autoscaling policy ARN."
  value       = module.ecs_autoscaling.api_memory_policy_arn
}

output "worker_backlog_policy_name" {
  description = "Development worker backlog-per-task autoscaling policy name."
  value       = module.ecs_autoscaling.worker_backlog_policy_name
}

output "worker_backlog_policy_arn" {
  description = "Development worker backlog-per-task autoscaling policy ARN."
  value       = module.ecs_autoscaling.worker_backlog_policy_arn
}

output "amp_workspace_id" {
  description = "Development AMP workspace ID."
  value       = module.observability.workspace_id
}

output "amp_workspace_arn" {
  description = "Development AMP workspace ARN."
  value       = module.observability.workspace_arn
}

output "amp_workspace_prometheus_endpoint" {
  description = "Development AMP Prometheus endpoint."
  value       = module.observability.workspace_prometheus_endpoint
}

output "grafana_workspace_id" {
  description = "Development Amazon Managed Grafana workspace ID."
  value       = module.observability.grafana_workspace_id
}

output "grafana_workspace_arn" {
  description = "Development Amazon Managed Grafana workspace ARN."
  value       = module.observability.grafana_workspace_arn
}

output "grafana_endpoint" {
  description = "Development Amazon Managed Grafana endpoint."
  value       = module.observability.grafana_endpoint
}

output "alarm_topic_arn" {
  description = "Development CloudWatch alarm SNS topic ARN."
  value       = module.observability.alarm_topic_arn
}

output "cloudwatch_dashboard_name" {
  description = "Development CloudWatch dashboard name."
  value       = module.observability.dashboard_name
}

output "s3_gateway_endpoint_id" {
  description = "Development S3 Gateway VPC Endpoint ID."
  value       = module.vpc_endpoints.s3_gateway_endpoint_id
}
