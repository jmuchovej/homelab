# Authorization flows — adopt authentik's `default-provider-authorization-*`
# (imported at root in ak.tofu). Managed with our config layered on top.

resource "authentik_flow" "authz-explicit" {
  name               = "Explicit Authorization"
  slug               = "default-provider-authorization-explicit-consent"
  title              = "Redirecting to %(app)s"
  designation        = "authorization"
  policy_engine_mode = "any"
}

resource "authentik_stage_consent" "authz-explicit" {
  name              = "default-provider-authorization-consent"
  mode              = "expiring"
  consent_expire_in = "weeks=4"
}

resource "authentik_flow_stage_binding" "authz-explicit-consent" {
  target = authentik_flow.authz-explicit.uuid
  stage  = authentik_stage_consent.authz-explicit.id
  order  = 0
}

resource "authentik_flow" "authz-implicit" {
  name               = "Implicit Authorization"
  slug               = "default-provider-authorization-implicit-consent"
  title              = "Redirecting to %(app)s"
  designation        = "authorization"
  policy_engine_mode = "any"
}
