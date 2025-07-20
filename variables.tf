variable "config_file" {
  description = "config.yml file"
  type        = string
  default     = "config.yml"
}

variable "parameters" {
  description = "parameters variables defines in yaml template config file"
  type        = map(any)
  default     = {}
}
