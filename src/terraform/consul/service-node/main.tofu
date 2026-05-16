terraform {
  required_providers {
    consul = { source = "hashicorp/consul" }
  }
}

locals {
  node = coalesce(var.node, var.name)
  rtr  = "traefik.http.routers.${var.name}"
  svc  = "traefik.http.services.${var.name}"

  tags = concat(
    [
      "traefik.enable=true",

      ## Main router — Host-matched, gated by authentik forward-auth.
      ## NOTE: explicit `priority=10` is REQUIRED. Without it, traefik
      ## auto-calculates priority from rule length, which can exceed the
      ## bypass router's 15 and starve it. Mirrors `mk-traefik-service`.
      "${local.rtr}.entryPoints=websecure",
      "${local.rtr}.middlewares=authentik@file",
      "${local.rtr}.rule=Host(`${var.host}`)",
      "${local.rtr}.service=${var.name}",
      "${local.rtr}.tls.certResolver=letsencrypt",
      "${local.rtr}.priority=10",

      ## Auth-bypass router — higher priority. Handles the outpost's callback
      ## paths (`/outpost.goauthentik.io/*`) WITHOUT the forward-auth middleware,
      ## so the OAuth callback isn't itself auth-checked (which would kick off a
      ## second `/authorize` with a fresh `state` and 400 on mismatch).
      "${local.rtr}-auth.entryPoints=websecure",
      "${local.rtr}-auth.rule=Host(`${var.host}`) && PathPrefix(`/outpost.goauthentik.io/`)",
      "${local.rtr}-auth.service=authentik@file",
      "${local.rtr}-auth.tls.certResolver=letsencrypt",
      "${local.rtr}-auth.priority=15",

      "${local.svc}.loadBalancer.server.port=${var.port}",
    ],
    var.scheme == "https" ? ["${local.svc}.loadBalancer.server.scheme=https"] : [],
    var.servers-transport != null ? ["${local.svc}.loadBalancer.serversTransport=${var.servers-transport}"] : [],
    var.authentik.name != null ? ["authentik.name=${var.authentik.name}"] : [],
    [
      "authentik.enable=true",
      "authentik.group=${var.authentik.group}",
      "authentik.type=${var.authentik.type}",
      "authentik.url.int=https://${var.host}",
      "authentik.url.ext=https://${var.host}",
      "authentik.icon=${var.authentik.icon}",
      "authentik.access=${var.authentik.access}",
    ],
    var.authentik.skip-paths != null ? ["authentik.skip-paths=${var.authentik.skip-paths}"] : [],
  )
}

## External node — these devices (mikrotik relays, hubitat) run no Consul
## agent, so we register them in the catalog as their own node at the device
## IP, mirroring the `address` field of the old `src/consul/da/*.hcl` defs.
resource "consul_node" "this" {
  name    = local.node
  address = var.address

  ## Marks this as an agentless external node so consul-esm claims it and
  ## actively runs the service checks below (the catalog can't self-check —
  ## no agent lives on these devices). ESM filters on this exact meta key.
  meta = {
    external-node = "true"
  }
}

resource "consul_service" "this" {
  name    = var.name
  node    = consul_node.this.name
  address = var.address
  port    = var.port
  tags    = local.tags

  check {
    check_id = "service:${var.name}"
    name     = coalesce(var.check.name, "${var.name} service check")
    http     = var.check.type == "http" ? "http://${var.address}${var.check.path}" : null
    tcp      = var.check.type == "tcp" ? "${var.address}:${var.port}" : null
    method   = var.check.type == "http" ? "GET" : null
    interval = var.check.interval
    timeout  = var.check.timeout
  }
}
