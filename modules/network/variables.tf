variable "config" {
  type = map(any)
}

variable "name" {
  type = string
}

variable "router_map" {
  type    = map(any)
  default = {}
}
