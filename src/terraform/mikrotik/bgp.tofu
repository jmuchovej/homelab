variable "bgp" {
  type = object({
    asn          = number
    lb-pool-cidr = string
    peers        = map(string) # node name → lab IP
  })
  default     = null
  description = <<-EOT
    K8s LoadBalancer BGP. Set only on the cluster's relay; null disables.
      asn          = iBGP AS, both ends (e.g. 64512)
      lb-pool-cidr = CiliumLoadBalancerIPPool CIDR (e.g. 10.69.1.0/24)
      peers        = { "<node>" = "<lab IP>" }  — one iBGP session each
  EOT
}

locals {
  bgp-enabled = local.is-router && var.bgp != null
}

# Accept only the advertised LB pool from the peer; reject everything else.
resource "routeros_routing_filter_rule" "k8s-lb" {
  count = local.bgp-enabled ? 1 : 0

  chain   = "k8s-loadbalancer-ips"
  rule    = "if (dst in ${var.bgp.lb-pool-cidr}) { accept } else { reject }"
  comment = "K8s LoadBalancer pool"
}

# Shared settings for every node peer.
resource "routeros_routing_bgp_template" "k8s" {
  count = local.bgp-enabled ? 1 : 0

  name             = "k8s"
  as               = tostring(var.bgp.asn)
  routing_table    = "main"
  address_families = "ip"
  nexthop_choice   = "force-self"
  comment          = "K8s"

  keepalive_time = "30s"
  hold_time      = "1m30s"

  input {
    filter = routeros_routing_filter_rule.k8s-lb[0].chain
  }
  output {
    default_originate = "always"
  }
}

resource "routeros_routing_bgp_instance" "k8s" {
  count = local.bgp-enabled ? 1 : 0

  name          = "k8s"
  as            = tostring(var.bgp.asn)
  routing_table = "main"
  comment       = "K8s"
}

# One iBGP session per cluster node.
resource "routeros_routing_bgp_connection" "k8s" {
  for_each = local.bgp-enabled ? var.bgp.peers : {}

  name             = "bgp-${each.key}"
  comment          = each.key
  instance         = routeros_routing_bgp_instance.k8s[0].name
  as               = tostring(var.bgp.asn)
  routing_table    = "main"
  address_families = "ip"
  nexthop_choice   = "force-self"
  templates        = [routeros_routing_bgp_template.k8s[0].name]

  keepalive_time = "30s"
  hold_time      = "1m30s"

  local {
    role = "ibgp"
  }
  remote {
    address = each.value
  }
  output {
    default_originate = "always"
  }

  lifecycle {
    ignore_changes = [input]
  }
}
