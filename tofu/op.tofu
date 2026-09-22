# tofu is the single writer for the 1Password items it declares; the cluster
# reads them through ESO rather than by hand-copying.
provider "onepassword" {
  service_account_token = data.sops_file.secrets.data["1password.token"]
}

data "onepassword_vault" "homelab" {
  name = "Homelab"
}
