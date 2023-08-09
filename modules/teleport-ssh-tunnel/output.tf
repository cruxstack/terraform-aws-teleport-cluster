output "host" {
  value       = module.this.enabled ? data.external.tunnel.result.host : ""
  description = "SSH tunnel host."
}

output "port" {
  value       = module.this.enabled ? data.external.tunnel.result.port : ""
  description = "SSH tunnel port."
}
