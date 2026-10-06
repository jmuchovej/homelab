## Purpose

Defines how a hostname under a datacenter site's domain is reached from the Internet and from the site's own LAN — through a per-site Cloudflare tunnel into that site's external gateway with no inbound WAN port, and directly to the site VIP from inside — and how the tunnel's connector credential travels from Cloudflare to the cluster without ever being typed by hand.

## ADDED Requirements

### Requirement: Public hostnames resolve to a per-site tunnel

Each site's apex (`<site>.<root>`) and wildcard (`*.<site>.<root>`) public records SHALL be proxied CNAMEs to that site's Cloudflare tunnel, and SHALL NOT reference a relay's dynamic DNS name or public address.
Each site SHALL have its own tunnel whose ingress routes those hostnames to that site's external gateway, so that a connector in one site never serves another site's hostnames.

#### Scenario: Public lookup reaches the tunnel

- **WHEN** `app.<site>.<root>` is resolved from outside the site
- **THEN** the answer is a Cloudflare proxy address, and the request arrives at that site's external gateway with the original host header through that site's tunnel

#### Scenario: A site's tunnel serves only that site

- **WHEN** the ingress configuration of a site's tunnel is read
- **THEN** it lists only that site's apex and wildcard hostnames, followed by a catch-all 404

#### Scenario: Relay DDNS is not a public dependency

- **WHEN** a relay's IP Cloud DDNS name changes or IP Cloud is disabled
- **THEN** no public record changes and no public hostname becomes unreachable

### Requirement: No inbound WAN port is exposed

A site's router SHALL NOT forward any WAN port to the site VIP, and SHALL NOT hold hairpin NAT rules for the VIP.
Inbound HTTP and HTTPS from the Internet SHALL arrive only through the tunnel's outbound connection.

#### Scenario: WAN probe is refused

- **WHEN** TCP 80 or 443 on a site's public address is probed from the Internet
- **THEN** the connection is not forwarded to the VIP

#### Scenario: Router NAT table carries no VIP rules

- **WHEN** a site router's NAT rules are listed
- **THEN** there is no dst-nat to the VIP and no hairpin masquerade for it

### Requirement: LAN clients reach the VIP directly

A client on a site's LAN SHALL resolve `<site>.<root>` and every name under it to that site's VIP through the router's split-horizon DNS, and SHALL NOT traverse Cloudflare or the tunnel.

#### Scenario: LAN lookup returns the VIP

- **WHEN** `app.<site>.<root>` is resolved from a client on that site's LAN using the router as resolver
- **THEN** the answer is the site VIP

#### Scenario: Router holds no redundant public-name records

- **WHEN** the router's static DNS records are listed
- **THEN** the site domain is answered by one split-horizon record, with no separate CNAME records for the apex or wildcard

### Requirement: The connector token flows from Cloudflare to the cluster without a hand step

The tunnel's connector token SHALL be read from Cloudflare by OpenTofu after the tunnel exists, written to a 1Password item in the Homelab vault, and consumed by the cluster through External Secrets by item title.
No tunnel secret SHALL be stored in the sops tree or assembled by hand.
Recreating a tunnel SHALL rewrite the item, and the cluster SHALL pick up the new token without any manual copy.

#### Scenario: Tunnel recreate propagates

- **WHEN** a tunnel is destroyed and recreated by OpenTofu
- **THEN** the 1Password item holds the new token after apply, the connector's Secret resyncs on the next External Secrets refresh, and the connector reconnects without any value being copied by hand

#### Scenario: No tunnel secret in the repository

- **WHEN** the sops tree and the tracked OpenTofu configuration are searched for a tunnel secret or an assembled connector token
- **THEN** there are no matches

#### Scenario: Each tunnel has its own connector

- **WHEN** a cluster's workloads in the `network` namespace are listed
- **THEN** there is one cloudflared Deployment per tunnel that cluster serves, each bound to its own 1Password item, and no Deployment serves two tunnels
