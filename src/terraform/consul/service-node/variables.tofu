variable "name" {
  type        = string
  description = "Consul service name — also the traefik router/service key."
}

variable "node" {
  type        = string
  default     = null
  description = "Catalog node name for this external service. Defaults to `name`."
}

variable "address" {
  type        = string
  description = "Device IP. Used for the external node, the service, and health checks."
}

variable "port" {
  type        = number
  description = "Backend port. Consul service port and the traefik loadBalancer server port."
}

variable "host" {
  type        = string
  description = "Public FQDN the service is routed at (e.g. hubitat.da.jm0.io)."
}

variable "scheme" {
  type        = string
  default     = "http"
  description = "Backend scheme. `https` additionally emits the loadBalancer scheme tag."

  validation {
    condition     = contains(["http", "https"], var.scheme)
    error_message = "scheme must be \"http\" or \"https\"."
  }
}

variable "servers-transport" {
  type        = string
  default     = null
  description = "Optional traefik serversTransport (e.g. mikrotik-tls@file) for self-signed backends."
}

variable "authentik" {
  description = "Authentik proxy-outpost annotations consumed by the discovery pipeline."

  type = object({
    group      = string
    access     = string
    icon       = string
    name       = optional(string)
    type       = optional(string, "proxy")
    skip-paths = optional(string)
  })
}

variable "check" {
  description = "Health check. `http` hits http://<address><path>; `tcp` dials <address>:<port>."

  type = object({
    type     = optional(string, "http")
    path     = optional(string, "/")
    name     = optional(string)
    interval = optional(string, "10s")
    timeout  = optional(string, "2s")
  })
  default = {}

  validation {
    condition     = contains(["http", "tcp"], var.check.type)
    error_message = "check.type must be \"http\" or \"tcp\"."
  }
}
