resource "cloudflare_dns_record" "da-apex" {
  zone_id = data.cloudflare_zone.domain.id
  name    = local.domain.da
  type    = "CNAME"
  content = module.da-relay01.ddns_name
  ttl     = 60
  proxied = false
  comment = "da datacenter apex — tracks da-relay01 DDNS"
}

resource "cloudflare_dns_record" "da-wildcard" {
  zone_id = data.cloudflare_zone.domain.id
  name    = "*.${local.domain.da}"
  type    = "CNAME"
  content = module.da-relay01.ddns_name
  ttl     = 60
  proxied = false
  comment = "da datacenter wildcard — tracks da-relay01 DDNS"
}

resource "routeros_ip_dns_record" "da-apex" {
  provider = routeros.da-relay01
  type     = "CNAME"
  name     = local.domain.da
  cname    = local.catalog.vip
  ttl      = 60
  comment  = "da datacenter apex — tracks da-relay01 DDNS"
}

resource "routeros_ip_dns_record" "da-wildcard" {
  provider = routeros.da-relay01
  type     = "CNAME"
  name     = "*.${local.domain.da}"
  cname    = local.catalog.vip
  ttl      = 60
  comment  = "da datacenter wildcard — tracks da-relay01 DDNS"
}
