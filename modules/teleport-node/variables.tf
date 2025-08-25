
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
  type = string
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

variable "instance_spot_enabled" {
  type    = bool
  default = true
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

variable "vpc_security_group_allowed_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
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
