# /ip firewall filter
# /ipv6 firewall filter
# /ipv6 firewall address-list
#
locals {
  router-filter = var.role == "router"
}

resource "routeros_ip_firewall_filter" "r01_input_established" {
  action           = "accept"
  chain            = "input"
  connection_state = "established,related,untracked"
  comment          = "defconf: accept established,related,untracked"
}

resource "routeros_ip_firewall_filter" "fwd_vlans_to_wan" {
  count = local.router-filter ? 1 : 0

  action             = "accept"
  chain              = "forward"
  src_address_list   = "vlan-cidrs"
  out_interface_list = routeros_interface_list.wan.name
  comment            = "Allow vlan-cidrs to reach WAN"

  depends_on = [routeros_ip_firewall_addr_list.vlan_cidrs]
}

resource "routeros_ip_firewall_filter" "r08_input_drop_invalid" {
  action           = "drop"
  chain            = "input"
  connection_state = "invalid"
  comment          = "defconf: drop invalid"
}

resource "routeros_ip_firewall_filter" "r09_input_icmp" {
  action   = "accept"
  chain    = "input"
  protocol = "icmp"
  comment  = "defconf: accept ICMP"
}

resource "routeros_ip_firewall_filter" "r10_input_loopback_capsman" {
  action      = "accept"
  chain       = "input"
  dst_address = "127.0.0.1"
  comment     = "defconf: accept to local loopback (for CAPsMAN)"
}

resource "routeros_ip_firewall_filter" "r11_input_drop_not_lan" {
  action            = "drop"
  chain             = "input"
  in_interface_list = "!${routeros_interface_list.lan.name}"
  comment           = "defconf: drop all not coming from LAN"
}

resource "routeros_ip_firewall_filter" "r12_fwd_ipsec_in" {
  count = local.router-filter ? 1 : 0

  action       = "accept"
  chain        = "forward"
  ipsec_policy = "in,ipsec"
  comment      = "defconf: accept in ipsec policy"
}

resource "routeros_ip_firewall_filter" "r13_fwd_ipsec_out" {
  count = local.router-filter ? 1 : 0

  action       = "accept"
  chain        = "forward"
  ipsec_policy = "out,ipsec"
  comment      = "defconf: accept out ipsec policy"
}

resource "routeros_ip_firewall_filter" "r14_fwd_fasttrack" {
  count = local.router-filter ? 1 : 0

  action           = "fasttrack-connection"
  chain            = "forward"
  connection_state = "established,related"
  hw_offload       = true
  comment          = "defconf: fasttrack"
}

resource "routeros_ip_firewall_filter" "r15_fwd_established" {
  count = local.router-filter ? 1 : 0

  action           = "accept"
  chain            = "forward"
  connection_state = "established,related,untracked"
  comment          = "defconf: accept established,related, untracked"
}

resource "routeros_ip_firewall_filter" "r16_fwd_drop_invalid" {
  count = local.router-filter ? 1 : 0

  action           = "drop"
  chain            = "forward"
  connection_state = "invalid"
  comment          = "defconf: drop invalid"
}

resource "routeros_ip_firewall_filter" "r17_fwd_drop_wan_no_dstnat" {
  count = local.router-filter ? 1 : 0

  action               = "drop"
  chain                = "forward"
  connection_nat_state = "!dstnat"
  connection_state     = "new"
  in_interface_list    = routeros_interface_list.wan.name
  comment              = "defconf: drop all from WAN not DSTNATed"
}

resource "routeros_ip_firewall_addr_list" "vlan_cidrs" {
  for_each = local.vlans

  list    = "vlan-cidrs"
  address = each.value.cidr
  comment = each.value.comment
}

resource "routeros_ip_firewall_filter" "input_dns_allow" {
  for_each = local.router-filter ? toset(["udp", "tcp"]) : toset([])

  action           = "accept"
  chain            = "input"
  dst_port         = "53"
  protocol         = each.value
  src_address_list = "vlan-cidrs"
  comment          = "Allow vlan-cidrs to query DNS (${upper(each.value)})"

  depends_on = [routeros_ip_firewall_addr_list.vlan_cidrs]
}

