resource "authentik_rbac_role" "outpost" {
  name = "Outpost"
}

resource "authentik_rbac_permission_role" "outpost-global" {
  for_each = toset([
    "add_event"
  ])
  role       = authentik_rbac_role.outpost.id
  permission = lookup(var.permissions, each.value, each.value)
}
