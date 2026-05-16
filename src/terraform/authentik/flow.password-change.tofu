# Password change flow — adopt authentik's `default-password-change`
# (imported at root in ak.tofu). Resource addresses kept (cross-file refs hold);
# names/slug mirror authentik's defaults so the import is clean.

resource "authentik_flow" "password-change" {
  name               = "Change Password"
  slug               = "default-password-change"
  title              = "Change your password"
  designation        = "stage_configuration"
  authentication     = "require_authenticated"
  policy_engine_mode = "any"
}

# --- Shared password policy (referenced by enrollment + recovery, which are ours) ---

resource "authentik_policy_password" "password-policy" {
  name                   = "default-password-change-password-policy"
  error_message          = "Password must be at least 8 characters."
  length_min             = 8
  check_static_rules     = true
  check_zxcvbn           = true
  zxcvbn_score_threshold = 2
  password_field         = "password"
}

# --- Prompt Fields ---

resource "authentik_stage_prompt_field" "password-change" {
  name        = "default-password-change-field-password"
  field_key   = "password"
  label       = "New password"
  placeholder = "Password"
  type        = "password"
  required    = true
  order       = 300
}

resource "authentik_stage_prompt_field" "password-change-repeat" {
  name        = "default-password-change-field-password-repeat"
  field_key   = "password_repeat"
  label       = "Confirm new password"
  placeholder = "Password (repeat)"
  type        = "password"
  required    = true
  order       = 301
}

# --- Stages ---

resource "authentik_stage_prompt" "password-change" {
  name = "default-password-change-prompt"
  fields = [
    authentik_stage_prompt_field.password-change.id,
    authentik_stage_prompt_field.password-change-repeat.id,
  ]
  validation_policies = [
    authentik_policy_password.password-policy.id,
  ]
}

resource "authentik_stage_user_write" "password-change" {
  name               = "default-password-change-write"
  user_creation_mode = "never_create"
}

# --- Flow Stage Bindings ---

resource "authentik_flow_stage_binding" "password-change-prompt" {
  target = authentik_flow.password-change.uuid
  stage  = authentik_stage_prompt.password-change.id
  order  = 0
}

resource "authentik_flow_stage_binding" "password-change-write" {
  target = authentik_flow.password-change.uuid
  stage  = authentik_stage_user_write.password-change.id
  order  = 1
}
