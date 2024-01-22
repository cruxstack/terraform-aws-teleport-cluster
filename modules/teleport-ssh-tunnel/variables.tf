variable "tp_proxy" {
  type        = string
  description = "Domain to the Teleport cluster proxy for database login."
  default     = ""
}

variable "tp_cluster" {
  type        = string
  description = "Domain to the Teleport cluster for database login."
}

variable "tp_gateway_node" {
  type        = string
  description = "Teleport node to use as the gateway for the connection."
}

variable "target_host" {
  type        = string
  description = "Target host."
}

variable "target_port" {
  type        = number
  description = "Target port."
}
