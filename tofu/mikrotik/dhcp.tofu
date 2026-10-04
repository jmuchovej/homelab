locals {
  is-router = var.role == "router"
}

resource "routeros_ip_dhcp_server" "vlan" {
  for_each = local.is-router ? local.vlans : {}

  name                      = "dhcp${each.value.id}"
  interface                 = routeros_interface_vlan.vlan[each.key].name
  address_pool              = routeros_ip_pool.vlan[each.key].name
  dynamic_lease_identifiers = "client-mac,client-id"
}

locals {
  vlan_dhcp_networks = local.is-router ? { for k, v in local.vlans : k => v.cidr } : {}

  extra_dhcp_networks = (
    local.is-router
    ? {
      for k, v in var.extra-addrs : k => {
        cidr    = "${v.network}/${split("/", v.address)[1]}"
        comment = try(v.comment, null)
      }
    }
    : {}
  )
}

# gateway/dns_server READ THE ADDRESS RESOURCE rather than the topology literal
# they're both derived from. Holding the same fact twice is what let a failed
# address update ship a DHCP scope pointing at a gateway that was never
# created, stranding every client on the VLAN; the reference also makes the
# dependency implicit, so a failure here skips instead of applying.
locals {
  vlan_gateway  = { for k, _ in local.vlan_dhcp_networks : k => split("/", routeros_ip_address.vlan_primary[k].address)[0] }
  extra_gateway = { for k, _ in local.extra_dhcp_networks : k => split("/", routeros_ip_address.extra[k].address)[0] }
}

resource "routeros_ip_dhcp_server_network" "vlan" {
  for_each = local.vlan_dhcp_networks

  address    = each.value
  gateway    = local.vlan_gateway[each.key]
  dns_server = [local.vlan_gateway[each.key]]
  comment    = "${local.vlans[each.key].comment} DHCP"
}

resource "routeros_ip_dhcp_server_network" "extra" {
  for_each = local.extra_dhcp_networks

  address    = each.value.cidr
  gateway    = local.extra_gateway[each.key]
  dns_server = [local.extra_gateway[each.key]]
  comment    = each.value.comment
}

resource "routeros_ip_dhcp_server_lease" "static" {
  for_each = local.is-router ? var.static-leases : {}

  address     = each.value.address
  mac_address = each.value.mac-addr
  client_id   = each.value.client-id
  server      = routeros_ip_dhcp_server.vlan[each.value.vlan].name
}

resource "routeros_ip_dhcp_client" "wan" {
  count = local.is-router && var.enable-wan-dhcp ? 1 : 0

  interface    = var.wan-port
  use_peer_dns = false
  comment      = "defconf"
  # default_route_tables = ["main"]
}

resource "routeros_ip_cloud" "this" {
  count = local.is-router && var.enable-ip-cloud ? 1 : 0

  ddns_enabled         = "yes"
  ddns_update_interval = "1d"
  back_to_home_vpn     = "revoked-and-disabled"
}

resource "routeros_ip_cloud_advanced" "this" {
  count = local.is-router && var.enable-ip-cloud ? 1 : 0

  use_local_address = true
}
