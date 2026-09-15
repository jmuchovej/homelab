provider "sops" {
}

data "sops_file" "da" {
  source_file = "${path.root}/secrets/da.sops.yaml"
}

data "sops_file" "en" {
  source_file = "${path.root}/secrets/en.sops.yaml"
}

data "sops_file" "secrets" {
  source_file = "${path.root}/secrets/secrets.sops.yaml"
}

data "sops_file" "authentik" {
  source_file = "${path.root}/secrets/authentik.sops.yaml"
}

data "sops_file" "users" {
  source_file = "${path.root}/secrets/users.sops.yaml"
}
