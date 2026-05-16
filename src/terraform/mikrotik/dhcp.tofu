# /ip dhcp-server
# /ip dhcp-server lease
# /ip dhcp-server network
# /ip dhcp-client
# /ip cloud
# /ip cloud advanced
#
locals {
  is-router = var.role == "router"
}

# ─── DHCP servers (one per VLAN — routers only) ───────────────────────────
resource "routeros_ip_dhcp_server" "vlan" {
  for_each = local.is-router ? local.vlans : {}

  name         = "dhcp${each.value.id}"
  interface    = routeros_interface_vlan.vlan[each.key].name
  address_pool = routeros_ip_pool.vlan[each.key].name
  dynamic_lease_identifiers = "client-mac,client-id"
}

# ─── DHCP networks ────────────────────────────────────────────────────────
locals {
  vlan_dhcp_networks = (
    local.is-router
    ? {
      for k, v in local.vlans : k => {
        cidr       = v.cidr
        gateway    = v.gateway
        dns_server = v.gateway
      }
    }
    : {}
  )

  extra_dhcp_networks = (
    local.is-router
    ? {
      for k, v in var.extra-addrs : k => {
        cidr       = "${v.network}/${split("/", v.address)[1]}"
        gateway    = split("/", v.address)[0]
        dns_server = split("/", v.address)[0]
        comment    = try(v.comment, null)
      }
    }
    : {}
  )
}

resource "routeros_ip_dhcp_server_network" "vlan" {
  for_each = local.vlan_dhcp_networks

  address    = each.value.cidr
  gateway    = each.value.gateway
  dns_server = [each.value.dns_server]
  comment    = "${local.vlans[each.key].comment} DHCP"
}

resource "routeros_ip_dhcp_server_network" "extra" {
  for_each = local.extra_dhcp_networks

  address    = each.value.cidr
  gateway    = each.value.gateway
  dns_server = [each.value.dns_server]
  comment    = each.value.comment
}

# ─── DHCP static leases (router only) ─────────────────────────────────────
resource "routeros_ip_dhcp_server_lease" "static" {
  for_each = local.is-router ? var.static-leases : {}

  address     = each.value.address
  mac_address = each.value.mac-addr
  client_id   = each.value.client-id
  server      = each.value.server

  depends_on = [routeros_ip_dhcp_server.vlan]
}

# ─── DHCP client on WAN ───────────────────────────────────────────────────
resource "routeros_ip_dhcp_client" "wan" {
  count = local.is-router && var.enable-wan-dhcp ? 1 : 0

  interface    = var.wan-port
  use_peer_dns = false
  comment      = "defconf"
  # default_route_tables = ["main"]
}

# ─── IP Cloud (DDNS only — Back-to-Home VPN intentionally OFF) ───────────
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