resource "routeros_ip_firewall_filter" "r33_fwd_mgmt_to_homelab_dns_udp" {
  count = local.router-filter ? 1 : 0

  action      = "accept"
  chain       = "forward"
  src_address = local.vlans["mgmt"].cidr
  dst_address = local.vip
  dst_port    = "53"
  protocol    = "udp"
  comment     = "Allow Management VLAN to query Homelab DNS (VIP)"
}

resource "routeros_ip_firewall_filter" "r34_fwd_mgmt_to_homelab_dns_tcp" {
  count = local.router-filter ? 1 : 0

  action      = "accept"
  chain       = "forward"
  src_address = local.vlans["mgmt"].cidr
  dst_address = local.vip
  dst_port    = "53"
  protocol    = "tcp"
  comment     = "Allow Management VLAN to query Homelab DNS (VIP)"
}

# ─── VIP access from VLAN clients ────────────────────────────────────────
resource "routeros_ip_firewall_filter" "fwd_drop_iot_to_vip" {
  count = local.router-filter && contains(keys(local.vlans), "iot") ? 1 : 0

  action      = "drop"
  chain       = "forward"
  src_address = local.vlans["iot"].cidr
  dst_address = local.vip
  comment     = "Drop IoT → VIP (cloud-only, no internal services)"
}

resource "routeros_ip_firewall_filter" "fwd_vlans_to_vip" {
  count = local.router-filter ? 1 : 0

  action           = "accept"
  chain            = "forward"
  protocol         = "tcp"
  src_address_list = "vlan-cidrs"
  dst_address      = local.vip
  dst_port         = "80,443"
  comment          = "Allow vlan-cidrs to reach VIP (HTTP/HTTPS)"

  depends_on = [routeros_ip_firewall_addr_list.vlan_cidrs]
}

resource "routeros_ip_firewall_filter" "r39_fwd_guest_to_plex" {
  count = local.router-filter ? 1 : 0

  action      = "accept"
  chain       = "forward"
  src_address = local.vlans["guest"].cidr
  dst_address = local.vlans["lab"].cidr
  dst_port    = "32400"
  protocol    = "tcp"
  comment     = "Allow Guest to reach Plex"
}

resource "routeros_ip_firewall_filter" "r40_fwd_guest_to_hass" {
  count = local.router-filter ? 1 : 0

  action      = "accept"
  chain       = "forward"
  src_address = local.vlans["guest"].cidr
  dst_address = local.vlans["lab"].cidr
  dst_port    = "8123"
  protocol    = "tcp"
  comment     = "Allow Guest to reach Home Assistant"
}

resource "routeros_ip_firewall_filter" "r41_fwd_mgmt_to_hass" {
  count = local.router-filter ? 1 : 0

  action      = "accept"
  chain       = "forward"
  src_address = local.vlans["mgmt"].cidr
  dst_address = local.vlans["lab"].cidr
  dst_port    = "8123"
  protocol    = "tcp"
  comment     = "Allow Management VLAN to reach Home Assistant"
}

resource "routeros_ip_firewall_filter" "r43_input_block_wan_tcp" {
  count = local.router-filter ? 1 : 0

  action       = "drop"
  chain        = "input"
  in_interface = var.wan-port
  protocol     = "tcp"
  dst_port     = "22,80,443,8291,8728,8729"
  comment      = "Block WAN access to router"
}

resource "routeros_ip_firewall_filter" "r44_input_block_wan_dns" {
  count = local.router-filter ? 1 : 0

  action       = "drop"
  chain        = "input"
  in_interface = var.wan-port
  protocol     = "udp"
  dst_port     = "53"
  comment      = "Block WAN DNS queries"
}

resource "routeros_ip_firewall_filter" "r45_input_drop_wan_other" {
  count = local.router-filter ? 1 : 0

  action       = "drop"
  chain        = "input"
  in_interface = var.wan-port
  comment      = "Drop all other WAN->router"
}

resource "routeros_ip_firewall_filter" "r46_input_accept_lan" {
  action            = "accept"
  chain             = "input"
  in_interface_list = routeros_interface_list.lan.name
}

