locals {
  proxy-providers = [
    for name, app in module.authentik-app :
    app.provider_id
    if local.apps[name].type == "proxy"
  ]
  ldap-providers = [
    for name, app in module.authentik-app :
    app.provider_id
    if local.apps[name].type == "ldap"
  ]
  radius-providers = [
    for name, app in module.authentik-app :
    app.provider_id
    if local.apps[name].type == "radius"
  ]
}

resource "authentik_outpost" "proxy" {
  count = length(local.proxy-providers) > 0 ? 1 : 0
  name  = "Proxy"
  type  = "proxy"
  config = jsonencode({
    "authentik_host" : "https://id.${local.domain.dc}",
    "authentik_host_insecure" : false,
    "authentik_host_browser" : "https://id.${local.domain.dc}",
    "log_level" : "info",
  })
  protocol_providers = local.proxy-providers
}

resource "authentik_outpost" "ldap" {
  count = length(local.ldap-providers) > 0 ? 1 : 0
  name  = "LDAP"
  type  = "ldap"
  config = jsonencode({
    "authentik_host" : "https://id.${local.domain.dc}",
    "authentik_host_insecure" : false,
    "authentik_host_browser" : "https://id.${local.domain.dc}",
    "log_level" : "info",
  })
  protocol_providers = local.ldap-providers
}

resource "authentik_outpost" "radius" {
  count = length(local.radius-providers) > 0 ? 1 : 0
  name  = "RADIUS"
  type  = "radius"
  config = jsonencode({
    "authentik_host" : "https://id.${local.domain.dc}",
    "authentik_host_insecure" : false,
    "authentik_host_browser" : "https://id.${local.domain.dc}",
    "log_level" : "info",
  })
  protocol_providers = local.radius-providers
}
