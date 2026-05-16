# User settings flow — adopt authentik's `default-user-settings-flow`
# (imported at root in ak.tofu). Names mirror authentik's defaults for a clean
# import; addresses kept. authentik also ships a `username` prompt field we don't
# manage — our prompt stage lists only name/email/locale, so it's left untouched.

resource "authentik_flow" "user-settings" {
  name               = "User Settings"
  title              = "Update your account"
  slug               = "default-user-settings-flow"
  designation        = "stage_configuration"
  policy_engine_mode = "any"
  denied_action      = "message_continue"
  layout             = "stacked"
  authentication     = "require_authenticated"
}

# --- Prompt Fields ---

resource "authentik_stage_prompt_field" "settings-name" {
  name                     = "default-user-settings-field-name"
  field_key                = "name"
  label                    = "Name"
  placeholder              = "Name"
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
  name                     = "default-user-settings-field-email"
  field_key                = "email"
  label                    = "Email"
  placeholder              = "Email"
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
  name                     = "default-user-settings-field-locale"
  field_key                = "attributes.settings.locale"
  label                    = "Locale"
  placeholder              = "Locale"
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

resource "authentik_policy_expression" "settings-authorization" {
  name       = "default-user-settings-authorization"
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

resource "authentik_stage_prompt" "settings" {
  name = "default-user-settings"
  fields = [
    authentik_stage_prompt_field.settings-name.id,
    authentik_stage_prompt_field.settings-email.id,
    authentik_stage_prompt_field.settings-locale.id,
  ]
  validation_policies = [
    authentik_policy_expression.settings-authorization.id,
  ]
}

resource "authentik_stage_user_write" "settings" {
  name               = "default-user-settings-write"
  user_creation_mode = "never_create"
}

# --- Flow Stage Bindings ---

resource "authentik_flow_stage_binding" "settings-profile" {
  target = authentik_flow.user-settings.uuid
  stage  = authentik_stage_prompt.settings.id
  order  = 20
}

resource "authentik_flow_stage_binding" "settings-write" {
  target = authentik_flow.user-settings.uuid
  stage  = authentik_stage_user_write.settings.id
  order  = 100
}
