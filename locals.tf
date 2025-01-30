locals {
  # config file
  config = yamldecode(file("${path.root}/${var.config}"))

  separator = "_"

  # fip_network
  fip_network = { for key, value in local.config.cloud.fip_network : key => value }

  # network
  #  network => zone => network => subnet
  network_zone = { for key, value in local.config.network : key => value }

  # network
  #  network => zone => network => subnet

  # { subnet_name => { subnet value }}
  cidr_map = { for entry in flatten([
    for zone, zone_value in local.config.network : [
      for net, subnets in zone_value.networks : [
        for subnet, subnet_value in subnets : {
          key = subnet_value.cidr,
          value = {
            zone_name : "${zone}",
            network_name : "${zone}${local.separator}${net}",
            subnet_name : "${zone}${local.separator}${net}${local.separator}${subnet}",
          }
        }
      ]
    ]
  ]) : entry.key => entry.value }

  # instance
  #  instance => instance_name => { flavor,interfaces, volumes...}
  instance_map = { for instance, instance_value in local.config.instances : instance => { instance : instance_value } }

  #  ip_address => { network_name,subnet_name}
  ip_address_map = { for entry in flatten([
    for instance, instance_value in local.config.instances : [
      for key, value in instance_value.interfaces : [
        for cidr, cidr_value in local.cidr_map : {
          key = value.ip_address,
          value = {
            network_name : cidr_value.network_name
            subnet_name : cidr_value.subnet_name
            zone_name : cidr_value.zone_name
            subnet_id : length(module.network) > 0 ? module.network[cidr_value.zone_name].subnet[cidr_value.subnet_name].id : null
            network_id : length(module.network) > 0 ? module.network[cidr_value.zone_name].subnet[cidr_value.subnet_name].network_id : null
          }
          # if ip_address is in cidr, store network_name, and subnet_name
        } if contains([for i in range(0, pow(2, 32 - parseint(regex("/(\\d+)$", cidr)[0], 10))) : cidrhost(cidr, i)], value.ip_address)
      ]
    ]
  ]) : entry.key => entry.value }


  #
  # get sec group id
  #
  secgroup_v2_map_id = merge([for value in module.security_groups : 
           value.secgroup_v2_map_id
         ]...)

}
