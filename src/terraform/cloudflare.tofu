provider "cloudflare" {
  api_token = data.sops_file.secrets.data["cloudflare.api-key"]
}

data "cloudflare_zone" "domain" {
  filter = {
    name = data.sops_file.secrets.data["domain"]
  }
}
