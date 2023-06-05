#output "config" {
#  value = local.fip_network
#}
#
#output "cidr_count" {
#  value = length(local.cidr_map)
#}
#output "cidr" {
#  value = local.cidr_map
#}
#
#output "ip_address_count" {
#  value = length(local.ip_address_map)
#}
#
#output "ip_address" {
#  value = local.ip_address_map
#}
#
#output "instance_map" {
#  value = local.instance_map
#}
#output "networks" {
#  value = [for value in module.network : value]
#}
output "instances" {
  value = [for value in module.instance : value]
}
#output "secgroup" {
#  value = [for value in module.security_groups : value]
#}

output "sec_value" {
  value = local.secgroup_v2_map_id
}
