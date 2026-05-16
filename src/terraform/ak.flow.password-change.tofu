# Password change flow
# Requires authentication. Prompts for new password with validation.

import {
  to = authentik_flow.password-change
  id = "default-password-change"
}

resource "authentik_flow" "password-change" {
  name               = "Change Password"
  slug               = "password-change"
  title              = "Change your password"
  designation        = "stage_configuration"
  authentication     = "require_authenticated"
  policy_engine_mode = "any"
}

# --- Shared password policy (used by enrollment + password change + recovery) ---

import {
  to = authentik_policy_password.password-policy
  id = "542c2c55-125d-4fab-bc01-e03ba81484ab"
}

resource "authentik_policy_password" "password-policy" {
  name                   = "password-policy"
  error_message          = "Password must be at least 8 characters."
  length_min             = 8
  check_static_rules     = true
  check_zxcvbn           = true
  zxcvbn_score_threshold = 2
  password_field         = "password"
}

# --- Prompt Fields ---

resource "authentik_stage_prompt_field" "password-change" {
  name      = "password-change-field-password"
  field_key = "password"
  label     = "New password"
  type      = "password"
  required  = true
  order     = 300
}

resource "authentik_stage_prompt_field" "password-change-repeat" {
  name      = "password-change-field-password-repeat"
  field_key = "password_repeat"
  label     = "Confirm new password"
  type      = "password"
  required  = true
  order     = 301
}

# --- Stages ---

import {
  to = authentik_stage_prompt.password-change
  id = "a3b99161-2f9b-429f-8cbc-384534b88000"
}

resource "authentik_stage_prompt" "password-change" {
  name = "password-change-prompt"
  fields = [
    authentik_stage_prompt_field.password-change.id,
    authentik_stage_prompt_field.password-change-repeat.id,
  ]
  validation_policies = [
    authentik_policy_password.password-policy.id,
  ]
}

import {
  to = authentik_stage_user_write.password-change
  id = "be644779-f75c-4fa9-831e-516958ae5983"
}

resource "authentik_stage_user_write" "password-change" {
  name               = "password-change-write"
  user_creation_mode = "never_create"
}

# --- Flow Stage Bindings ---

import {
  to = authentik_flow_stage_binding.password-change-prompt
  id = "1e832f27-6810-41cd-afe5-256c97276058"
}

resource "authentik_flow_stage_binding" "password-change-prompt" {
  target = authentik_flow.password-change.uuid
  stage  = authentik_stage_prompt.password-change.id
  order  = 0
}

import {
  to = authentik_flow_stage_binding.password-change-write
  id = "f2d530f2-7392-4c84-94f8-70e19b6b6460"
}

resource "authentik_flow_stage_binding" "password-change-write" {
  target = authentik_flow.password-change.uuid
  stage  = authentik_stage_user_write.password-change.id
  order  = 10
}
