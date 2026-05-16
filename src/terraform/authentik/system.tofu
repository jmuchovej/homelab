resource "authentik_brand" "default" {
  default             = false
  domain              = var.domain.da
  branding_logo       = "icon.png"
  branding_favicon    = "icon.png"
  branding_title      = "The Rebellion"
  flow_authentication = authentik_flow.authn.uuid
  flow_invalidation   = authentik_flow.invalidation.uuid
  flow_user_settings  = authentik_flow.user-settings.uuid
  flow_recovery       = authentik_flow.recovery.uuid
  flow_unenrollment   = authentik_flow.unenrollment.uuid
  default_application = module.authentik-app-tailscale.uuid
}

# Brand for external access via Cloudflare tunnel
resource "authentik_brand" "external" {
  default             = false
  domain              = var.domain.root
  branding_logo       = "icon.png"
  branding_favicon    = "icon.png"
  branding_title      = "The Rebellion"
  flow_authentication = authentik_flow.authn.uuid
  flow_invalidation   = authentik_flow.invalidation.uuid
  flow_user_settings  = authentik_flow.user-settings.uuid
  flow_recovery       = authentik_flow.recovery.uuid
  flow_unenrollment   = authentik_flow.unenrollment.uuid
  default_application = module.authentik-app-tailscale.uuid
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
  flags = jsonencode({
    core_default_app_access                = false,
    enterprise_audit_include_expanded_diff = false,
    flows_continuous_login                 = false,
    flows_refresh_others                   = false,
  })
}

resource "authentik_certificate_key_pair" "wildcard" {
  name             = "Wildcard Certificate for ${var.domain.da}"
  certificate_data = data.sops_file.da.data["certs.lab.crt"]
  key_data         = data.sops_file.da.data["certs.lab.key"]
}
