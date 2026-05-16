data "authentik_property_mapping_provider_scope" "oidc" {
  managed_list = [
    "goauthentik.io/providers/oauth2/scope-email",
    "goauthentik.io/providers/oauth2/scope-openid",
    "goauthentik.io/providers/oauth2/scope-profile",
  ]
}

import {
  to = authentik_property_mapping_provider_scope.profile
  id = "5ac73f1b-086f-4533-a5d5-0f879ce57e47"
}

resource "authentik_property_mapping_provider_scope" "profile" {
  name        = "authentik default OAuth Mapping: OpenID 'profile'"
  description = "General Profile Information"
  scope_name  = "profile"
  expression  = <<-EOF
    # Fall back through name -> username -> email so the `name` claim is
    # always non-empty regardless of how the user was provisioned (local,
    # LDAP, SCIM, OIDC source).
    name = request.user.name or request.user.username or request.user.email
    return {
      "name": name,
      "given_name": name,
      "family_name": "",
      "preferred_username": request.user.username,
      "nickname": request.user.username,
      "groups": [group.name for group in request.user.groups.all()],
    }
  EOF
}

import {
  to = authentik_property_mapping_provider_scope.email
  id = "54ec3d78-f5d3-43a2-a2da-d108fb14130e"
}

resource "authentik_property_mapping_provider_scope" "email" {
  name        = "authentik default OAuth Mapping: OpenID 'email'"
  description = "Email address"
  scope_name  = "email"
  expression  = <<-EOF
    return {
      "email": request.user.email,
      "email_verified": False
    }
  EOF
}

import {
  to = authentik_property_mapping_provider_scope.openid
  id = "bbf3fe6b-0b16-43e7-a046-d0b60c8a43e9"
}

resource "authentik_property_mapping_provider_scope" "openid" {
  name       = "authentik default OAuth Mapping: OpenID 'openid'"
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
