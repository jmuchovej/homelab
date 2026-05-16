# User settings flow
# Allows authenticated users to update profile and manage authenticators.

import {
  to = authentik_flow.user-settings
  id = "default-user-settings-flow"
}

resource "authentik_flow" "user-settings" {
  name               = "User Settings"
  title              = "Update your account"
  slug               = "user-settings"
  designation        = "stage_configuration"
  policy_engine_mode = "any"
  denied_action      = "message_continue"
  layout             = "stacked"
  authentication     = "require_authenticated"
}

# --- Prompt Fields ---

resource "authentik_stage_prompt_field" "settings-name" {
  name                     = "settings-field-name"
  field_key                = "name"
  label                    = "Name"
  type                     = "text"
  required                 = true
  initial_value            = <<-EOT
    try:
        return user.name
    except:
        return ''
  EOT
  initial_value_expression = true
  order                    = 200
}

resource "authentik_stage_prompt_field" "settings-email" {
  name                     = "settings-field-email"
  field_key                = "email"
  label                    = "Email"
  type                     = "email"
  required                 = true
  initial_value            = <<-EOT
    try:
        return user.email
    except:
        return ''
  EOT
  initial_value_expression = true
  order                    = 201
}

resource "authentik_stage_prompt_field" "settings-locale" {
  name                     = "settings-field-locale"
  field_key                = "attributes.settings.locale"
  label                    = "Locale"
  type                     = "ak-locale"
  required                 = true
  initial_value            = <<-EOT
    try:
        return user.attributes.get("settings", {}).get("locale", "")
    except:
        return ''
  EOT
  initial_value_expression = true
  order                    = 202
}

# --- Validation Policy ---

import {
  to = authentik_policy_expression.settings-authorization
  id = "4e8fa399-cb09-493f-a2ea-6e0f7f58da5f"
}

resource "authentik_policy_expression" "settings-authorization" {
  name       = "settings-authorization"
  expression = <<-EOT
    from authentik.core.models import (
        USER_ATTRIBUTE_CHANGE_EMAIL,
        USER_ATTRIBUTE_CHANGE_NAME,
        USER_ATTRIBUTE_CHANGE_USERNAME
    )
    prompt_data = request.context.get("prompt_data")

    if not request.user.group_attributes(request.http_request).get(
        USER_ATTRIBUTE_CHANGE_EMAIL, request.http_request.tenant.default_user_change_email
    ):
        if prompt_data.get("email") != request.user.email:
            ak_message("Not allowed to change email address.")
            return False

    if not request.user.group_attributes(request.http_request).get(
        USER_ATTRIBUTE_CHANGE_NAME, request.http_request.tenant.default_user_change_name
    ):
        if prompt_data.get("name") != request.user.name:
            ak_message("Not allowed to change name.")
            return False

    return True
  EOT
}

# --- Stages ---

import {
  to = authentik_stage_prompt.settings
  id = "35b3b5ab-e456-4c79-860c-fdef578b82f6"
}

resource "authentik_stage_prompt" "settings" {
  name = "settings-profile-prompt"
  fields = [
    authentik_stage_prompt_field.settings-name.id,
    authentik_stage_prompt_field.settings-email.id,
    authentik_stage_prompt_field.settings-locale.id,
  ]
  validation_policies = [
    authentik_policy_expression.settings-authorization.id,
  ]
}

import {
  to = authentik_stage_user_write.settings
  id = "fce1e02b-fc4b-4fb0-b204-956dc0e48c9e"
}

resource "authentik_stage_user_write" "settings" {
  name               = "settings-user-write"
  user_creation_mode = "never_create"
}

# --- Flow Stage Bindings ---

import {
  to = authentik_flow_stage_binding.settings-profile
  id = "c127a948-26db-4b40-b407-b38a8621c21b"
}

resource "authentik_flow_stage_binding" "settings-profile" {
  target = authentik_flow.user-settings.uuid
  stage  = authentik_stage_prompt.settings.id
  order  = 20
}

import {
  to = authentik_flow_stage_binding.settings-write
  id = "46c4ef3e-16a6-4c8b-a142-b9de4b80aed1"
}

resource "authentik_flow_stage_binding" "settings-write" {
  target = authentik_flow.user-settings.uuid
  stage  = authentik_stage_user_write.settings.id
  order  = 100
}
