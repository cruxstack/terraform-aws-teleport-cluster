locals {
  enabled = coalesce(var.enabled, module.this.enabled, true)
  name    = coalesce(var.name, module.this.name, "teleport-cluster-${random_string.teleport_cluster_random_suffix.result}")

  aws_account_id   = try(coalesce(var.aws_account_id, data.aws_caller_identity.current[0].account_id), "")
  aws_region_name  = try(coalesce(var.aws_region_name, data.aws_region.current[0].name), "")
  aws_kv_namespace = trim(coalesce(var.aws_kv_namespace, "teleport-cluster/${module.teleport_cluster_label.id}"), "/")

  teleport_cluster_name      = join("-", [module.teleport_cluster_label.name, module.teleport_cluster_label.stage, module.teleport_cluster_label.environment])
  teleport_image_name        = "gravitational-teleport-ami-oss-${var.teleport_runtime_version}"
  teleport_image_id          = try(data.aws_ami.official_image[0].id, "")
  teleport_letsencrypt_email = var.teleport_letsencrypt_email
  teleport_setup_mode        = var.teleport_setup_mode
  teleport_experimental_mode = var.teleport_experimental_mode
  teleport_aws_account_id    = "126027368216" # gravitational teleport's aws account id for ami filtering

  artifacts_bucket_name = coalesce(var.artifacts_bucket_name, local.teleport_bucket_name)
  logs_bucket_name      = coalesce(var.logs_bucket_name, local.teleport_bucket_name)
  teleport_bucket_name  = module.s3_bucket.bucket_id

  is_teleport_and_logs_bucket_same = local.artifacts_bucket_name == local.logs_bucket_name

  instance_config = {
    auth  = merge({ sizes = ["t3.micro", "t3a.micro"], count = 1 }, lookup(var.instance_config, "auth", {}))
    node  = merge({ sizes = ["t3.micro", "t3a.micro"], count = 1 }, lookup(var.instance_config, "node", {}))
    proxy = merge({ sizes = ["t3.micro", "t3a.micro"], count = 1 }, lookup(var.instance_config, "proxy", {}))
  }
}

data "aws_caller_identity" "current" {
  count = module.this.enabled && var.aws_account_id == "" ? 1 : 0
}

data "aws_region" "current" {
  count = module.this.enabled && var.aws_region_name == "" ? 1 : 0
}

# ================================================================= teleport ===

module "teleport_cluster_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  enabled = local.enabled
  name    = local.name
  context = module.this.context
}

# only appliable if name variable was not set
resource "random_string" "teleport_cluster_random_suffix" {
  length  = 6
  special = false
  upper   = false
}

# ================================================================== cluster ===

module "auth_servers" {
  source = "./modules/teleport-node"

  instance_sizes = local.instance_config.auth.sizes
  instance_count = local.instance_config.auth.count

  teleport_cluster_name      = local.teleport_cluster_name
  teleport_image_id          = local.teleport_image_id
  teleport_letsencrypt_email = local.teleport_letsencrypt_email
  teleport_node_type         = "auth"
  teleport_setup_mode        = local.teleport_setup_mode

  teleport_bucket_name           = module.s3_bucket.bucket_id
  teleport_ddb_table_events_name = aws_dynamodb_table.events[0].name
  teleport_ddb_table_locks_name  = aws_dynamodb_table.locks[0].name
  teleport_ddb_table_state_name  = aws_dynamodb_table.state[0].name
  teleport_security_group_ids    = compact([module.security_group.id])

  experimental = local.teleport_experimental_mode

  dns_parent_zone_id     = var.dns_parent_zone_id
  dns_parent_zone_name   = var.dns_parent_zone_name
  artifacts_bucket_name  = local.artifacts_bucket_name
  logs_bucket_name       = local.logs_bucket_name
  vpc_id                 = var.vpc_id
  vpc_private_subnet_ids = var.vpc_private_subnet_ids
  vpc_public_subnet_ids  = var.vpc_public_subnet_ids
  aws_account_id         = local.aws_account_id
  aws_kv_namespace       = local.aws_kv_namespace
  aws_region_name        = local.aws_region_name

  context = module.teleport_cluster_label.context
}

module "proxy_servers" {
  source = "./modules/teleport-node"

  instance_sizes = local.instance_config.proxy.sizes
  instance_count = local.instance_config.proxy.count

  teleport_cluster_name      = local.teleport_cluster_name
  teleport_image_id          = local.teleport_image_id
  teleport_letsencrypt_email = local.teleport_letsencrypt_email
  teleport_node_type         = "proxy"
  teleport_setup_mode        = local.teleport_setup_mode

