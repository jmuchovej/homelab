data "sops_file" "da-relay01" {
  source_file = "${path.root}/secrets/hosts/da-relay01.sops.yaml"
}

data "sops_file" "da-relay02" {
  source_file = "${path.root}/secrets/hosts/da-relay02.sops.yaml"
}

provider "routeros" {
  alias    = "da-relay01"
  hosturl  = "https://da-relay01.${local.domain.holo}"
  username = "terraform"
  password = data.sops_file.da-relay01.data["tofu-password"]
}

provider "routeros" {
  alias    = "da-relay02"
  hosturl  = "https://da-relay02.${local.domain.holo}"
  username = "terraform"
  password = data.sops_file.da-relay02.data["tofu-password"]
}

locals {
  # Lab reservations. `.1.0/24` is the k8s LB pool, `.4.x` devices, `.10.1`
  # NAS, `.1x.1` k8s nodes — the BGP peers above read their addresses from
  # here so a reservation and its peer can never drift apart.
  da-lab-hosts = {
    "da-gr75.eth1"  = "10.32.10.1"
    "da-vcx-1.eth1" = "10.32.11.1"
    "da-vcx-2.eth1" = "10.32.12.1"
    # "da-vcx-3.eth1"   = "10.32.13.1"
    # "da-vcx-4.eth1"   = "10.32.14.1"
    "da-hubitat-c8.eth1" = "10.32.4.2"
  }

  da-ports = {
    relay01 = {
      ether2 = { role = "access", access = "mgmt" }
      ether3 = { role = "access", access = "lab" }
      ether4 = { role = "access", access = "lab" }
      ether5 = { role = "trunk", comment = "Downstream trunk (relay02 ether1)" }
      wifi1  = { role = "access", access = "guest", comment = "Holonet wifi → guest VLAN by default" }
      wifi2  = { role = "access", access = "iot", comment = "Droids wifi → iot VLAN" }
    }
    relay02 = {
      ether1 = { role = "trunk", comment = "Trunk uplink (relay01 ether5)" }
      ether2 = { role = "access", access = "mgmt" }
      ether3 = { role = "access", access = "lab" }
      ether4 = { role = "access", access = "lab" }
      ether5 = { role = "access", access = "trusted" }
      ether6 = { role = "access", access = "trusted" }
      ether7 = { role = "access", access = "trusted" }
      ether8 = { role = "access", access = "trusted" }
    }
  }
}

module "da-relay01" {
  source = "./mikrotik"

  providers = {
    routeros = routeros.da-relay01
  }

  relay   = "da-relay01"
  catalog = local.catalog

  role     = "router"
  wan-port = "ether1"

  bgp = {
    asn          = 64512
    lb-pool-cidr = local.catalog.k8s-for["da"].lb-pool
    peers = {
      da-gr75  = local.da-lab-hosts["da-gr75.eth1"]
      da-vcx-1 = local.da-lab-hosts["da-vcx-1.eth1"]
      da-vcx-2 = local.da-lab-hosts["da-vcx-2.eth1"]
    }
  }

  bridge-mac = data.sops_file.da-relay01.data["bridge-mac"]

  enable-wan-dhcp = true
  enable-ip-cloud = true
  enable-hairpin  = true

  ports = local.da-ports.relay01

  wifi = {
    holonet = {
      name    = "wifi1"
      comment = "Holonet"
      configuration = {
        country = "United States"
        mode    = "ap"
        ssid    = "Holonet"
      }
      channel = {
        band              = "5ghz-ax"
        frequency         = "5170-5330,5490-5730,5735-5835"
        skip_dfs_channels = "10min-cac"
        width             = "20/40/80mhz"
      }
      security = {
        authentication_types = "wpa2-psk,wpa3-psk"
        ft                   = "true"
        ft_over_ds           = "true"
        wps                  = "disable"
      }
    }
    droids = {
      name    = "wifi2"
      comment = "The Droids You're Looking For"
      configuration = {
        country  = "United States"
        mode     = "ap"
        ssid     = "The Droids You're Looking For"
        tx_power = 12 # dBm; kept low so 2.4GHz wifi does not drown out Zigbee
      }
      channel = {
        band              = "2ghz-ax"
        frequency         = "2412,2437"
        skip_dfs_channels = "10min-cac"
        width             = "20mhz"
      }
      security = {
        authentication_types = null
        ft                   = null
        ft_over_ds           = null
        passphrase           = null
      }
    }
  }

  wifi-passphrases = {
    holonet = data.sops_file.da.data["network.wifi"]
    droids  = null
  }

  # No `client-id`: clients send `1:<MAC>` as option 61, so a hostname-style
  # client-id would never match and the lease would fall through to the pool.
  static-leases = merge({
    for name, lease in merge(
      { for n, addr in local.da-lab-hosts : n => { address = addr, vlan = local.vlans.lab.dhcp } },
      {
        "replicator.wifi"  = { address = "10.66.1.2", vlan = local.vlans.iot.dhcp }
        "da-apple-tv.eth1" = { address = "10.99.1.2", vlan = local.vlans.guest.dhcp }
      }
      ) : name => {
      address  = lease.address
      mac-addr = data.sops_file.topology.data["devices.${name}"]
      server   = lease.vlan
    }
    }, {
    relay02-mgmt = {
      address  = "10.42.0.2"
      mac-addr = data.sops_file.da-relay02.data["bridge-mac"]
      server   = local.vlans.mgmt.dhcp
    }
  })
}

module "da-relay02" {
  source = "./mikrotik"

  providers = {
    routeros = routeros.da-relay02
  }

  relay   = "da-relay02"
  catalog = local.catalog

  role     = "switch"
  wan-port = "ether1"

  bridge-mac = data.sops_file.da-relay02.data["bridge-mac"]

  enable-wan-dhcp = false
  enable-ip-cloud = false
  enable-hairpin  = false

  ports = local.da-ports.relay02
}
