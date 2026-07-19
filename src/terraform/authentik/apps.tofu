# Frozen 2026-07-20 from the last consul-tag-discovered state (the mesh that
# published `authentik.*` tags is gone). Snapshot via `tofu show -json` —
# same for_each keys, so zero destroys. To migrate an entry: label+annotate
# its HTTPRoute (`authentik.rbn/*`), wait for Flux to apply it, then delete
# the frozen entry here — discovery wins on collision, so the plan stays
# zero-diff throughout.
locals {
  apps = merge(local.frozen-apps, var.discovered-apps)

  frozen-apps = {
    home-assistant = {
      name       = "Home Assistant"
      group      = "Home"
      type       = "oauth"
      icon       = "di:home-assistant"
      access     = ["home"]
      skip_paths = null
      basic_auth = {
        enabled  = false
        username = "username"
        password = "password"
      }
      url = {
        int = ""
        ext = "https://home.${var.domain.da}"
      }
      redirect_uris = ["https://home.${var.domain.da}/auth/oidc/callback"]
    }
    homebox = {
      name       = "homebox"
      group      = "Family"
      type       = "oauth"
      icon       = "di:homebox"
      access     = ["family"]
      skip_paths = null
      basic_auth = {
        enabled  = false
        username = "username"
        password = "password"
      }
      url = {
        int = ""
        ext = "https://homebox.${var.domain.da}"
      }
      redirect_uris = ["https://homebox.${var.domain.da}/api/v1/users/login/oidc/callback"]
    }
    hubitat = {
      name       = "hubitat"
      group      = "Home"
      type       = "proxy"
      icon       = "di:hubitat"
      access     = ["home"]
      skip_paths = "/apps/api/*"
      basic_auth = {
        enabled  = false
        username = "username"
        password = "password"
      }
      url = {
        int = "https://hubitat.${var.domain.da}"
        ext = "https://hubitat.${var.domain.da}"
      }
      redirect_uris = []
    }
    immich = {
      name       = "immich"
      group      = "Family"
      type       = "oauth"
      icon       = "di:immich"
      access     = ["family"]
      skip_paths = null
      basic_auth = {
        enabled  = false
        username = "username"
        password = "password"
      }
      url = {
        int = ""
        ext = "https://immich.${var.domain.da}"
      }
      redirect_uris = [
        "https://immich.${var.domain.da}/auth/login",
        "https://photos.${var.domain.da}/auth/login",
      ]
    }
    lidarr = {
      name       = "Lidarr"
      group      = "Media Management"
      type       = "proxy"
      icon       = "di:lidarr"
      access     = ["media-managers"]
      skip_paths = "/api/*"
      basic_auth = {
        enabled  = true
        username = "servarr-username"
        password = "servarr-password"
      }
      url = {
        int = "https://lidarr.${var.domain.da}"
        ext = "https://lidarr.${var.domain.da}"
      }
      redirect_uris = []
    }
    ollama = {
      name       = "Ollama"
      group      = "Compute"
      type       = "proxy"
      icon       = "di:ollama"
      access     = ["compute", "compute-managers"]
      skip_paths = null
      basic_auth = {
        enabled  = true
        username = "username"
        password = "password"
      }
      url = {
        int = "https://ollama.${var.domain.da}"
        ext = "https://ollama.${var.domain.da}"
      }
      redirect_uris = []
    }
    open-webui = {
      name       = "Open WebUI"
      group      = "Compute"
      type       = "oauth"
      icon       = "di:open-webui"
      access     = ["compute", "compute-managers"]
      skip_paths = null
      basic_auth = {
        enabled  = false
        username = "username"
        password = "password"
      }
      url = {
        int = ""
        ext = "https://chat.${var.domain.da}"
      }
      redirect_uris = ["https://chat.${var.domain.da}/oauth/oidc/callback"]
    }
    openbao = {
      name       = "OpenBao"
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
    prowlarr = {
      name       = "Prowlarr"
      group      = "Media Management"
      type       = "proxy"
      icon       = "di:prowlarr"
      access     = ["media-managers"]
      skip_paths = "/api/*"
      basic_auth = {
        enabled  = true
        username = "servarr-username"
        password = "servarr-password"
      }
      url = {
        int = "https://prowlarr.${var.domain.da}"
        ext = "https://prowlarr.${var.domain.da}"
      }
      redirect_uris = []
    }
    qbittorrent = {
      name       = "qBittorrent"
      group      = "Media Management"
      type       = "proxy"
      icon       = "di:qbittorrent"
      access     = ["media-managers"]
      skip_paths = "/api/*"
      basic_auth = {
        enabled  = true
        username = "servarr-username"
        password = "servarr-password"
      }
      url = {
        int = "https://qbittorrent.${var.domain.da}"
        ext = "https://qbittorrent.${var.domain.da}"
      }
      redirect_uris = []
    }
    radarr = {
      name       = "Radarr"
      group      = "Media Management"
      type       = "proxy"
      icon       = "di:radarr"
      access     = ["media-managers"]
      skip_paths = "/api/*"
      basic_auth = {
        enabled  = true
        username = "servarr-username"
        password = "servarr-password"
      }
      url = {
        int = "https://radarr.${var.domain.da}"
        ext = "https://radarr.${var.domain.da}"
      }
      redirect_uris = []
    }
    readarr = {
      name       = "Readarr"
      group      = "Media Management"
      type       = "proxy"
      icon       = "di:readarr"
      access     = ["media-managers"]
      skip_paths = "/api/*"
      basic_auth = {
        enabled  = true
        username = "servarr-username"
        password = "servarr-password"
      }
      url = {
        int = "https://readarr.${var.domain.da}"
        ext = "https://readarr.${var.domain.da}"
      }
      redirect_uris = []
    }
    relay01 = {
      name       = "Router: Relay01"
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
    sonarr = {
      name       = "Sonarr"
      group      = "Media Management"
      type       = "proxy"
      icon       = "di:sonarr"
      access     = ["media-managers"]
      skip_paths = "/api/*"
      basic_auth = {
        enabled  = true
        username = "servarr-username"
        password = "servarr-password"
      }
      url = {
        int = "https://sonarr.${var.domain.da}"
        ext = "https://sonarr.${var.domain.da}"
      }
      redirect_uris = []
    }
    split-pro = {
      name       = "Split Pro"
      group      = "Home"
      type       = "oauth"
      icon       = "di:spliit"
      access     = ["home"]
      skip_paths = null
      basic_auth = {
        enabled  = false
        username = "username"
        password = "password"
      }
      url = {
        int = ""
        ext = "https://split-pro.${var.domain.da}"
      }
      redirect_uris = ["https://split-pro.${var.domain.da}/api/auth/callback/the rebellion"]
    }
    syncthing = {
      name       = "Syncthing"
      group      = "Admin"
      type       = "proxy"
      icon       = "di:syncthing"
      access     = ["admin"]
      skip_paths = "/rest/*"
      basic_auth = {
        enabled  = true
        username = "username"
        password = "password"
      }
      url = {
        int = "https://syncthing.da-vcx-1.${var.domain.root}"
        ext = "https://syncthing.da-vcx-1.${var.domain.root}"
      }
      redirect_uris = []
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
