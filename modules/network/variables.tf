variable "config" {
  type = map(any)
}

variable "name" {
  type = string
}

variable "fip_network" {
  type = map(any)
}

variable "router_map" {
  type    = map(any)
  default = {}
}
