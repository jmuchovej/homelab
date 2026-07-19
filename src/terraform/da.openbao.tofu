# Disabled 2026-07-20: the NixOS openbao deployment was torn down with the
# service mesh. Kept as reference for the bao-in-cluster re-integration —
# re-add the `vault` provider to __main__.tofu when reviving.
#
# provider "vault" {
#   alias   = "da"
#   address = "https://vault.${local.domain.da}"
#   auth_login_userpass {
#     username = "admin"
#     password = data.sops_file.da.data["openbao.admin-pass"]
#   }
# }
#
# module "da-vault" {
#   source = "./vault"
#
#   providers = {
#     vault = vault.da
#   }
#
#   datacenter = "da"
#   vault-url  = "vault.${local.domain.da}"
#   idp-url    = "id.${local.domain.da}"
# }
