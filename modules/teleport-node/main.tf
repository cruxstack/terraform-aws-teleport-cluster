locals {
  teleport_auth_address      = var.teleport_auth_address
  teleport_bucket_name       = var.teleport_bucket_name
  teleport_cluster_name      = var.teleport_cluster_name
  teleport_image_id          = var.teleport_image_id
  teleport_letsencrypt_email = var.teleport_letsencrypt_email
  teleport_node_type         = var.teleport_node_type
  teleport_setup_enabled     = module.this.enabled && var.teleport_setup_mode
  teleport_public_addr       = var.teleport_public_addr

  teleport_ddb_table_events_name = var.teleport_ddb_table_events_name
  teleport_ddb_table_locks_name  = var.teleport_ddb_table_locks_name
  teleport_ddb_table_state_name  = var.teleport_ddb_table_state_name
  teleport_security_group_ids    = var.teleport_security_group_ids

  aws_account_id        = var.aws_account_id
  aws_kv_namespace      = var.aws_kv_namespace
  aws_region_name       = var.aws_region_name
  artifacts_bucket_name = var.artifacts_bucket_name
  logs_bucket_name      = var.logs_bucket_name
  experimental          = var.experimental

  desired_capacity = local.teleport_setup_enabled ? (local.teleport_node_type == "auth" ? 1 : 0) : var.instance_count
  min_capacity     = local.teleport_setup_enabled ? (local.teleport_node_type == "auth" ? 1 : 0) : var.instance_count
  max_capacity     = local.teleport_setup_enabled ? (local.teleport_node_type == "auth" ? 1 : 0) : var.instance_count
  instance_sizes   = var.instance_sizes
  instance_spot    = var.instance_spot

  dns_name           = "${module.dns_label.id}.${var.dns_parent_zone_name}"
  dns_parent_zone_id = var.dns_parent_zone_id

  vpc_associate_public_ips = var.vpc_associate_public_ips
  vpc_id                   = var.vpc_id
  vpc_security_group_ids   = var.vpc_security_group_ids
  vpc_private_subnet_ids   = var.vpc_private_subnet_ids
  vpc_public_subnet_ids    = var.vpc_public_subnet_ids

  nlb_security_group_id = var.nlb_security_group_id
  target_group_arns     = var.target_group_arns

  iam_role_attached_policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
  iam_role_attached_policies = flatten([
    module.this.enabled ? [
      {
        name   = "ec2-management-access"
        policy = one(data.aws_iam_policy_document.ec2_management.*.json)
      },
      {
        name   = "teleport-base-access"
        policy = one(data.aws_iam_policy_document.base_access.*.json)
      }
    ] : [],
    contains(["auth"], local.teleport_node_type) ? [
      {
        name   = "teleport-auth-access"
        policy = one(data.aws_iam_policy_document.auth_access.*.json)
      }
    ] : [],
    contains(["proxy"], local.teleport_node_type) ? [
      {
        name   = "teleport-proxy-access"
        policy = one(data.aws_iam_policy_document.proxy_access.*.json)
      }
    ] : [],
  ])
}

module "dns_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  label_order = ["environment", "name", "attributes"]
  tags        = { TeleportCluster = local.teleport_cluster_name, TeleportRole = local.teleport_node_type }
  context     = module.this.context
}

module "node_type_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  attributes = [local.teleport_node_type]
  tags       = { TeleportCluster = local.teleport_cluster_name, TeleportRole = local.teleport_node_type }
  context    = module.this.context
}

# ================================================================= teleport ===

