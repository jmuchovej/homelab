terraform {
  required_providers {
    routeros = { source = "terraform-routeros/routeros" }
    zerotier = { source = "zerotier/zerotier" }
  }
}

variable "relay" {
  type        = string
  description = <<-EOT
    This router's key in the catalog (e.g. "da-relay01", "en-relay02").
    Used to look up the per-relay slice in `var.catalog.holonet-wg-config-for`,
    derive the DC ("da-relay01" → "da") for admin-source allowlists, and
    set the RouterOS `/system identity` (the suffix after the first
    hyphen — "da-relay01" → "relay01").
  EOT

  validation {
    condition     = length(split("-", var.relay)) == 2
    error_message = "relay must be of the form '<dc>-<name>' (e.g. 'da-relay01')."
  }
}

variable "catalog" {
  type        = any
  description = <<-EOT
    The shared catalog object — built once in mk.holonet.tofu, passed
    verbatim to every relay's module call. Expected shape:

      {
        vlans                 = <local.vlans>
        holonet               = <local.holonet>           # subnets, port, …
        holonet-peers-for     = <local.holonet-peers-for>
        holonet-wg-config-for = <local.holonet-wg-config-for>

        vip          = string  # cluster VIP for hairpin / DNAT
        lan-supernet = string  # broad-match CIDR for firewall rules

        certificates = {
          holonet = { crt = string, key = string }
        }
      }

    Typed as `any` because the schema is internal to this homelab and
    documenting it as a typed object adds maintenance burden without
    catching real bugs (it'd just duplicate the catalog definition).
  EOT
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
  description = "Public WAN IPv4 used by hairpin NAT rules. Source from sops. Unused when role=switch."
  sensitive   = true
  default     = null
}

variable "bridge-mac" {
  type        = string
  description = "Static MAC for the bridge (auto-mac disabled). Use the bridge MAC from the .rsc export so it survives reboots predictably."
}

variable "wan-port" {
  type        = string
  description = "Physical interface name used as the WAN uplink. Set comment=WAN and used as in-interface for WAN-input drops."
}

variable "ports" {
  type = map(object({
    role    = string           # "trunk" | "access"
    access  = optional(string) # VLAN key from var.vlans (required when role=access)
    comment = optional(string)
  }))
  description = <<-EOT
    Per-device physical port layout.

    Each interface has a `role`:
      - `trunk`  — carries every VLAN tagged (typical: uplink between routers/switches,
                   the local end of a tagged downlink). pvid defaults to 1.
      - `access` — carries one VLAN untagged. `access` must reference a key from
                   var.vlans (e.g. "mgmt", "lab", "iot"). pvid = that VLAN's id.

    The module derives bridge port pvids and the bridge VLAN tagged/untagged table
    from this map. The bridge interface itself is always tagged on every VLAN that
    appears in var.vlans, since it terminates L3 (or, on switches, the mgmt VLAN).

    Wifi interfaces are valid keys.
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
  description = "Additional IP addresses beyond the per-VLAN gateway. e.g. relay01 has 10.42.1.1/24 on vlan2."
  default     = {}
}

variable "static-leases" {
  type = map(object({
    address   = string
    mac-addr  = string
    client-id = optional(string)
    server    = string
  }))
  description = "Static DHCP reservations. Server names must match the dhcp-server entries (dhcp1..dhcp5 or defconf)."
  default     = {}
}

variable "enable-wan-dhcp" {
  type        = bool
  description = "Whether this router runs a DHCP client on the WAN interface. Disable for routers behind another NAT."
  default     = false
}

variable "enable-ip-cloud" {
  type        = bool
  description = "Whether to enable MikroTik IP Cloud DDNS + Back-to-Home VPN."
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
  description = "WiFi interfaces to adopt (set empty if this router has no radio). Keys are logical labels."
  default     = {}
}

variable "wifi-passphrases" {
  type        = map(string)
  sensitive   = true
  default     = {}
  description = <<-EOT
    PSK passphrases per wifi key, e.g. { holonet = "supersecret" }.
    Keyed by var.wifi map key; entries here override / extend the
    `security` map on the corresponding wifi resource.

    Separated from var.wifi to keep the wifi catalog non-sensitive —
    putting passphrases inside `security` would taint the whole map as
    sensitive, blocking `for_each` and forcing `nonsensitive()` wrappers
    that risk leaking other security fields (auth-types, ft, wps, etc.)
    into plan output.

    Wifi keys with no entry here get no passphrase (open network or
    handled out-of-band). Typically: pass sops-decrypted values like
    `wifi-passphrases = { holonet = data.sops_file.da.data["network.wifi"] }`.
  EOT
}

locals {
  # ─── Identity decomposition ──────────────────────────────────────────
  dc       = split("-", var.relay)[0]
  identity = split("-", var.relay)[1]

  # ─── Catalog slices ──────────────────────────────────────────────────
  vlans        = var.catalog.vlans
  vip          = var.catalog.vip
  lan-supernet = var.catalog.lan-supernet

  wg-holonet = var.catalog.holonet-wg-config-for[var.relay]

  holonet-sibling-mgmt-ips = {
    for k, ip in var.catalog.holonet-mgmt-ip-for : k => ip
    if startswith(k, "${local.dc}-") && k != var.relay
  }

  mgmt-ip = "${var.catalog.holonet-mgmt-ip-for[var.relay]}/${split("/", local.vlans.mgmt.cidr)[1]}"

  admin-allowed-sources = join(",", [
    var.catalog.vlans.mgmt.cidr,
    var.catalog.holonet-subnets[local.dc],
    var.catalog.holonet-subnets.clients,
  ])

  has-wan-cert        = try(var.catalog.certificates.holonet.crt, null) != null
  wan-certificate     = local.has-wan-cert ? "holonet" : ""
  wan-certificate-pem = try(var.catalog.certificates.holonet.crt, null)
  wan-certificate-key = try(var.catalog.certificates.holonet.key, null)
}

output "vlans" {
  description = "Resolved local.vlans (caller overrides + module defaults)."
  value       = local.vlans
}

output "ddns_name" {
  description = "MikroTik IP Cloud DDNS hostname (<serial>.sn.mynetname.net). Null if IP Cloud is disabled or hasn't registered yet."
  value       = var.role == "router" && var.enable-ip-cloud ? try(routeros_ip_cloud.this[0].dns_name, null) : null
}

output "public_ip" {
  description = "Public IPv4 reported to MikroTik IP Cloud. Null if IP Cloud is disabled. Note: this is what the cloud server sees from its end, NOT necessarily what's on the router's WAN interface (see use_local_address in dhcp.tofu)."
  value       = var.role == "router" && var.enable-ip-cloud ? try(routeros_ip_cloud.this[0].public_address, null) : null
}

# output "bad_ipv6" {
#   description = "IPv6 bad-address list — used by the root caller to import existing /ipv6/firewall/address-list entries."
#   value       = local.bad_ipv6
# }
