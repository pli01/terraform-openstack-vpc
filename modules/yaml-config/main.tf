variable "config_file" {}
variable "parameters" {
  type    = map(any)
  default = {}
}
locals {
  # template file and replace ${vars} with var.parameters
  # yaml decode config file
  config = yamldecode(templatefile(format("%s", var.config_file), var.parameters))

#  nets      = length(keys(local.config.resources.net)) > 0 ? flatten(keys(local.config.resources.net)) : []
#  public_ip = length(keys(local.config.resources.public_ip)) > 0 ? flatten(keys(local.config.resources.public_ip)) : []
#
  resource_key = [
    "network",
    "security_groups",
    "instances"
  ]
  check_default = lookup(local.config, "default", {})

  check_resources = { for entry in flatten([
    for k, v in local.resource_key : {
      key : v
      value : lookup(local.config.resources, v, {})
    }
  ]) : entry.key => entry.value }
}

output "check_config" {
  value = merge({ default : local.check_default }, { resources : local.check_resources })
}


output "config" {
  # value = local.config
  value = merge({ default : local.check_default }, { resources : local.check_resources })
}

#output "nets" {
#  value = local.nets
#}
#output "public_ip" {
#  value = local.public_ip
#}
