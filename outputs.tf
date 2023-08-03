# ================================================================= teleport ===

output "teleport_dns_name" {
  value       = module.auth_servers.teleport_dns_name
  description = "The DNS name of the Teleport service."
}

output "teleport_auth_config" {
  value       = module.auth_servers.teleport_config
  description = "The configuration details for the Teleport auth service."
}

output "teleport_node_config" {
  value       = module.node_servers.teleport_config
  description = "The configuration details for the Teleport node service."
}

output "teleport_proxy_config" {
  value       = module.proxy_servers.teleport_config
  description = "The configuration details for the Teleport proxy service."
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
