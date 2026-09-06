locals {
  name_prefix         = "${var.project_name}-${var.environment}"
  alb_arn_suffix      = split(":loadbalancer/", var.alb_arn)[1]
  target_group_suffix = "targetgroup/${split(":targetgroup/", var.target_group_arn)[1]}"
  alarm_topic_name    = "${local.name_prefix}-alarms"
}

resource "aws_prometheus_workspace" "this" {
  alias = local.name_prefix

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-amp"
  })
}

data "aws_iam_policy_document" "telemetry_export" {
  statement {
    sid       = "RemoteWriteToAmpWorkspace"
    effect    = "Allow"
    actions   = ["aps:RemoteWrite"]
    resources = [aws_prometheus_workspace.this.arn]
  }

  statement {
    sid    = "WriteTracesToXRay"
    effect = "Allow"
    actions = [
      "xray:PutTelemetryRecords",
      "xray:PutTraceSegments"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "api_telemetry_export" {
  name   = "api-telemetry-export"
  role   = var.api_task_role_name
  policy = data.aws_iam_policy_document.telemetry_export.json
}

resource "aws_iam_role_policy" "worker_telemetry_export" {
  name   = "worker-telemetry-export"
  role   = var.worker_task_role_name
  policy = data.aws_iam_policy_document.telemetry_export.json
}

data "aws_iam_policy_document" "grafana_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["grafana.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "grafana" {
  name               = "${local.name_prefix}-grafana"
  description        = "Read-only Amazon Managed Grafana workspace role."
  assume_role_policy = data.aws_iam_policy_document.grafana_assume_role.json

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-grafana"
  })
}

data "aws_iam_policy_document" "grafana_read" {
  statement {
    sid    = "ReadCloudWatchMetricsAndLogs"
    effect = "Allow"
    actions = [
      "cloudwatch:DescribeAlarms",
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:FilterLogEvents",
      "logs:GetLogEvents",
      "logs:GetLogGroupFields",
      "logs:GetQueryResults",
      "logs:StartQuery",
      "logs:StopQuery"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ReadAmpWorkspace"
    effect = "Allow"
    actions = [
      "aps:GetLabels",
      "aps:GetMetricMetadata",
      "aps:GetSeries",
      "aps:QueryMetrics"
    ]
    resources = [aws_prometheus_workspace.this.arn]
  }

  statement {
    sid    = "ReadXRay"
    effect = "Allow"
    actions = [
      "xray:BatchGetTraces",
      "xray:GetInsightEvents",
      "xray:GetInsightSummaries",
      "xray:GetServiceGraph",
      "xray:GetTimeSeriesServiceStatistics",
      "xray:GetTraceGraph",
      "xray:GetTraceSummaries"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "grafana_read" {
  name   = "grafana-read-observability"
  role   = aws_iam_role.grafana.id
  policy = data.aws_iam_policy_document.grafana_read.json
}

resource "aws_grafana_workspace" "this" {
  name                     = local.name_prefix
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  data_sources             = ["CLOUDWATCH", "PROMETHEUS", "XRAY"]
  permission_type          = "CUSTOMER_MANAGED"
  role_arn                 = aws_iam_role.grafana.arn

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-grafana"
  })
}

#trivy:ignore:AVD-AWS-0095 Alarm SNS stays unencrypted until a CMK publisher policy is deliberately designed.
resource "aws_sns_topic" "alarms" {
  name = local.alarm_topic_name

  tags = merge(var.tags, {
    Name     = local.alarm_topic_name
    Severity = "critical"
  })
}

resource "aws_cloudwatch_metric_alarm" "dlq_visible_messages" {
  alarm_name          = "${local.name_prefix}-dlq-visible-messages-critical"
  alarm_description   = "Critical: DLQ has visible messages and needs investigation."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = var.dlq_name }
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  tags = merge(var.tags, {
    Severity = "critical"
  })
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "${local.name_prefix}-alb-unhealthy-hosts-critical"
  alarm_description   = "Critical: ALB has unhealthy registered targets."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  dimensions          = { LoadBalancer = local.alb_arn_suffix, TargetGroup = local.target_group_suffix }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  tags = merge(var.tags, {
    Severity = "critical"
  })
}

resource "aws_cloudwatch_metric_alarm" "api_5xx_error_rate" {
  alarm_name        = "${local.name_prefix}-api-5xx-error-rate-warning"
  alarm_description = "Warning: API target 5XX error-rate threshold exceeded."

  metric_query {
    id          = "e1"
    expression  = "IF(m2>0,(m1/m2)*100,0)"
    label       = "api_target_5xx_error_rate_percent"
    return_data = true
  }

  metric_query {
    id          = "m1"
    return_data = false

    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      period      = 60
      stat        = "Sum"
      dimensions  = { LoadBalancer = local.alb_arn_suffix, TargetGroup = local.target_group_suffix }
    }
  }

  metric_query {
    id          = "m2"
    return_data = false

    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      period      = 60
      stat        = "Sum"
      dimensions  = { LoadBalancer = local.alb_arn_suffix, TargetGroup = local.target_group_suffix }
    }
  }

  evaluation_periods  = 5
  threshold           = var.api_5xx_error_rate_alarm_percent
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  tags = merge(var.tags, {
    Severity = "warning"
  })
}

