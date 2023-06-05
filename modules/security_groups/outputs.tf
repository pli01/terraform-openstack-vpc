output "security_group_map" {
    value = local.security_group_map
}
output "secgroup_v2_map_id" {
  #  value = openstack_networking_secgroup_v2.secgroup
  value = { for v in local.all_security_group_list : v => openstack_networking_secgroup_v2.secgroup[v].id }
}

output "secgroup_map" {
  value = local.security_group_map
}
output "secgroup_rule_map" {
  value = local.security_group_rule_map
}
output "security_group_rule_list_addons" {
  value = local.security_group_rule_list_addons
}