locals {
  # TLS routing requires auth `proxy_listener_mode: multiplex` and proxy
  # `version: v2` to agree (gravitational/teleport#57009).
  teleport_config = {
    auth = {
      version = "v2"
      teleport = {
        nodename     = "$TELEPORT_NODENAME"
        advertise_ip = "$TELEPORT_ADVERTISE_IP"
        log = {
          output   = "stderr"
          severity = "INFO"
        }
        data_dir = "/var/lib/teleport"
        storage = {
          type               = "dynamodb"
          region             = local.aws_region_name
          table_name         = local.teleport_ddb_table_state_name
          audit_events_uri   = "dynamodb://${local.teleport_ddb_table_events_name}"
          audit_sessions_uri = "s3://${local.teleport_bucket_name}/records"
        }
      }
      auth_service = {
        enabled              = "yes"
        cluster_name         = local.dns_name
        public_addr          = local.teleport_public_addr != "" ? "${local.teleport_public_addr}:3025" : ""
        keep_alive_interval  = "1m"
        keep_alive_count_max = 3
        listen_addr          = "0.0.0.0:3025"
        proxy_listener_mode  = "multiplex"
        authentication = {
          second_factor = "otp"
        }
        session_recording = "node-sync"
      }
      proxy_service = {
        enabled = "no"
      }
      ssh_service = {
        enabled = "no"
      }
    }
    proxy = {
      version = "v2"
      teleport = {
        auth_token   = "/var/lib/teleport/token"
        ca_pin       = "CA_PIN_HASH_PLACEHOLDER"
        nodename     = "$TELEPORT_NODENAME"
        advertise_ip = "$TELEPORT_ADVERTISE_IP"
        cache = {
          type = "in-memory"
        }
        connection_limits = {
          max_connections = 1000
          max_users       = 100
        }
        log = {
          output   = "stderr"
          severity = "INFO"
        }
        data_dir = "/var/lib/teleport"
        storage = {
          type = "dir"
          path = "/var/lib/teleport/backend"
        }
        auth_servers = [
          "${local.teleport_auth_address}:3025",
        ]
      }
      auth_service = {
        enabled = "no"
      }
      proxy_service = {
        enabled         = "yes"
        proxy_protocol  = "on" # paired with proxy_protocol_v2 on the NLB target group
        web_listen_addr = "0.0.0.0:3080"
        public_addr     = "${local.dns_name}:443"
        https_keypairs = [{
          cert_file = "/var/lib/teleport/fullchain.pem"
          key_file  = "/var/lib/teleport/privkey.pem"
        }]
        kubernetes = {
          enabled     = "yes"
          public_addr = ["${local.dns_name}:443"]
        }
      }
      ssh_service = {
        enabled = "no"
      }
    }
  }
}

# ---------------------------------------------------------------- cloudinit ---

data "cloudinit_config" "this" {
  count = module.this.enabled ? 1 : 0

  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/assets/cloud-init/cloud-config.yaml", {
      cloudwatch_agent_config_encoded = base64encode(
        templatefile("${path.module}/assets/cloud-init/cloudwatch-agent-config.json", {
          cluster_log_group_name = aws_cloudwatch_log_group.this[0].name
        })
      )
      teleport_envs_encoded = base64encode(
        templatefile("${path.module}/assets/teleport/teleport.conf", {
          aws_region_name               = local.aws_region_name
          teleport_node_type            = local.teleport_node_type
          teleport_cluster_name         = local.teleport_cluster_name
          teleport_ddb_table_locks_name = local.teleport_ddb_table_locks_name
          teleport_domain_email         = local.teleport_letsencrypt_email
          teleport_domain_name          = local.dns_name
          teleport_bucket_name          = local.teleport_bucket_name
        })
      )
      teleport_config_tmpl_encoded = base64encode(
        yamlencode(local.teleport_config[local.teleport_node_type])
      )
    })
  }

  part {
    content_type = "text/x-shellscript"
    content      = file("${path.module}/assets/cloud-init/install_packages.sh")
  }

  part {
    content_type = "text/x-shellscript"
    content      = file("${path.module}/assets/cloud-init/start_core_services.sh")
  }

  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/assets/cloud-init/pull_files.sh", {
      src_bucket_name = local.artifacts_bucket_name
      src_bucket_path = "${local.aws_kv_namespace}/image/files/bin"
      dst_path        = "/usr/local/bin"
    })
  }
}

