# =================================================================== nlb ===

variable "nlb_internal" {
  type        = bool
  description = "Whether the consolidated NLB should be internal (true, the default) or internet-facing (false). Internal places the NLB in `vpc_private_subnet_ids` so same-VPC consumers resolve it to private ENI IPs."
  default     = true
}

variable "nlb_allowed_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the consolidated NLB on the public client port (443)."
  default     = ["0.0.0.0/0"]
}

variable "nlb_auth_allowed_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the consolidated NLB on the auth listener (3025). Defaults to empty — :3025 is gated to members of the cluster security group only. Set to e.g. the VPC's NAT gateway EIPs when `nlb_internal = false` and same-VPC proxies must reach auth through the NLB's public IPs (the source IP at the NLB then no longer matches the cluster SG)."
  default     = []
}

variable "nlb_privatelink_enabled" {
  type        = bool
  description = "When true, expose the NLB as an AWS PrivateLink (VPC Endpoint Service) so consumers in other VPCs/accounts can reach Teleport over the AWS network. Only the client port (443) is reachable through the endpoint service; the internal auth listener (3025) remains SG-gated and blocked at the NLB."
  default     = false
}

variable "nlb_privatelink_config" {
  type = object({
    acceptance_required = optional(bool, true)
    allowed_principals  = optional(list(string), [])
    private_dns_name    = optional(string, "")
    supported_regions   = optional(list(string), [])
  })
  description = "Configuration applied to the PrivateLink endpoint service when `nlb_privatelink_enabled` is true."
  default     = {}
}

# ----------------------------------------------------------------- network ---

variable "vpc_id" {
  type        = string
  description = "ID of the VPC the NLB will be attached to."
}

variable "vpc_private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs used when `nlb_internal` is true."
  default     = []
}

variable "vpc_public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs used when `nlb_internal` is false."
  default     = []
}

variable "cluster_security_group_id" {
  type        = string
  description = "Security group ID shared by the Teleport auth and proxy instances. The NLB is attached to this group so its self-ingress rule grants cluster members (and the NLB ENIs themselves) full intra-cluster reachability — including the auth listener on 3025."
}

# --------------------------------------------------------------------- dns ---

variable "dns_parent_zone_id" {
  type        = string
  description = "ID of the Route53 hosted zone that will hold the proxy alias records."
}

variable "dns_parent_zone_name" {
  type        = string
  description = "Name of the Route53 parent hosted zone (used to build the FQDN)."
}

# ----------------------------------------------------------------- buckets ---

variable "logs_bucket_name" {
  type        = string
  description = "S3 bucket used to store NLB access logs."
}

# --------------------------------------------------------------- behaviour ---

variable "deletion_protection_enabled" {
  type        = bool
  description = "Enable deletion protection on the consolidated NLB."
  default     = true
}
