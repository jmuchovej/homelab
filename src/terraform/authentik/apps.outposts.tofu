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

# Authentik auto-creates a managed `ak-outpost-<uuid>` service account + a
# non-expiring API token for each outpost — that's the credential the outpost
# connects with, and it can't be substituted with a hand-rolled SA. The token
# isn't exposed by the provider, so it's pulled from the REST API and synced to
# sops out-of-band: `just -f authentik/justfile sync-outpost-tokens`.

# With a local kubernetes service connection, authentik deploys and manages
# the outpost workloads itself (`ak-outpost-<slug(name)>` Deployment+Service
# in its own namespace) — no token syncing, no hand-rolled manifests.
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
