# /system clock
# /system identity
# /ip service
# /ip ssh
# /ip neighbor discovery-settings
# /tool mac-server
# /tool mac-server mac-winbox
# /interface ethernet  (set comment on var.wan_interface)
# /iot lora servers    (NOT SUPPORTED by terraform-provider-routeros — see note)

resource "routeros_interface_ethernet" "wan" {
  count = var.role == "router" ? 1 : 0

  factory_name = var.wan-port
  name         = var.wan-port
  comment      = "WAN"
}

resource "routeros_system_clock" "this" {
  time_zone_name = "America/New_York"
}

resource "routeros_system_identity" "this" {
  name = var.relay
}

resource "routeros_ip_service" "ftp" {
  numbers  = "ftp"
  port     = 21
  disabled = true
}

resource "routeros_ip_service" "telnet" {
  numbers  = "telnet"
  port     = 23
  disabled = true
}

resource "routeros_ip_service" "www" {
  numbers = "www"
  port    = 80
  address = local.admin-allowed-sources
}

data "routeros_x509" "wan" {
  count = local.wan-certificate != "" ? 1 : 0
  data  = local.wan-certificate-pem
}

resource "routeros_system_certificate" "wan" {
  count = local.wan-certificate != "" ? 1 : 0

  name        = local.wan-certificate
  common_name = data.routeros_x509.wan[0].common_name

  import {
    cert_file_content = local.wan-certificate-pem
    key_file_content  = local.wan-certificate-key
  }
}

resource "routeros_ip_service" "www_ssl" {
  numbers = "www-ssl"
  port    = 443
  address = local.admin-allowed-sources

  certificate = local.wan-certificate == "" ? null : local.wan-certificate
  disabled    = local.wan-certificate == ""

  depends_on = [routeros_system_certificate.wan]
}

resource "routeros_ip_service" "winbox" {
  numbers  = "winbox"
  port     = 8291
  disabled = true
}

resource "routeros_ip_service" "api" {
  numbers  = "api"
  port     = 8728
  disabled = true
}

resource "routeros_ip_service" "api_ssl" {
  numbers  = "api-ssl"
  port     = 8729
  disabled = true
}

resource "routeros_ip_ssh_server" "this" {
  strong_crypto = true
}

resource "routeros_ip_neighbor_discovery_settings" "this" {
  discover_interface_list = routeros_interface_list.lan.name
}

resource "routeros_tool_mac_server" "this" {
  allowed_interface_list = routeros_interface_list.lan.name
}

resource "routeros_tool_mac_server_winbox" "this" {
  allowed_interface_list = routeros_interface_list.lan.name
}
