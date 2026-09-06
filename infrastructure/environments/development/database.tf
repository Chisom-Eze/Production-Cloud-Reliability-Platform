module "rds" {
  source = "../../modules/rds"

  identifier           = "${local.project_name}-${local.environment}-postgres"
  db_subnet_group_name = "${local.project_name}-${local.environment}-db-subnets"

  database_name   = "platform"
  master_username = "platformadmin"
  engine_version  = "16.15"
  instance_class  = "db.t4g.micro"

  allocated_storage     = 20
  max_allocated_storage = 100

  subnet_ids             = values(module.vpc.database_private_subnet_ids)
  vpc_security_group_ids = [module.security_groups.rds_security_group_id]

  backup_retention_period = 7
  preferred_backup_window = "03:00-04:00"

  deletion_protection = false
  skip_final_snapshot = false

  multi_az = false

  auto_minor_version_upgrade   = true
  apply_immediately            = false
  preferred_maintenance_window = "sun:04:00-sun:05:00"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  cloudwatch_log_retention_days   = 7
  enhanced_monitoring_interval    = 60

  performance_insights_enabled          = false
  performance_insights_retention_period = 7
}
