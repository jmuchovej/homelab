# Parked: RBAC role for end-user 802.1X/RADIUS network auth, not yet implemented.

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
