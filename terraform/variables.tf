
variable "region" {
  type = string
}

variable "service_name" {
  type = string
}

variable "image_version" {
  type = string
}

variable "log_retention_in_days" {
  type = number
  default = 14
}
