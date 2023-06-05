variable "config" {
  type = map(any)
}

variable "name" {
  type = string
}

variable "ip_address_map" {
  type = map(any)
}

variable "secgroup_v2_map_id" {
  type    = map(any)
  default = {}
}

variable "subnets" {
  type    = map(any)
  default = {}
}

variable "keypair_name" {
  type    = string
  default = "default_keypair"
}

variable "volume_type" {
  type    = string
  default = "classic"
}
#variable "volume_size" {
#  type    = number
#  default = 0
#}
