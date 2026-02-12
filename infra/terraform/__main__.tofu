terraform {
  required_providers {
    cloudflare = { source = "cloudflare/cloudflare" }
    sops       = { source = "carlpett/sops" }
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

data "sops_file" "dc" {
  source_file = "${path.root}/secrets/${local.datacenter}.sops.yaml"
}

provider "cloudflare" {
  api_token = data.sops_file.secrets.data["cloudflare.api-key"]
}

module "cloudflare" {
  source = "./cloudflare"
}
