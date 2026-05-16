# Authenticator setup flows + stages.
# TOTP / static / webauthn adopt authentik's `default-authenticator-*-setup`
# (imported at root in ak.tofu). Duo is OURS (authentik ships no default) —
# created, no import.

resource "authentik_flow" "authenticator-totp-setup" {
  name               = "TOTP Setup"
  slug               = "default-authenticator-totp-setup"
  title              = "Set up time-based authentication"
  designation        = "stage_configuration"
  authentication     = "require_authenticated"
  policy_engine_mode = "any"
}

resource "authentik_stage_authenticator_totp" "totp" {
  name           = "default-authenticator-totp-setup"
  friendly_name  = "Time-based One-Time Passcodes (TOTP)"
  digits         = 6
  configure_flow = authentik_flow.authenticator-totp-setup.uuid
}

resource "authentik_flow_stage_binding" "authenticator-totp-setup" {
  target = authentik_flow.authenticator-totp-setup.uuid
  stage  = authentik_stage_authenticator_totp.totp.id
  order  = 0
}

# Duo — ours, no authentik default. Created, not imported.
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
  friendly_name  = "Duo (Push)"
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

resource "authentik_flow" "authenticator-webauthn-setup" {
  name               = "Passkey Setup"
  slug               = "default-authenticator-webauthn-setup"
  title              = "Set up a passkey"
  designation        = "stage_configuration"
  authentication     = "require_authenticated"
  policy_engine_mode = "any"
}

resource "authentik_stage_authenticator_webauthn" "webauthn" {
  name                     = "default-authenticator-webauthn-setup"
  friendly_name            = "Passkey (WebAuthn)"
  configure_flow           = authentik_flow.authenticator-webauthn-setup.uuid
  user_verification        = "preferred"
  resident_key_requirement = "preferred"
}

resource "authentik_flow_stage_binding" "authenticator-webauthn-setup" {
  target = authentik_flow.authenticator-webauthn-setup.uuid
  stage  = authentik_stage_authenticator_webauthn.webauthn.id
  order  = 0
}

resource "authentik_flow" "authenticator-static-setup" {
  name               = "Recovery Codes Setup"
  slug               = "default-authenticator-static-setup"
  title              = "Set up recovery codes"
  designation        = "stage_configuration"
  authentication     = "require_authenticated"
  policy_engine_mode = "any"
}

resource "authentik_stage_authenticator_static" "static" {
  name           = "default-authenticator-static-setup"
  friendly_name  = "Static Recovery Codes"
  token_count    = 12
  configure_flow = authentik_flow.authenticator-static-setup.uuid
}

resource "authentik_flow_stage_binding" "authenticator-static-setup" {
  target = authentik_flow.authenticator-static-setup.uuid
  stage  = authentik_stage_authenticator_static.static.id
  order  = 0
}
