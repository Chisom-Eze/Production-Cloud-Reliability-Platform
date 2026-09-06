module "artifact_storage" {
  source = "../../modules/s3-artifacts"

  project_display_name = "ProductionCloudReliabilityPlatform"
  environment          = local.environment
  bucket_name_prefix   = "prod-cloud-reliability-dev-artifacts-"

  noncurrent_version_retention_days      = 30
  abort_incomplete_multipart_upload_days = 7
  force_destroy                          = false
}
