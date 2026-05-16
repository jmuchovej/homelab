# /ip firewall nat
# /ip firewall connection tracking

locals {
  # Address-list contents — see resources below. RouterOS NAT
  # `src-address` is single-valued; multi-value matching requires the
  # `src-address-list` field, which accepts a named address-list (with
  # `!` prefix for negation).
  rfc1918-cidrs = toset(["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"])
}

resource "routeros_ip_firewall_addr_list" "rfc1918" {
  for_each = var.role == "router" ? local.rfc1918-cidrs : toset([])

  list    = "rfc1918"
  address = each.value
  comment = "defconf: RFC1918 private range"
}

resource "routeros_ip_firewall_addr_list" "mgmt_vlan" {
  count = var.role == "router" ? 1 : 0

  list    = "mgmt-vlan"
  address = local.vlans["mgmt"].cidr
  comment = "Management VLAN — exclude from hairpin so admin reaches router itself"
}

resource "routeros_ip_firewall_addr_list" "no_hairpin_dst" {
  for_each = var.role == "router" && var.enable-hairpin ? merge(
    { "wg-holonet" = {
      address = split("/", local.wg-holonet.address)[0]
      comment = "wg-holonet IP — keep mesh-bound admin traffic local"
    } },
    { for k, v in local.vlans : k => {
      address = v.gateway
      comment = "${v.comment} VLAN gateway — keep admin-bound traffic local"
    } },
  ) : {}

  list    = "no-hairpin-dst"
  address = each.value.address
  comment = each.value.comment
}

resource "routeros_ip_firewall_nat" "n01_masq_wan" {
  count = var.role == "router" ? 1 : 0

  action             = "masquerade"
  chain              = "srcnat"
  ipsec_policy       = "out,none"
  out_interface_list = routeros_interface_list.wan.name
  comment            = "defconf: masquerade"
}

resource "routeros_ip_firewall_nat" "n03_dnat_https_to_vip" {
  count      = var.role == "router" && var.enable-hairpin ? 1 : 0
  depends_on = [routeros_ip_firewall_addr_list.rfc1918]

  action           = "dst-nat"
  chain            = "dstnat"
  protocol         = "tcp"
  in_interface     = var.wan-port
  src_address_list = "!rfc1918" # exclude RFC1918 sources (see addr_list above)
  dst_port         = "443"
  to_addresses     = local.vip # bare IP is correct for to_addresses (target host)
  to_ports         = "443"
  log              = true
  log_prefix       = "[vip.ext]"
  comment          = "[ext] HTTPs to Traefik VIP"
}

resource "routeros_ip_firewall_nat" "n04_dnat_http_to_vip" {
  count      = var.role == "router" && var.enable-hairpin ? 1 : 0
  depends_on = [routeros_ip_firewall_addr_list.rfc1918]

  action           = "dst-nat"
  chain            = "dstnat"
  protocol         = "tcp"
  in_interface     = var.wan-port
  src_address_list = "!rfc1918"
  dst_port         = "80"
  to_addresses     = local.vip
  to_ports         = "80"
  log              = true
  log_prefix       = "[vip.ext]"
  comment          = "[ext] HTTP to Traefik VIP"
}

resource "routeros_ip_firewall_nat" "n09_hairpin_masq_replies" {
  count = var.role == "router" && var.enable-hairpin ? 1 : 0

  action = "masquerade"
  chain  = "srcnat"
  dst_address = local.vip
  src_address = local.lan-supernet
  comment     = "Hairpin masquerade so VIP replies via router"
}

resource "routeros_ip_firewall_nat" "n10_hairpin_local_dst_443" {
  count = var.role == "router" && var.enable-hairpin ? 1 : 0
  depends_on = [
    routeros_ip_firewall_addr_list.mgmt_vlan,
    routeros_ip_firewall_addr_list.no_hairpin_dst,
  ]

  action           = "dst-nat"
  chain            = "dstnat"
  protocol         = "tcp"
  dst_address_type = "local"
  dst_address_list = "!no-hairpin-dst" # don't catch traffic to wg-holonet IP
  dst_port         = "443"
  src_address      = local.lan-supernet # broad LAN match
  src_address_list = "!mgmt-vlan"       # but exclude mgmt — admin REST goes to router itself
  to_addresses     = local.vip
  to_ports         = "443"
  comment          = "Hairpin: LAN  WAN-IP:443  VIP"
}

resource "routeros_ip_firewall_nat" "n11_hairpin_local_dst_80" {
  count = var.role == "router" && var.enable-hairpin ? 1 : 0
  depends_on = [
    routeros_ip_firewall_addr_list.mgmt_vlan,
    routeros_ip_firewall_addr_list.no_hairpin_dst,
  ]

  action           = "dst-nat"
  chain            = "dstnat"
  protocol         = "tcp"
  dst_address_type = "local"
  dst_address_list = "!no-hairpin-dst"
  dst_port         = "80"
  src_address      = local.lan-supernet
  src_address_list = "!mgmt-vlan"
  to_addresses     = local.vip
  to_ports         = "80"
  comment          = "Hairpin: LAN  WAN-IP:80  VIP"
}

resource "routeros_ip_firewall_nat" "n12_hairpin_masq_client_src" {
  count = var.role == "router" && var.enable-hairpin ? 1 : 0

  action      = "masquerade"
  chain       = "srcnat"
  protocol    = "tcp"
  dst_address = local.vip
  dst_port    = "443,80"
  src_address = local.lan-supernet
  comment     = "Hairpin masquerade: rewrite client src so VIP replies via router"
}

resource "routeros_ip_firewall_connection_tracking" "this" {
  generic_timeout = "1m"
}
