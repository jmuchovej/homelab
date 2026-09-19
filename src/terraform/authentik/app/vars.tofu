variable "name" {
  type = string
}

variable "site" {
  type        = string
  description = <<-EOT
    Datacenter this instance of the app lives in. Decides which site's outpost
    carries its provider, and by default suffixes the slug — so the same
    service at two sites gets two identities, which it needs because the two
    serve different hostnames.
  EOT
}

variable "site-scoped" {
  type        = bool
  default     = false
  description = <<-EOT
    Whether the slug carries `-<site>`. Set only when the SAME service runs at
    more than one DC: those are two applications serving two hostnames, so
    they need separate providers and OAuth clients. An app at a single site
    cannot collide, and suffixing it would rename its authentik objects and
    its secrets/authentik.sops.yaml keys for nothing.
  EOT
}

variable "group" {
  type = string
}

variable "internal" {
  type    = string
  default = null
}

variable "external" {
  type    = string
  default = null
}

variable "icon" {
  type    = string
  default = null
}

variable "suffix" {
  type    = string
  default = "svg"
}

variable "publisher" {
  type    = string
  default = null
}

variable "skip_path_regex" {
  type    = string
  default = null
}

variable "access_group" {
  type = list(string)
}

variable "access_user" {
  type    = list(number)
  default = []
}

variable "internal_host_ssl_validation" {
  type    = bool
  default = true
}

variable "property_mappings" {
  type    = list(string)
  default = []
}

variable "redirect_uris" {
  description = "Exact-match redirect URIs allowed for the OAuth provider. Sourced from per-service mesh registration → `authentik.redirect_uris` consul tag. Only consulted when `type == \"oauth\"`."
  type        = list(string)
  default     = []
}

variable "jwks_sources" {
  type    = list(string)
  default = []
}

variable "type" {
  type = string
  validation {
    condition     = contains(["proxy", "oauth", "ldap"], var.type)
    error_message = "Valid values for `type` are `[proxy, oauth, ldap]`."
  }
}

variable "client_type" {
  description = "OAuth client type — `public` (PKCE, no secret; e.g. hass-oidc-auth) or `confidential`."
  type        = string
  default     = "confidential"
  validation {
    condition     = contains(["confidential", "public"], var.client_type)
    error_message = "Valid values for `client_type` are `[confidential, public]`."
  }
}

variable "sub_mode" {
  type = string
  validation {
    condition = contains(
      ["hashed_user_id", "user_id", "user_uuid", "user_username", "user_email", "user_upn", ],
      var.sub_mode
    )
    error_message = "Invalid `sub_mode` provided. Check the Authentik Terraform Provider!"
  }
  default = "hashed_user_id"
}

variable "launch_url" {
  type    = string
  default = null
}

variable "signing_key" {
  type    = string
  default = null
}

variable "flows" {
  description = "Flow IDs by provider type"
  type = object({
    ldap = object({
      bind   = string
      unbind = string
    })
    proxy = object({
      authorization = string
      invalidation  = string
    })
    oauth = object({
      authentication = string
      authorization  = string
      invalidation   = string
    })
  })
}

variable "basic_auth" {
  type = object({
    enabled  = bool,
    username = string,
    password = string,
  })
  default = {
    enabled  = false,
    username = "username",
    password = "password",
  }
}
