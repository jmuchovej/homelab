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

# A local service connection lets authentik deploy and manage the outpost
# workloads itself, so no outpost tokens or manifests are handled here.
resource "authentik_service_connection_kubernetes" "local" {
  name  = "local-cluster"
  local = true
}

resource "authentik_outpost" "proxy" {
  count              = length(local.proxy-providers) > 0 ? 1 : 0
  name               = "Proxy"
  type               = "proxy"
  service_connection = authentik_service_connection_kubernetes.local.id
  config = jsonencode({
    "authentik_host" : "https://id.${var.domain.da}",
    "authentik_host_insecure" : false,
    "authentik_host_browser" : "https://id.${var.domain.da}",
    "log_level" : "info",
  })
  protocol_providers = local.proxy-providers
}

resource "authentik_outpost" "ldap" {
  count              = length(local.ldap-providers) > 0 ? 1 : 0
  name               = "LDAP"
  type               = "ldap"
  service_connection = authentik_service_connection_kubernetes.local.id
  config = jsonencode({
    "authentik_host" : "https://id.${var.domain.da}",
    "authentik_host_insecure" : false,
    "authentik_host_browser" : "https://id.${var.domain.da}",
    "log_level" : "info",
  })
  protocol_providers = local.ldap-providers
}

resource "authentik_outpost" "radius" {
  count              = length(local.radius-providers) > 0 ? 1 : 0
  name               = "RADIUS"
  type               = "radius"
  service_connection = authentik_service_connection_kubernetes.local.id
  config = jsonencode({
    "authentik_host" : "https://id.${var.domain.da}",
    "authentik_host_insecure" : false,
    "authentik_host_browser" : "https://id.${var.domain.da}",
    "log_level" : "info",
  })
  protocol_providers = local.radius-providers
}
