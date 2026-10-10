terraform {
  encryption {
    key_provider "pbkdf2" "state" { }
    method "aes_gcm" "state" {
      keys = key_provider.pbkdf2.state
    }
    state {
      method = method.aes_gcm.state
      enforced = true
    }
    plan {
      method = method.aes_gcm.state
      enforced = true
    }
  }

  # Credentials, the endpoint, and the state-encryption key are NOT here: backend
  # config is evaluated before any provider or data source, so sops cannot supply
  # it. They arrive as environment variables from `just tofu::*` — see rules/tofu.md.
  backend "s3" {
    bucket = "rbn"
    key    = "tofu/terraform.tfstate"
    region = "auto"

    # R2 is S3-compatible, not S3: no STS, no EC2 metadata, no AWS region names,
    # and FULL_OBJECT checksums only for CRC-64/NVME while the SDK sends CRC-32.
    use_path_style              = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true

    # Conditional writes, which R2 implements; no DynamoDB equivalent exists.
    use_lockfile = true
  }

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
