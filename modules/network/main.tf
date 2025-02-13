#
# use locals to convert config yaml structure to data object
#
locals {
  separator     = "_"
  dhcp_first_ip = 5
  dhcp_last_ip  = -6
  next_hop_ip   = -2

  # { network_name => { subnet_name => { subnet value }}}
  network_map = { for net, subnets in var.config.networks :
    "${var.name}${local.separator}${net}" => {
      for subnet, subnet_value in subnets :
      "${var.name}${local.separator}${net}${local.separator}${subnet}" => {
        network_name : "${var.name}${local.separator}${net}",
        subnet_name : "${var.name}${local.separator}${net}${local.separator}${subnet}",
        subnet_value : subnet_value
      }
    }
  }

  # { subnet_name => { subnet value }}
  subnet_map = { for entry in flatten([for net, subnets in var.config.networks : [
    for subnet, subnet_value in subnets : {
      key = "${var.name}${local.separator}${net}${local.separator}${subnet}",
      value = {
        network_name : "${var.name}${local.separator}${net}",
        subnet_name : "${var.name}${local.separator}${net}${local.separator}${subnet}",
        subnet_value : merge(subnet_value,
          {
            enable_dhcp : (subnet_value.dhcp != "" && subnet_value.dhcp != false ? "true" : "false")
            # dhcp start/end :  5 ip from cidr start , end last 5 ip from cidr end :  -6
            dhcp_start : (subnet_value.dhcp != "" && subnet_value.dhcp != false ? cidrhost(subnet_value.cidr, local.dhcp_first_ip) : 0)
            dhcp_end : (subnet_value.dhcp != "" && subnet_value.dhcp != false ? cidrhost(subnet_value.cidr, local.dhcp_last_ip) : 0)
            dns_nameservers : (subnet_value.dhcp != "" && subnet_value.dhcp != false ? flatten([subnet_value.dhcp.dns]) : [])
        })
      }
    }
    ]
  ]) : entry.key => entry.value }

  # { "subnet_local_route_x_x_x_x_y" = { "network_name" = "admin_tools",}
  local_route_map = { for entry in flatten([for net, subnets in var.config.networks : [
    for subnet, subnet_value in subnets : [
      for route, route_value in try(subnet_value.dhcp.routes, []) : {
        key = format("%s_local_route_%s", "${var.name}${local.separator}${net}${local.separator}${subnet}", replace(route_value, "/[./]/", local.separator))
        value = {
          route : route,
          route_value : route_value
          network_name : "${var.name}${local.separator}${net}",
          subnet_name : "${var.name}${local.separator}${net}${local.separator}${subnet}",
          next_hop : (contains(keys(subnet_value), "gateway") ? subnet_value.gateway : cidrhost(subnet_value.cidr, local.next_hop_ip))
        }
      }
    ]
    ]
  ]) : entry.key => entry.value }

}

resource "openstack_networking_network_v2" "network" {
  for_each       = local.network_map
  name           = each.key
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "subnet" {
  for_each = local.subnet_map

  name = each.value.subnet_name

  network_id = openstack_networking_network_v2.network[each.value.network_name].id
  ip_version = 4
  cidr       = each.value.subnet_value.cidr
  # dhcp
  enable_dhcp = each.value.subnet_value.enable_dhcp
  dynamic "allocation_pool" {
    for_each = each.value.subnet_value.enable_dhcp ? [1] : []
    content {
      start = each.value.subnet_value.dhcp_start
      end   = each.value.subnet_value.dhcp_end
    }
  }
  # dns
  dns_nameservers = each.value.subnet_value.dns_nameservers
  # gateway
  gateway_ip = (contains(keys(each.value.subnet_value), "gateway") ? each.value.subnet_value.gateway : null)
  no_gateway = (contains(keys(each.value.subnet_value), "no_gateway") ? true : null )
}

resource "openstack_networking_port_v2" "port" {
  for_each = { for subnet, value in local.subnet_map : subnet => value if contains(keys(value.subnet_value), "router") }

  name = format("%s%s%s", each.value.subnet_name, local.separator, "router")

  network_id     = openstack_networking_network_v2.network[each.value.network_name].id
  admin_state_up = true
  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.subnet[each.value.subnet_name].id
    ip_address = (contains(keys(each.value.subnet_value), "gateway") ? each.value.subnet_value.gateway : cidrhost(each.value.subnet_value.cidr, local.next_hop_ip))
  }
}

resource "openstack_networking_router_interface_v2" "router_interface" {
  for_each  = { for subnet, value in local.subnet_map : subnet => value if contains(keys(value.subnet_value), "router") }
  router_id = var.router_map[each.value.subnet_value.router].id
  port_id   = openstack_networking_port_v2.port[each.value.subnet_name].id
}

resource "openstack_networking_subnet_route_v2" "route" {
  for_each         = local.local_route_map
  subnet_id        = openstack_networking_subnet_v2.subnet[each.value.subnet_name].id
  destination_cidr = each.value.route_value
  next_hop         = each.value.next_hop
}

# DEBUG:
#resource "null_resource" "network" {
#  for_each = local.network_map
#  provisioner "local-exec" {
#    command = "echo ${each.key}"
#  }
#}
#
#resource "null_resource" "subnet" {
#  for_each = local.subnet_map
#  provisioner "local-exec" {
#        interpreter = ["/bin/bash", "-c"]
#    command = <<EOC
#    echo ${each.value.network_name}
#    echo ${each.value.subnet_name}
#    echo ${each.value.subnet_value.cidr}
#    EOC
#  }
#}
#
