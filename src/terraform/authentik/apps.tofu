# Frozen entries cover apps not yet discovered from HTTPRoutes. Discovery
# wins on key collision, so an entry can be deleted once its route is labeled.
locals {
  apps = merge(local.frozen-apps, var.discovered-apps)

  frozen-apps = {
    openbao = {
      name       = "OpenBao"
      site       = "da"
      group      = "Compute"
      type       = "oauth"
      icon       = "sh:openbao"
      access     = ["compute", "compute-managers"]
      skip_paths = null
      basic_auth = {
        enabled  = false
        username = "username"
        password = "password"
      }
      url = {
        int = ""
        ext = "https://vault.${var.domain.da}"
      }
      redirect_uris = []
    }
    relay01 = {
      name       = "Router: Relay01"
      site       = "da"
      group      = "Home"
      type       = "proxy"
      icon       = "di:mikrotik"
      access     = ["compute-managers"]
      skip_paths = null
      basic_auth = {
        enabled  = false
        username = "username"
        password = "password"
      }
      url = {
        int = "https://da-relay01.${var.domain.holo}"
        ext = "https://da-relay01.${var.domain.holo}"
      }
      redirect_uris = []
    }
    relay02 = {
      name       = "Router: Relay02"
      site       = "da"
      group      = "Home"
      type       = "proxy"
      icon       = "di:mikrotik"
      access     = ["compute-managers"]
      skip_paths = null
      basic_auth = {
        enabled  = false
        username = "username"
        password = "password"
      }
      url = {
        int = "https://da-relay02.${var.domain.holo}"
        ext = "https://da-relay02.${var.domain.holo}"
      }
      redirect_uris = []
    }
    s3 = {
      name       = "MinIO"
      site       = "da"
      group      = "Compute"
      type       = "oauth"
      icon       = "di:minio"
      access     = ["compute-managers"]
      skip_paths = null
      basic_auth = {
        enabled  = false
        username = "username"
        password = "password"
      }
      url = {
        int = ""
        ext = "https://s3.${var.domain.da}"
      }
      redirect_uris = []
    }
    # Delete once the syncthing HTTPRoute is discovered.
    syncthing = {
      name       = "Syncthing"
      site       = "da"
      group      = "Sync"
      type       = "proxy"
      icon       = "di:syncthing"
      access     = ["syncthing"]
      skip_paths = null
      basic_auth = {
        enabled  = false
        username = "username"
        password = "password"
      }
      url = {
        int = "https://syncthing.${var.domain.da}"
        ext = "https://syncthing.${var.domain.da}"
      }
      redirect_uris = []
    }
  }
}

module "authentik-app" {
  source   = "./app"
  for_each = local.apps

  name            = each.value.name
  site            = each.value.site
  site-scoped     = try(each.value.site-scoped, false)
  group           = each.value.group
  type            = each.value.type
  client_type     = try(each.value.client_type, "confidential")
  icon            = each.value.icon
  internal        = each.value.url.int
  external        = each.value.url.ext
  launch_url      = each.value.url.ext
  skip_path_regex = each.value.skip_paths
  # `access` entries are `group:<key>`, `user:<key>`, or bare (== group).
  access_group  = [for a in each.value.access : local.groups[trimprefix(a, "group:")].id if !startswith(a, "user:")]
  access_user   = [for a in each.value.access : tonumber(authentik_user.u[trimprefix(a, "user:")].id) if startswith(a, "user:")]
  basic_auth    = each.value.basic_auth
  redirect_uris = each.value.redirect_uris
  signing_key   = authentik_certificate_key_pair.wildcard.id

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

  name = "Tailscale"
  # SaaS, not a workload at either site: it is reached at tailscale.com, so
  # there is nothing to suffix and no outpost to place.
  site  = "da"
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
