# Cloudflare

data "cloudflare_zone" "domain" {
  filter = {
    name = data.sops_file.secrets.data["domain"]
  }
}
