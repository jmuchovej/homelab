# RBAC role for end-user network authentication via RADIUS — i.e. letting
# people log in to the network (802.1X / RADIUS) against Authentik.
#
# This is NOT the RADIUS *outpost* service-account role in apps.outposts.tofu
# (`authentik_rbac_role.radius`), which only lets the outpost read its own
# config. RADIUS network auth isn't implemented yet, so this is parked.
#
# NOTE: before uncommenting, rename this resource — the address
# `authentik_rbac_role.radius` is already taken by the outpost role. Something
# like `authentik_rbac_role.network-radius` would disambiguate the two.

# resource "authentik_rbac_role" "radius" {
#   name = "RADIUS"
# }
#
# resource "authentik_rbac_permission_role" "radius-global" {
#   for_each = toset([
#   ])
#   role       = authentik_rbac_role.radius.id
#   permission = each.value
# }
