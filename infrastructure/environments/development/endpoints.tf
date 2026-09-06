module "vpc_endpoints" {
  source = "../../modules/vpc-endpoints"

  project_name = local.project_name
  environment  = local.environment
  aws_region   = var.aws_region
  tags         = local.standard_tags

  vpc_id                              = module.vpc.vpc_id
  application_private_route_table_ids = values(module.vpc.application_private_route_table_ids)
  artifact_bucket_arn                 = module.artifact_storage.bucket_arn
}

