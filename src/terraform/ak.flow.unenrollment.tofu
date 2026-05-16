# Unenrollment (account deletion) flow
# Requires authentication. Confirms and deletes the user account.

resource "authentik_flow" "unenrollment" {
  name               = "Delete Account"
  slug               = "unenrollment"
  title              = "Delete your account"
  designation        = "unenrollment"
  authentication     = "require_authenticated"
  policy_engine_mode = "any"
}

resource "authentik_stage_consent" "unenrollment" {
  name = "unenrollment-confirm"
  mode = "always_require"
}

resource "authentik_stage_user_delete" "unenrollment" {
  name = "unenrollment-delete"
}

resource "authentik_flow_stage_binding" "unenrollment-confirm" {
  target = authentik_flow.unenrollment.uuid
  stage  = authentik_stage_consent.unenrollment.id
  order  = 0
}

resource "authentik_flow_stage_binding" "unenrollment-delete" {
  target = authentik_flow.unenrollment.uuid
  stage  = authentik_stage_user_delete.unenrollment.id
  order  = 10
}