locals {
  bad_ipv6 = {
    unspec     = { addr = "::/128", comment = "defconf: unspecified address" }
    loopback   = { addr = "::1/128", comment = "defconf: lo" }
    site_local = { addr = "fec0::/10", comment = "defconf: site-local" }
    v4_mapped  = { addr = "::ffff:0.0.0.0/96", comment = "defconf: ipv4-mapped" }
    v4_compat  = { addr = "::/96", comment = "defconf: ipv4 compat" }
    discard    = { addr = "100::/64", comment = "defconf: discard only " }
    doc        = { addr = "2001:db8::/32", comment = "defconf: documentation" }
    orchid     = { addr = "2001:10::/28", comment = "defconf: ORCHID" }
    six_bone   = { addr = "3ffe::/16", comment = "defconf: 6bone" }
  }
}

resource "routeros_ipv6_firewall_addr_list" "bad" {
  for_each = local.router-filter ? local.bad_ipv6 : {}

  list    = "bad_ipv6"
  address = each.value.addr
  comment = each.value.comment
}

locals {
  v6_filter_rules = [
    # ── first block ─────────────────────────────────────────────────────
    { id = "v01", chain = "input", action = "accept", connection_state = "established,related,untracked", comment = "defconf: accept established,related,untracked" },
    { id = "v02", chain = "input", action = "drop", connection_state = "invalid", comment = "defconf: drop invalid" },
    { id = "v03", chain = "input", action = "accept", protocol = "icmpv6", comment = "defconf: accept ICMPv6" },
    { id = "v04", chain = "input", action = "accept", protocol = "udp", dst_port = "33434-33534", comment = "defconf: accept UDP traceroute" },
    { id = "v05", chain = "input", action = "accept", protocol = "udp", dst_port = "546", src_address = "fe80::/10", comment = "defconf: accept DHCPv6-Client prefix delegation." },
    { id = "v06", chain = "input", action = "accept", protocol = "udp", dst_port = "500,4500", comment = "defconf: accept IKE" },
    { id = "v07", chain = "input", action = "accept", protocol = "ipsec-ah", comment = "defconf: accept ipsec AH" },
    { id = "v08", chain = "input", action = "accept", protocol = "ipsec-esp", comment = "defconf: accept ipsec ESP" },
    { id = "v09", chain = "input", action = "accept", ipsec_policy = "in,ipsec", comment = "defconf: accept all that matches ipsec policy" },
    { id = "v10", chain = "input", action = "drop", in_interface_list = "!LAN", comment = "defconf: drop everything else not coming from LAN" },
    { id = "v11", chain = "forward", action = "fasttrack-connection", connection_state = "established,related", comment = "defconf: fasttrack6" },
    { id = "v12", chain = "forward", action = "accept", connection_state = "established,related,untracked", comment = "defconf: accept established,related,untracked" },
    { id = "v13", chain = "forward", action = "drop", connection_state = "invalid", comment = "defconf: drop invalid" },
    { id = "v14", chain = "forward", action = "drop", src_address_list = "bad_ipv6", comment = "defconf: drop packets with bad src ipv6" },
    { id = "v15", chain = "forward", action = "drop", dst_address_list = "bad_ipv6", comment = "defconf: drop packets with bad dst ipv6" },
    { id = "v16", chain = "forward", action = "drop", hop_limit = "equal:1", protocol = "icmpv6", comment = "defconf: rfc4890 drop hop-limit=1" },
    { id = "v17", chain = "forward", action = "accept", protocol = "icmpv6", comment = "defconf: accept ICMPv6" },
    { id = "v18", chain = "forward", action = "accept", protocol = "139", comment = "defconf: accept HIP" },
    { id = "v19", chain = "forward", action = "accept", protocol = "udp", dst_port = "500,4500", comment = "defconf: accept IKE" },
    { id = "v20", chain = "forward", action = "accept", protocol = "ipsec-ah", comment = "defconf: accept ipsec AH" },
    { id = "v21", chain = "forward", action = "accept", protocol = "ipsec-esp", comment = "defconf: accept ipsec ESP" },
    { id = "v22", chain = "forward", action = "accept", ipsec_policy = "in,ipsec", comment = "defconf: accept all that matches ipsec policy" },
    { id = "v23", chain = "forward", action = "drop", in_interface_list = "!LAN", comment = "defconf: drop everything else not coming from LAN" },
  ]
}

