terraform {
  required_providers {
    sops      = { source = "carlpett/sops" }
    authentik = { source = "goauthentik/authentik" }
  }
}

locals {
  slug = replace(replace(lower(var.name), " ", "-"), "/[^-a-z0-9]/", "")
}

data "sops_file" "authentik" {
  source_file = "${path.root}/secrets/authentik.sops.yaml"
}

resource "authentik_provider_ldap" "provider" {
  count       = var.type == "ldap" ? 1 : 0
  name        = "tf-${local.slug}-ldap"
  base_dn     = "dc=${local.slug}"
  bind_flow   = var.flows.ldap.bind
  unbind_flow = var.flows.ldap.unbind
  # https://docs.goauthentik.io/add-secure-apps/providers/ldap/#searching--search-modes
  # search_group = var.access_group[0]
  search_mode = "direct"
  bind_mode   = "direct"
}

resource "authentik_provider_proxy" "provider" {
  count                         = var.type == "proxy" ? 1 : 0
  name                          = "tf-${local.slug}-proxy"
  internal_host                 = var.internal == "" ? null : var.internal
  external_host                 = var.external
  mode                          = "forward_single"
  authorization_flow            = var.flows.proxy.authorization
  invalidation_flow             = var.flows.proxy.invalidation
  skip_path_regex               = var.skip_path_regex
  internal_host_ssl_validation  = var.internal_host_ssl_validation
  jwks_sources                  = var.jwks_sources
  basic_auth_enabled            = var.basic_auth.enabled
  basic_auth_username_attribute = var.basic_auth.username
  basic_auth_password_attribute = var.basic_auth.password

  lifecycle {
    ignore_changes = [jwks_sources]
  }
}

resource "authentik_provider_oauth2" "provider" {
  count                      = var.type == "oauth" ? 1 : 0
  name                       = "tf-${local.slug}-oauth"
  client_id                  = data.sops_file.authentik.data["${local.slug}.client-id"]
  client_secret              = data.sops_file.authentik.data["${local.slug}.client-secret"]
  authorization_flow         = var.flows.oauth.authorization
  authentication_flow        = var.flows.oauth.authentication
  invalidation_flow          = var.flows.oauth.invalidation
  include_claims_in_id_token = true
  sub_mode                   = var.sub_mode
  signing_key                = var.signing_key
  property_mappings          = var.property_mappings
}

locals {
  providers = {
    "proxy" : one(authentik_provider_proxy.provider[*]),
    "oauth" : one(authentik_provider_oauth2.provider[*]),
    "ldap" : one(authentik_provider_ldap.provider[*]),
  }
  provider = local.providers[var.type]

  _icon    = try(split(":", var.icon)[1], var.icon)
  _library = try(split(":", var.icon)[0], var.icon)
  app-icon = {
    "di" : "di/${var.suffix}/${local._icon}.${var.suffix}"
    "sh" : "sh/${var.suffix}/${local._icon}.${var.suffix}"
  }
  library = contains(keys(local.app-icon), local._library) ? local._library : "di"
}

resource "authentik_application" "app" {
  name              = var.name
  slug              = "${local.slug}-${var.type}"
  protocol_provider = local.provider.id
  meta_icon         = local.app-icon[local.library]
  meta_publisher    = var.publisher
  meta_launch_url   = var.launch_url
  group             = var.group
}

resource "authentik_policy_binding" "app-access" {
  for_each = tomap({ for idx, group in var.access_group : idx => group })
  target   = authentik_application.app.uuid
  group    = each.value
  order    = index(var.access_group, each.value) + 100
}
