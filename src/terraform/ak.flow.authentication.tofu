# Authentication flows
# Login with username/email + password (or passkey), then TOTP/Duo/Passkey,
# then conditional captcha post-MFA.

import {
  to = authentik_flow.authn
  id = "default-authentication-flow"
}

resource "authentik_flow" "authn" {
  name               = "Login"
  slug               = "auth"
  title              = "Welcome to The Rebellion!"
  designation        = "authentication"
  authentication     = "none"
  compatibility_mode = true
  policy_engine_mode = "any"
}

import {
  to = authentik_stage_identification.authn
  id = "a5a735c0-6cf8-40bc-9794-16da468de00a"
}

resource "authentik_stage_identification" "authn" {
  name              = "authn-identification"
  user_fields       = ["email", "username"]
  password_stage    = authentik_stage_password.authn.id
  recovery_flow     = authentik_flow.recovery.uuid
  passwordless_flow = authentik_flow.authn.uuid
  show_matched_user = true
  sources           = []
}

import {
  to = authentik_stage_password.authn
  id = "b880e0f8-d0e4-4762-92cf-77dac33d1d54"
}

resource "authentik_stage_password" "authn" {
  name = "authn-password"
  backends = [
    "authentik.core.auth.InbuiltBackend",
    "authentik.core.auth.TokenBackend",
  ]
  configure_flow                = authentik_flow.password-change.uuid
  allow_show_password           = true
  failed_attempts_before_cancel = 3
}

import {
  to = authentik_stage_authenticator_validate.authn-mfa
  id = "919cf196-2677-411f-ab3e-6cb0852ac250"
}

resource "authentik_stage_authenticator_validate" "authn-mfa" {
  name                  = "authn-mfa-validation"
  device_classes        = ["totp", "duo", "webauthn"]
  not_configured_action = "deny"
  last_auth_threshold   = "seconds=0"
  configuration_stages = [
    authentik_stage_authenticator_totp.totp.id,
    authentik_stage_authenticator_duo.duo.id,
    authentik_stage_authenticator_webauthn.webauthn.id,
  ]
}

import {
  to = authentik_stage_user_login.authn
  id = "8d030ce8-84bb-4799-a8c5-7fb2698e2c12"
}

resource "authentik_stage_user_login" "authn" {
  name = "authn-login"
}

resource "authentik_stage_captcha" "authn" {
  name        = "authn-captcha"
  public_key  = data.sops_file.secrets.data["captcha.public-key"]
  private_key = data.sops_file.secrets.data["captcha.secret-key"]
}

# --- Flow Stage Bindings ---

import {
  to = authentik_flow_stage_binding.authn-identification
  id = "d68bfe47-3cf3-41a1-af2b-e4209c9d77ad"
}

resource "authentik_flow_stage_binding" "authn-identification" {
  target = authentik_flow.authn.uuid
  stage  = authentik_stage_identification.authn.id
  order  = 10
}

import {
  to = authentik_flow_stage_binding.authn-password
  id = "c3c8af94-ddac-4647-b925-c31ddf715e00"
}

resource "authentik_flow_stage_binding" "authn-password" {
  target               = authentik_flow.authn.uuid
  stage                = authentik_stage_password.authn.id
  order                = 20
  re_evaluate_policies = true
}

import {
  to = authentik_flow_stage_binding.authn-mfa
  id = "8e94e03b-b647-4cb1-887b-cd24438f2cb4"
}

resource "authentik_flow_stage_binding" "authn-mfa" {
  target               = authentik_flow.authn.uuid
  stage                = authentik_stage_authenticator_validate.authn-mfa.id
  order                = 30
  re_evaluate_policies = true
}

resource "authentik_flow_stage_binding" "authn-captcha" {
  target               = authentik_flow.authn.uuid
  stage                = authentik_stage_captcha.authn.id
  order                = 40
  evaluate_on_plan     = false
  re_evaluate_policies = true
}

import {
  to = authentik_flow_stage_binding.authn-login
  id = "3475c57e-29ec-4ba8-952b-3193fdb5dde7"
}

resource "authentik_flow_stage_binding" "authn-login" {
  target = authentik_flow.authn.uuid
  stage  = authentik_stage_user_login.authn.id
  order  = 100
}

# --- Policies ---

# Skip password stage if user authenticated via passkey (WebAuthn passwordless)
import {
  to = authentik_policy_expression.authn-password-required
  id = "0cea6f84-eb65-4cc4-912b-9dac76eb361f"
}

resource "authentik_policy_expression" "authn-password-required" {
  name       = "authn-password-required"
  expression = <<-EOT
    flow_plan = request.context.get("flow_plan")
    if not flow_plan:
        return True
    return not hasattr(flow_plan.context.get("pending_user"), "backend")
  EOT
}

# Skip MFA stage if user already authenticated via passkey
import {
  to = authentik_policy_expression.authn-mfa-required
  id = "7fca054a-44c2-4546-9a41-d1111abf56d8"
}

resource "authentik_policy_expression" "authn-mfa-required" {
  name       = "authn-mfa-required"
  expression = <<-EOT
    flow_plan = request.context.get("flow_plan")
    if not flow_plan:
        return True
    return not (flow_plan.context.get("auth_method") == "auth_webauthn_pwl")
  EOT
}

# Conditional captcha based on reputation score
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

resource "authentik_policy_binding" "authn-captcha-conditional" {
  target = authentik_flow_stage_binding.authn-captcha.id
  policy = authentik_policy_reputation.authn-captcha.id
  order  = 0
}
