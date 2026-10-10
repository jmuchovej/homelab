terraform {
  required_providers {
    cloudflare  = { source = "cloudflare/cloudflare", version = "~> 5" }
    onepassword = { source = "1password/onepassword", version = "~> 3" }
  }
}

provider "onepassword" {
  account = "SNDQCTZFLVHCTA6ILHCIFZJCO4"
}

data "onepassword_environment" "bootstrap" {
  environment_id = "z3zoqeuhgnk2lgc24vccedyzyu"
}

locals {
  account-id = nonsensitive(data.onepassword_environment.bootstrap.variables["CLOUDFLARE_ACCOUNT_ID"])
}

provider "cloudflare" {
  api_token = data.onepassword_environment.bootstrap.variables["CLOUDFLARE_API_TOKEN"]
}

data "onepassword_vault" "homelab" {
  name = "Homelab"
}

module "cf" {
  source = "./cloudflare"

  account-id = local.account-id
  op-vault   = data.onepassword_vault.homelab.uuid
}
