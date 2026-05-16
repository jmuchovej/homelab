# /interface bridge
# /interface bridge port
# /interface bridge vlan

locals {
  port_pvids = {
    for name, p in var.ports : name => (
      p.role == "access" ? local.vlans[p.access].vlan_id : 1
    )
  }

  trunk_ports = [
    for name, p in var.ports :
    name if p.role == "trunk"
  ]
  access_ports = {
    for name, p in var.ports : name =>
    p.access if p.role == "access"
  }

  derived_bridge_vlans = {
    for vlan_key, v in local.vlans : vlan_key => {
      vid     = tostring(v.vlan_id)
      comment = v.comment
      tagged  = concat(["bridge"], local.trunk_ports)
      untagged = [
        for port_name, access_key in local.access_ports :
        port_name if access_key == vlan_key
      ]
    }
  }
}

resource "routeros_interface_bridge" "bridge" {
  name           = "bridge"
  admin_mac      = var.bridge-mac
  auto_mac       = false
  vlan_filtering = true
  comment        = "defconf"
}

resource "routeros_interface_bridge_port" "port" {
  for_each = var.ports

  bridge    = routeros_interface_bridge.bridge.name
  interface = each.key
  pvid      = local.port_pvids[each.key]
  comment   = coalesce(each.value.comment, "defconf")
}

# ─── Bridge VLAN table ────────────────────────────────────────────────────
resource "routeros_interface_bridge_vlan" "vlan" {
  for_each = local.derived_bridge_vlans

  bridge   = routeros_interface_bridge.bridge.name
  vlan_ids = [each.value.vid]
  tagged   = each.value.tagged
  untagged = length(each.value.untagged) > 0 ? each.value.untagged : null
  comment  = each.value.comment

  depends_on = [routeros_interface_bridge_port.port]
}
