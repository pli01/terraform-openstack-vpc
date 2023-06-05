#
# security groups
#
module "security_groups" {
  source   = "./modules/security_groups"
  for_each = { for k, v in local.config.security_groups : k => { group : v } }

  name   = each.key
  config = each.value
}


# data.openstack_networking_network_v2.fip_network["FIP_NET"]
data "openstack_networking_network_v2" "fip_network" {
  for_each = local.fip_network
  name     = each.value
}

# default_keypair
resource "openstack_compute_keypair_v2" "default_keypair" {
  for_each   = local.config.cloud.keypair
  name       = each.key
  public_key = each.value
}

# openstack_networking_router_v2.router["FIP_NET"]
resource "openstack_networking_router_v2" "router" {
  for_each            = local.fip_network
  name                = each.key
  external_network_id = data.openstack_networking_network_v2.fip_network[each.key].id
}

#
# image "openstack_images_image_v2" 
#

# module.network["FRONT_NET"]
module "network" {
  source   = "./modules/network"
  for_each = local.network_zone

  name        = each.key
  config      = each.value
  fip_network = data.openstack_networking_network_v2.fip_network
  router_map  = openstack_networking_router_v2.router
}


# module.instance["bastion"]
module "instance" {
  source   = "./modules/instance"
  for_each = local.instance_map

  name           = each.key
  config         = each.value
  ip_address_map = local.ip_address_map
  secgroup_v2_map_id = local.secgroup_v2_map_id
}

