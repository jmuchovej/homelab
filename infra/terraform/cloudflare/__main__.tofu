terraform {
  required_providers {
    # https://registry.terraform.io/providers/carlpett/sops/latest
    sops = {
      source  = "carlpett/sops"
      version = ">= 1.3.0"
    }
    # https://registry.terraform.io/providers/cloudflare/cloudflare/latest
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 4.7.1"
    }
  }
}

data "sops_file" "secrets" {
  source_file = "${path.root}/secrets/secrets.sops.yaml"
}

data "cloudflare_zone" "domain" {
  filter = {
    name = data.sops_file.secrets.data["domain"]
  }
}

output "domain" {
  description = "Domain"
  value       = data.cloudflare_zone.domain
  sensitive   = true
}
