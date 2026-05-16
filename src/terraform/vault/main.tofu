terraform {
  required_providers {
    sops  = { source = "carlpett/sops" }
    vault = { source = "hashicorp/vault" }
  }
}

variable "datacenter" {
  type = string
}

variable "vault-url" {
  type = string
}

variable "idp-url" {
  type = string
}

data "sops_file" "authentik" {
  source_file = "${path.root}/secrets/authentik.sops.yaml"
}
