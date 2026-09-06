output "s3_gateway_endpoint_id" {
  description = "S3 Gateway VPC Endpoint ID."
  value       = aws_vpc_endpoint.s3.id
}

output "s3_gateway_endpoint_arn" {
  description = "S3 Gateway VPC Endpoint ARN."
  value       = aws_vpc_endpoint.s3.arn
}

output "s3_gateway_endpoint_service_name" {
  description = "Regional S3 Gateway VPC Endpoint service name."
  value       = aws_vpc_endpoint.s3.service_name
}

output "s3_prefix_list_id" {
  description = "AWS-managed S3 prefix list ID used by the gateway endpoint route."
  value       = aws_vpc_endpoint.s3.prefix_list_id
}

