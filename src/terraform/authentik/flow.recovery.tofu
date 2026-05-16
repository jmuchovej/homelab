# Recovery flow
# Password reset via email verification.
# Flow: identify user → send recovery email → new password prompt → write → login

resource "authentik_flow" "recovery" {
  name               = "Password Recovery"
  slug               = "recovery"
  title              = "Reset your password"
  designation        = "recovery"
  authentication     = "require_unauthenticated"
  compatibility_mode = true
  policy_engine_mode = "any"
}

# --- Stages ---

resource "authentik_stage_identification" "recovery" {
  name        = "recovery-identification"
  user_fields = ["email", "username"]
}

resource "authentik_stage_email" "recovery" {
  name                     = "recovery-email"
  use_global_settings      = true
  template                 = "email/password_reset.html"
  activate_user_on_success = true
  token_expiry             = "minutes=30"
  subject                  = "Password reset"
}

resource "authentik_stage_prompt_field" "recovery-password" {
  name      = "recovery-field-password"
  field_key = "password"
  label     = "New password"
  type      = "password"
  required  = true
  order     = 0
}

resource "authentik_stage_prompt_field" "recovery-password-repeat" {
  name      = "recovery-field-password-repeat"
  field_key = "password_repeat"
  label     = "Confirm new password"
  type      = "password"
  required  = true
  order     = 1
}

resource "authentik_stage_prompt" "recovery-password" {
  name = "recovery-password-prompt"
  fields = [
    authentik_stage_prompt_field.recovery-password.id,
    authentik_stage_prompt_field.recovery-password-repeat.id,
  ]
  validation_policies = [
    authentik_policy_password.password-policy.id,
  ]
}

resource "authentik_stage_user_write" "recovery" {
  name               = "recovery-user-write"
  user_creation_mode = "never_create"
}

resource "authentik_stage_user_login" "recovery" {
  name = "recovery-login"
}

# --- Policies ---

# Skip identification if the user has already been restored (e.g. via email link)
resource "authentik_policy_expression" "recovery-skip-if-restored" {
  name       = "recovery-skip-if-restored"
  expression = <<-EOT
    return bool(request.context.get('is_restored', True))
  EOT
}

# --- Flow Stage Bindings ---

resource "authentik_flow_stage_binding" "recovery-identification" {
  target               = authentik_flow.recovery.uuid
  stage                = authentik_stage_identification.recovery.id
  order                = 10
  re_evaluate_policies = true
}

resource "authentik_flow_stage_binding" "recovery-email" {
  target               = authentik_flow.recovery.uuid
  stage                = authentik_stage_email.recovery.id
  order                = 20
  re_evaluate_policies = true
}

resource "authentik_flow_stage_binding" "recovery-password" {
  target = authentik_flow.recovery.uuid
  stage  = authentik_stage_prompt.recovery-password.id
  order  = 30
}

resource "authentik_flow_stage_binding" "recovery-write" {
  target = authentik_flow.recovery.uuid
  stage  = authentik_stage_user_write.recovery.id
  order  = 40
}

resource "authentik_flow_stage_binding" "recovery-login" {
  target = authentik_flow.recovery.uuid
  stage  = authentik_stage_user_login.recovery.id
  order  = 100
}

# --- Policy Bindings ---

resource "authentik_policy_binding" "recovery-skip-if-restored" {
  target = authentik_flow_stage_binding.recovery-identification.id
  policy = authentik_policy_expression.recovery-skip-if-restored.id
  order  = 0
}
