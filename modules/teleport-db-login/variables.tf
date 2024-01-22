variable "tp_proxy" {
  type        = string
  description = "Domain to the Teleport cluster proxy for database login."
  default     = ""
}

variable "tp_cluster" {
  type        = string
  description = "Domain to the Teleport cluster for database login."
}

variable "target_db" {
  type        = string
  description = "Name of the target database resource within the Teleport cluster."
}

variable "target_db_name" {
  type        = string
  description = "Name of the database within the target database resource."
  default     = ""
}

variable "target_db_user" {
  type        = string
  description = "Name of the user to use when connecting to the database resource."
  default     = ""
}