  teleport_auth_address          = module.auth_servers.lb_dns_name
  teleport_bucket_name           = module.s3_bucket.bucket_id
  teleport_ddb_table_events_name = aws_dynamodb_table.events[0].name
  teleport_ddb_table_locks_name  = aws_dynamodb_table.locks[0].name
  teleport_ddb_table_state_name  = aws_dynamodb_table.state[0].name
  teleport_security_group_ids    = compact([module.security_group.id])

  experimental = local.teleport_experimental_mode

  dns_parent_zone_id     = var.dns_parent_zone_id
  dns_parent_zone_name   = var.dns_parent_zone_name
  artifacts_bucket_name  = local.artifacts_bucket_name # todo - create bucket with module
  logs_bucket_name       = local.logs_bucket_name
  vpc_id                 = var.vpc_id
  vpc_private_subnet_ids = var.vpc_private_subnet_ids
  vpc_public_subnet_ids  = var.vpc_public_subnet_ids
  aws_account_id         = local.aws_account_id
  aws_kv_namespace       = local.aws_kv_namespace
  aws_region_name        = local.aws_region_name

  context = module.teleport_cluster_label.context
}

module "node_servers" {
  source = "./modules/teleport-node"

  instance_sizes = local.instance_config.node.sizes
  instance_count = local.instance_config.node.count

  teleport_cluster_name      = local.teleport_cluster_name
  teleport_image_id          = local.teleport_image_id
  teleport_letsencrypt_email = local.teleport_letsencrypt_email
  teleport_node_type         = "node"
  teleport_setup_mode        = local.teleport_setup_mode

  teleport_auth_address          = module.auth_servers.lb_dns_name
  teleport_bucket_name           = module.s3_bucket.bucket_id
  teleport_ddb_table_events_name = aws_dynamodb_table.events[0].name
  teleport_ddb_table_locks_name  = aws_dynamodb_table.locks[0].name
  teleport_ddb_table_state_name  = aws_dynamodb_table.state[0].name
  teleport_security_group_ids    = compact([module.security_group.id])

  experimental = local.teleport_experimental_mode

  dns_parent_zone_id     = var.dns_parent_zone_id
  dns_parent_zone_name   = var.dns_parent_zone_name
  artifacts_bucket_name  = local.artifacts_bucket_name # todo - create bucket with module
  logs_bucket_name       = local.logs_bucket_name
  vpc_id                 = var.vpc_id
  vpc_private_subnet_ids = var.vpc_private_subnet_ids
  vpc_public_subnet_ids  = var.vpc_public_subnet_ids
  aws_account_id         = local.aws_account_id
  aws_kv_namespace       = local.aws_kv_namespace
  aws_region_name        = local.aws_region_name

  context = module.teleport_cluster_label.context
}

# ========================================================= cluster-resource ===

# ---------------------------------------------------------------------- ddb ---

resource "aws_dynamodb_table" "state" {
  count = local.enabled ? 1 : 0

  name             = "${module.teleport_cluster_label.id}-state"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "HashKey"
  range_key        = "FullPath"
  stream_enabled   = "true"
  stream_view_type = "NEW_IMAGE"

  server_side_encryption {
    enabled = true
  }

  lifecycle {
    ignore_changes = [
      read_capacity,
      write_capacity,
    ]
  }

  attribute {
    name = "HashKey"
    type = "S"
  }

  attribute {
    name = "FullPath"
    type = "S"
  }

  ttl {
    attribute_name = "Expires"
    enabled        = true
  }

  tags = module.teleport_cluster_label.tags
}

resource "aws_dynamodb_table" "events" {
  count = local.enabled ? 1 : 0

  name         = "${module.teleport_cluster_label.id}-events"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "SessionID"
  range_key    = "EventIndex"

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  global_secondary_index {
    name            = "timesearchV2"
    hash_key        = "CreatedAtDate"
    range_key       = "CreatedAt"
    write_capacity  = 10
    read_capacity   = 10
    projection_type = "ALL"
  }

  lifecycle {
    ignore_changes = all
  }

  attribute {
    name = "SessionID"
    type = "S"
  }

  attribute {
    name = "EventIndex"
    type = "N"
  }

  attribute {
    name = "CreatedAtDate"
    type = "S"
  }

  attribute {
    name = "CreatedAt"
    type = "N"
  }

  ttl {
    attribute_name = "Expires"
    enabled        = true
  }

  tags = module.teleport_cluster_label.tags
}

