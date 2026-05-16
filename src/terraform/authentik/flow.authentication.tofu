# Authentication flow — adopt authentik's `default-authentication-flow`
# (imported at root in ak.tofu) and manage it with our config. The captcha
# stage + its binding/policy/policy-binding are OURS (no authentik default),
# created not imported, inserted at order 40 between MFA (30) and login (100).

resource "authentik_flow" "authn" {
  name               = "Login"
  slug               = "default-authentication-flow"
  title              = "Welcome to The Rebellion!"
  designation        = "authentication"
  authentication     = "none"
  compatibility_mode = true
  policy_engine_mode = "any"
}

resource "authentik_stage_identification" "authn" {
  name              = "default-authentication-identification"
  user_fields       = ["email", "username"]
  password_stage    = authentik_stage_password.authn.id
  recovery_flow     = authentik_flow.recovery.uuid
  passwordless_flow = authentik_flow.authn.uuid
  show_matched_user = true
  sources           = []
}

resource "authentik_stage_password" "authn" {
  name = "default-authentication-password"
  backends = [
    "authentik.core.auth.InbuiltBackend",
    "authentik.core.auth.TokenBackend",
  ]
  configure_flow                = authentik_flow.password-change.uuid
  allow_show_password           = true
  failed_attempts_before_cancel = 3
}

resource "authentik_stage_authenticator_validate" "authn-mfa" {
  name                  = "default-authentication-mfa-validation"
  device_classes        = ["totp", "duo", "webauthn"]
  not_configured_action = "deny"
  last_auth_threshold   = "seconds=0"
  configuration_stages = [
    authentik_stage_authenticator_totp.totp.id,
    authentik_stage_authenticator_duo.duo.id,
    authentik_stage_authenticator_webauthn.webauthn.id,
  ]
}

resource "authentik_stage_user_login" "authn" {
  name = "default-authentication-login"
}

# Captcha — ours, no authentik default. Created, not imported.
resource "authentik_stage_captcha" "authn" {
  name        = "authn-captcha"
  public_key  = data.sops_file.secrets.data["captcha.public-key"]
  private_key = data.sops_file.secrets.data["captcha.secret-key"]
}

# --- Flow Stage Bindings ---

resource "authentik_flow_stage_binding" "authn-identification" {
  target = authentik_flow.authn.uuid
  stage  = authentik_stage_identification.authn.id
  order  = 10
}

resource "authentik_flow_stage_binding" "authn-password" {
  target               = authentik_flow.authn.uuid
  stage                = authentik_stage_password.authn.id
  order                = 20
  re_evaluate_policies = true
}

resource "authentik_flow_stage_binding" "authn-mfa" {
  target               = authentik_flow.authn.uuid
  stage                = authentik_stage_authenticator_validate.authn-mfa.id
  order                = 30
  re_evaluate_policies = true
}

# Ours (captcha) — created.
resource "authentik_flow_stage_binding" "authn-captcha" {
  target               = authentik_flow.authn.uuid
  stage                = authentik_stage_captcha.authn.id
  order                = 40
  evaluate_on_plan     = false
  re_evaluate_policies = true
}

resource "authentik_flow_stage_binding" "authn-login" {
  target = authentik_flow.authn.uuid
  stage  = authentik_stage_user_login.authn.id
  order  = 100
}

# --- Policies ---

# Skip password stage if user authenticated via passkey (WebAuthn passwordless)
resource "authentik_policy_expression" "authn-password-required" {
  name       = "default-authentication-flow-password-stage"
  expression = <<-EOT
    flow_plan = request.context.get("flow_plan")
    if not flow_plan:
        return True
    # If the user does not have a backend attached to it, they haven't
    # been authenticated yet and we need the password stage
    return not hasattr(flow_plan.context.get("pending_user"), "backend")
  EOT
}

# Skip MFA stage if user already authenticated via passkey
resource "authentik_policy_expression" "authn-mfa-required" {
  name       = "default-authentication-flow-authenticator-validate-stage"
  expression = <<-EOT
    flow_plan = request.context.get("flow_plan")
    if not flow_plan:
        return True
    # if the authentication method is webauthn (passwordless), then we skip the
    # authenticatorvalidation stage by returning false (true will execute the stage)
    return not (flow_plan.context.get("auth_method") == "auth_webauthn_pwl")
  EOT
}

# Conditional captcha based on reputation score — ours, created.
resource "authentik_policy_reputation" "authn-captcha" {
  name           = "authn-conditional-captcha"
  check_ip       = true
  check_username = true
  threshold      = -5
}

# --- Policy Bindings ---

resource "authentik_policy_binding" "authn-password-required" {
  target         = authentik_flow_stage_binding.authn-password.id
  policy         = authentik_policy_expression.authn-password-required.id
  order          = 0
  failure_result = true
}

resource "authentik_policy_binding" "authn-mfa-required" {
  target         = authentik_flow_stage_binding.authn-mfa.id
  policy         = authentik_policy_expression.authn-mfa-required.id
  order          = 0
  failure_result = true
}

# Ours (captcha) — created.
resource "authentik_policy_binding" "authn-captcha-conditional" {
  target = authentik_flow_stage_binding.authn-captcha.id
  policy = authentik_policy_reputation.authn-captcha.id
  order  = 0
}
