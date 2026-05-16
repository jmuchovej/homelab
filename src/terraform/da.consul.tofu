provider "consul" {
  alias      = "da"
  address    = "https://consul.${local.domain.da}"
  datacenter = "da"
  token      = data.sops_file.da.data["consul.token"]
}

data "consul_services" "da" {
  provider = consul.da
  query_options {
    datacenter = "da"
  }
}

module "da-consul-relay01" {
  source = "./consul/service-node"

  providers = { consul = consul.da }
  name      = "relay01"
  address   = "10.69.0.1"
  port      = 443
  host      = "da-relay01.${local.domain.holo}"
  scheme    = "https"

  authentik = {
    name   = "Router: Relay01"
    group  = "Home"
    access = "compute-managers"
    icon   = "di:mikrotik"
  }

  check = {
    type = "tcp"
    name = "MikroTik hAP ax³ service check"
  }
}

module "da-consul-relay02" {
  source = "./consul/service-node"

  providers = { consul = consul.da }
  name      = "relay02"
  address   = "10.69.0.2"
  port      = 443
  host      = "da-relay02.${local.domain.holo}"
  scheme    = "https"

  authentik = {
    name   = "Router: Relay02"
    group  = "Home"
    access = "compute-managers"
    icon   = "di:mikrotik"
  }

  check = {
    type = "tcp"
    name = "MikroTik L009UiGS-RM service check"
  }
}

module "da-consul-hubitat" {
  source = "./consul/service-node"

  providers = { consul = consul.da }
  name      = "hubitat"
  node      = "hubitat-c8"
  address   = "10.69.4.2"
  port      = 80
  host      = "hubitat.${local.domain.da}"

  authentik = {
    group      = "Home"
    access     = "home"
    icon       = "di:hubitat"
    skip-paths = "/apps/api/*"
  }
}

module "da-consul-esm" {
  source     = "./consul/esm"
  providers  = { consul = consul.da }
  datacenter = "da"
}

resource "consul_node" "da-vcx-1" {
  provider   = consul.da
  name       = "da-vcx-1"
  address    = "10.69.11.1"
  datacenter = "da"
}

# resource "consul_node" "da-vcx-2" {
#   provider   = consul.da
#   name       = "da-vcx-2"
#   address    = "10.69.12.1"
#   datacenter = "da"
# }

# resource "consul_node" "da-vcx-3" {
#   provider   = consul.da
#   name       = "da-vcx-3"
#   address    = "10.69.13.1"
#   datacenter = "da"
# }
