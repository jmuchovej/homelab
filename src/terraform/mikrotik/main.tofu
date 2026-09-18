terraform {
  required_providers {
    routeros = { source = "terraform-routeros/routeros" }
    zerotier = { source = "zerotier/zerotier" }
  }
}

variable "relay" {
  type        = string
  description = "This router's key in the catalog, '<dc>-<name>' (e.g. \"da-relay01\")."

  validation {
    condition     = length(split("-", var.relay)) == 2
    error_message = "relay must be of the form '<dc>-<name>' (e.g. 'da-relay01')."
  }
}

variable "catalog" {
  type        = any
  description = "Shared catalog built in holonet.tofu and passed verbatim to every relay. Typed `any` so the schema lives only in the caller."
}

variable "role" {
  type        = string
  description = "Routing role: 'router' creates L3 (DHCP, DNS, NAT, forward firewall, WAN); 'switch' only creates L2 (bridge, ports, VLAN table) + management IP + mgmt-input firewall."
  default     = "router"

  validation {
    condition     = contains(["router", "switch"], var.role)
    error_message = "role must be one of: router, switch."
  }
}

variable "public-ip" {
  type        = string
  description = "Public WAN IPv4 used by hairpin NAT rules. Unused when role=switch."
  sensitive   = true
  default     = null
}

variable "bridge-mac" {
  type        = string
  description = "Static MAC for the bridge; use the value from the device's .rsc export."
}

variable "wan-port" {
  type        = string
  description = "Physical interface name used as the WAN uplink."
}

variable "ports" {
  type = map(object({
    role    = string           # "trunk" | "access"
    access  = optional(string) # catalog vlans key (required when role=access)
    comment = optional(string)
  }))
  description = <<-EOT
    Physical port layout keyed by interface name (wifi interfaces are valid keys).
    `trunk` carries every VLAN tagged; `access` carries one VLAN untagged.
  EOT
  default     = {}

  validation {
    condition = alltrue([
      for k, v in var.ports : contains(["trunk", "access"], v.role)
    ])
    error_message = "Every port's role must be one of: trunk, access."
  }
  validation {
    condition = alltrue([
      for k, v in var.ports : v.role != "access" || v.access != null
    ])
    error_message = "Every access port must set `access = \"<vlan-key>\"`."
  }
}

variable "extra-addrs" {
  type = map(object({
    address   = string
    interface = string
    network   = string
    comment   = optional(string)
  }))
  description = "Additional IP addresses beyond the per-VLAN gateway."
  default     = {}
}

variable "static-leases" {
  type = map(object({
    address   = string
    mac-addr  = string
    client-id = optional(string)
    server    = string
  }))
  description = "Static DHCP reservations. `server` must name an existing dhcp-server."
  default     = {}
}

variable "enable-wan-dhcp" {
  type        = bool
  description = "Whether this router runs a DHCP client on the WAN interface. Disable for routers behind another NAT."
  default     = false
}

variable "enable-ip-cloud" {
  type        = bool
  description = "Whether to enable MikroTik IP Cloud DDNS."
  default     = false
}

variable "enable-hairpin" {
  type        = bool
  description = "Whether to install hairpin DNAT rules so LAN clients reach the VIP via the public WAN IP. Only one router on a given subnet should hold these."
  default     = false
}

variable "wifi" {
  type = map(object({
    name          = string
    comment       = optional(string)
    disabled      = optional(bool, false)
    configuration = map(string)
    channel       = map(string)
    security      = optional(map(string), {})
  }))
  description = "WiFi interfaces to manage, keyed by logical label."
  default     = {}
}

variable "wifi-passphrases" {
  type        = map(string)
  sensitive   = true
  default     = {}
  description = <<-EOT
    PSK passphrases keyed by var.wifi key. Kept out of var.wifi so the
    sensitive taint does not spread to the map used for `for_each`.
  EOT
}

locals {
  dc       = split("-", var.relay)[0]
  identity = split("-", var.relay)[1]

  vlans        = var.catalog.vlans-for[local.dc]
  k8s          = var.catalog.k8s-for[local.dc]
  vip          = local.k8s.vip
  lan-supernet = var.catalog.lan-supernet

  wg-holonet = var.catalog.holonet-wg-config-for[var.relay]

  holonet-sibling-mgmt-ips = {
    for k, ip in var.catalog.holonet-mgmt-ip-for : k => ip
    if startswith(k, "${local.dc}-") && k != var.relay
  }

  mgmt-ip = "${var.catalog.holonet-mgmt-ip-for[var.relay]}/${split("/", local.vlans.mgmt.cidr)[1]}"

  admin-allowed-sources = join(",", concat(
    [local.vlans.mgmt.cidr],
    values(var.catalog.holonet-subnets)
  ))

  has-wan-cert        = try(var.catalog.certificates.holonet.crt, null) != null
  wan-certificate     = local.has-wan-cert ? "holonet" : ""
  wan-certificate-pem = try(var.catalog.certificates.holonet.crt, null)
  wan-certificate-key = try(var.catalog.certificates.holonet.key, null)
}

output "vlans" {
  description = "The catalog vlans map as seen by this module."
  value       = local.vlans
}

output "ddns_name" {
  description = "MikroTik IP Cloud DDNS hostname. Null if IP Cloud is disabled or not yet registered."
  value       = var.role == "router" && var.enable-ip-cloud ? try(routeros_ip_cloud.this[0].dns_name, null) : null
}

output "public_ip" {
  description = "Public IPv4 as seen by the MikroTik IP Cloud server, which may differ from the WAN interface address. Null if IP Cloud is disabled."
  value       = var.role == "router" && var.enable-ip-cloud ? try(routeros_ip_cloud.this[0].public_address, null) : null
}

# output "bad_ipv6" {
#   description = "IPv6 bad-address list — used by the root caller to import existing /ipv6/firewall/address-list entries."
#   value       = local.bad_ipv6
# }
