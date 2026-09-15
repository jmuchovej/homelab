# An HTTPRoute labeled `authentik.rbn/enabled=true` registers an Authentik
# app; its `authentik.rbn/*` annotations carry the app metadata.
provider "kubernetes" {
  config_path = "~/.kube/config"
}

locals {
  ak-ann = "authentik.rbn"
}

data "kubernetes_resources" "namespaces" {
  api_version = "v1"
  kind        = "Namespace"
}

# kubernetes_resources without a namespace queries `default`, not the cluster.
data "kubernetes_resources" "authentik-apps" {
  for_each = toset([
    for ns in data.kubernetes_resources.namespaces.objects : ns.metadata.name
  ])

  api_version    = "gateway.networking.k8s.io/v1"
  kind           = "HTTPRoute"
  namespace      = each.value
  label_selector = "${local.ak-ann}/enabled=true"
}

locals {
  ak-discovered-routes = flatten([
    for d in values(data.kubernetes_resources.authentik-apps) : d.objects
  ])

  ak-discovered-apps = {
    for r in local.ak-discovered-routes :
    r.metadata.name => {
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
}
