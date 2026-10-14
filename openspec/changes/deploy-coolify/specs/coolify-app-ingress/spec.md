## Purpose

Defines how an application deployed through Coolify is reached: the per-runner development URL on the cluster's internal gateway, the vanity hostname through the Coolify tunnel, where TLS terminates on each path, and the rule that nothing becomes public without an infrastructure commit.

## ADDED Requirements

### Requirement: Every application has a development URL on its runner's wildcard

An application deployed to runner `N` SHALL be reachable over HTTPS at a hostname under `*.cfy-<N>.<site-domain>`, assigned automatically at creation.
That hostname SHALL route through the cluster's internal gateway to the owning runner.

#### Scenario: Automatic hostname on deploy

- **WHEN** an application is created on runner `da-cfy-1` without a domain specified
- **THEN** it receives a hostname under `*.cfy-1.<site-domain>` and answers at that hostname over HTTPS from the LAN

#### Scenario: Hostname lands on the right runner

- **WHEN** two applications on different runners are requested by their development URLs
- **THEN** each request reaches the runner that hosts that application

### Requirement: Development URLs are not public

A development URL SHALL resolve and route only on the LAN and VPN.
It SHALL NOT be reachable from the public internet, and deploying an application SHALL NOT by itself create any public exposure.

#### Scenario: Not resolvable from outside

- **WHEN** a development URL is requested from outside the LAN and VPN
- **THEN** no route exists to it

#### Scenario: Deploy creates no public record

- **WHEN** an application is deployed with only its development URL
- **THEN** no public DNS record and no tunnel rule for it exists afterwards

### Requirement: TLS for development URLs terminates at the gateway

The cluster's wildcard certificate SHALL cover every runner's development wildcard.
Runner proxies SHALL serve plain HTTP and SHALL NOT request or hold certificates.
Application domains on runners SHALL use the `http` scheme.

#### Scenario: Certificate covers a new runner

- **WHEN** a runner is added and its wildcard is declared
- **THEN** the gateway presents a certificate valid for that wildcard, and browsers show no warning for its development URLs

#### Scenario: Runner requests no certificates

- **WHEN** an application's domain is set on a runner
- **THEN** the runner's proxy performs no certificate issuance and holds no certificate for that hostname

### Requirement: A vanity hostname reaches an application through the Coolify tunnel

An application MAY be given a hostname on a zone the operator controls.
Such a hostname SHALL be served through a tunnel dedicated to Coolify applications, with the tunnel's edge presenting the certificate and the tunnel's origin leg delivering plain HTTP to the owning runner.
The tunnel SHALL be declared in infrastructure code, with one rule per vanity hostname.

#### Scenario: Vanity hostname is public and valid

- **WHEN** a vanity hostname has a tunnel rule to its runner and a proxied DNS record
- **THEN** it answers over HTTPS from the public internet with a certificate valid for that hostname, and the request reaches the owning runner

#### Scenario: Tunnel is not shared with identity

- **WHEN** the tunnels in the account are listed
- **THEN** Coolify application hostnames are on a tunnel of their own, and the identity-provider tunnel carries none of them

#### Scenario: Development URL may coexist

- **WHEN** an application has both a vanity hostname and its development URL configured
- **THEN** both reach the application, the vanity hostname from anywhere and the development URL from the LAN and VPN

### Requirement: Making an application public is one infrastructure commit

Exposing an application publicly SHALL require exactly: one tunnel rule naming the hostname and the owning runner, one DNS record for the hostname, and the hostname set on the application.
It SHALL NOT require a gateway change, a certificate request, or a cluster manifest.

#### Scenario: Promotion touches only infrastructure code

- **WHEN** an application is given a vanity hostname
- **THEN** the only repository changes are the tunnel rule and DNS record, and no cluster manifest or certificate definition changes

#### Scenario: Removal is symmetric

- **WHEN** the tunnel rule and DNS record for a vanity hostname are removed
- **THEN** the hostname stops resolving to the application and its development URL is unaffected

### Requirement: Applications observe the original scheme

An application behind either path SHALL observe that the client used HTTPS, so that absolute URLs and redirects it generates use `https`.

#### Scenario: Redirects stay on HTTPS

- **WHEN** an application behind a vanity hostname or a development URL issues a redirect to a relative path
- **THEN** the browser follows it over HTTPS without a downgrade

### Requirement: Adding a runner adds one of each, in one place

Adding a runner SHALL require, for ingress, exactly: one certificate name, one route, one backend, and one DNS record, all declared in the per-cluster tree.
It SHALL NOT change anything shared between clusters.

#### Scenario: New runner, bounded change

- **WHEN** runner `da-cfy-3` is added
- **THEN** the ingress changes are one wildcard added to the certificate, one route for `*.cfy-3.<site-domain>`, one backend for the runner's address, and one DNS record, and no manifest shared with other clusters changes

### Requirement: The control plane is never on the application paths

The Coolify web interface SHALL NOT be reachable through the application tunnel or at any development URL.

#### Scenario: UI not on the tunnel

- **WHEN** the tunnel's rules are listed
- **THEN** none routes to the control plane
