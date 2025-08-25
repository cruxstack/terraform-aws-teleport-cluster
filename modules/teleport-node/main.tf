locals {
  teleport_auth_address      = var.teleport_auth_address
  teleport_bucket_name       = var.teleport_bucket_name
  teleport_cluster_name      = var.teleport_cluster_name
  teleport_image_id          = var.teleport_image_id
  teleport_letsencrypt_email = var.teleport_letsencrypt_email
  teleport_node_type         = var.teleport_node_type
  teleport_setup_enabled     = module.this.enabled && var.teleport_setup_mode

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

  desired_capacity      = local.teleport_setup_enabled ? (local.teleport_node_type == "auth" ? 1 : 0) : var.instance_count
  min_capacity          = local.teleport_setup_enabled ? (local.teleport_node_type == "auth" ? 1 : 0) : var.instance_count
  max_capacity          = local.teleport_setup_enabled ? (local.teleport_node_type == "auth" ? 1 : 0) : var.instance_count
  instance_sizes        = var.instance_sizes
  instance_spot_enabled = var.instance_spot_enabled

  dns_name           = "${module.dns_label.id}.${var.dns_parent_zone_name}"
  dns_parent_zone_id = var.dns_parent_zone_id

  vpc_associate_public_ips = var.vpc_associate_public_ips
  vpc_id                   = var.vpc_id
  vpc_security_group_ids   = var.vpc_security_group_ids
  vpc_private_subnet_ids   = var.vpc_private_subnet_ids
  vpc_public_subnet_ids    = var.vpc_public_subnet_ids

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
    contains(["node"], local.teleport_node_type) ? [
      {
        name   = "teleport-node-access"
        policy = one(data.aws_iam_policy_document.node_access.*.json)
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
  teleport_config = {
    auth = {
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
        public_addr          = tobool(local.teleport_node_type == "auth") ? "${aws_lb.this[0].dns_name}:3025" : ""
        keep_alive_interval  = "1m"
        keep_alive_count_max = 3
        listen_addr          = "0.0.0.0:3025"
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
    node = {
      teleport = {
        auth_token   = "/var/lib/teleport/token"
        ca_pin       = "CA_PIN_HASH_PLACEHOLDER"
        nodename     = "$TELEPORT_NODENAME"
        advertise_ip = "$TELEPORT_ADVERTISE_IP"
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
          "${local.dns_name}:443",
          "${local.teleport_auth_address}:3025",
        ]
      }
      app_service = {
        enabled   = "yes"
        debug_app = true
        resources = [{
          labels = {
            "*" : "*"
          }
        }]
      }
      auth_service = {
        enabled = "no"
      }
      db_service = {
        enabled = "yes"
        aws = [{
          types   = ["rds", "redshift"]
          regions = [local.aws_region_name]
          tags = {
            "*" : "*"
          }
        }]
        resources = [{
          labels = {
            "*" : "*"
          }
        }]
      }
      proxy_service = {
        enabled = "no"
      }
      ssh_service = {
        enabled     = "yes"
        listen_addr = "0.0.0.0:3022"
        enhanced_recording = {
          enabled             = false # todo enable w/ amazon-linux 2022; minimum supported kernel is 5.8.0
          command_buffer_size = 8
          disk_buffer_size    = 128
          network_buffer_size = 8
          cgroup_path         = "/cgroup2"
        }
        labels = module.this.tags
      }
    }
    proxy = {
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
        enabled            = "yes"
        listen_addr        = "0.0.0.0:3023"
        tunnel_listen_addr = "0.0.0.0:3080"
        web_listen_addr    = "0.0.0.0:3080"
        public_addr        = "${local.dns_name}:443"
        ssh_public_addr    = "${local.dns_name}:3023"
        tunnel_public_addr = "${local.dns_name}:443"
        https_keypairs = [{
          cert_file = "/var/lib/teleport/fullchain.pem"
          key_file  = "/var/lib/teleport/privkey.pem"
        }]
        kubernetes = {
          enabled     = "yes"
          listen_addr = "0.0.0.0:3026"
          public_addr = ["${local.dns_name}:3026"]
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

  target_group_arns = flatten([
    contains(["auth"], local.teleport_node_type) ? [
      aws_lb_target_group.auth_ssh[0].arn
    ] : [],
    contains(["proxy"], local.teleport_node_type) ? [
      aws_lb_target_group.proxy_ssh[0].arn,
      aws_lb_target_group.proxy_web[0].arn,
    ] : [],
  ])

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
      on_demand_percentage_above_base_capacity = local.instance_spot_enabled ? 0 : 100
      spot_allocation_strategy                 = "capacity-optimized"
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

  rules = flatten([
    [{
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
    }],
    length(var.vpc_security_group_allowed_cidrs) > 0 ? [{
      key                      = "auth"
      type                     = "ingress"
      from_port                = 3025
      to_port                  = 3025
      protocol                 = "tcp"
      description              = "allow auth traffic"
      cidr_blocks              = var.vpc_security_group_allowed_cidrs
      ipv6_cidr_blocks         = []
      source_security_group_id = null
      self                     = null
    }] : [],
    length(var.vpc_security_group_allowed_cidrs) > 0 ? [{
      key                      = "node-ssh"
      type                     = "ingress"
      from_port                = 3022
      to_port                  = 3022
      protocol                 = "tcp"
      description              = "allow teleport node ssh"
      cidr_blocks              = var.vpc_security_group_allowed_cidrs
      ipv6_cidr_blocks         = []
      source_security_group_id = null
      self                     = null
    }] : [],
    length(var.vpc_security_group_allowed_cidrs) > 0 ? [{
      key                      = "proxy-ssh"
      type                     = "ingress"
      from_port                = 3023
      to_port                  = 3023
      protocol                 = "tcp"
      description              = "allow teleport proxy ssh"
      cidr_blocks              = var.vpc_security_group_allowed_cidrs
      ipv6_cidr_blocks         = []
      source_security_group_id = null
      self                     = null
    }] : [],
    length(var.vpc_security_group_allowed_cidrs) > 0 ? [{
      key                      = "proxy-reverse-ssh"
      type                     = "ingress"
      from_port                = 3024
      to_port                  = 3024
      protocol                 = "tcp"
      description              = "allow teleport proxy reverse-ssh"
      cidr_blocks              = var.vpc_security_group_allowed_cidrs
      ipv6_cidr_blocks         = []
      source_security_group_id = null
      self                     = null
    }] : [],
    length(var.vpc_security_group_allowed_cidrs) > 0 ? [{
      key                      = "proxy-https"
      type                     = "ingress"
      from_port                = 443
      to_port                  = 443
      protocol                 = "tcp"
      description              = "allow teleport proxy https"
      cidr_blocks              = var.vpc_security_group_allowed_cidrs
      ipv6_cidr_blocks         = []
      source_security_group_id = null
      self                     = null
    }] : [],
    length(var.vpc_security_group_allowed_cidrs) > 0 ? [{
      key                      = "proxy-web"
      type                     = "ingress"
      from_port                = 3080
      to_port                  = 3080
      protocol                 = "tcp"
      description              = "allow teleport proxy (alternative) https"
      cidr_blocks              = var.vpc_security_group_allowed_cidrs
      ipv6_cidr_blocks         = []
      source_security_group_id = null
      self                     = null
    }] : [],
    length(var.vpc_security_group_allowed_cidrs) > 0 ? [{
      key                      = "proxy-mysql"
      type                     = "ingress"
      from_port                = 3036
      to_port                  = 3036
      protocol                 = "tcp"
      description              = "allow teleport proxy db connections"
      cidr_blocks              = var.vpc_security_group_allowed_cidrs
      ipv6_cidr_blocks         = []
      source_security_group_id = null
      self                     = null
    }] : [],
  ])

  tags    = merge(module.node_type_label.tags, { Name = module.node_type_label.id })
  context = module.node_type_label.context
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
  count = contains(["auth", "node", "proxy"], local.teleport_node_type) ? 1 : 0

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
  count = module.this.enabled ? 1 : 0

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

data "aws_iam_policy_document" "node_access" {
  count = contains(["node"], local.teleport_node_type) ? 1 : 0

  statement {
    sid    = "AllowDatabaseClusterAccess"
    effect = "Allow"
    actions = [
      "redshift:DescribeClusters",
      "redshift:GetClusterCredentials",
      "rds:DescribeDBInstances",
      "rds:ModifyDBInstance",
      "rds:DescribeDBClusters",
      "rds:ModifyDBCluster",
      "rds-db:connect",
    ]
    resources = [
      "*",
    ]
  }

  statement {
    sid    = "AllowDatabaseIamAccess"
    effect = "Allow"
    actions = [
      "iam:GetRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
    ]
    resources = [
      "*", # todo limit which resources
    ]
  }
}

data "aws_iam_policy_document" "proxy_access" {
  count = module.this.enabled ? 1 : 0

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

# ====================================================================== nlb ===

module "node_lb_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  id_length_limit = 32
  label_order     = ["name", "attributes"]
  context         = module.node_type_label.context
}

resource "aws_lb" "this" {
  count = contains(["auth", "proxy"], local.teleport_node_type) ? 1 : 0

  name                             = module.node_lb_label.id
  internal                         = contains(["auth"], local.teleport_node_type)
  subnets                          = contains(["auth"], local.teleport_node_type) ? local.vpc_private_subnet_ids : local.vpc_public_subnet_ids
  load_balancer_type               = "network"
  idle_timeout                     = 3600
  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = local.experimental ? false : true

  access_logs {
    bucket  = local.logs_bucket_name
    enabled = true
  }

  tags = module.node_type_label.tags
}

resource "aws_route53_record" "proxy" {
  count = contains(["proxy"], local.teleport_node_type) ? 1 : 0

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
  count = contains(["proxy"], local.teleport_node_type) ? 1 : 0

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

# ---------------------------------------------------------------- auth: ssh ---

module "auth_ssh_lb_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  # ensure there are room for the 6 unique chars plus dash for actual label
  attributes      = ["auth", "ssh"]
  id_length_limit = 32
  label_order     = ["name", "attributes"]
  context         = module.node_lb_label.context
}

resource "aws_lb_target_group" "auth_ssh" {
  count = contains(["auth"], local.teleport_node_type) ? 1 : 0

  name     = module.node_lb_label.id
  port     = 3025
  vpc_id   = local.vpc_id
  protocol = "TCP"
}

resource "aws_lb_listener" "auth_ssh" {
  count = contains(["auth"], local.teleport_node_type) ? 1 : 0

  load_balancer_arn = aws_lb.this[0].arn
  port              = 3025
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.auth_ssh[0].arn
    type             = "forward"
  }
}

# --------------------------------------------------------------- proxy: ssh ---

module "proxy_ssh_lb_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  # ensure there are room for the 6 unique chars plus dash for actual label
  attributes      = ["proxy", "ssh"]
  id_length_limit = 32
  label_order     = ["name", "attributes"]
  context         = module.node_lb_label.context
}

resource "aws_lb_target_group" "proxy_ssh" {
  count = contains(["proxy"], local.teleport_node_type) ? 1 : 0

  name     = module.proxy_ssh_lb_label.id
  port     = 3023
  vpc_id   = local.vpc_id
  protocol = "TCP"
}

resource "aws_lb_listener" "proxy_ssh" {
  count = contains(["proxy"], local.teleport_node_type) ? 1 : 0

  load_balancer_arn = aws_lb.this[0].arn
  port              = 3023
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.proxy_ssh[0].arn
    type             = "forward"
  }
}

# --------------------------------------------------------------- proxy: web ---

module "proxy_web_lb_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  attributes      = ["proxy", "web"]
  id_length_limit = 32
  label_order     = ["name", "attributes"]
  context         = module.node_lb_label.context
}

resource "aws_lb_target_group" "proxy_web" {
  count = contains(["proxy"], local.teleport_node_type) ? 1 : 0

  name     = module.proxy_web_lb_label.id
  port     = 3080
  vpc_id   = local.vpc_id
  protocol = "TCP"
}

resource "aws_lb_listener" "proxy_web" {
  count = contains(["proxy"], local.teleport_node_type) ? 1 : 0

  load_balancer_arn = aws_lb.this[0].arn
  port              = 443
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.proxy_web[0].arn
    type             = "forward"
  }
}
