# Invalidation (logout) flow
# PILOT: adopt authentik's built-in `default-invalidation-flow` (imported at root
# in ak.tofu via local.authentik-builtins) rather than creating a parallel copy.
# Resource config mirrors authentik's default so the import is a clean no-op.

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
