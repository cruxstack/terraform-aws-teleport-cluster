locals {}

# ================================================================== example ===

module "teleport_cluster" {
  source = "../.."

  teleport_experimental_mode = true
  teleport_letsencrypt_email = var.teleport_letsencrypt_email
  teleport_runtime_version   = var.teleport_runtime_version
  dns_parent_zone_id         = var.dns_parent_zone_id
  dns_parent_zone_name       = var.dns_parent_zone_name
  vpc_id                     = var.vpc_id
  vpc_private_subnet_ids     = var.vpc_private_subnet_ids
  vpc_public_subnet_ids      = var.vpc_public_subnet_ids
  teleport_setup_mode        = false

  context = module.example_label.context # not required
}

# ===================================================== supporting-resources ===

module "example_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  name        = "tf-example-complete-${random_string.example_random_suffix.result}"
  environment = "use1" # us-east-1
}

resource "random_string" "example_random_suffix" {
  length  = 6
  special = false
  upper   = false
}
