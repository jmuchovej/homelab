resource "vault_jwt_auth_backend" "oidc" {
  type               = "oidc"
  path               = "oidc"
  description        = "The Rebellion"
  oidc_discovery_url = "https://${var.idp-url}/application/o/${data.sops_file.authentik.data["openbao.client-id"]}-oauth/"
  oidc_client_id     = data.sops_file.authentik.data["openbao.client-id"]
  oidc_client_secret = data.sops_file.authentik.data["openbao.client-secret"]
  default_role       = "compute"

  tune {
    listing_visibility = "unauth"
  }
}

locals {
  redirect_uris = [
    "https://${var.vault-url}/ui/vault/auth/oidc/oidc/callback",
    "https://${var.vault-url}/v1/auth/oidc/callback",
  ]
}

resource "vault_jwt_auth_backend_role" "compute" {
  backend   = vault_jwt_auth_backend.oidc.path
  role_name = "compute"
  role_type = "oidc"

  user_claim            = "preferred_username"
  groups_claim          = "groups"
  allowed_redirect_uris = local.redirect_uris
  oidc_scopes           = ["openid", "profile", "email", "groups"]
  token_policies        = ["reader"]
}

resource "vault_jwt_auth_backend_role" "compute-manager" {
  backend   = vault_jwt_auth_backend.oidc.path
  role_name = "compute-manager"
  role_type = "oidc"

  user_claim            = "preferred_username"
  groups_claim          = "groups"
  allowed_redirect_uris = local.redirect_uris
  oidc_scopes           = ["openid", "profile", "email", "groups"]
  token_policies        = ["superuser"]

  bound_claims = {
    groups = "compute-manager"
  }
}
