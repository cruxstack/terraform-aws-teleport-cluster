locals {
  db_connection_info     = data.external.db_connection_info.result
  db_connection_host     = module.this.enabled ? local.db_connection_info["host"] : ""
  db_connection_port     = module.this.enabled ? local.db_connection_info["port"] : ""
  db_connection_ssl_ca   = module.this.enabled ? local.db_connection_info["ca"] : ""
  db_connection_ssl_cert = module.this.enabled ? local.db_connection_info["cert"] : ""
  db_connection_ssl_key  = module.this.enabled ? local.db_connection_info["key"] : ""
}

data "external" "db_connection_info" {
  program = [
    "${path.module}/assets/tsh.sh",
    "db-login",
    "stdin"
  ]

  query = {
    tp_proxy   = coalesce(var.tp_proxy, var.tp_cluster)
    tp_cluster = var.tp_cluster
    target_db  = var.target_db
  }
}
