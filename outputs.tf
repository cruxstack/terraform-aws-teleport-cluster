# ================================================================= teleport ===

output "teleport_dns_name" {
  value       = module.teleport_nlb.teleport_dns_name
  description = "The DNS name of the Teleport service."
}

output "teleport_auth_config" {
  value       = module.auth_servers.teleport_config
  description = "The configuration details for the Teleport auth service."
}

output "teleport_proxy_config" {
  value       = module.proxy_servers.teleport_config
  description = "The configuration details for the Teleport proxy service."
}

# ====================================================================== nlb ===

output "teleport_nlb_dns_name" {
  value       = module.teleport_nlb.nlb_dns_name
  description = "DNS name of the consolidated Teleport NLB."
}

output "teleport_nlb_arn" {
  value       = module.teleport_nlb.nlb_arn
  description = "ARN of the consolidated Teleport NLB."
}

output "teleport_nlb_zone_id" {
  value       = module.teleport_nlb.nlb_zone_id
  description = "Hosted zone ID of the consolidated Teleport NLB (useful for Route53 alias records)."
}

output "teleport_nlb_security_group_id" {
  value       = module.teleport_nlb.security_group_id
  description = "Security group attached to the consolidated Teleport NLB."
}

output "teleport_nlb_target_group_arns" {
  value       = module.teleport_nlb.target_group_arns
  description = "Map of target group ARNs keyed by listener name."
}

output "teleport_nlb_vpce_service_name" {
  value       = module.teleport_nlb.vpce_service_name
  description = "PrivateLink endpoint service name (for consumers). Empty when PrivateLink is disabled."
}

output "teleport_nlb_vpce_service_id" {
  value       = module.teleport_nlb.vpce_service_id
  description = "PrivateLink endpoint service ID. Empty when PrivateLink is disabled."
}

output "teleport_nlb_vpce_service_arn" {
  value       = module.teleport_nlb.vpce_service_arn
  description = "PrivateLink endpoint service ARN. Empty when PrivateLink is disabled."
}

# ================================================================ resources ===

output "security_group_id" {
  value       = module.security_group.id
  description = "The ID of the security group created for the Teleport service."
}

output "security_group_name" {
  value       = module.security_group.name
  description = "The name of the security group created for the Teleport service."
}
