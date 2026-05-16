resource "authentik_brand" "default" {
  default             = false
  domain              = local.domain.dc
  branding_logo       = "icon.png"
  branding_favicon    = "icon.png"
  branding_title      = "The Rebellion"
  flow_authentication = authentik_flow.authn.uuid
  flow_invalidation   = authentik_flow.invalidation.uuid
  flow_user_settings  = authentik_flow.user-settings.uuid
  flow_recovery       = authentik_flow.recovery.uuid
  flow_unenrollment   = authentik_flow.unenrollment.uuid
}

# Brand for external access via Cloudflare tunnel
resource "authentik_brand" "external" {
  default             = false
  domain              = local.domain.root
  branding_logo       = "icon.png"
  branding_favicon    = "icon.png"
  branding_title      = "The Rebellion"
  flow_authentication = authentik_flow.authn.uuid
  flow_invalidation   = authentik_flow.invalidation.uuid
  flow_user_settings  = authentik_flow.user-settings.uuid
  flow_recovery       = authentik_flow.recovery.uuid
  flow_unenrollment   = authentik_flow.unenrollment.uuid
}

resource "authentik_system_settings" "default" {
  event_retention              = "days=730" # 2 years
  avatars                      = "gravatar,initials"
  default_token_duration       = "minutes=30"
  default_token_length         = 60
  default_user_change_email    = true
  default_user_change_name     = true
  default_user_change_username = false
  gdpr_compliance              = true
  pagination_default_page_size = 200
  pagination_max_page_size     = 1000
}

resource "authentik_certificate_key_pair" "wildcard" {
  name             = "Wildcard Certificate for ${local.domain.dc}"
  certificate_data = data.sops_file.dc.data["certs.lab.crt"]
  key_data         = data.sops_file.dc.data["certs.lab.key"]
}
