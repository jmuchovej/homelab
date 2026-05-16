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
  da-ports = {
    relay01 = {
      ether2 = { role = "access", access = "mgmt" }
      ether3 = { role = "access", access = "lab" }
      ether4 = { role = "access", access = "lab" }
      ether5 = { role = "trunk", comment = "Downstream trunk (relay02 ether1)" }
      # Holonet wifi: default-VLAN guest, untagged frames from clients get
      # tagged by the bridge's pvid. Future: switch to trunk + per-client
      # VLAN override via RADIUS (Tunnel-Private-Group-ID) when 802.1X is
      # wired up. Until then, "join holonet" = "you're a guest."
      wifi1 = { role = "access", access = "guest", comment = "Holonet wifi → guest VLAN by default" }
      wifi2 = { role = "access", access = "iot", comment = "Droids wifi → iot VLAN" }
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

  # All catalog-derived (vlans, vip, lan-supernet, admin allowlist,
  # wan-cert, wg-holonet config, mgmt-ip). Module slices by var.relay.
  relay   = "da-relay01"
  catalog = local.catalog

  role     = "router"
  wan-port = "ether1"

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
        tx_power = 12 # dBm (attempting to avoid blasting Zigbee)
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
      # Planned: MAC-address allowlist (access-list on /interface/wifi/
      # access-list) so only known IoT devices can associate. RouterOS
      # supports it via a separate resource; not wired into this module
      # yet. When it lands, droids stays open at the L2 layer but the
      # AP rejects associations from unknown MACs.
    }
  }

  wifi-passphrases = {
    holonet = data.sops_file.da.data["network.wifi"]
    droids  = null
  }

  # Static leases match on mac-addr alone. `client-id` is omitted because
  # NixOS dhcpcd (and most DHCP clients) send `1:<MAC>` as DHCP option 61
  # rather than a string identifier — a `client-id = "da-vcx-1"`-style
  # constraint would never match and the lease would fall through to the
  # pool.
  static-leases = merge({
    for addr, device in {
      "10.69.11.1" = "vcx-1",
      # "10.69.12.1" = "vcx-2",
      # "10.69.13.1" = "vcx-3",
      "10.69.4.2" = "hubitat-c8",
      } : device => {
      address  = addr
      mac-addr = data.sops_file.da.data["devices.${device}"]
      server   = local.vlans.lab.dhcp
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
