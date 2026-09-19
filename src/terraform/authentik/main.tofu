terraform {
  required_providers {
    sops      = { source = "carlpett/sops" }
    authentik = { source = "goauthentik/authentik" }
  }
}

data "sops_file" "da" {
  source_file = "${path.root}/secrets/da.sops.yaml"
}

data "sops_file" "en" {
  source_file = "${path.root}/secrets/en.sops.yaml"
}

data "sops_file" "secrets" {
  source_file = "${path.root}/secrets/secrets.sops.yaml"
}

data "sops_file" "users" {
  source_file = "${path.root}/secrets/users.sops.yaml"
}

variable "domain" {
  type = object({
    root = string
    da   = string
    en   = string
    holo = string
  })
}

# Codename -> "app_label.codename", from `just authentik discover-permissions`.
# A map rather than per-codename data lookups, which hit the provider's
# 100-item cap. Codenames that collide across apps are absent; write those
# in full form so `lookup` passes them through.
variable "permissions" {
  type    = map(string)
  default = {}
}

# Apps discovered from cluster HTTPRoutes in ak.discovery.tofu at root.
variable "remote-clusters" {
  type        = set(string)
  description = <<-EOT
    Sites whose Kubernetes API authentik may deploy outposts into, keyed by
    site (e.g. "en"). Each needs the `authentik-remote-cluster` chart
    installed there. da is not listed — it uses a `local` connection.
  EOT
  default     = []
}

variable "remote-cluster-kubeconfigs" {
  type        = map(string)
  sensitive   = true
  default     = {}
  description = <<-EOT
    JSON kubeconfig per site from `remote-clusters`. Kept OUT of that set so
    the sensitive taint does not spread to the value used for `for_each`,
    which tofu rejects — same split as mikrotik's `wifi-passphrases`.
  EOT
}

variable "discovered-apps" {
  # This type is a FILTER, not just a check: tofu coerces the incoming value
  # to it and silently drops any attribute missing here. An attribute added in
  # ak.discovery.tofu but not added below simply never arrives, and the only
  # symptom is an "object does not have an attribute" error at the consumer.
  type = map(object({
    name        = string
    site        = string
    site-scoped = optional(bool, false)
    group       = string
    type        = string
    client_type = optional(string, "confidential")
    icon        = string
    access      = list(string)
    skip_paths  = optional(string)
    basic_auth = object({
      enabled  = bool
      username = string
      password = string
    })
    url = object({
      int = string
      ext = string
    })
    redirect_uris = list(string)
  }))
  default = {}
}