resource "aws_cloudwatch_metric_alarm" "api_p95_latency" {
  alarm_name          = "${local.name_prefix}-api-p95-latency-warning"
  alarm_description   = "Warning: API target p95 latency threshold exceeded."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  dimensions          = { LoadBalancer = local.alb_arn_suffix, TargetGroup = local.target_group_suffix }
  extended_statistic  = "p95"
  period              = 60
  evaluation_periods  = 5
  threshold           = var.api_p95_latency_alarm_seconds
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  tags = merge(var.tags, {
    Severity = "warning"
  })
}

resource "aws_cloudwatch_metric_alarm" "queue_oldest_message_age" {
  alarm_name          = "${local.name_prefix}-queue-oldest-message-age-warning"
  alarm_description   = "Warning: main queue oldest visible message age threshold exceeded."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateAgeOfOldestMessage"
  dimensions          = { QueueName = var.queue_name }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 5
  threshold           = var.queue_oldest_message_age_alarm_seconds
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  tags = merge(var.tags, {
    Severity = "warning"
  })
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${local.name_prefix}-rds-cpu-warning"
  alarm_description   = "Warning: RDS CPU utilization threshold exceeded."
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  dimensions          = { DBInstanceIdentifier = var.rds_identifier }
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  threshold           = var.rds_cpu_alarm_percent
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  tags = merge(var.tags, {
    Severity = "warning"
  })
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  alarm_name          = "${local.name_prefix}-rds-free-storage-warning"
  alarm_description   = "Warning: RDS free storage threshold breached."
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  dimensions          = { DBInstanceIdentifier = var.rds_identifier }
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  threshold           = var.rds_free_storage_alarm_bytes
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  tags = merge(var.tags, {
    Severity = "warning"
  })
}

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = "${local.name_prefix}-operations"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          title  = "EDGE - ALB Requests, Latency, 5XX, Unhealthy Hosts"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", local.alb_arn_suffix, { stat = "Sum" }],
            [".", "TargetResponseTime", ".", ".", { stat = "p95" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { stat = "Sum" }],
            [".", "UnHealthyHostCount", ".", ".", "TargetGroup", local.target_group_suffix, { stat = "Maximum" }]
          ]
        }
      },
      {
        type = "metric"
        properties = {
          title  = "ECS - API and Worker CPU/Memory/Running Tasks"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["ECS/ContainerInsights", "CpuUtilized", "ClusterName", var.ecs_cluster_name, "ServiceName", var.api_service_name],
            [".", "MemoryUtilized", ".", ".", ".", "."],
            [".", "RunningTaskCount", ".", ".", ".", "."],
            [".", "CpuUtilized", ".", ".", "ServiceName", var.worker_service_name],
            [".", "MemoryUtilized", ".", ".", ".", "."],
            [".", "RunningTaskCount", ".", ".", ".", "."]
          ]
        }
      },
      {
        type = "metric"
        properties = {
          title  = "QUEUE - Backlog, In Flight, Oldest Age, DLQ"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.queue_name],
            [".", "ApproximateNumberOfMessagesNotVisible", ".", "."],
            [".", "ApproximateAgeOfOldestMessage", ".", "."],
            [".", "ApproximateNumberOfMessagesVisible", "QueueName", var.dlq_name]
          ]
        }
      },
      {
        type = "metric"
        properties = {
          title  = "DATABASE - CPU, Connections, Storage, Memory"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_identifier],
            [".", "DatabaseConnections", ".", "."],
            [".", "FreeStorageSpace", ".", "."],
            [".", "FreeableMemory", ".", "."]
          ]
        }
      }
    ]
  })
}

resource "aws_cloudwatch_query_definition" "api_errors" {
  name            = "${local.name_prefix}/api/errors"
  log_group_names = [var.api_log_group_name, var.nginx_log_group_name]
  query_string    = "fields @timestamp, service, message, status_code, path, error, request_id, correlation_id, trace_id | filter status_code >= 500 or ispresent(error) | sort @timestamp desc | limit 100"
}

resource "aws_cloudwatch_query_definition" "worker_failures" {
  name            = "${local.name_prefix}/worker/failures"
  log_group_names = [var.worker_log_group_name]
  query_string    = "fields @timestamp, service, message, job_id, error, request_id, correlation_id, trace_id | filter message like /failed/ or ispresent(error) | sort @timestamp desc | limit 100"
}

resource "aws_cloudwatch_query_definition" "correlation_lookup" {
  name            = "${local.name_prefix}/correlation/request-lookup"
  log_group_names = [var.api_log_group_name, var.nginx_log_group_name, var.worker_log_group_name]
  query_string    = "fields @timestamp, service, message, request_id, correlation_id, trace_id, span_id | filter request_id = 'REPLACE_REQUEST_ID' or correlation_id = 'REPLACE_CORRELATION_ID' | sort @timestamp asc | limit 200"
}

resource "aws_cloudwatch_query_definition" "trace_lookup" {
  name            = "${local.name_prefix}/trace/trace-id-lookup"
  log_group_names = [var.api_log_group_name, var.nginx_log_group_name, var.worker_log_group_name]
  query_string    = "fields @timestamp, service, message, request_id, correlation_id, trace_id, span_id | filter trace_id = 'REPLACE_TRACE_ID' | sort @timestamp asc | limit 200"
}
