import {
  to = authentik_user.admin
  id = 6 // pk
}

resource "authentik_user" "admin" {
  username  = data.sops_file.users.data["admin.username"]
  type      = "internal"
  path      = "users"
  name      = data.sops_file.users.data["admin.name"]
  email     = data.sops_file.users.data["admin.email"]
  is_active = true
}

data "authentik_users" "all" {}

locals {
  user-keys = nonsensitive(toset([
    for user in keys(data.sops_file.users.data) :
    split(".", user)[0]
    if !startswith(user, "admin")
  ]))
  user-data = yamldecode(data.sops_file.users.raw)
}

resource "authentik_user" "u" {
  for_each  = local.user-keys
  username  = local.user-data[each.value].username
  email     = local.user-data[each.value].email
  path      = lookup(local.user-data[each.value], "path", "users")
  type      = lookup(local.user-data[each.value], "type", "internal")
  is_active = lookup(local.user-data[each.value], "is-active", true)
  attributes = jsonencode(merge({
    "user-key" = each.key
    },
    lookup(local.user-data[each.value], "attributes", {})
  ))
}
