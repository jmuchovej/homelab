locals {
  # An outpost can only reach workloads in the cluster it is deployed into, so
  # providers are grouped by SITE as well as type: an app at en whose provider
  # sat on da's outpost would be proxied by a pod that cannot route to it.
  outpost-types = ["proxy", "ldap", "radius"]

  outpost-sites = toset([for name, app in local.apps : app.site])

  outposts = {
    for pair in setproduct(local.outpost-sites, local.outpost-types) :
    "${pair[0]}-${pair[1]}" => {
      site = pair[0]
      type = pair[1]
      providers = [
        for name, app in module.authentik-app :
        app.provider_id
        if local.apps[name].type == pair[1] && local.apps[name].site == pair[0]
      ]
    }
  }

  # An outpost with nothing to serve is not created at all — authentik would
  # otherwise deploy an idle pod into that cluster.
  active-outposts = { for k, o in local.outposts : k => o if length(o.providers) > 0 }
}

# A local service connection lets authentik deploy and manage the outpost
# workloads itself, so no outpost tokens or manifests are handled here.
resource "authentik_service_connection_kubernetes" "local" {
  name  = "local-cluster"
  local = true
}

# The same mechanism aimed at another cluster's API. An app at a remote site
# then authenticates against an outpost deployed INTO that site, rather than
# needing an authentik of its own — which would mean a second database, and
# so a second signing keypair.
resource "authentik_service_connection_kubernetes" "remote" {
  for_each = var.remote-clusters

  name       = "${each.value}-cluster"
  kubeconfig = var.remote-cluster-kubeconfigs[each.value]
}

resource "authentik_outpost" "site" {
  for_each = local.active-outposts

  name = "${upper(each.value.site)} ${title(each.value.type)}"
  type = each.value.type

  # `local` for the site authentik itself runs in; every other site is reached
  # through its remote connection.
  service_connection = (
    contains(var.remote-clusters, each.value.site)
    ? authentik_service_connection_kubernetes.remote[each.value.site].id
    : authentik_service_connection_kubernetes.local.id
  )

  config = jsonencode({
    # Outposts always phone HOME — authentik core is single-site, so this
    # stays the primary's URL even for an outpost running elsewhere.
    "authentik_host" : "https://id.${var.domain.da}",
    "authentik_host_insecure" : false,
    "authentik_host_browser" : "https://id.${var.domain.da}",
    "log_level" : "info",
  })

  protocol_providers = each.value.providers
}
