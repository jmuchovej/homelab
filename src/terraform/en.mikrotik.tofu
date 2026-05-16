data "sops_file" "en-relay01" {
  source_file = "${path.root}/secrets/hosts/en-relay01.sops.yaml"
}

provider "routeros" {
  alias    = "en-relay01"
  hosturl  = "https://en-relay01.${local.domain.holo}"
  username = "terraform"
  password = data.sops_file.en-relay01.data["tofu-password"]
}

locals {
  en-ports = {
    relay01 = {
      ether2 = { role = "access", access = "mgmt" }
      ether3 = { role = "access", access = "lab" }
      ether4 = { role = "access", access = "lab" }
      ether5 = { role = "access", access = "trusted" }
      ether6 = { role = "access", access = "trusted" }
      ether7 = { role = "access", access = "trusted" }
      ether8 = { role = "access", access = "guest" }
    }
  }
}

module "en-relay01" {
  source = "./mikrotik"

  providers = {
    routeros = routeros.en-relay01
  }

  # All catalog-derived (vlans, vip, lan-supernet, admin allowlist,
  # wan-cert, wg-holonet config, mgmt-ip). Module slices by var.relay.
  relay   = "en-relay01"
  catalog = local.catalog

  role     = "router"
  wan-port = "ether1"

  bridge-mac = data.sops_file.en-relay01.data["bridge-mac"]

  enable-wan-dhcp = true
  enable-ip-cloud = true
  enable-hairpin  = true

  ports = local.en-ports.relay01

  static-leases = merge({
    for addr, device in {
      "10.69.11.1" = "t65-1.eth1",
      "10.69.4.2"  = "hubitat-c8.eth1",
      } : device => {
      address  = addr
      mac-addr = data.sops_file.topology.data["devices.en-${device}"]
      server   = local.vlans.lab.dhcp
    }
    },
  )
}
