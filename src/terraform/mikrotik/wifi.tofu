# /interface wifi   (RouterOS 7.13+ new WiFi stack)

resource "routeros_wifi" "this" {
  for_each = var.wifi

  name     = each.value.name
  comment  = each.value.comment
  disabled = each.value.disabled

  configuration = each.value.configuration
  channel       = each.value.channel
  security = merge(
    each.value.security,
    can(var.wifi-passphrases[each.key]) ? { passphrase = var.wifi-passphrases[each.key] } : {},
  )
}
