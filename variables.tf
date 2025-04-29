# ================================================================= teleport ===

variable "teleport_runtime_version" {
  type        = string
  description = "The runtime version of Teleport."
}

variable "teleport_letsencrypt_email" {
  type        = string
  description = "The email address to use for Let's Encrypt."
}

variable "teleport_setup_mode" {
  type        = bool
  description = "Toggle Teleport setup mode."
  default     = true
}

variable "teleport_experimental_mode" {
  type        = bool
  description = "Toggle Teleport experimental mode."
  default     = false
}

# ----------------------------------------------------------------- instance ---

variable "instance_config" {
  type = object({
    auth = optional(object({
      count = optional(number, 1)
      sizes = optional(list(string), ["t3.micro", "t3a.micro"])
    }), {})
    node = optional(object({
      count = optional(number, 1)
      sizes = optional(list(string), ["t3.micro", "t3a.micro"])
    }), {})
    proxy = optional(object({
      count = optional(number, 1)
      sizes = optional(list(string), ["t3.micro", "t3a.micro"])
    }), {})
  })
  description = "Configuration for the instances. Each type (`auth`, `node`, `proxy`) contains an object with `count` and `sizes`."
  default     = {}
}

# ------------------------------------------------------------------ buckets ---

variable "artifacts_bucket_name" {
  type        = string
  description = "The name of the S3 bucket for artifacts."
  default     = ""
}

variable "logs_bucket_name" {
  type        = string
  description = "The name of the S3 bucket for logs."
  default     = ""
}

# ---------------------------------------------------------------------- ddb ---

variable "ddb_deletion_protection_enabled" {
  type        = bool
  description = "Toggle deletion protection mode for all DynamoDB tables"
  default     = true
}

# ---------------------------------------------------------------------- dns ---

variable "dns_parent_zone_id" {
  type        = string
  description = "The ID of the parent DNS zone."
}

variable "dns_parent_zone_name" {
  type        = string
  description = "The name of the parent DNS zone."
}

# ------------------------------------------------------------------ network ---

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC to deploy resources into."
}

variable "vpc_private_subnet_ids" {
  type        = list(string)
  description = "The IDs of the private subnets in the VPC to deploy resources into."
}

variable "vpc_public_subnet_ids" {
  type        = list(string)
  description = "The IDs of the public subnets in the VPC to deploy resources into."
}

# ================================================================== context ===

variable "aws_region_name" {
  type        = string
  description = "The name of the AWS region."
  default     = ""
}

variable "aws_account_id" {
  type        = string
  description = "The ID of the AWS account."
  default     = ""
}

variable "aws_kv_namespace" {
  type        = string
  description = "The namespace or prefix for AWS SSM parameters and similar resources."
  default     = ""
}
