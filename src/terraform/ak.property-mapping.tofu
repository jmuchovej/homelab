data "authentik_property_mapping_provider_scope" "oidc" {
  managed_list = [
    "goauthentik.io/providers/oauth2/scope-email",
    "goauthentik.io/providers/oauth2/scope-openid",
    "goauthentik.io/providers/oauth2/scope-profile",
  ]
}

resource "authentik_property_mapping_provider_scope" "groups" {
  name       = "groups"
  scope_name = "groups"
  expression = <<-EOF
    return {
      "groups": [group.name for group in request.user.ak_groups.all()],
    }
  EOF
}
