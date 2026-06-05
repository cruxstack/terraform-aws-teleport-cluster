locals {
  enabled = module.this.enabled

  nlb_internal              = var.nlb_internal
  nlb_subnet_ids            = local.nlb_internal ? var.vpc_private_subnet_ids : var.vpc_public_subnet_ids
  nlb_privatelink_enabled   = local.enabled && var.nlb_privatelink_enabled
  nlb_privatelink_config    = var.nlb_privatelink_config
  nlb_allowed_cidrs         = var.nlb_allowed_cidrs
  nlb_auth_allowed_cidrs    = var.nlb_auth_allowed_cidrs
  cluster_security_group_id = var.cluster_security_group_id

  dns_parent_zone_id   = var.dns_parent_zone_id
  dns_parent_zone_name = var.dns_parent_zone_name
  dns_name             = "${module.dns_label.id}.${local.dns_parent_zone_name}"

  listeners = {
    proxy_web = {
      port           = 443
      target_port    = 3080
      proxy_protocol = true
    }
    auth_ssh = {
      port           = 3025
      target_port    = 3025
      proxy_protocol = false
    }
  }

  proxy_ingress_pairs = {
    for cidr in local.nlb_allowed_cidrs : "proxy_web-cidr-${replace(cidr, "/[^0-9a-zA-Z]/", "-")}" => {
      port = local.listeners.proxy_web.port
      cidr = cidr
    }
  }

  auth_ingress_pairs = {
    for cidr in local.nlb_auth_allowed_cidrs : "auth_ssh-cidr-${replace(cidr, "/[^0-9a-zA-Z]/", "-")}" => {
      port = local.listeners.auth_ssh.port
      cidr = cidr
    }
  }
}

# ================================================================== labels ===

module "nlb_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  id_length_limit = 32
  label_order     = ["name", "attributes"]
  context         = module.this.context
}

# TG names are capped at 32 chars; reserve 10 for the "-proxy-web" suffix.
module "tg_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  id_length_limit = 22
  label_order     = ["name", "attributes"]
  context         = module.this.context
}

module "dns_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  label_order = ["environment", "name", "attributes"]
  context     = module.this.context
}

# ================================================================== nlb sg ===

resource "aws_security_group" "this" {
  count = local.enabled ? 1 : 0

  name        = module.nlb_label.id
  description = "Public ingress controls for the consolidated Teleport NLB"
  vpc_id      = var.vpc_id

  tags = merge(module.this.tags, { Name = module.nlb_label.id })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "proxy_cidrs" {
  for_each = local.enabled ? local.proxy_ingress_pairs : {}

  security_group_id = aws_security_group.this[0].id
  description       = "allow proxy_web (${each.value.port}) from ${each.value.cidr}"
  ip_protocol       = "tcp"
  from_port         = each.value.port
  to_port           = each.value.port
  cidr_ipv4         = each.value.cidr
}

# Opt-in CIDR ingress on the auth listener. Off by default so :3025 stays
# gated to the cluster SG. Required when nlb_internal=false and same-VPC
# proxies must reach auth through the NLB's public IPs.
resource "aws_vpc_security_group_ingress_rule" "auth_cidrs" {
  for_each = local.enabled ? local.auth_ingress_pairs : {}

  security_group_id = aws_security_group.this[0].id
  description       = "allow auth_ssh (${each.value.port}) from ${each.value.cidr}"
  ip_protocol       = "tcp"
  from_port         = each.value.port
  to_port           = each.value.port
  cidr_ipv4         = each.value.cidr
}

# ===================================================================== nlb ===

resource "aws_lb" "this" {
  count = local.enabled ? 1 : 0

  name                                                         = module.nlb_label.id
  internal                                                     = local.nlb_internal
  subnets                                                      = local.nlb_subnet_ids
  load_balancer_type                                           = "network"
  idle_timeout                                                 = 3600
  enable_cross_zone_load_balancing                             = true
  enable_deletion_protection                                   = var.deletion_protection_enabled
  enforce_security_group_inbound_rules_on_private_link_traffic = "on"

  security_groups = [
    aws_security_group.this[0].id,
    local.cluster_security_group_id,
  ]

  access_logs {
    bucket  = var.logs_bucket_name
    enabled = true
  }

  tags = module.this.tags
}

# ----------------------------------------------------------- target-groups ---

resource "aws_lb_target_group" "auth_ssh" {
  count = local.enabled ? 1 : 0

  name     = "${module.tg_label.id}-auth-ssh"
  port     = local.listeners.auth_ssh.target_port
  vpc_id   = var.vpc_id
  protocol = "TCP"

  proxy_protocol_v2 = local.listeners.auth_ssh.proxy_protocol

  tags = module.this.tags
}

resource "aws_lb_target_group" "proxy_web" {
  count = local.enabled ? 1 : 0

  name     = "${module.tg_label.id}-proxy-web"
  port     = local.listeners.proxy_web.target_port
  vpc_id   = var.vpc_id
  protocol = "TCP"

  proxy_protocol_v2 = local.listeners.proxy_web.proxy_protocol

  tags = module.this.tags
}

# --------------------------------------------------------------- listeners ---

resource "aws_lb_listener" "auth_ssh" {
  count = local.enabled ? 1 : 0

  load_balancer_arn = aws_lb.this[0].arn
  port              = local.listeners.auth_ssh.port
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.auth_ssh[0].arn
    type             = "forward"
  }
}

