terraform {
  required_providers {
    # https://registry.terraform.io/providers/carlpett/sops/latest
    sops = {
      source  = "carlpett/sops"
      version = ">= 1.3.0"
    }
    # https://registry.terraform.io/providers/goauthentik/authentik/latest
    authentik = {
      source  = "goauthentik/authentik"
      version = ">= 2025.12"
    }
    # https://registry.terraform.io/providers/cloudflare/cloudflare/latest
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 4.7.1"
    }
    # https://registry.terraform.io/providers/terraform-routeros/routeros/latest
    routeros = {
      source  = "terraform-routeros/routeros"
      version = ">= 1.86.0"
    }
    # https://registry.terraform.io/providers/zerotier/zerotier/latest
    zerotier = {
      source  = "zerotier/zerotier"
      version = "~> 1.6.0"
    }
  }
}

locals {
  domain = {
    root = data.cloudflare_zone.domain.name
    da   = "da.${data.cloudflare_zone.domain.name}"
    en   = "en.${data.cloudflare_zone.domain.name}"
    holo = "holonet.${data.cloudflare_zone.domain.name}"
  }
}

provider "sops" {
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

data "sops_file" "authentik" {
  source_file = "${path.root}/secrets/authentik.sops.yaml"
}

data "sops_file" "users" {
  source_file = "${path.root}/secrets/users.sops.yaml"
}
