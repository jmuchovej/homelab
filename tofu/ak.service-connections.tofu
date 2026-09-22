# A remote service connection lets da's authentik deploy and manage outposts
# INSIDE another cluster, so apps there authenticate against a local outpost
# instead of needing a second authentik. The kubeconfig is assembled from the
# ServiceAccount that cluster's `authentik-remote-cluster` chart creates.
# Providers are defined in ak.discovery.tofu.
# Kubernetes creates this ServiceAccount token, so tofu can only ever READ it:
# the k8s half has to land first. A missing Secret does not fail the read — the
# provider hands back a null `data` — so without this postcondition the error
# surfaces much later as "attempt to index null value" in the kubeconfig.
data "kubernetes_secret_v1" "authentik-remote-en" {
  provider = kubernetes.en

  metadata {
    name      = "authentik-remote-cluster"
    namespace = "auth"
  }

  lifecycle {
    postcondition {
      condition     = self.data != null && lookup(self.data, "token", "") != ""
      error_message = <<-EOT
        No populated `authentik-remote-cluster` ServiceAccount token in en's
        `auth` namespace. Push the Kubernetes side and let Flux reconcile
        `apps/auth/remote-cluster` first — tofu reads this token, it cannot
        create it. Check with:
          kubectl --context en get secret authentik-remote-cluster -n auth
      EOT
    }
  }
}

locals {
  # The ZeroTier address, NOT the lab one: it is an explicit `--tls-san`,
  # whereas lab IPs are only in the cert because k3s adds the current node IP
  # — which the renumber moved, and could move again.
  ak-remote-clusters = {
    en = "https://${local.topology.clients["en-t65-1"].ip}:6443"
  }

  # The kubernetes provider hands back `data` already base64-DECODED, but a
  # kubeconfig wants the CA re-encoded.
  ak-remote-secrets = {
    en = data.kubernetes_secret_v1.authentik-remote-en.data
  }

  ak-remote-kubeconfigs = {
    for site, server in local.ak-remote-clusters : site => jsonencode({
      apiVersion      = "v1"
      kind            = "Config"
      current-context = site
      clusters = [{
        name = site
        cluster = {
          server                     = server
          certificate-authority-data = base64encode(local.ak-remote-secrets[site]["ca.crt"])
        }
      }]
      users = [{
        name = "authentik"
        user = { token = local.ak-remote-secrets[site]["token"] }
      }]
      contexts = [{
        name    = site
        context = { cluster = site, user = "authentik" }
      }]
    })
  }
}
