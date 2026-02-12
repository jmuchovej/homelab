terraform {
  required_providers {
    sops      = { source = "carlpett/sops" }
    authentik = { source = "goauthentik/authentik" }
    consul    = { source = "hashicorp/consul" }
  }
}

data "sops_file" "secrets" {
  source_file = "${path.root}/secrets/secrets.sops.yaml"
}
data "sops_file" "dc" {
  source_file = "${path.root}/secrets/${var.datacenter}.sops.yaml"
}
