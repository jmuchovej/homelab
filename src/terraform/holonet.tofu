data "sops_file" "topology" {
  source_file = "${path.root}/secrets/topology.sops.yaml"
}

locals {
  topology = yamldecode(file("${path.root}/topology.yaml"))

  vlans = local.topology.vlans

  # ─── Catalog — invariants for the main mikrotik module ──────────────
  catalog = {
    vlans        = local.vlans
    vip          = "10.69.1.1"
    lan-supernet = "10.0.0.0/8"

    holonet-subnets = local.topology.subnets

    holonet-wg-config-for = local.holonet-wg-config-for

    holonet-mgmt-ip-for = local.holonet-peer-mgmt-ip

    root-domain = local.domain.root

    certificates = {
      holonet = {
        crt = data.sops_file.topology.data["holonet.crt"]
        key = data.sops_file.topology.data["holonet.key"]
      }
    }
  }

  mgmt-base = join(".", slice(split(".", cidrhost(local.vlans.mgmt.cidr, 0)), 0, 3))

  holonet = {
    port    = local.topology.listen-port
    subnets = local.topology.subnets

    relays = {
      for relay-key, relay in local.topology.network : relay-key => {
        ip     = relay.ip
        pubkey = relay.public
        ddns   = relay.ddns
      }
    }

    clients = {
      for client-key, client in local.topology.clients : client-key => {
        ip     = client.ip
        pubkey = try(client.public, null)
      }
    }
  }

  holonet-is-public-routable = {
    for k, _ in local.topology.network : k => endswith(k, "-relay01")
  }

  holonet-client-home-relay = {
    for cname, _ in local.topology.clients : cname =>
    "${split("-", cname)[0]}-relay01"
  }

  holonet-is-clients-gateway = {
    for rk, _ in local.topology.network : rk =>
    contains(values(local.holonet-client-home-relay), rk)
  }

  holonet-mgmt-base = join(".", slice(split(".", cidrhost(local.vlans.mgmt.cidr, 0)), 0, 3))

  holonet-peer-mgmt-ip = {
    for k, _ in local.topology.network : k =>
    format("%s.%d", local.mgmt-base, tonumber(regex("[0-9]+$", k)))
  }

  holonet-wg-config-for = {
    for relay-key, _ in local.topology.network : relay-key => {
      address     = "${local.topology.network[relay-key].ip}/24"
      private-key = data.sops_file.topology.data["network.${relay-key}"]
      listen-port = local.topology.listen-port

      peers = merge(
        {
          for peer-key, peer in local.topology.network : peer-key => {
            public-key = peer.public
            allowed-address = local.holonet-is-clients-gateway[peer-key] ? (
              "${peer.ip}/32,${local.topology.subnets.clients}"
              ) : (
              "${peer.ip}/32"
            )
            endpoint-address = (
              split("-", peer-key)[0] == split("-", relay-key)[0] ? local.holonet-peer-mgmt-ip[peer-key] :
              local.holonet-is-public-routable[peer-key] ? peer.ddns :
              null
            )

            endpoint-port = (
              split("-", peer-key)[0] == split("-", relay-key)[0] ||
              local.holonet-is-public-routable[peer-key]
            ) ? local.topology.listen-port : null

            persistent-keepalive = (
              split("-", peer-key)[0] == split("-", relay-key)[0] ||
              local.holonet-is-public-routable[peer-key]
            ) ? "25s" : "0s"
            comment = "wg-holonet: peer ${peer-key}"
          } if peer-key != relay-key && peer.public != null
        },
        local.holonet-is-public-routable[relay-key] ? {
          for cname, client in local.topology.clients : cname => {
            public-key           = client.public
            allowed-address      = "${client.ip}/32"
            endpoint-address     = null
            endpoint-port        = null
            persistent-keepalive = "0s"
            comment              = "wg-holonet: client ${cname}"
          } if try(client.public, null) != null
        } : {}
      )

      routes = toset([
        for sk, sv in local.topology.subnets :
        sv if !startswith(relay-key, sk)
      ])
    }
  }
}

resource "cloudflare_dns_record" "holonet" {
  for_each = { for k, r in local.topology.network : k => r.ip }

  zone_id = data.cloudflare_zone.domain.id
  name    = "${each.key}.holonet"
  type    = "A"
  content = each.value
  ttl     = 300
  proxied = false # private IPs can't be proxied
  comment = "wg-holonet: ${each.key}"

  depends_on = [
    module.da-relay01,
    module.da-relay02,
    module.en-relay01,
  ]
}
