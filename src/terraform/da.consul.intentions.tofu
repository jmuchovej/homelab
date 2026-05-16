resource "consul_config_entry_service_intentions" "default-deny" {
  provider = consul.da
  name     = "*"

  sources {
    name   = "*"
    action = "deny"
  }
}
