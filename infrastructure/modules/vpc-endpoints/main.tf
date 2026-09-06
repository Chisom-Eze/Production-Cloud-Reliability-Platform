locals {
  name_prefix                   = "${var.project_name}-${var.environment}"
  s3_service_name               = "com.amazonaws.${var.aws_region}.s3"
  ecr_starport_layer_bucket_arn = "arn:aws:s3:::prod-${var.aws_region}-starport-layer-bucket/*"
  artifact_reports_resource_arn = "${var.artifact_bucket_arn}/reports/*"
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = local.s3_service_name
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.application_private_route_table_ids

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowApplicationReportArtifacts"
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = local.artifact_reports_resource_arn
      },
      {
        Sid       = "AllowEcrStarportLayerDownloads"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = local.ecr_starport_layer_bucket_arn
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-s3-gateway-endpoint"
  })
}

