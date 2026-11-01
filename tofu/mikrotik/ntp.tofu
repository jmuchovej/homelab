resource "routeros_system_ntp_client" "this" {
  enabled = true
  mode    = "unicast"
  servers = [
    "0.pool.ntp.org",
    "1.pool.ntp.org",
    "2.pool.ntp.org",
    "3.pool.ntp.org",
  ]
}

# `use_local_clock` is deliberately absent – the routers have no battery-backed
# RTC, so a relay that reboots but can't reach the pool would advertise
# epoch-era time a valid, which is wrong. without `use_local_clock`, the router
# will answer at stratum 16, so chrony will ignore it.
resource "routeros_system_ntp_server" "this" {
  count = local.is-router ? 1 : 0

  enabled = true

  depends_on = [routeros_system_ntp_client.this]
}
