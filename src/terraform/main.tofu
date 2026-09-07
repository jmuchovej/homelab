terraform {
  required_providers {
    sops = {
      source  = "carlpett/sops"
      version = ">= 1.3.0"
    }
    authentik = {
      source  = "goauthentik/authentik"
      version = ">= 2025.12"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 4.7.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.30"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = ">= 3.3.1"
    }
    routeros = {
      source  = "terraform-routeros/routeros"
      version = ">= 1.86.0"
    }
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
