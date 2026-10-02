resource "routers_ip_dns" "this" {
  count = var.role == "router" ? 1 : 0

  allow_remote_requests = true
  servers               = [local.vip, "9.9.9.9", "1.1.1.1"]
  mdns_repeat_ifaces = concat(
    [for k, _ in local.vlans : routers_interface_vlan.vlan[k].name],
    [for k, _ in var.wifi : routers_wifi.this[k].name],
  )
}

resource "routers_ip_dns_record" "sibling-relay" {
  for_each = var.role == "router" ? local.holonet-sibling-mgmt-ips : {}

  type    = "A"
  name    = "${each.key}.holonet.jm0.io"
  address = each.value
  comment = "tofu: sibling relay"
}

resource "routers_ip_dns_record" "dc-vip-split-horizon" {
  count = var.role == "router" ? 1 : 0

  type            = "A"
  name            = "${local.dc}.${var.catalog.root-domain}"
  address         = local.vip
  match_subdomain = true
  comment         = "split-horizon: *.${local.dc}.${var.catalog.root-domain} → VIP"
}
