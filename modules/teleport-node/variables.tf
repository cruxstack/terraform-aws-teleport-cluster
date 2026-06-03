
variable "teleport_auth_address" {
  type    = string
  default = ""
}

variable "teleport_bucket_name" {
  type = string
}

variable "teleport_cluster_name" {
  type = string
}

variable "teleport_ddb_table_events_name" {
  type = string
}

variable "teleport_ddb_table_locks_name" {
  type = string
}

variable "teleport_ddb_table_state_name" {
  type = string
}

variable "teleport_image_id" {
  type = string
}

variable "teleport_letsencrypt_email" {
  type = string
}

variable "teleport_node_type" {
  type        = string
  description = "Type of Teleport server this module manages. Only `auth` and `proxy` are supported in v2 (the `node` role was removed)."

  validation {
    condition     = contains(["auth", "proxy"], var.teleport_node_type)
    error_message = "teleport_node_type must be one of: auth, proxy."
  }
}

variable "teleport_public_addr" {
  type        = string
  description = "Public address of the consolidated Teleport NLB. Used to populate `auth_service.public_addr` for the auth role."
  default     = ""
}

variable "teleport_security_group_ids" {
  type = list(string)
}

variable "teleport_setup_mode" {
  type    = bool
  default = true
}

variable "experimental" {
  type    = bool
  default = false
}

# ----------------------------------------------------------------- instance ---

variable "instance_count" {
  type    = number
  default = 1
}

variable "instance_sizes" {
  type    = list(string)
  default = ["t3.medium", "t3a.medium"]
}

variable "instance_spot" {
  type = object({
    enabled             = optional(bool, true)
    allocation_strategy = optional(string, "capacity-optimized")
  })
  default = {}
}

# ----------------------------------------------------------- infrastructure ---

variable "artifacts_bucket_name" {
  type = string
}

variable "logs_bucket_name" {
  type = string
}

variable "dns_parent_zone_id" {
  type = string
}

variable "dns_parent_zone_name" {
  type = string
}

variable "vpc_associate_public_ips" {
  type    = bool
  default = false
}

variable "vpc_id" {
  type = string
}

variable "vpc_security_group_ids" {
  type    = list(string)
  default = []
}

variable "vpc_private_subnet_ids" {
  type    = list(string)
  default = []
}

variable "vpc_public_subnet_ids" {
  type    = list(string)
  default = []
}

# ------------------------------------------------------------ load-balancer ---

variable "target_group_arns" {
  type        = list(string)
  description = "Target group ARNs the ASG should register instances with. Provided by the consolidated `teleport-nlb` submodule in v2."
  default     = []
}

variable "nlb_security_group_id" {
  type        = string
  description = "Security group ID of the consolidated NLB. The instance security group accepts ingress from this SG on the Teleport ports relevant to the node type (3025 for auth, 3080 for proxy). Required."
}

# ---------------------------------------------------------------- component ---

variable "aws_account_id" {
  type = string
}

variable "aws_kv_namespace" {
  type = string
}

variable "aws_region_name" {
  type = string
}
