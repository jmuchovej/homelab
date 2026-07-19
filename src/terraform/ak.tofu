provider "authentik" {
  url   = "https://id.${local.domain.da}"
  token = data.sops_file.secrets.data["authentik.token"]
}

module "authentik" {
  source = "./authentik"

  providers = {
    sops      = sops
    authentik = authentik
  }

  domain      = local.domain
  permissions = var.authentik-builtins.permissions
}

import {
  to = module.authentik.authentik_flow.invalidation
  id = "default-invalidation-flow"
}
import {
  to = module.authentik.authentik_stage_user_logout.invalidation
  id = var.authentik-builtins.stages["default-invalidation-logout"]
}
import {
  to = module.authentik.authentik_flow_stage_binding.invalidation-logout
  id = var.authentik-builtins.bindings["default-invalidation-flow|0"]
}

import {
  to = module.authentik.authentik_flow.authz-explicit
  id = "default-provider-authorization-explicit-consent"
}
import {
  to = module.authentik.authentik_stage_consent.authz-explicit
  id = var.authentik-builtins.stages["default-provider-authorization-consent"]
}
import {
  to = module.authentik.authentik_flow_stage_binding.authz-explicit-consent
  id = var.authentik-builtins.bindings["default-provider-authorization-explicit-consent|0"]
}
import {
  to = module.authentik.authentik_flow.authz-implicit
  id = "default-provider-authorization-implicit-consent"
}

import {
  to = module.authentik.authentik_flow.authenticator-totp-setup
  id = "default-authenticator-totp-setup"
}
import {
  to = module.authentik.authentik_stage_authenticator_totp.totp
  id = var.authentik-builtins.stages["default-authenticator-totp-setup"]
}
import {
  to = module.authentik.authentik_flow_stage_binding.authenticator-totp-setup
  id = var.authentik-builtins.bindings["default-authenticator-totp-setup|0"]
}
import {
  to = module.authentik.authentik_flow.authenticator-static-setup
  id = "default-authenticator-static-setup"
}
import {
  to = module.authentik.authentik_stage_authenticator_static.static
  id = var.authentik-builtins.stages["default-authenticator-static-setup"]
}
import {
  to = module.authentik.authentik_flow_stage_binding.authenticator-static-setup
  id = var.authentik-builtins.bindings["default-authenticator-static-setup|0"]
}
import {
  to = module.authentik.authentik_flow.authenticator-webauthn-setup
  id = "default-authenticator-webauthn-setup"
}
import {
  to = module.authentik.authentik_stage_authenticator_webauthn.webauthn
  id = var.authentik-builtins.stages["default-authenticator-webauthn-setup"]
}
import {
  to = module.authentik.authentik_flow_stage_binding.authenticator-webauthn-setup
  id = var.authentik-builtins.bindings["default-authenticator-webauthn-setup|0"]
}

# Password-change flow
import {
  to = module.authentik.authentik_flow.password-change
  id = "default-password-change"
}
import {
  to = module.authentik.authentik_policy_password.password-policy
  id = var.authentik-builtins.policies["default-password-change-password-policy"]
}
import {
  to = module.authentik.authentik_stage_prompt_field.password-change
  id = var.authentik-builtins.prompt_fields["default-password-change-field-password"]
}
import {
  to = module.authentik.authentik_stage_prompt_field.password-change-repeat
  id = var.authentik-builtins.prompt_fields["default-password-change-field-password-repeat"]
}
import {
  to = module.authentik.authentik_stage_prompt.password-change
  id = var.authentik-builtins.stages["default-password-change-prompt"]
}
import {
  to = module.authentik.authentik_stage_user_write.password-change
  id = var.authentik-builtins.stages["default-password-change-write"]
}
import {
  to = module.authentik.authentik_flow_stage_binding.password-change-prompt
  id = var.authentik-builtins.bindings["default-password-change|0"]
}
import {
  to = module.authentik.authentik_flow_stage_binding.password-change-write
  id = var.authentik-builtins.bindings["default-password-change|1"]
}

# User-settings flow (username prompt field left unmanaged)
import {
  to = module.authentik.authentik_flow.user-settings
  id = "default-user-settings-flow"
}
import {
  to = module.authentik.authentik_stage_prompt_field.settings-name
  id = var.authentik-builtins.prompt_fields["default-user-settings-field-name"]
}
import {
  to = module.authentik.authentik_stage_prompt_field.settings-email
  id = var.authentik-builtins.prompt_fields["default-user-settings-field-email"]
}
import {
  to = module.authentik.authentik_stage_prompt_field.settings-locale
  id = var.authentik-builtins.prompt_fields["default-user-settings-field-locale"]
}
import {
  to = module.authentik.authentik_policy_expression.settings-authorization
  id = var.authentik-builtins.policies["default-user-settings-authorization"]
}
import {
  to = module.authentik.authentik_stage_prompt.settings
  id = var.authentik-builtins.stages["default-user-settings"]
}
import {
  to = module.authentik.authentik_stage_user_write.settings
  id = var.authentik-builtins.stages["default-user-settings-write"]
}
import {
  to = module.authentik.authentik_flow_stage_binding.settings-profile
  id = var.authentik-builtins.bindings["default-user-settings-flow|20"]
}
import {
  to = module.authentik.authentik_flow_stage_binding.settings-write
  id = var.authentik-builtins.bindings["default-user-settings-flow|100"]
}

# Authentication flow (captcha stage/binding/policy/policy-binding are ours — not imported)
import {
  to = module.authentik.authentik_flow.authn
  id = "default-authentication-flow"
}
import {
  to = module.authentik.authentik_stage_identification.authn
  id = var.authentik-builtins.stages["default-authentication-identification"]
}
import {
  to = module.authentik.authentik_stage_password.authn
  id = var.authentik-builtins.stages["default-authentication-password"]
}
import {
  to = module.authentik.authentik_stage_authenticator_validate.authn-mfa
  id = var.authentik-builtins.stages["default-authentication-mfa-validation"]
}
import {
  to = module.authentik.authentik_stage_user_login.authn
  id = var.authentik-builtins.stages["default-authentication-login"]
}
import {
  to = module.authentik.authentik_flow_stage_binding.authn-identification
  id = var.authentik-builtins.bindings["default-authentication-flow|10"]
}
import {
  to = module.authentik.authentik_flow_stage_binding.authn-password
  id = var.authentik-builtins.bindings["default-authentication-flow|20"]
}
import {
  to = module.authentik.authentik_flow_stage_binding.authn-mfa
  id = var.authentik-builtins.bindings["default-authentication-flow|30"]
}
import {
  to = module.authentik.authentik_flow_stage_binding.authn-login
  id = var.authentik-builtins.bindings["default-authentication-flow|100"]
}
import {
  to = module.authentik.authentik_policy_expression.authn-password-required
  id = var.authentik-builtins.policies["default-authentication-flow-password-stage"]
}
import {
  to = module.authentik.authentik_policy_expression.authn-mfa-required
  id = var.authentik-builtins.policies["default-authentication-flow-authenticator-validate-stage"]
}
import {
  to = module.authentik.authentik_policy_binding.authn-password-required
  id = var.authentik-builtins.policy_bindings["default-authentication-flow|20|default-authentication-flow-password-stage"]
}
import {
  to = module.authentik.authentik_policy_binding.authn-mfa-required
  id = var.authentik-builtins.policy_bindings["default-authentication-flow|30|default-authentication-flow-authenticator-validate-stage"]
}
