output "db_host" {
  value       = local.db_connection_host
  description = "Database host address."
}

output "db_port" {
  value       = local.db_connection_port
  description = "Database port number."
}

output "db_ssl_ca" {
  value       = local.db_connection_ssl_ca
  description = "SSL CA for database."
}

output "db_ssl_cert" {
  value       = local.db_connection_ssl_cert
  description = "SSL certificate for database."
}

output "db_ssl_key" {
  value       = local.db_connection_ssl_key
  description = "SSL key for database."
}
