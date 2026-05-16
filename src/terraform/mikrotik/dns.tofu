# /ip dns
# /ip dns static

resource "routeros_ip_dns" "this" {
  count = var.role == "router" ? 1 : 0

  allow_remote_requests = true
  servers               = [local.vip, "9.9.9.9", "1.1.1.1"]
  mdns_repeat_ifaces = concat(
    [for k, _ in local.vlans : routeros_interface_vlan.vlan[k].name],
    [for k, _ in var.wifi : routeros_wifi.this[k].name],
  )
}

# ─── Sibling-relay static records (router-only) ──────────────────────────
resource "routeros_ip_dns_record" "sibling-relay" {
  for_each = var.role == "router" ? local.holonet-sibling-mgmt-ips : {}

  type    = "A"
  name    = "${each.key}.holonet.jm0.io"
  address = each.value
  comment = "tofu: sibling relay"
}

resource "routeros_ip_dns_record" "dc-vip-split-horizon" {
  count = var.role == "router" ? 1 : 0

  type            = "A"
  name            = "${local.dc}.${var.catalog.root-domain}"
  address         = var.catalog.vip
  match_subdomain = true
  comment         = "split-horizon: *.${local.dc}.${var.catalog.root-domain} → VIP"
}