resource "aws_lb_listener" "proxy_web" {
  count = local.enabled ? 1 : 0

  load_balancer_arn = aws_lb.this[0].arn
  port              = local.listeners.proxy_web.port
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.proxy_web[0].arn
    type             = "forward"
  }
}

# ================================================================== route53 ===

resource "aws_route53_record" "proxy" {
  count = local.enabled ? 1 : 0

  zone_id         = local.dns_parent_zone_id
  name            = local.dns_name
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = aws_lb.this[0].dns_name
    zone_id                = aws_lb.this[0].zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "proxy_wildcard" {
  count = local.enabled ? 1 : 0

  zone_id         = local.dns_parent_zone_id
  name            = "*.${local.dns_name}"
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = aws_lb.this[0].dns_name
    zone_id                = aws_lb.this[0].zone_id
    evaluate_target_health = true
  }
}

# ============================================================== privatelink ===

resource "aws_vpc_endpoint_service" "this" {
  count = local.nlb_privatelink_enabled ? 1 : 0

  acceptance_required        = local.nlb_privatelink_config.acceptance_required
  network_load_balancer_arns = [aws_lb.this[0].arn]
  allowed_principals         = local.nlb_privatelink_config.allowed_principals
  private_dns_name           = local.nlb_privatelink_config.private_dns_name != "" ? local.nlb_privatelink_config.private_dns_name : null
  supported_regions          = length(local.nlb_privatelink_config.supported_regions) > 0 ? local.nlb_privatelink_config.supported_regions : null

  tags = module.this.tags
}

# Verifies the endpoint service's private_dns_name with AWS so consumers can
# create endpoints with private_dns_enabled = true. The TXT record lives in
# dns_parent_zone_id (same zone as the proxy alias records).
resource "aws_route53_record" "vpce_private_dns_verification" {
  count = local.nlb_privatelink_enabled && local.nlb_privatelink_config.private_dns_name != "" ? 1 : 0

  zone_id = local.dns_parent_zone_id
  name    = "${tolist(aws_vpc_endpoint_service.this[0].private_dns_name_configuration)[0].name}.${local.nlb_privatelink_config.private_dns_name}"
  type    = tolist(aws_vpc_endpoint_service.this[0].private_dns_name_configuration)[0].type
  ttl     = 1800
  records = [tolist(aws_vpc_endpoint_service.this[0].private_dns_name_configuration)[0].value]
}