resource "routeros_ipv6_firewall_filter" "rule" {
  for_each = local.router-filter ? { for r in local.v6_filter_rules : r.id => r } : {}

  chain             = each.value.chain
  action            = each.value.action
  comment           = each.value.comment
  connection_state  = try(each.value.connection_state, null)
  protocol          = try(each.value.protocol, null)
  dst_port          = try(each.value.dst_port, null)
  src_address       = try(each.value.src_address, null)
  src_address_list  = try(each.value.src_address_list, null)
  dst_address_list  = try(each.value.dst_address_list, null)
  in_interface_list = try(each.value.in_interface_list, null)
  ipsec_policy      = try(each.value.ipsec_policy, null)
  hop_limit         = try(each.value.hop_limit, null)
}

locals {
  ipv4-filter-order = local.router-filter ? concat(
    [routeros_ip_firewall_filter.r01_input_established.id],
    [routeros_ip_firewall_filter.fwd_vlans_to_wan[0].id],
    [
      routeros_ip_firewall_filter.r08_input_drop_invalid.id,
      routeros_ip_firewall_filter.r09_input_icmp.id,
      routeros_ip_firewall_filter.r10_input_loopback_capsman.id,
      # input_dns_allow MUST precede r11 (drop !LAN), otherwise lab/
      # trusted/guest/iot DNS queries to the router get dropped before
      # this rule can accept them — those VLANs are members of the
      # `VLAN` interface-list, not `LAN`, so r11's `!LAN` predicate
      # catches them.
      routeros_ip_firewall_filter.input_dns_allow["udp"].id,
      routeros_ip_firewall_filter.input_dns_allow["tcp"].id,
    ],
    var.role == "router" ? [routeros_ip_firewall_filter.input_accept_holonet[0].id] : [],
    [
      routeros_ip_firewall_filter.r11_input_drop_not_lan.id,
      routeros_ip_firewall_filter.r12_fwd_ipsec_in[0].id,
      routeros_ip_firewall_filter.r13_fwd_ipsec_out[0].id,
      routeros_ip_firewall_filter.r14_fwd_fasttrack[0].id,
      routeros_ip_firewall_filter.r15_fwd_established[0].id,
      routeros_ip_firewall_filter.r16_fwd_drop_invalid[0].id,
      routeros_ip_firewall_filter.r17_fwd_drop_wan_no_dstnat[0].id,
    ],
    [
      routeros_ip_firewall_filter.r33_fwd_mgmt_to_homelab_dns_udp[0].id,
      routeros_ip_firewall_filter.r34_fwd_mgmt_to_homelab_dns_tcp[0].id,
    ],
    # IoT drop MUST precede `fwd_vlans_to_vip` — same dst but more
    # specific source, otherwise iot would be accepted by the broad rule.
    contains(keys(local.vlans), "iot") ? [routeros_ip_firewall_filter.fwd_drop_iot_to_vip[0].id] : [],
    [
      routeros_ip_firewall_filter.fwd_vlans_to_vip[0].id,
      routeros_ip_firewall_filter.r39_fwd_guest_to_plex[0].id,
      routeros_ip_firewall_filter.r40_fwd_guest_to_hass[0].id,
      routeros_ip_firewall_filter.r41_fwd_mgmt_to_hass[0].id,
    ],
    [
      routeros_ip_firewall_filter.r43_input_block_wan_tcp[0].id,
      routeros_ip_firewall_filter.r44_input_block_wan_dns[0].id,
      routeros_ip_firewall_filter.r45_input_drop_wan_other[0].id,
      routeros_ip_firewall_filter.r46_input_accept_lan.id,
    ],
  ) : []

  # IPv6: list-shaped source, so preserving the original ordering is trivial.
  ipv6-filter-order = local.router-filter ? [
    for r in local.v6_filter_rules : routeros_ipv6_firewall_filter.rule[r.id].id
  ] : []
}

resource "routeros_move_items" "ipv4_filter" {
  count = local.router-filter ? 1 : 0

  resource_path = "/ip/firewall/filter"
  sequence      = local.ipv4-filter-order
}

resource "routeros_move_items" "ipv6_filter" {
  count = local.router-filter ? 1 : 0

  resource_path = "/ipv6/firewall/filter"
  sequence      = local.ipv6-filter-order
}
