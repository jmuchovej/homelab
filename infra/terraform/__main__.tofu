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
    # https://registry.terraform.io/providers/cloudflare/cloudflare/latest
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 4.7.1"
    }
  }
}

locals {
  datacenter = "da"
  domain = {
    root = "${module.cloudflare.domain.name}"
    dc   = "${local.datacenter}.${module.cloudflare.domain.name}"
    cf   = module.cloudflare.domain
  }
}

provider "sops" {
}

data "sops_file" "secrets" {
  source_file = "${path.root}/secrets/secrets.sops.yaml"
}

provider "cloudflare" {
  api_token = data.sops_file.secrets.data["cloudflare.api-key"]
}

provider "authentik" {
  url   = "https://id.${local.domain.dc}"
  token = data.sops_file.secrets.data["authentik.token"]
}

module "cloudflare" {
  source = "./cloudflare"
}

module "authentik" {
  source     = "./authentik"
  domain     = local.domain
  datacenter = local.datacenter
}
