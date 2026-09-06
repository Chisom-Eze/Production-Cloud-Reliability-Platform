module "job_queue" {
  source = "../../modules/sqs"

  project_display_name = "ProductionCloudReliabilityPlatform"
  environment          = local.environment

  visibility_timeout_seconds    = 60
  max_receive_count             = 3
  message_retention_seconds     = 345600
  dlq_message_retention_seconds = 1209600
  receive_wait_time_seconds     = 20
}
