output "nlb_dns_name" {
  value       = local.enabled ? aws_lb.this[0].dns_name : ""
  description = "DNS name of the consolidated Teleport NLB."
}

output "nlb_arn" {
  value       = local.enabled ? aws_lb.this[0].arn : ""
  description = "ARN of the consolidated Teleport NLB."
}

output "nlb_zone_id" {
  value       = local.enabled ? aws_lb.this[0].zone_id : ""
  description = "Hosted zone ID of the consolidated Teleport NLB."
}

output "security_group_id" {
  value       = local.enabled ? aws_security_group.this[0].id : ""
  description = "Security group attached to the consolidated Teleport NLB."
}

output "target_group_arns" {
  value = {
    auth_ssh  = local.enabled ? aws_lb_target_group.auth_ssh[0].arn : ""
    proxy_web = local.enabled ? aws_lb_target_group.proxy_web[0].arn : ""
  }
  description = "Target group ARNs keyed by listener name."
}

output "teleport_dns_name" {
  value       = local.enabled ? local.dns_name : ""
  description = "Public DNS name (FQDN) the Teleport proxy is reachable at."
}

output "vpce_service_name" {
  value       = local.nlb_privatelink_enabled ? aws_vpc_endpoint_service.this[0].service_name : ""
  description = "PrivateLink service name (consumers use this when creating a VPC endpoint). Empty when PrivateLink is disabled."
}

output "vpce_service_id" {
  value       = local.nlb_privatelink_enabled ? aws_vpc_endpoint_service.this[0].id : ""
  description = "PrivateLink endpoint service ID. Empty when PrivateLink is disabled."
}

output "vpce_service_arn" {
  value       = local.nlb_privatelink_enabled ? aws_vpc_endpoint_service.this[0].arn : ""
  description = "PrivateLink endpoint service ARN. Empty when PrivateLink is disabled."
}
