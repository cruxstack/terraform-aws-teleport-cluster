data "external" "tunnel" {
  program = [
    "${path.module}/assets/tunneler.sh",
    "create",
    "stdin"
  ]

  query = {
    terraform_cluster = var.terraform_cluster
    terraform_gateway = var.terraform_gateway
    target_host       = var.target_host
    target_port       = var.target_port
  }
}
