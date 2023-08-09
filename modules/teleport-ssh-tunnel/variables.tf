variable "terraform_cluster" {
  type        = string
  description = "Teleport cluster domain."
}

variable "terraform_gateway" {
  type        = string
  description = "Teleport gateway."
}

variable "target_host" {
  type        = string
  description = "Target host."
}

variable "target_port" {
  type        = number
  description = "Target port."
}
