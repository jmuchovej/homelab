# Invalidation (logout) flow

import {
  to = authentik_flow.invalidation
  id = "default-invalidation-flow"
}

resource "authentik_flow" "invalidation" {
  name               = "Logout"
  slug               = "default-invalidation-flow"
  title              = "Logging out..."
  designation        = "invalidation"
  authentication     = "none"
  policy_engine_mode = "any"
}

import {
  to = authentik_stage_user_logout.invalidation
  id = "efe1133d-f80f-46fe-b40a-1f36050ddfc2"
}

resource "authentik_stage_user_logout" "invalidation" {
  name = "invalidation-logout"
}

import {
  to = authentik_flow_stage_binding.invalidation-logout
  id = "eaf1f11b-d0b8-4047-bf24-66e27917f005"
}

resource "authentik_flow_stage_binding" "invalidation-logout" {
  target = authentik_flow.invalidation.uuid
  stage  = authentik_stage_user_logout.invalidation.id
  order  = 0
}
