locals {
  db_connection_info     = data.external.db_connection_info.result
  db_connection_host     = module.this.enabled ? local.db_config["host"] : ""
  db_connection_port     = module.this.enabled ? local.db_config["port"] : ""
  db_connection_ssl_ca   = module.this.enabled ? local.db_config["ca"] : ""
  db_connection_ssl_cert = module.this.enabled ? local.db_config["cert"] : ""
  db_connection_ssl_key  = module.this.enabled ? local.db_config["key"] : ""
}

data "external" "db_connection_info" {
  program = [
    "${path.module}/assets/tsh.sh",
    "db-login",
    "stdin"
  ]

  query = {
    target_cluster = var.target_cluster
    target_db      = var.target_db
  }
}