resource "aws_autoscaling_group" "this" {
  count = module.this.enabled ? 1 : 0

  name                      = module.node_type_label.id
  vpc_zone_identifier       = local.vpc_private_subnet_ids
  max_instance_lifetime     = 86400
  metrics_granularity       = "1Minute"
  termination_policies      = ["OldestLaunchTemplate", "AllocationStrategy", "Default"]
  health_check_grace_period = 300
  health_check_type         = "EC2"

  desired_capacity = local.desired_capacity
  min_size         = local.min_capacity
  max_size         = local.max_capacity

  target_group_arns = local.target_group_arns

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
    "GroupInServiceCapacity",
    "GroupPendingCapacity",
    "GroupStandbyCapacity",
    "GroupTerminatingCapacity",
    "GroupTotalCapacity",
  ]

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = local.instance_spot.enabled ? 0 : 100
      spot_allocation_strategy                 = local.instance_spot.allocation_strategy
      spot_instance_pools                      = 0
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.this[0].id
        version            = aws_launch_template.this[0].latest_version
      }

      dynamic "override" {
        for_each = local.instance_sizes

        content {
          instance_type     = override.value
          weighted_capacity = "1"
        }
      }
    }
  }

  instance_refresh {
    strategy = "Rolling"
    triggers = ["tag"]

    preferences {
      min_healthy_percentage = 0
    }
  }

  dynamic "tag" {
    for_each = merge(module.node_type_label.tags, { Name = module.node_type_label.id })

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

resource "aws_launch_template" "this" {
  count = module.this.enabled ? 1 : 0

  name                   = module.node_type_label.id
  image_id               = local.teleport_image_id
  user_data              = data.cloudinit_config.this[0].rendered
  update_default_version = true

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = true
      encrypted             = true
      iops                  = null
      kms_key_id            = null
      snapshot_id           = null
      throughput            = null
      volume_size           = 100
      volume_type           = "gp3"
    }
  }

  iam_instance_profile {
    name = resource.aws_iam_instance_profile.this[0].id
  }

  monitoring {
    enabled = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
    instance_metadata_tags      = "enabled"
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = distinct(concat([module.security_group.id], local.teleport_security_group_ids))
  }
}

# ======================================================== instance-resource ===

resource "aws_cloudwatch_log_group" "this" {
  count = module.this.enabled ? 1 : 0

  name              = module.node_type_label.id
  retention_in_days = local.experimental ? 90 : 180
  tags              = module.node_type_label.tags
}

module "security_group" {
  source  = "cloudposse/security-group/aws"
  version = "2.2.0"

  vpc_id                     = local.vpc_id
  create_before_destroy      = false
  preserve_security_group_id = true
  allow_all_egress           = true

  rules = [{
    key                      = "group"
    type                     = "ingress"
    from_port                = 0
    to_port                  = 0
    protocol                 = "all"
    description              = "allow all group ingress"
    cidr_blocks              = []
    ipv6_cidr_blocks         = []
    source_security_group_id = null
    self                     = true
  }]

  tags    = merge(module.node_type_label.tags, { Name = module.node_type_label.id })
  context = module.node_type_label.context
}

locals {
  nlb_ingress_ports = local.teleport_node_type == "auth" ? {
    auth = 3025
    } : local.teleport_node_type == "proxy" ? {
    proxy-web = 3080
  } : {}
}

# Gate only on module.this.enabled; nlb_security_group_id is known-after-apply
# and including it in the for_each condition would block plan.
resource "aws_vpc_security_group_ingress_rule" "from_nlb" {
  for_each = module.this.enabled ? local.nlb_ingress_ports : {}

  security_group_id            = module.security_group.id
  description                  = "allow ${each.key} (${each.value}) from nlb"
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value
  referenced_security_group_id = local.nlb_security_group_id
}

# ---------------------------------------------------------------------- iam ---

resource "aws_iam_instance_profile" "this" {
  count = module.this.enabled ? 1 : 0

  name = module.node_type_label.id
  role = aws_iam_role.this[0].name
}

resource "aws_iam_role" "this" {
  count = module.this.enabled ? 1 : 0

  name        = module.node_type_label.id
  description = ""

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow"
      Principal = { "Service" : "ec2.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = module.node_type_label.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = toset(local.iam_role_attached_policy_arns)

  role       = aws_iam_role.this[0].name
  policy_arn = each.key
}

resource "aws_iam_role_policy" "this" {
  for_each = { for x in local.iam_role_attached_policies : x.name => x }

  role   = aws_iam_role.this[0].name
  name   = each.key
  policy = each.value.policy
}

data "aws_iam_policy_document" "ec2_management" {
  count = module.this.enabled ? 1 : 0

  statement {
    sid    = "AllowSsmSessionLogging"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:PutObjectTagging",
      "s3:GetEncryptionConfiguration",
      "s3:GetBucketLocation",
    ]
    resources = [
      "arn:aws:s3:::${local.logs_bucket_name}",
      "arn:aws:s3:::${local.logs_bucket_name}/*"
    ]
  }

  statement {
    sid    = "AllowArtifactsBucketRead"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket*",
    ]
    resources = [
      "arn:aws:s3:::${local.artifacts_bucket_name}",
      "arn:aws:s3:::${local.artifacts_bucket_name}/*"
    ]
  }
}

