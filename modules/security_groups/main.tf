locals {
  separator           = "_"
  default_description = "Managed by terraform"
  default_direction   = "ingress"
  default_ethertype   = "IPv4"
  default_protocol    = "tcp"
  default_source      = "0.0.0.0/0"

  all_security_group_map = merge(local.security_group_map, local.security_group_rule_list_addons)
  all_security_group_list = distinct(keys(local.all_security_group_map))

  # security_group_map_description
  security_group_map_description = flatten([
    for group_name, group_value in var.config.group : [
      for rule, rule_value in group_value : [
        for source in formatlist("%s", flatten([try(rule_value.sources, [])])) : {
          name        = format("%s%s%s", var.name, local.separator, group_name)
          description = lookup(rule_value, "description", "")
        }
      ]
    ]
  ])

  # security_group_map 
  security_group_keys_available = distinct([for k in local.security_group_map_description : k.name])
  # with duplicate values
  security_group_helper_map = merge([for key in local.security_group_keys_available :
    { for k in local.security_group_map_description :
      key => k["description"]... if k["name"] == key
    }
  ]...)
  # duplicates removed
  #  format description group
  security_group_map = { for k, v in local.security_group_helper_map : k => join(" - ", distinct(concat(v, [local.default_description]))) }

  # security_group_rule_map
  security_group_rule_map = {
    for k in local.security_group_rule_list :
    k.name => k
  }

  security_group_rule_list = flatten([
    for group_name, group_value in var.config.group : [
      for rule, rule_value in group_value : [
        for source in formatlist("%s", flatten([try(rule_value.sources, [])])) : {
          rule       = rule
          rule_value = rule_value

          # format rule name
          name = join(local.separator, [
            var.name,
            group_name,
            replace(try(source, local.default_source), "/[./]/", local.separator),
            try(rule_value.protocol, local.default_protocol),
            replace(try(rule_value.ports, ""), ":", local.separator)
          ])
          security_group_name    = format("%s%s%s", var.name, local.separator, group_name)
          security_group_network = var.name
          group_name             = group_name
          description            = lookup(rule_value, "description", "")
          direction              = lookup(rule_value, "direction", local.default_direction)
          protocol               = lookup(rule_value, "protocol", local.default_protocol)
          port_range_min         = tonumber(element(split(":", try(rule_value.ports, 0)), 0))
          port_range_max = tonumber(element(split(":", try(rule_value.ports, 0)),
          length(split(":", try(rule_value.ports, 0))) - 1))
          ethertype = lookup(rule_value, "ethertype", local.default_ethertype)
          source    = try(source, local.default_source)

          #
          # detect if source is IP or CIDR (1 to 32) block specified
          #
          is_remote_ip_prefix = can(regex("^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)($|/([1-9]|[12][0-9]|3[012]))?$", try(source, local.default_source)))
          remote_group_id     = format("%s%s%s", var.name, local.separator, try(source, local.default_source))
        }
      ]
    ]
  ])


  security_group_rule_list_addons = { for v in distinct([for k, v in local.security_group_rule_map :
    v.remote_group_id if v.is_remote_ip_prefix == false
    ]) :
    v => local.default_description
  }

}

#
resource "openstack_networking_secgroup_v2" "secgroup" {
  for_each = local.all_security_group_map

  name        = each.key
  description = each.value
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule" {
  for_each = local.security_group_rule_map

  description    = each.value.description
  direction      = each.value.direction
  ethertype      = each.value.ethertype
  protocol       = each.value.protocol
  port_range_min = each.value.port_range_min
  port_range_max = each.value.port_range_max

  remote_ip_prefix = each.value.is_remote_ip_prefix ? try(each.value.source, local.default_source) : null
  remote_group_id  = each.value.is_remote_ip_prefix ? null : openstack_networking_secgroup_v2.secgroup[each.value.remote_group_id].id

  security_group_id = openstack_networking_secgroup_v2.secgroup[each.value.security_group_name].id
}
