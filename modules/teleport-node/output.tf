output "teleport_dns_name" {
  value = local.dns_name
}

output "teleport_config" {
  value = local.teleport_config[local.teleport_node_type]
}
