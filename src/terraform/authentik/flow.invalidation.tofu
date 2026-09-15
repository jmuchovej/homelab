# Adopts authentik's default flow (imported in ak.tofu), so names and slugs
# must stay as shipped.

resource "authentik_flow" "invalidation" {
  name               = "Logout"
  slug               = "default-invalidation-flow"
  title              = "Default Invalidation Flow"
  designation        = "invalidation"
  authentication     = "none"
  policy_engine_mode = "any"
}

resource "authentik_stage_user_logout" "invalidation" {
  name = "default-invalidation-logout"
}

resource "authentik_flow_stage_binding" "invalidation-logout" {
  target = authentik_flow.invalidation.uuid
  stage  = authentik_stage_user_logout.invalidation.id
  order  = 0
}
