# /interface vlan
# /interface list
# /interface list member
# /ip address
# /ip pool

locals {
  relay-counter = tonumber(regex("[0-9]+$", var.relay))

  vlan-interfaces = local.vlans

  vlan-mask-bits = { for k, v in local.vlans : k => split("/", v.cidr)[1] }

  vlan-ip-assignments = merge(
    {
      mgmt = {
        address = local.mgmt-ip
        network = cidrhost(local.mgmt-ip, 0)
      }
    },
    {
      for k, v in local.vlans : k => {
        address = (
          var.role == "router"
          ? "${v.gateway}/${local.vlan-mask-bits[k]}"
          : "${cidrhost(v.cidr, local.relay-counter)}/${local.vlan-mask-bits[k]}"
        )
        network = cidrhost(v.cidr, 0)
      } if k != "mgmt"
    }
  )
}

resource "routeros_interface_vlan" "vlan" {
  for_each = local.vlan-interfaces

  interface = routeros_interface_bridge.bridge.name
  name      = each.value.name
  vlan_id   = each.value.vlan_id
  comment   = each.value.comment
}

# ─── Interface lists ──────────────────────────────────────────────────────
resource "routeros_interface_list" "wan" {
  name    = "WAN"
  comment = "defconf"
}

resource "routeros_interface_list" "vlan" {
  name = "VLAN"
}

resource "routeros_interface_list" "lan" {
  name = "LAN"
  comment = "defconf"

  lifecycle {
    ignore_changes = [exclude]
  }
}

# ─── Interface list members ───────────────────────────────────────────────
resource "routeros_interface_list_member" "bridge-in-lan" {
  list      = routeros_interface_list.lan.name
  interface = routeros_interface_bridge.bridge.name
  comment   = "defconf"
}

resource "routeros_interface_list_member" "wan-uplink" {
  list      = routeros_interface_list.wan.name
  interface = var.wan-port
  comment   = "defconf"
}

resource "routeros_interface_list_member" "vlan-members" {
  for_each = local.vlan-interfaces

  list      = routeros_interface_list.vlan.name
  interface = routeros_interface_vlan.vlan[each.key].name
}

# ─── IP pools (router only — switches don't run DHCP) ────────────────────
resource "routeros_ip_pool" "vlan" {
  for_each = var.role == "router" ? local.vlans : {}

  name    = "pool${each.value.id}"
  ranges  = each.value.ranges
  comment = each.value.comment
}

# ─── IP addresses (router L3 interfaces) ──────────────────────────────────
resource "routeros_ip_address" "vlan_primary" {
  for_each = local.vlan-ip-assignments

  address   = each.value.address
  interface = routeros_interface_vlan.vlan[each.key].name
  network   = each.value.network
  comment   = local.vlans[each.key].comment
}

# Extra addresses (secondary IPs, bridges, etc.).
resource "routeros_ip_address" "extra" {
  for_each = var.extra-addrs

  address   = each.value.address
  interface = each.value.interface
  network   = each.value.network
  comment   = each.value.comment
}
