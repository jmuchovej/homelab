resource "cloudflare_dns_record" "en-apex" {
  zone_id = data.cloudflare_zone.domain.id
  name    = local.domain.en
  type    = "CNAME"
  content = module.en-relay01.ddns_name
  ttl     = 60
  proxied = false
  comment = "en datacenter apex — tracks en-relay01 DDNS"
}

resource "cloudflare_dns_record" "en-wildcard" {
  zone_id = data.cloudflare_zone.domain.id
  name    = "*.${local.domain.en}"
  type    = "CNAME"
  content = module.en-relay01.ddns_name
  ttl     = 60
  proxied = false
  comment = "en datacenter wildcard — tracks en-relay01 DDNS"
}

resource "routeros_ip_dns_record" "en-apex" {
  provider = routeros.en-relay01
  type     = "CNAME"
  name     = local.domain.en
  cname    = local.catalog.vip
  ttl      = 60
  comment  = "en datacenter apex — tracks en-relay01 DDNS"
}

resource "routeros_ip_dns_record" "en-wildcard" {
  provider = routeros.en-relay01
  type     = "CNAME"
  name     = "*.${local.domain.en}"
  cname    = local.catalog.vip
  ttl      = 60
  comment  = "en datacenter wildcard — tracks en-relay01 DDNS"
}
