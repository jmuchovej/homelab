# LDAP binds are non-interactive, so MFA cannot be prompted here. The MFA
# stage skips unconfigured users and app-password logins; MFA is enforced
# at web login instead.

resource "authentik_flow" "ldap" {
  name               = "ldap-authn"
  slug               = "ldap-authn"
  title              = "LDAP Authentication"
  designation        = "authentication"
  policy_engine_mode = "any"
}

resource "authentik_stage_identification" "ldap" {
  name           = "ldap-identification"
  user_fields    = ["username"]
  password_stage = authentik_stage_password.ldap.id
}

resource "authentik_stage_password" "ldap" {
  name = "ldap-password"
  backends = [
    "authentik.core.auth.InbuiltBackend",
    "authentik.core.auth.TokenBackend",
  ]
}

resource "authentik_stage_authenticator_validate" "ldap-mfa" {
  name                  = "ldap-mfa-validation"
  device_classes        = ["totp", "duo", "webauthn", "static"]
  not_configured_action = "skip"
}

resource "authentik_stage_user_login" "ldap" {
  name             = "ldap-login"
  session_duration = "days=14"
}

resource "authentik_flow_stage_binding" "ldap-identification" {
  target = authentik_flow.ldap.uuid
  stage  = authentik_stage_identification.ldap.id
  order  = 10
}

resource "authentik_flow_stage_binding" "ldap-mfa" {
  target               = authentik_flow.ldap.uuid
  stage                = authentik_stage_authenticator_validate.ldap-mfa.id
  order                = 20
  re_evaluate_policies = true
}

resource "authentik_flow_stage_binding" "ldap-login" {
  target = authentik_flow.ldap.uuid
  stage  = authentik_stage_user_login.ldap.id
  order  = 100
}

resource "authentik_policy_expression" "ldap-mfa-skip-app-password" {
  name       = "ldap-mfa-skip-app-password"
  expression = <<-EOT
    flow_plan = request.context.get("flow_plan")
    if not flow_plan:
        return True
    return flow_plan.context.get("auth_method") != "app_password"
  EOT
}

resource "authentik_policy_binding" "ldap-mfa-skip-app-password" {
  target         = authentik_flow_stage_binding.ldap-mfa.id
  policy         = authentik_policy_expression.ldap-mfa-skip-app-password.id
  order          = 0
  failure_result = true
}
