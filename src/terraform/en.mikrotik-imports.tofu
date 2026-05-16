# --- Relay01 --------------------------------------------------------------------------
import {
  to = module.en-relay01.routeros_system_user_group.terraform
  id = "name=terraform"
}

import {
  to = module.en-relay01.routeros_system_user.terraform
  id = "name=terraform"
}

import {
  to = module.en-relay01.routeros_system_certificate.wan[0]
  id = "name=holonet"
}

import {
  to = module.en-relay01.routeros_interface_list.wan
  id = "name=WAN"
}

import {
  to = module.en-relay01.routeros_interface_list.lan
  id = "name=LAN"
}

import {
  to = module.en-relay01.routeros_interface_bridge.bridge
  id = "name=bridge"
}

import {
  to = module.en-relay01.routeros_interface_vlan.vlan["mgmt"]
  id = "name=mgmt"
}

import {
  to = module.en-relay01.routeros_ip_address.vlan_primary["mgmt"]
  id = "address=10.42.0.1/24"
}

import {
  to = module.en-relay01.routeros_interface_bridge_vlan.vlan["mgmt"]
  id = "vlan-ids=42"
}

import {
  to = module.en-relay01.routeros_ip_pool.vlan["mgmt"]
  id = "name=pool-mgmt"
}

import {
  to = module.en-relay01.routeros_ip_dhcp_server.vlan["mgmt"]
  id = "name=dhcp-mgmt"
}

import {
  to = module.en-relay01.routeros_ip_dhcp_server_network.vlan["mgmt"]
  id = "address=10.42.0.0/24"
}

import {
  to = module.en-relay01.routeros_ip_dhcp_client.wan[0]
  id = "interface=ether1"
}

import {
  for_each = local.en-ports.relay01
  to       = module.en-relay01.routeros_interface_bridge_port.port[each.key]
  id       = "interface=${each.key}"
}

# ssh admin@10.42.0.1 '/interface/list/member/print'
import {
  to = module.en-relay01.routeros_interface_list_member.bridge-in-lan
  id = "*1"
}

import {
  to = module.en-relay01.routeros_interface_list_member.wan-uplink
  id = "*2"
}

import {
  to = module.en-relay01.routeros_ip_firewall_filter.r01_input_established
  id = "*1"
}

import {
  to = module.en-relay01.routeros_ip_firewall_filter.r08_input_drop_invalid
  id = "*2"
}

import {
  to = module.en-relay01.routeros_ip_firewall_filter.r09_input_icmp
  id = "*3"
}

import {
  to = module.en-relay01.routeros_ip_firewall_filter.r11_input_drop_not_lan
  id = "*4"
}
