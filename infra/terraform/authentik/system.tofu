resource "authentik_brand" "default" {
  default             = false
  domain              = var.domain.dc
  branding_logo       = "media/public/icon.png"
  branding_favicon    = "media/public/icon.png"
  branding_title      = "The Rebellion"
  flow_authentication = data.authentik_flow.authn.id
  flow_user_settings  = data.authentik_flow.user-settings.id
}

# Brand for external access via Cloudflare tunnel
resource "authentik_brand" "external" {
  default             = false
  domain              = var.domain.root
  branding_logo       = "media/public/icon.png"
  branding_favicon    = "media/public/icon.png"
  branding_title      = "The Rebellion"
  flow_authentication = data.authentik_flow.authn.id
  flow_user_settings  = data.authentik_flow.user-settings.id
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
  name             = "Wildcard Certificate for ${var.domain.dc}"
  certificate_data = data.sops_file.dc.data["certs.lab.crt"]
  key_data         = data.sops_file.dc.data["certs.lab.key"]
}
