# Deliberately not named "authentik Admins", so it does not shadow the
# bootstrap superuser group that holds akadmin.
resource "authentik_group" "akadmin" {
  name  = "rebellion-admins"
  users = []
}

resource "authentik_group" "compute" {
  name = "compute"
  users = compact([
    try(authentik_user.u["ypah-xuuk"].id, null),
    try(authentik_user.u["mxqk-hhtv"].id, null),
  ])
}

resource "authentik_group" "compute-manager" {
  name = "compute-manager"
  users = compact([
    try(authentik_user.u["ypah-xuuk"].id, null)
  ])
  parents = [
    authentik_group.compute.id,
    authentik_group.admin-ro.id,
  ]
}

resource "authentik_group" "family" {
  name = "family"
  users = compact([
    try(authentik_user.u["ypah-xuuk"].id, null),
    try(authentik_user.u["ggms-eksu"].id, null),
    try(authentik_user.u["gasm-egbe"].id, null),
    try(authentik_user.u["floe-rlfn"].id, null),
  ])
}

resource "authentik_group" "home" {
  name = "home"
  users = compact([
    try(authentik_user.u["ypah-xuuk"].id, null),
    try(authentik_user.u["mxqk-hhtv"].id, null),
  ])
}

resource "authentik_group" "media" {
  name = "media"
  users = compact([
    try(authentik_user.u["ypah-xuuk"].id, null),
    try(authentik_user.u["mxqk-hhtv"].id, null),
    try(authentik_user.u["gasm-egbe"].id, null),
    try(authentik_user.u["floe-rlfn"].id, null),
  ])
}

resource "authentik_group" "media-manager" {
  name = "media-manager"
  users = compact([
    try(authentik_user.u["ypah-xuuk"].id, null)
  ])
  parents = [authentik_group.media.id]
  attributes = jsonencode({
    "servarr-username" : data.sops_file.da.data["servarr.username"],
    "servarr-password" : data.sops_file.da.data["servarr.password"],
  })
}

resource "authentik_group" "minecraft" {
  name = "minecraft"
  users = compact([
    try(authentik_user.u["ypah-xuuk"].id, null),
    try(authentik_user.u["ggms-eksu"].id, null),
  ])
}

resource "authentik_group" "minecraft-manager" {
  name = "minecraft-manager"
  users = compact([
    try(authentik_user.u["ypah-xuuk"].id, null),
    try(authentik_user.u["ggms-eksu"].id, null),
  ])
  parents = [authentik_group.minecraft.id]
}

# Gates the shared entry point only; per-user instances bind their owner
# directly, since a shared group would expose every member's GUI to the others.
resource "authentik_group" "syncthing" {
  name = "syncthing"
  users = compact([
    try(authentik_user.u["ypah-xuuk"].id, null),
    try(authentik_user.u["ggms-eksu"].id, null),
    try(authentik_user.u["gasm-egbe"].id, null),
    try(authentik_user.u["floe-rlfn"].id, null),
  ])
}

locals {
  groups = {
    "compute"            = authentik_group.compute
    "compute-managers"   = authentik_group.compute-manager
    "family"             = authentik_group.family
    "home"               = authentik_group.home
    "media"              = authentik_group.media
    "media-managers"     = authentik_group.media-manager
    "minecraft"          = authentik_group.minecraft
    "minecraft-managers" = authentik_group.minecraft-manager
    "syncthing"          = authentik_group.syncthing
    "admin"              = authentik_group.akadmin
  }
}
