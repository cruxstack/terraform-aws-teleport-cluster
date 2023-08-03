output "teleport_dns_name" {
  value       = module.teleport_cluster.teleport_dns_name
  description = "The DNS name of the Teleport service."
}

output "teleport_web_portal_url" {
  value       = "https://${module.teleport_cluster.teleport_dns_name}/web"
  description = "The URL of the Teleport web portal."
}
