output "out" {
  value = local.network_map
}

output "sub" {
  value = local.subnet_map
}
output "subnet" {
  value = openstack_networking_subnet_v2.subnet
}

#output "network" {
#  value = openstack_networking_network_v2.network
#}
#
output "route" {
  value = local.local_route_map
}
