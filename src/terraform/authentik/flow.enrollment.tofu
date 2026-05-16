# Enrollment flow
# Admin-created user accounts receive an email to verify their address
# and set up their initial password + MFA.
#
# Flow: invitation gate → password prompt → MFA setup → user write → email verification → login

resource "authentik_flow" "enrollment" {
  name               = "User Enrollment"
  slug               = "enrollment"
  title              = "Welcome to The Rebellion!"
  designation        = "enrollment"
  authentication     = "require_unauthenticated"
  compatibility_mode = true
  policy_engine_mode = "any"
}

# --- Stages ---

resource "authentik_stage_invitation" "enrollment" {
  name                             = "enrollment-invitation"
  continue_flow_without_invitation = false
}

resource "authentik_stage_prompt_field" "enrollment-password" {
  name      = "enrollment-field-password"
  field_key = "password"
  label     = "Password"
  type      = "password"
  required  = true
  order     = 100
}

resource "authentik_stage_prompt_field" "enrollment-password-repeat" {
  name      = "enrollment-field-password-repeat"
  field_key = "password_repeat"
  label     = "Confirm password"
  type      = "password"
  required  = true
  order     = 101
}

resource "authentik_stage_prompt" "enrollment-password" {
  name = "enrollment-password-prompt"
  fields = [
    authentik_stage_prompt_field.enrollment-password.id,
    authentik_stage_prompt_field.enrollment-password-repeat.id,
  ]
  validation_policies = [
    authentik_policy_password.password-policy.id,
  ]
}

resource "authentik_stage_authenticator_validate" "enrollment-mfa" {
  name                  = "enrollment-mfa-setup"
  device_classes        = ["totp", "duo"]
  not_configured_action = "configure"
  configuration_stages = [
    authentik_stage_authenticator_totp.totp.id,
    authentik_stage_authenticator_duo.duo.id,
  ]
}

resource "authentik_stage_user_write" "enrollment" {
  name                     = "enrollment-user-write"
  user_creation_mode       = "never_create"
  create_users_as_inactive = false
}

resource "authentik_stage_email" "enrollment-verification" {
  name                     = "enrollment-email-verification"
  use_global_settings      = true
  template                 = "email/account_confirmation.html"
  activate_user_on_success = true
  token_expiry             = "minutes=30"
  subject                  = "Verify your account"
}

resource "authentik_stage_user_login" "enrollment" {
  name = "enrollment-login"
}

# --- Flow Stage Bindings ---

resource "authentik_flow_stage_binding" "enrollment-invitation" {
  target = authentik_flow.enrollment.uuid
  stage  = authentik_stage_invitation.enrollment.id
  order  = 10
}

resource "authentik_flow_stage_binding" "enrollment-password" {
  target = authentik_flow.enrollment.uuid
  stage  = authentik_stage_prompt.enrollment-password.id
  order  = 20
}

resource "authentik_flow_stage_binding" "enrollment-mfa" {
  target = authentik_flow.enrollment.uuid
  stage  = authentik_stage_authenticator_validate.enrollment-mfa.id
  order  = 30
}

resource "authentik_flow_stage_binding" "enrollment-write" {
  target = authentik_flow.enrollment.uuid
  stage  = authentik_stage_user_write.enrollment.id
  order  = 40
}

resource "authentik_flow_stage_binding" "enrollment-email" {
  target = authentik_flow.enrollment.uuid
  stage  = authentik_stage_email.enrollment-verification.id
  order  = 50
}

resource "authentik_flow_stage_binding" "enrollment-login" {
  target = authentik_flow.enrollment.uuid
  stage  = authentik_stage_user_login.enrollment.id
  order  = 100
}
