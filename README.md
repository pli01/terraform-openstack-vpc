# terraform-openstack-vpc

This repository contains terraform modules to build a VPC in an openstack cloud

One Yaml configuration file describe the topology: networks, images, security group, instances

## configuration file
Create your own config.yml file based on config.yml.sample

Sample data structure:
```yaml
cloud:
#
# keypair map to add
#
  keypair:
    default_keypair: "ssh-rsa ......"
#
# router map: external net
# 2 Routers to External Net
  fip_network:
    FIP_PUB: Ext-Net
    FIP_ADM: Ext-Net

#
# 1 zone : 2 network with 1 subnet
# zone: admin
#  network: admin_fip
#    subnet: admin_fip_fip_nat connected to on router (static)
#  network: admin_tools
#    subnet: admin_tools_tools (with dhcp allocation pool and static routes)
#
network:
  admin:
    networks:
      fip:
        fip_nat:
          cidr: 10.1.1.0/29
          dhcp: false
          gateway: 10.1.1.1
          router: FIP_ADM
      tools:
        tools:
          cidr: 10.1.2.0/24
          dhcp:
            dns:
              - 10.1.2.14
            routes:
              - 10.1.1.0/16
              - 192.168.0.0/10

#
# security group
#
security_groups:
  admin:
    default:
      - ports: 22
        description: SSH
        sources:
          - bastion
      - protocol: icmp
        sources:
          - 10.1.1.0/24
          - 192.168.1.1/32
          - bastion
      - ports: 5666:5667
        description: Nagios
        sources: nagios
    bastion:
      - ports: 22
        description: SSH
        sources: 10.2.2.0/24
#
# instances map:
# 1 instance, 1 root disk , 1 data disk, 1 interface
#
instances:
  bastion-01:
    openstack_instance_name: bastion-01
    flavor: s1-2
    interfaces:
      - ip_address: 10.1.1.3
        floating_ip: X.X.X.X
        security_groups:
          - bastion
        #port_security_enabled: false
        #mac_address: ab:cd:ef:1a:bc:00
        #allowed_address_pairs_ip: 10.1.1.100
    volumes:
      - name: boot
        size: 10
        image: Debian 10
      - name: data
        size: 20
```

Tested on :
- OVH Public Cloud
