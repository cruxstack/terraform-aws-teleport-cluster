data "external" "tunnel" {
  program = [
    "${path.module}/assets/tunneler.sh",
    "create",
    "stdin"
  ]

  query = {
    tp_proxy        = coalesce(var.tp_proxy, var.tp_cluster)
    tp_cluster      = var.tp_cluster
    tp_gateway_node = var.tp_gateway_node
    target_host     = var.target_host
    target_port     = var.target_port
  }
}
