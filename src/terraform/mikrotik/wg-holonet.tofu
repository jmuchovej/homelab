resource "routeros_interface_wireguard" "holonet" {
  name        = "wg-holonet"
  listen_port = local.wg-holonet.listen-port
  mtu         = "1420"
  private_key = local.wg-holonet.private-key
  disabled    = true # dormant; ZeroTier is the holonet transport (see header)
  comment     = "wg-holonet"
}

# ─── IP address bound to the WG interface ────────────────────────────────
resource "routeros_ip_address" "holonet" {
  address   = local.wg-holonet.address
  interface = routeros_interface_wireguard.holonet.name
  network   = cidrhost(local.wg-holonet.address, 0)
  comment   = "wg: wg-holonet"
}

# ─── LAN list membership ─────────────────────────────────────────────────
resource "routeros_interface_list_member" "holonet_in_lan" {
  list      = routeros_interface_list.lan.name
  interface = routeros_interface_wireguard.holonet.name
  comment   = "wg: wg-holonet"
}

# ─── Peers ───────────────────────────────────────────────────────────────
resource "routeros_interface_wireguard_peer" "holonet" {
  for_each = nonsensitive(local.wg-holonet.peers)

  interface  = routeros_interface_wireguard.holonet.name
  name       = each.key
  public_key = each.value.public-key
  allowed_address  = split(",", each.value.allowed-address)
  endpoint_address = each.value.endpoint-address
  endpoint_port    = each.value.endpoint-port
  persistent_keepalive = each.value.persistent-keepalive == "0s" ? null : each.value.persistent-keepalive
  comment              = each.value.comment
}

# ─── Routes for transit subnets ──────────────────────────────────────────
resource "routeros_ip_route" "holonet" {
  for_each = nonsensitive(local.wg-holonet.routes)

  dst_address = each.value
  gateway     = routeros_interface_wireguard.holonet.name
  comment     = "wg-holonet"
}

# ─── Router-only: accept inbound WG on WAN ───────────────────────────────
resource "routeros_ip_firewall_filter" "input_accept_holonet" {
  count = var.role == "router" ? 1 : 0

  chain        = "input"
  action       = "accept"
  protocol     = "udp"
  in_interface = var.wan-port
  dst_port     = tostring(local.wg-holonet.listen-port)
  comment      = "Accept WG: wg-holonet (udp/${local.wg-holonet.listen-port})"
}
