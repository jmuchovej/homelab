provider "zerotier" {
  zerotier_central_token = data.sops_file.secrets.data["zerotier.token"]
}

import {
  to = zerotier_network.holonet
  id = local.topology.zerotier.network
}

resource "zerotier_network" "holonet" {
  name        = "holonet"
  description = "Holonet Backbone: Managed by OpenTofu"

  private = true

  assign_ipv4 {
    zerotier = false
  }

  assign_ipv6 {
    zerotier = false
    rfc4193  = true
    sixplane = false
  }

  route {
    target = local.topology.zerotier.overlay
  }

  # Each DC's lab reachable from every member via that DC's relay01. Without
  # these, ZeroTier carries only the overlay itself, so cross-site traffic can
  # address nothing but node overlay IPs — no LoadBalancer VIPs, no NAS, no
  # non-k8s devices. Relies on the labs being unique per site.
  dynamic "route" {
    for_each = local.lab-routes

    content {
      target = route.value.target
      via    = route.value.via
    }
  }

  flow_rules = <<-EOT
    #
    # Default rule set: allow IPv4/IPv6/ARP, otherwise behave like a standard
    # Ethernet switch. https://docs.zerotier.com/rules/
    #
    drop
      not ethertype ipv4
      and not ethertype arp
      and not ethertype ipv6
    ;
    accept;
  EOT
}

resource "zerotier_member" "clients" {
  for_each = {
    for name, c in local.topology.clients : name => c
    if try(c.zerotier, null) != null
  }

  network_id         = zerotier_network.holonet.id
  member_id          = each.value.zerotier
  name               = each.key
  authorized         = true
  no_auto_assign_ips = true
  ip_assignments     = [each.value.ip]
}
