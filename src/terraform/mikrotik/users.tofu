# /user
# /user/group
locals {
  terraform-user-policy = [
    "api", "rest-api", "read", "write", "sensitive", "policy",
    "!reboot", "!ssh", "!telnet", "!ftp", "!winbox",
    "!web", "!local", "!password", "!sniff", "!test",
  ]
}

resource "routeros_system_user_group" "terraform" {
  name    = "terraform"
  policy  = local.terraform-user-policy
  comment = "Restricted: REST/API only, no shell/UI/reboot. Address allowlist via tofu."
}

resource "routeros_system_user" "terraform" {
  name    = "terraform"
  group   = routeros_system_user_group.terraform.name
  address = local.admin-allowed-sources
  comment = "Managed by tofu. Password rotated via src/mikrotik/justfile."

  lifecycle {
    ignore_changes = [password]
  }
}
