variable "teleport_runtime_version" {
  type        = string
  description = "The runtime version of Teleport."
  default     = "10.3.15"
}

variable "teleport_letsencrypt_email" {
  type        = string
  description = "The email address to use for Let's Encrypt."
}

variable "dns_parent_zone_id" {
  type        = string
  description = "The ID of the parent DNS zone."
}

variable "dns_parent_zone_name" {
  type        = string
  description = "The name of the parent DNS zone."
}

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