data "aws_iam_policy_document" "base_access" {
  count = contains(["auth", "proxy"], local.teleport_node_type) ? 1 : 0

  statement {
    sid    = "AllowSecretsKmsKeyAccess"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
    ]
    resources = [
      "*",
    ]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values = [
        "ssm.${local.aws_region_name}.amazonaws.com",
      ]
    }
  }

  statement {
    sid    = "AllowTeleportSsmParameterAccess"
    effect = "Allow"
    actions = [
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:GetParameter"
    ]
    resources = [
      "arn:aws:ssm:${local.aws_region_name}:${local.aws_account_id}:parameter/${local.aws_kv_namespace}/*/tokens/proxy",
      "arn:aws:ssm:${local.aws_region_name}:${local.aws_account_id}:parameter/${local.aws_kv_namespace}/*/ca-pin-hash",
      "arn:aws:ssm:${local.aws_region_name}:${local.aws_account_id}:parameter/teleport/${local.teleport_cluster_name}/tokens/proxy",
      "arn:aws:ssm:${local.aws_region_name}:${local.aws_account_id}:parameter/teleport/${local.teleport_cluster_name}/ca-pin-hash",
    ]
  }

  statement {
    sid    = "AllowCloudWatchLogging"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "${aws_cloudwatch_log_group.this[0].arn}*"
    ]
  }
}

data "aws_iam_policy_document" "auth_access" {
  count = contains(["auth"], local.teleport_node_type) ? 1 : 0

  statement {
    sid    = "AllowSecretsKmsKeyAccess"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
    ]
    resources = [
      "*",
    ]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values = [
        "ssm.${local.aws_region_name}.amazonaws.com",
      ]
    }
  }

  statement {
    sid    = "AllowR53ReadAccess"
    effect = "Allow"
    actions = [
      "route53:ListHostedZones",
      "route53:GetChange",
    ]
    resources = [
      "*",
    ]
  }

  statement {
    sid    = "AllowR53WriteAccess"
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets",
    ]
    resources = [
      "arn:aws:route53:::hostedzone/${local.dns_parent_zone_id}"
    ]
  }

  statement {
    sid    = "AllowTeleportDdbTableFullAccess"
    effect = "Allow"
    actions = [
      "dynamodb:*",
    ]
    resources = [
      "arn:aws:dynamodb:${local.aws_region_name}:${local.aws_account_id}:table/${local.teleport_ddb_table_events_name}",
      "arn:aws:dynamodb:${local.aws_region_name}:${local.aws_account_id}:table/${local.teleport_ddb_table_events_name}/index/*",
      "arn:aws:dynamodb:${local.aws_region_name}:${local.aws_account_id}:table/${local.teleport_ddb_table_locks_name}",
      "arn:aws:dynamodb:${local.aws_region_name}:${local.aws_account_id}:table/${local.teleport_ddb_table_state_name}",
      "arn:aws:dynamodb:${local.aws_region_name}:${local.aws_account_id}:table/${local.teleport_ddb_table_state_name}/stream/*",
    ]
  }

  statement {
    sid    = "AllowTeleportS3BucketAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject",
    ]
    resources = [
      "arn:aws:s3:::${local.teleport_bucket_name}",
      "arn:aws:s3:::${local.teleport_bucket_name}/*",
    ]
  }

  statement {
    sid    = "AllowTeleportSsmParameterAccess"
    effect = "Allow"
    actions = [
      "ssm:DescribeParameters",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:GetParameter",
      "ssm:PutParameter",
      "ssm:DeleteParameter",
    ]
    resources = [
      "arn:aws:ssm:${local.aws_region_name}:${local.aws_account_id}:parameter/${local.aws_kv_namespace}/*",
      "arn:aws:ssm:${local.aws_region_name}:${local.aws_account_id}:parameter/teleport/${local.teleport_cluster_name}/*",
    ]
  }
}

data "aws_iam_policy_document" "proxy_access" {
  count = contains(["proxy"], local.teleport_node_type) ? 1 : 0

  statement {
    sid    = "AllowTeleportS3BucketAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::${local.teleport_bucket_name}",
      "arn:aws:s3:::${local.teleport_bucket_name}/*",
    ]
  }
}
