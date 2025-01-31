locals {
  separator = "_"

  openstack_instance_name = contains(keys(var.config.instance), "openstack_instance_name") ? var.config.instance.openstack_instance_name : var.name

  image_list = distinct(flatten([for k, v in var.config.instance.volumes :
    v.image if contains(keys(v), "image")
  ]))

  volume_list = { for k, v in var.config.instance.volumes :
    "${local.openstack_instance_name}${local.separator}${v.name}" => v
  }

  interface_list = { for k, v in var.config.instance.interfaces :
    format("%s%s%s", local.openstack_instance_name, local.separator, var.ip_address_map[v.ip_address].subnet_name) => merge(v, {
      subnet_name : var.ip_address_map[v.ip_address].subnet_name
      network_name : var.ip_address_map[v.ip_address].network_name
      subnet_id : var.ip_address_map[v.ip_address].subnet_id
      network_id : var.ip_address_map[v.ip_address].network_id
      #
      # resolve security group id (TODO: add default if defined)
      #
      sec_group : flatten([ for sec_name in flatten([for s in lookup(v,"security_groups",{}) : format("%s%s%s",var.ip_address_map[v.ip_address].zone_name,local.separator,s) ]): 
        var.secgroup_v2_map_id[sec_name] if contains(keys(var.secgroup_v2_map_id), sec_name)
      ])
    })
  }

  fip_list = flatten([for k, v in local.interface_list : k if contains(keys(v), "floating_ip")])

}

data "openstack_images_image_v2" "image" {
  for_each = { for k in local.image_list : k => k }
  name     = each.key
}

resource "openstack_networking_port_v2" "port" {
  for_each              = local.interface_list
  name                  = each.key
  network_id            = each.value.network_id
  admin_state_up        = "true"
  port_security_enabled = !contains(keys(each.value), "port_security_enabled") ? true : each.value.port_security_enabled
  mac_address           = contains(keys(each.value), "mac_address") ? each.value.mac_address : null

  fixed_ip {
    subnet_id  = each.value.subnet_id
    ip_address = each.value.ip_address
  }

  dynamic "allowed_address_pairs" {
    for_each = contains(keys(each.value), "allowed_address_pairs_ip") ? [1] : []
    content {
      ip_address = each.value.allowed_address_pairs_ip
    }
  }

  security_group_ids = flatten(each.value.sec_group)

  #  no_security_groups = false
}

resource "openstack_networking_floatingip_associate_v2" "fip" {
  for_each    = { for k in local.fip_list : k => k }
  floating_ip = local.interface_list[each.key].floating_ip
  port_id     = openstack_networking_port_v2.port[each.key].id
}

resource "openstack_blockstorage_volume_v3" "volume" {
  for_each    = local.volume_list
  name        = each.key
  size        = each.value.size
  image_id    = contains(keys(each.value), "image") ? data.openstack_images_image_v2.image[each.value.image].id : null
  volume_type = each.value.volume_type

  lifecycle {
    ignore_changes  = [image_id, snapshot_id]
    prevent_destroy = false # true
  }
}

resource "openstack_compute_instance_v2" "instance" {
  name        = local.openstack_instance_name
  flavor_name = var.config.instance.flavor
  availability_zone = contains(keys(var.config.instance), "availability_zone") ? var.config.instance.availability_zone : null
  key_pair    = var.keypair_name
  user_data = local.enable_user_data ? local.user_data : null

  lifecycle {
    ignore_changes = [key_pair, power_state, scheduler_hints]
  }

  dynamic "network" {
    for_each = local.interface_list
    iterator = interface
    content {
      port = openstack_networking_port_v2.port[interface.key].id
    }
  }

  dynamic "block_device" {
    for_each = local.volume_list
    iterator = device
    content {
      uuid                  = openstack_blockstorage_volume_v3.volume[device.key].id
      source_type           = "volume"
      boot_index            = index(keys(local.volume_list), device.key)
      destination_type      = "volume"
      delete_on_termination = false
    }
  }
}
