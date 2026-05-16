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
      version = ">= 2025.12.0"
    }
    # https://registry.terraform.io/providers/hashicorp/consul/latest
    consul = {
      source  = "hashicorp/consul"
      version = "~> 2.20"
    }
    # https://registry.terraform.io/providers/cloudflare/cloudflare/latest
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 4.7.1"
    }
    # https://registry.terraform.io/providers/hashicorp/vault/latest
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}

locals {
  datacenter = "da"
  domain = {
    root = data.cloudflare_zone.domain.name
    dc   = "${local.datacenter}.${data.cloudflare_zone.domain.name}"
    cf   = data.cloudflare_zone.domain
  }
}

provider "sops" {
}

data "sops_file" "dc" {
  source_file = "${path.root}/secrets/${local.datacenter}.sops.yaml"
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

provider "cloudflare" {
  api_token = data.sops_file.secrets.data["cloudflare.api-key"]
}

provider "consul" {
  address = "https://consul.${local.domain.dc}"
}

provider "authentik" {
  url   = "https://id.${local.domain.dc}"
  token = data.sops_file.secrets.data["authentik.token"]
}

provider "vault" {
  address = "https://vault.${local.domain.dc}"
  auth_login_userpass {
    username = "admin"
    password = data.sops_file.dc.data["openbao.admin-pass"]
  }
}
