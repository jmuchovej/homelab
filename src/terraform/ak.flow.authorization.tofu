# Authorization flows

import {
  to = authentik_flow.authz-explicit
  id = "default-provider-authorization-explicit-consent"
}

resource "authentik_flow" "authz-explicit" {
  name               = "Explicit Authorization"
  slug               = "authz-explicit"
  title              = "Redirecting to %(app)s"
  designation        = "authorization"
  policy_engine_mode = "any"
}

import {
  to = authentik_stage_consent.authz-explicit
  id = "679ccc50-6cf7-4f89-802c-2089423add4c"
}

resource "authentik_stage_consent" "authz-explicit" {
  name              = "authz-explicit-consent"
  mode              = "expiring"
  consent_expire_in = "weeks=4"
}

import {
  to = authentik_flow_stage_binding.authz-explicit-consent
  id = "0b550a95-ad31-4ad2-9efc-86aaa41f69a8"
}

resource "authentik_flow_stage_binding" "authz-explicit-consent" {
  target = authentik_flow.authz-explicit.uuid
  stage  = authentik_stage_consent.authz-explicit.id
  order  = 0
}

import {
  to = authentik_flow.authz-implicit
  id = "default-provider-authorization-implicit-consent"
}

resource "authentik_flow" "authz-implicit" {
  name               = "Implicit Authorization"
  slug               = "authz-implicit"
  title              = "Redirecting to %(app)s"
  designation        = "authorization"
  policy_engine_mode = "any"
}
