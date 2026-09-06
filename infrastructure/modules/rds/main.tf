locals {
  enabled_cloudwatch_logs_exports = toset(var.enabled_cloudwatch_logs_exports)
}

resource "aws_db_subnet_group" "this" {
  name        = var.db_subnet_group_name
  description = "Database subnet group for ${var.identifier}."
  subnet_ids  = var.subnet_ids

  tags = {
    Name = var.db_subnet_group_name
  }
}

data "aws_iam_policy_document" "enhanced_monitoring_assume_role" {
  count = var.enhanced_monitoring_interval > 0 ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "enhanced_monitoring" {
  count = var.enhanced_monitoring_interval > 0 ? 1 : 0

  name               = "${var.identifier}-em"
  description        = "Allows RDS Enhanced Monitoring for ${var.identifier}."
  assume_role_policy = data.aws_iam_policy_document.enhanced_monitoring_assume_role[0].json

  tags = {
    Name = "${var.identifier}-em"
  }
}

resource "aws_iam_role_policy_attachment" "enhanced_monitoring" {
  count = var.enhanced_monitoring_interval > 0 ? 1 : 0

  role       = aws_iam_role.enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_cloudwatch_log_group" "rds" {
  for_each = local.enabled_cloudwatch_logs_exports

  name              = "/aws/rds/instance/${var.identifier}/${each.value}"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = {
    Name = "${var.identifier}-${each.value}-logs"
  }
}

resource "aws_db_instance" "this" {
  identifier     = var.identifier
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name                     = var.database_name
  username                    = var.master_username
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.vpc_security_group_ids
  publicly_accessible    = false

  backup_retention_period = var.backup_retention_period
  backup_window           = var.preferred_backup_window
  copy_tags_to_snapshot   = true

  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot
  final_snapshot_identifier = (
    var.skip_final_snapshot
    ? null
    : "${var.identifier}-final-snapshot"
  )

  multi_az                    = var.multi_az
  auto_minor_version_upgrade  = var.auto_minor_version_upgrade
  allow_major_version_upgrade = false
  apply_immediately           = var.apply_immediately
  maintenance_window          = var.preferred_maintenance_window

  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  monitoring_interval             = var.enhanced_monitoring_interval
  monitoring_role_arn = (
    var.enhanced_monitoring_interval > 0
    ? aws_iam_role.enhanced_monitoring[0].arn
    : null
  )

  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null

  depends_on = [
    aws_cloudwatch_log_group.rds,
    aws_iam_role_policy_attachment.enhanced_monitoring
  ]

  tags = {
    Name = var.identifier
  }
}
