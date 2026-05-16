locals {
  service-names = split(" ",
    lookup(data.consul_services.da.tags, "authentik.enable=true", "")
  )

  service-tags = {
    for name in local.service-names :
    name => [
      for tag, services in data.consul_services.da.tags :
      replace(tag, "authentik.", "")
      if strcontains(services, name) && startswith(tag, "authentik.")
    ]
  }

  services = {
    for service, tags in local.service-tags : service => {
      for tag in tags :
      regex("([^=]+)=.*$", tag)[0] => regex("[^=]+=(.*)$", tag)[0]
    }
  }

  apps = {
    for service, tags in local.services : service => {
      name       = lookup(tags, "name", service)
      group      = lookup(tags, "group", "Ungrouped")
      type       = lookup(tags, "type", "proxy")
      icon       = lookup(tags, "icon", service)
      access     = split(",", lookup(tags, "access", "users"))
      skip_paths = lookup(tags, "skip-paths", null)
      basic_auth = {
        enabled  = lookup(tags, "basic-auth.enabled", "false") == "true"
        username = lookup(tags, "basic-auth.username", "username")
        password = lookup(tags, "basic-auth.password", "password")
      }
      url = {
        int = lookup(tags, "url.int", "")
        ext = lookup(tags, "url.ext", "")
      }
      # Pre-expanded by `mk-authentik` (one entry per (template × subdomain)
      # pair, joined by `;` to avoid clashing with the `,` delimiter used for
      # `access`).
      redirect_uris = [
        for u in split(";", lookup(tags, "redirect-uris", "")) :
        u if u != ""
      ]
    }
  }
}

module "authentik-app" {
  source   = "./app"
  for_each = local.apps

  name            = each.value.name
  group           = each.value.group
  type            = each.value.type
  icon            = each.value.icon
  internal        = each.value.url.int
  external        = each.value.url.ext
  launch_url      = each.value.url.ext
  skip_path_regex = each.value.skip_paths
  access_group    = [for access in each.value.access : local.groups[access].id]
  basic_auth      = each.value.basic_auth
  redirect_uris   = each.value.redirect_uris
  signing_key     = authentik_certificate_key_pair.wildcard.id

  flows = {
    ldap = {
      bind   = authentik_flow.ldap.uuid
      unbind = authentik_flow.invalidation.uuid
    }
    proxy = {
      authorization = authentik_flow.authz-explicit.uuid
      invalidation  = authentik_flow.invalidation.uuid
    }
    oauth = {
      authentication = authentik_flow.authn.uuid
      authorization  = authentik_flow.authz-explicit.uuid
      invalidation   = authentik_flow.invalidation.uuid
    }
  }

  property_mappings = [
    authentik_property_mapping_provider_scope.openid.id,
    authentik_property_mapping_provider_scope.email.id,
    authentik_property_mapping_provider_scope.profile.id,
    authentik_property_mapping_provider_scope.groups.id,
  ]
}

module "authentik-app-tailscale" {
  source = "./app"

  name  = "Tailscale"
  group = "Compute"
  type  = "oauth"
  icon  = "di:tailscale"
  access_group = [
    local.groups["admin"].id,
    local.groups["family"].id,
    local.groups["compute"].id,
    local.groups["minecraft"].id,
  ]
  redirect_uris = [
    "https://login.tailscale.com/a/oauth_response",
  ]
  signing_key = authentik_certificate_key_pair.wildcard.id

  flows = {
    ldap = {
      bind   = authentik_flow.ldap.uuid
      unbind = authentik_flow.invalidation.uuid
    }
    proxy = {
      authorization = authentik_flow.authz-explicit.uuid
      invalidation  = authentik_flow.invalidation.uuid
    }
    oauth = {
      authentication = authentik_flow.authn.uuid
      authorization  = authentik_flow.authz-explicit.uuid
      invalidation   = authentik_flow.invalidation.uuid
    }
  }

  property_mappings = [
    authentik_property_mapping_provider_scope.openid.id,
    authentik_property_mapping_provider_scope.email.id,
    authentik_property_mapping_provider_scope.profile.id,
    authentik_property_mapping_provider_scope.groups.id,
  ]
}
