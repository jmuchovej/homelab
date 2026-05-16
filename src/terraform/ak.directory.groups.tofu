import {
  to = authentik_group.akadmin
  id = "6aa2889c-f54f-465d-b8b8-674fe33aed8c"
}

resource "authentik_group" "akadmin" {
  name = "authentik-admin"
  users = compact([
    authentik_user.admin.id,
  ])
}

resource "authentik_group" "compute" {
  name = "compute"
  users = compact([
    authentik_user.admin.id,
    try(authentik_user.u["ypah-xuuk"].id, null),
    try(authentik_user.u["mxqk-hhtv"].id, null),
  ])
}

data "authentik_group" "compute" {
  name = authentik_group.compute.name
}

resource "authentik_group" "compute-manager" {
  name = "compute-manager"
  users = compact([
    authentik_user.admin.id,
    try(authentik_user.u["ypah-xuuk"].id, null)
  ])
  parents = [
    authentik_group.compute.id,
    authentik_group.admin-ro.id,
  ]
}

data "authentik_group" "compute-manager" {
  name = authentik_group.compute-manager.name
}

resource "authentik_group" "family" {
  name = "family"
  users = compact([
    authentik_user.admin.id,
    try(authentik_user.u["ypah-xuuk"].id, null),
    try(authentik_user.u["ggms-eksu"].id, null),
    try(authentik_user.u["gasm-egbe"].id, null),
    try(authentik_user.u["floe-rlfn"].id, null),
  ])
}

data "authentik_group" "family" {
  name = authentik_group.family.name
}

resource "authentik_group" "home" {
  name = "home"
  users = compact([
    authentik_user.admin.id,
    try(authentik_user.u["ypah-xuuk"].id, null),
    try(authentik_user.u["mxqk-hhtv"].id, null),
  ])
}

data "authentik_group" "home" {
  name = authentik_group.home.name
}

resource "authentik_group" "media" {
  name = "media"
  users = compact([
    authentik_user.admin.id,
    try(authentik_user.u["ypah-xuuk"].id, null),
    try(authentik_user.u["mxqk-hhtv"].id, null),
    try(authentik_user.u["gasm-egbe"].id, null),
    try(authentik_user.u["floe-rlfn"].id, null),
  ])
}

data "authentik_group" "media" {
  name = authentik_group.media.name
}

resource "authentik_group" "media-manager" {
  name = "media-manager"
  users = compact([
    authentik_user.admin.id,
    try(authentik_user.u["ypah-xuuk"].id, null)
  ])
  parents = [authentik_group.media.id]
  attributes = jsonencode({
    "servarr-username" : data.sops_file.dc.data["servarr.username"],
    "servarr-password" : data.sops_file.dc.data["servarr.password"],
  })
}

data "authentik_group" "media-manager" {
  name = authentik_group.media-manager.name
}

resource "authentik_group" "minecraft" {
  name = "minecraft"
  users = compact([
    authentik_user.admin.id,
    try(authentik_user.u["ypah-xuuk"].id, null),
    try(authentik_user.u["ggms-eksu"].id, null),
  ])
}

data "authentik_group" "minecraft" {
  name = authentik_group.minecraft.name
}

resource "authentik_group" "minecraft-manager" {
  name = "minecraft-manager"
  users = compact([
    authentik_user.admin.id,
    try(authentik_user.u["ypah-xuuk"].id, null),
    try(authentik_user.u["ggms-eksu"].id, null),
  ])
  parents = [authentik_group.minecraft.id]
}

data "authentik_group" "minecraft-manager" {
  name = authentik_group.minecraft-manager.name
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
    "admin"              = authentik_group.akadmin
  }
}
