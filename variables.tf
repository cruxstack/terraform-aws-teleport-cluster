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

variable "deletion_protection_enabled" {
  type        = bool
  description = "Enable deletion protection on stateful resources (DynamoDB tables and the consolidated NLB). When `null` (the default) the value follows `!teleport_experimental_mode` so non-experimental clusters protect their resources while experimental clusters remain tear-down friendly."
  default     = null
  nullable    = true
}

# ----------------------------------------------------------------- instance ---

variable "instance_config" {
  type = object({
    auth = optional(object({
      count = optional(number, 1)
      sizes = optional(list(string), ["t3.micro", "t3a.micro"])
      spot = optional(object({
        enabled             = optional(bool, true)
        allocation_strategy = optional(string, "capacity-optimized")
      }), {})
    }), {})
    proxy = optional(object({
      count = optional(number, 1)
      sizes = optional(list(string), ["t3.micro", "t3a.micro"])
      spot = optional(object({
        enabled             = optional(bool, true)
        allocation_strategy = optional(string, "capacity-optimized")
      }), {})
    }), {})
  })
  description = "Configuration for the auth and proxy instance ASGs. The `node` role is no longer supported in v2. Client allow-lists moved from this object to `nlb_allowed_cidrs` on the consolidated NLB."
  default     = {}
}

# ====================================================================== nlb ===

variable "nlb_internal" {
  type        = bool
  description = "When true (default) the consolidated NLB uses an internal scheme and lives in `vpc_private_subnet_ids`; same-VPC proxy<->auth traffic resolves to private ENI IPs and the cluster SG admits it cleanly. When false the NLB is internet-facing in `vpc_public_subnet_ids` and same-VPC consumers (incl. the proxy reaching auth on :3025) hairpin through the VPC NAT EIPs — populate `nlb_auth_allowed_cidrs` with those EIPs in that scenario. Expose an internal NLB externally via PrivateLink, VPN, or Direct Connect."
  default     = true
}

variable "nlb_allowed_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the consolidated NLB on the public client port (443)."
  default     = ["0.0.0.0/0"]
}

variable "nlb_auth_allowed_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the consolidated NLB on the auth listener (3025). Defaults to empty so :3025 stays gated to members of the cluster security group only. Required when `nlb_internal = false` and same-VPC proxies must reach auth via the NLB's public IPs (set to the VPC NAT gateway EIPs)."
  default     = []
}

variable "nlb_privatelink_enabled" {
  type        = bool
  description = "When true an `aws_vpc_endpoint_service` is created for the consolidated NLB so consumers in other VPCs/accounts can reach Teleport over PrivateLink. Only the public client port (443) is reachable through the endpoint service; auth (3025) remains gated to the cluster security group."
  default     = false
}

variable "nlb_privatelink_config" {
  type = object({
    acceptance_required = optional(bool, true)
    allowed_principals  = optional(list(string), [])
    private_dns_name    = optional(string, "")
    supported_regions   = optional(list(string), [])
  })
  description = "Configuration for the optional PrivateLink endpoint service. `acceptance_required` defaults to true so the provider must approve each consumer endpoint."
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
  description = "The IDs of the private subnets in the VPC. Required: hosts the auth/proxy ASGs and the consolidated NLB when `nlb_internal = true` (the default)."

  validation {
    condition     = length(var.vpc_private_subnet_ids) > 0
    error_message = "vpc_private_subnet_ids must be non-empty."
  }
}

variable "vpc_public_subnet_ids" {
  type        = list(string)
  description = "The IDs of the public subnets in the VPC. Required when `nlb_internal = false`; may be empty when `nlb_internal = true` (the default)."
  default     = []

  validation {
    condition     = var.nlb_internal || length(var.vpc_public_subnet_ids) > 0
    error_message = "vpc_public_subnet_ids must be non-empty when nlb_internal is false."
  }
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
