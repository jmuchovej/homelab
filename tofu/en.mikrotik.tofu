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
  # Lab reservations, same structure as da — `.1.0/24` is the k8s LB pool,
  # `.4.x` devices, `.1x.1` k8s nodes. The BGP peer below reads t65-1 from
  # here so the two can never drift.
  en-lab-hosts = {
    "t65-1.eth1"      = "10.36.11.1"
    "hubitat-c8.eth1" = "10.36.4.2"
  }

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

  relay   = "en-relay01"
  catalog = local.catalog

  role     = "router"
  wan-port = "ether1"

  bgp = {
    asn          = 64512
    lb-pool-cidr = local.catalog.k8s-for["en"].lb-pool
    peers = {
      en-t65-1 = local.en-lab-hosts["t65-1.eth1"]
    }
  }

  bridge-mac = data.sops_file.en-relay01.data["bridge-mac"]

  enable-wan-dhcp = true
  enable-ip-cloud = true
  enable-hairpin  = true

  ports = local.en-ports.relay01

  static-leases = {
    for device, addr in local.en-lab-hosts : device => {
      address  = addr
      mac-addr = data.sops_file.topology.data["devices.en-${device}"]
      vlan     = "lab"
    }
  }
}
