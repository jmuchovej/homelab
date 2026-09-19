# An HTTPRoute labeled `authentik.rbn/enabled=true` registers an Authentik
# app; its `authentik.rbn/*` annotations carry the app metadata.
#
# One provider per DC, each pinned with `config_context`. There is no default
# (unaliased) provider on purpose: an unpinned one follows whatever context
# happens to be current, so discovery silently returned one cluster's routes
# and called it the whole homelab.
#
# Both address their cluster over ZeroTier, which is the only link between the
# datacenters — and only at node level, so a lab address would not be routable
# from here at all.
provider "kubernetes" {
  alias = "da"
  config_paths = [
    "~/.kube/config",
    "~/.kube/config.d/da.yaml",
    "~/.kube/config.d/en.yaml",
  ]
  config_context = "da"
}

provider "kubernetes" {
  alias = "en"
  config_paths = [
    "~/.kube/config",
    "~/.kube/config.d/da.yaml",
    "~/.kube/config.d/en.yaml",
  ]
  config_context = "en"
}

locals {
  ak-ann = "authentik.rbn"
}

# Per-site and not for_each'd: a data source's provider cannot be chosen by a
# key, so each site is spelled out. Adding a DC means copying a pair.
data "kubernetes_resources" "namespaces-da" {
  provider    = kubernetes.da
  api_version = "v1"
  kind        = "Namespace"
}

data "kubernetes_resources" "namespaces-en" {
  provider    = kubernetes.en
  api_version = "v1"
  kind        = "Namespace"
}

# kubernetes_resources without a namespace queries `default`, not the cluster.
data "kubernetes_resources" "authentik-apps-da" {
  provider = kubernetes.da
  for_each = toset([
    for ns in data.kubernetes_resources.namespaces-da.objects : ns.metadata.name
  ])

  api_version    = "gateway.networking.k8s.io/v1"
  kind           = "HTTPRoute"
  namespace      = each.value
  label_selector = "${local.ak-ann}/enabled=true"
}

data "kubernetes_resources" "authentik-apps-en" {
  provider = kubernetes.en
  for_each = toset([
    for ns in data.kubernetes_resources.namespaces-en.objects : ns.metadata.name
  ])

  api_version    = "gateway.networking.k8s.io/v1"
  kind           = "HTTPRoute"
  namespace      = each.value
  label_selector = "${local.ak-ann}/enabled=true"
}

locals {
  ak-routes-by-site = {
    da = flatten([
      for d in values(data.kubernetes_resources.authentik-apps-da) : d.objects
    ])
    en = flatten([
      for d in values(data.kubernetes_resources.authentik-apps-en) : d.objects
    ])
  }

  # Which sites each route appears at. A route at two DCs serves two
  # hostnames, so it is two apps and both need the site in their key and slug
  # — one would otherwise silently overwrite the other in the merge. A route
  # at one DC cannot collide and keeps its bare name.
  #
  # Derived rather than declared, so this cannot drift from where apps are
  # actually deployed. The cost is that selecting an existing app into a
  # SECOND cluster renames the first one's slug: that shows up in the plan as
  # a replace, and its secrets/authentik.sops.yaml keys move with it.
  ak-route-sites = {
    for name in distinct(flatten([
      for site, routes in local.ak-routes-by-site : [for r in routes : r.metadata.name]
      ])) : name => [
      for site, routes in local.ak-routes-by-site :
      site if contains([for r in routes : r.metadata.name], name)
    ]
  }

  ak-discovered-apps = merge([
    for site, routes in local.ak-routes-by-site : {
      for r in routes :
      (length(local.ak-route-sites[r.metadata.name]) > 1 ? "${r.metadata.name}-${site}" : r.metadata.name) => {
        site        = site
        site-scoped = length(local.ak-route-sites[r.metadata.name]) > 1
        name        = lookup(r.metadata.annotations, "${local.ak-ann}/name", r.metadata.name)
        group       = lookup(r.metadata.annotations, "${local.ak-ann}/group", "Ungrouped")
        type        = lookup(r.metadata.annotations, "${local.ak-ann}/type", "proxy")
        client_type = lookup(r.metadata.annotations, "${local.ak-ann}/oauth-client-type", "confidential")
        icon        = lookup(r.metadata.annotations, "${local.ak-ann}/icon", r.metadata.name)
        access      = split(",", lookup(r.metadata.annotations, "${local.ak-ann}/access", "users"))
        skip_paths  = lookup(r.metadata.annotations, "${local.ak-ann}/skip-paths", null)
        basic_auth = {
          enabled  = lookup(r.metadata.annotations, "${local.ak-ann}/basic-auth.enabled", "false") == "true"
          username = lookup(r.metadata.annotations, "${local.ak-ann}/basic-auth.username", "username")
          password = lookup(r.metadata.annotations, "${local.ak-ann}/basic-auth.password", "password")
        }
        url = {
          int = "https://${r.spec.hostnames[0]}"
          ext = "https://${r.spec.hostnames[0]}"
        }
        # `;`-separated because `,` is the delimiter for `access`.
        redirect_uris = [
          for u in split(";", lookup(r.metadata.annotations, "${local.ak-ann}/redirect-uris", "")) :
          u if u != ""
        ]
      }
    }
  ]...)
}
