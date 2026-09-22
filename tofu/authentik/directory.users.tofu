# The admin user is intentionally unmanaged; break-glass is authentik's
# bootstrap `akadmin`. The `admin.*` sops keys are excluded below.

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
  for_each = local.user-keys

  name      = local.user-data[each.value].name
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

  # Users are archived (is-active = false in sops), never destroyed.
  lifecycle {
    prevent_destroy = true
  }
}
