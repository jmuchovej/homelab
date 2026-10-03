resource "cloudflare_zero_trust_tunnel_cloudflared" "id" {
  account_id = data.cloudflare_zone.domain.account.id
  name       = "id-${local.domain.root}"
  # must be >= 32 bytes, base64-encoded. kept in sops so the connector token can
  # be recomputed without tainting the tunnel.
  #   (this would require re-issuing credentials to every connector.)
  tunnel_secret = data.sops_file.secrets.data["cloudflare.tunnel-secret"]
  # keep the config in the tofu resource so routing stays here
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "id" {
  account_id = data.cloudflare_zone.domain.account.id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.id.id

  config = {
    ingress = [
      {
        hostname = "id.${local.domain.root}"
        service  = "http://authentik-server.auth.svc.cluster.local:80"
      },
      { service = "http_status:404" },
    ]
  }
}

resource "cloudflare_dns_record" "id-apex" {
  zone_id = data.cloudflare_zone.domain.id
  name    = "id.${local.domain.root}"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.id.id}.cfargotunnel.com"
  ttl     = 1
  proxied = true
  comment = "cluster-agnostic idP"
}

# The connector token. The provider exposes no `token` attribute, so assemble
# the documented shape ourselves: base64({"a": account tag, "t": tunnel id,
# "s": tunnel secret}). Only `s` is a credential — `a` and `t` are identifiers
# that sit in tofu state and the Cloudflare dashboard regardless.
#
# Written directly to 1Password instead of read out with `tofu output`: `t` is
# assigned at create time, so a tainted or recreated tunnel silently invalidated
# a hand-pasted copy and cloudflared then failed auth with nothing in-cluster
# pointing at the cause. Keeping the item in this resource graph makes the
# refresh structural.
resource "onepassword_item" "cf-tunnel-idp" {
  vault    = data.onepassword_vault.homelab.uuid
  title    = "cf-tunnel-idp"
  category = "password"
  password = base64encode(jsonencode({
    a = cloudflare_zero_trust_tunnel_cloudflared.id.account_tag
    t = cloudflare_zero_trust_tunnel_cloudflared.id.id
    s = data.sops_file.secrets.data["cloudflare.tunnel-secret"]
  }))
  note_value = join("\n", [
    "Managed by tofu — tofu/da.cloudflare-tunnel.tofu.",
    "Edits made here are reverted on the next apply.",
    "",
    "cloudflared connector token for the `id-${local.domain.root}` tunnel,",
    "consumed by apps/network/cloudflare-tunnel via the op-connect-ro store.",
    "",
    "IdP-ONLY TUNNEL. Connector placement is a property of the tunnel, not the",
    "connector, and Cloudflare load-balances across every healthy connector.",
    "Adding an `en` connector here to make id.<root> multi-DC would therefore",
    "drag any other hostname on this tunnel into en as well. Other services get",
    "their own tunnel.",
  ])
}

# break-glass read only – the cluster gets this via 1password + ESO.
output "cloudflare-tunnel-id-token" {
  description = "cloudflared connector token for the `id` tunnel (1Password: cf-tunnel-idp)"
  sensitive   = true
  value       = onepassword_item.cf-tunnel-idp.password
}
