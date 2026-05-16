provider "vault" {
  alias   = "da"
  address = "https://vault.${local.domain.da}"
  auth_login_userpass {
    username = "admin"
    password = data.sops_file.da.data["openbao.admin-pass"]
  }
}

module "da-vault" {
  source = "./vault"

  providers = {
    vault = vault.da
  }

  datacenter = "da"
  vault-url  = "vault.${local.domain.da}"
  idp-url    = "id.${local.domain.da}"
}
