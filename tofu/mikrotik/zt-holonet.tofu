resource "zerotier_identity" "this" {}

resource "routers_zerotier" "zt1" {
  comment    = "Zerotier: Holonet"
  identity   = zerotier_identity.this.private_key
  interfaces = ["all"]
  name       = "zt1"
  disabled   = false
}

resource "routers_zerotier_interface" "holonet" {
  instance      = routers_zerotier.zt1.name
  name          = "zerotier1"
  network       = var.catalog.zerotier-network-id
  allow_managed = true
  allow_global  = false
  allow_default = false
  disabled      = false
  comment       = "zt: holonet"
}

resource "routers_interface_list_member" "zt_in_lan" {
  list      = routers_interface_list.lan.name
  interface = routers_zerotier_interface.holonet.name
  comment   = "zt: holonet"
}

resource "zerotier_member" "this" {
  network_id         = var.catalog.zerotier-network-id
  member_id          = zerotier_identity.this.id
  name               = var.relay
  authorized         = true
  no_auto_assign_ips = true
  ip_assignments     = [split("/", local.wg-holonet.address)[0]]
}
