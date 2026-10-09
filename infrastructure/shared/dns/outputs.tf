output "hosted_zone_id" {
  description = "Public Route53 hosted zone ID for separately owned application and ACM records."
  value       = aws_route53_zone.authoritative.zone_id
}

output "domain_name" {
  description = "Name of the shared authoritative public hosted zone."
  value       = aws_route53_zone.authoritative.name
}

output "name_servers" {
  description = "Four Route53 authoritative nameservers to configure as Namecheap Custom DNS."
  value       = aws_route53_zone.authoritative.name_servers
}
