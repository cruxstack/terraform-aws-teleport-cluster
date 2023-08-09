variable "target_cluster" {
  type        = string
  description = "Domain to the Teleport cluster for database login."
}

variable "target_db" {
  type        = string
  description = "Name of the target database within the Teleport cluster."
}