resource "aws_dynamodb_table" "locks" {
  count = local.enabled ? 1 : 0

  name         = "${module.teleport_cluster_label.id}-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "Lock"


  lifecycle {
    ignore_changes = [
      read_capacity,
      write_capacity,
    ]
  }

  attribute {
    name = "Lock"
    type = "S"
  }

  ttl {
    attribute_name = "Expires"
    enabled        = true
  }

  tags = merge(module.teleport_cluster_label.tags, {
    TeleportCluster = local.teleport_cluster_name
  })
}

# ----------------------------------------------------------------------- s3 ---

module "s3_bucket" {
  source  = "cloudposse/s3-bucket/aws"
  version = "3.1.2"

  acl                     = "private"
  block_public_policy     = true
  force_destroy           = local.teleport_experimental_mode
  sse_algorithm           = "AES256"
  allow_ssl_requests_only = true
  source_policy_documents = [data.aws_iam_policy_document.bucket.json]

  logging = {
    bucket_name = local.logs_bucket_name
    prefix      = "access/s3/${module.teleport_cluster_label.id}"
  }

  lifecycle_configuration_rules = [{
    enabled = true
    id      = "transition-old-versions"

    abort_incomplete_multipart_upload_days = 5

    filter_and                    = null
    expiration                    = null
    transition                    = []
    noncurrent_version_expiration = null

    noncurrent_version_transition = [
      {
        newer_noncurrent_versions = 2
        noncurrent_days           = 30
        storage_class             = "STANDARD_IA"
      },
      {
        newer_noncurrent_versions = 2
        noncurrent_days           = 60
        storage_class             = "GLACIER"
      }
    ]
  }]

  context = module.teleport_cluster_label.context
}

data "aws_iam_policy_document" "bucket" {
  dynamic "statement" {
    for_each = local.is_teleport_and_logs_bucket_same ? [true] : []

    content {
      sid       = "AWSLogDeliveryWrite"
      effect    = "Allow"
      actions   = ["s3:PutObject"]
      resources = ["arn:aws:s3:::${local.logs_bucket_name}/AWSLogs/${local.aws_account_id}/*"]

      principals {
        type        = "Service"
        identifiers = ["delivery.logs.amazonaws.com"]
      }

      condition {
        test     = "StringEquals"
        variable = "s3:x-amz-acl"
        values   = ["bucket-owner-full-control"]
      }
    }
  }

  dynamic "statement" {
    for_each = local.is_teleport_and_logs_bucket_same ? [true] : []

    content {
      sid       = "AWSLogDeliveryAclCheck"
      effect    = "Allow"
      actions   = ["s3:GetBucketAcl"]
      resources = ["arn:aws:s3:::${local.logs_bucket_name}"]

      principals {
        type        = "Service"
        identifiers = ["delivery.logs.amazonaws.com"]
      }
    }
  }
}

# ----------------------------------------------------------- security-group ---

module "security_group" {
  source  = "cloudposse/security-group/aws"
  version = "2.2.0"

  vpc_id = var.vpc_id

  rules = [{
    key                      = "gropu-egress"
    type                     = "egress"
    from_port                = 0
    to_port                  = 0
    protocol                 = "-1"
    description              = "allow all group egress"
    cidr_blocks              = []
    ipv6_cidr_blocks         = []
    source_security_group_id = null
    self                     = true
    }, {
    key                      = "group-ingress"
    type                     = "ingress"
    from_port                = 0
    to_port                  = 0
    protocol                 = "-1"
    description              = "allow all group ingress"
    cidr_blocks              = []
    ipv6_cidr_blocks         = []
    source_security_group_id = null
    self                     = true
  }]

  tags    = merge(module.teleport_cluster_label.tags, { Name = module.teleport_cluster_label.id })
  context = module.teleport_cluster_label.context
}

# ================================================================== uploads ===

resource "aws_s3_object" "image_files" {
  for_each = toset(local.enabled ? fileset("${path.module}/assets/image-files", "*") : [])

  bucket = local.artifacts_bucket_name
  key    = "${local.aws_kv_namespace}/image/files/bin/${each.key}"
  source = "${path.module}/assets/image-files/${each.key}"
  etag   = filemd5("${path.module}/assets/image-files/${each.key}")

  tags = module.teleport_cluster_label.tags
}

# =================================================================== lookup ===

data "aws_ssm_parameter" "amzn2_image_id" {
  count = module.teleport_cluster_label.enabled ? 1 : 0
  name  = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-ebs"
}

data "aws_ami" "official_image" {
  count = module.teleport_cluster_label.enabled ? 1 : 0

  most_recent = true
  owners      = [local.teleport_aws_account_id]

  filter {
    name   = "name"
    values = [local.teleport_image_name]
  }
}

