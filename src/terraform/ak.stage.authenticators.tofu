# Authenticator setup stages and flows
# Each authenticator has a dedicated setup flow (designation: stage_configuration)
# that can be used for initial setup, change, or re-registration.

# =============================================================================
# TOTP
# =============================================================================

import {
  to = authentik_flow.authenticator-totp-setup
  id = "default-authenticator-totp-setup"
}

resource "authentik_flow" "authenticator-totp-setup" {
  name               = "TOTP Setup"
  slug               = "authenticator-totp-setup"
  title              = "Set up time-based authentication"
  designation        = "stage_configuration"
  authentication     = "require_authenticated"
  policy_engine_mode = "any"
}

import {
  to = authentik_stage_authenticator_totp.totp
  id = "98307690-c0da-4036-92a4-3d9dc5149460"
}

resource "authentik_stage_authenticator_totp" "totp" {
  name           = "totp-setup"
  friendly_name  = "Configure time-based one-time passcodes (TOTP)"
  digits         = 6
  configure_flow = authentik_flow.authenticator-totp-setup.uuid
}

import {
  to = authentik_flow_stage_binding.authenticator-totp-setup
  id = "1e603491-e70d-4e45-854d-3a3bc5623fb3"
}

resource "authentik_flow_stage_binding" "authenticator-totp-setup" {
  target = authentik_flow.authenticator-totp-setup.uuid
  stage  = authentik_stage_authenticator_totp.totp.id
  order  = 0
}

# =============================================================================
# Duo
# =============================================================================

resource "authentik_flow" "authenticator-duo-setup" {
  name               = "Duo Setup"
  slug               = "authenticator-duo-setup"
  title              = "Set up Duo authentication"
  designation        = "stage_configuration"
  authentication     = "require_authenticated"
  policy_engine_mode = "any"
}

resource "authentik_stage_authenticator_duo" "duo" {
  name           = "duo-setup"
  friendly_name  = "Configure Duo push notifications"
  client_id      = data.sops_file.secrets.data["duo.client-id"]
  client_secret  = data.sops_file.secrets.data["duo.client-secret"]
  api_hostname   = data.sops_file.secrets.data["duo.api-hostname"]
  configure_flow = authentik_flow.authenticator-duo-setup.uuid
}

resource "authentik_flow_stage_binding" "authenticator-duo-setup" {
  target = authentik_flow.authenticator-duo-setup.uuid
  stage  = authentik_stage_authenticator_duo.duo.id
  order  = 0
}

# =============================================================================
# WebAuthn (Passkey)
# =============================================================================

import {
  to = authentik_flow.authenticator-webauthn-setup
  id = "default-authenticator-webauthn-setup"
}

resource "authentik_flow" "authenticator-webauthn-setup" {
  name               = "Passkey Setup"
  slug               = "authenticator-webauthn-setup"
  title              = "Set up a passkey"
  designation        = "stage_configuration"
  authentication     = "require_authenticated"
  policy_engine_mode = "any"
}

import {
  to = authentik_stage_authenticator_webauthn.webauthn
  id = "0b7fb286-09b2-4142-86be-5e56058073ec"
}

resource "authentik_stage_authenticator_webauthn" "webauthn" {
  name                     = "webauthn-setup"
  friendly_name            = "Configure a passkey (WebAuthn)"
  configure_flow           = authentik_flow.authenticator-webauthn-setup.uuid
  user_verification        = "preferred"
  resident_key_requirement = "preferred"
}

import {
  to = authentik_flow_stage_binding.authenticator-webauthn-setup
  id = "00c1ba7f-b284-4221-962e-1b8fe36d26a4"
}

resource "authentik_flow_stage_binding" "authenticator-webauthn-setup" {
  target = authentik_flow.authenticator-webauthn-setup.uuid
  stage  = authentik_stage_authenticator_webauthn.webauthn.id
  order  = 0
}

# =============================================================================
# Static Recovery Codes
# =============================================================================

import {
  to = authentik_flow.authenticator-static-setup
  id = "default-authenticator-static-setup"
}

resource "authentik_flow" "authenticator-static-setup" {
  name               = "Recovery Codes Setup"
  slug               = "authenticator-static-setup"
  title              = "Set up recovery codes"
  designation        = "stage_configuration"
  authentication     = "require_authenticated"
  policy_engine_mode = "any"
}

import {
  to = authentik_stage_authenticator_static.static
  id = "e41e63f8-86e5-43d8-b4e1-1ff14ce1c7d6"
}

resource "authentik_stage_authenticator_static" "static" {
  name           = "static-setup"
  friendly_name  = "Recovery codes"
  token_count    = 12
  configure_flow = authentik_flow.authenticator-static-setup.uuid
}

import {
  to = authentik_flow_stage_binding.authenticator-static-setup
  id = "db128114-0aa6-4f0c-93df-b12bd1a80220"
}

resource "authentik_flow_stage_binding" "authenticator-static-setup" {
  target = authentik_flow.authenticator-static-setup.uuid
  stage  = authentik_stage_authenticator_static.static.id
  order  = 0
}
