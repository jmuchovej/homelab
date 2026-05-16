# OAuth/OIDC scope mappings — owned wholesale by tofu (no import, no reliance on
# authentik's managed `goauthentik.io/providers/oauth2/scope-*` defaults). Names are
# deliberately custom so they don't collide with authentik's shipped mappings.

resource "authentik_property_mapping_provider_scope" "profile" {
  name        = "OIDC profile"
  description = "General Profile Information"
  scope_name  = "profile"
  expression  = <<-EOF
    # Fall back through name -> username -> email so the `name` claim is
    # always non-empty regardless of how the user was provisioned (local,
    # LDAP, SCIM, OIDC source).
    name = request.user.name or request.user.username or request.user.email
    (given_name, *family_name) = request.user.name.split(" ")
    return {
      "name": name,
      "given_name": given_name or "",
      "family_name": family_name or "",
      "preferred_username": request.user.username,
      "nickname": request.user.username,
      "groups": [group.name for group in request.user.groups.all()],
    }
  EOF
}

resource "authentik_property_mapping_provider_scope" "email" {
  name        = "OIDC email"
  description = "Email address"
  scope_name  = "email"
  expression  = <<-EOF
    return {
      "email": request.user.email,
      "email_verified": False
    }
  EOF
}

resource "authentik_property_mapping_provider_scope" "openid" {
  name       = "OIDC openid"
  scope_name = "openid"
  expression = <<-EOF
    # This scope is required by the OpenID-spec, and must as such exist in authentik.
    # The scope by itself does not grant any information
    return {}
  EOF
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
