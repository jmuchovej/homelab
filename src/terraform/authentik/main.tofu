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
variable "discovered-apps" {
  type = map(object({
    name        = string
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
