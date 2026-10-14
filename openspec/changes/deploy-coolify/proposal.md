# Deploy Coolify as a dispatch-only control plane with VM runners

## Why

The cluster is excellent at running the services it already runs, and bad at the thing a prototype needs: `git push` and a URL, without a Deployment, Service, HTTPRoute, and Kustomization authored first.
That authoring cost is why side projects keep landing on Netlify and Cloudflare Pages instead of on hardware we own.

Coolify (`coollabsio/coolify`) is a self-hosted PaaS whose entire surface is that gap: register a git repo, pick a server, get a running container behind a proxy with a hostname.
It is also, by design, a root-equivalent remote-code-execution engine, so where each of its halves runs is the whole question.

## What this is — and what it is not

Three findings from reading the upstream source bound this change, and each cuts against the obvious reading of "install Coolify":

**Coolify is not a package.**
There is no `coolify` in nixpkgs and no `services.coolify` module.
Upstream ships a three-container Compose stack (`coolify`, `postgres:15-alpine`, `redis:7-alpine`) plus an installer that hard-refuses any `/etc/os-release` ID it does not list, NixOS included.
A Nix derivation of the Laravel application would reproduce the PHP source faithfully and then diverge on everything the image bakes in and the app hard-assumes: the PHP build, the nginx and s6 layout at `/var/www/html`, and version-locked helpers (`helper_version`, `railpack_version`).
The reproducibility we want is a digest in git, and an OCI digest is a stronger pin than a derivation of the wrong artifact.
The empty `packages/by-name/co/coolify/package.nix` placeholder is removed by this change.

**The control plane never touches Docker.**
The production Compose file mounts no `/var/run/docker.sock` into the `coolify` container.
Its single privileged primitive is `ssh`: every operation — `docker ps`, `docker compose up`, writing a generated compose file, `git clone`, the web terminal — is a shell line sent through `instant_remote_process()` to a registered `Server`, and the host it runs on is just the `Server` row whose IP is `host.docker.internal`.
Upstream's own hosted product runs exactly this shape, a central control plane managing only remote servers (`SELF_HOSTED=false`), and the image is already role-splittable through `COOLIFY_CONTAINER_ROLE` with s6 guards for `worker`, `horizon`, `scheduler`, and `scheduler-worker`.
So the control plane is an ordinary stateless web workload with Postgres and Redis behind it, and it belongs in the cluster under Flux, CNPG, ESO, and Envoy like everything else.

**The runner is where untrusted code executes, and it cannot be de-rooted.**
Non-root servers are supported, but the documented rule is `cooluser ALL=(ALL) NOPASSWD: ALL`, and the docs concede the account "still has root-level access".
The mechanism forbids anything tighter: `parseCommandsByLineForSudo()` prefixes `sudo ` onto every generated shell line and after every unquoted pipe, so the command surface is synthesized at runtime from the user's own configuration and has no finite form a sudoers allowlist could name.
Docker-group membership is root-equivalent regardless.
The only real boundary is the machine, so each runner is a disposable NixOS guest holding nothing but `dockerd`, `sshd`, one authorized key, and containers that can be recreated.

The two halves therefore have opposite threat models and go to opposite places:

|               | executes untrusted code                          | holds the keys                                                      | lives in                                                                     |
| ------------- | ------------------------------------------------ | ------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| runner        | yes — builds, Dockerfiles, `postinstall` scripts | no                                                                  | a libvirt guest per compute node                                             |
| control plane | no — only Coolify's own code                     | yes — `APP_KEY`, every runner's SSH private key, arbitrary dispatch | the cluster, beside 1Password Connect and authentik, which already hold more |

A fourth finding shapes how deployed applications are reached.
Each runner runs its own Coolify-managed proxy that routes by hostname, so a hostname must land on the right runner, and Coolify does nothing upstream of the runner.
Two paths cover the two kinds of name a prototype has:

- **A development URL** on the lab domain, reached through the cluster's internal gateway with the cluster's own wildcard certificate, visible on the LAN and VPN only.
- **A vanity hostname** on a zone we own, reached through a dedicated Cloudflare tunnel straight to the runner, with Cloudflare presenting the certificate.
  Making a prototype public is therefore a deliberate infrastructure commit, never a side effect of deploying it.

## What Changes

- **New namespace `kubernetes/apps/coolify/`**, selected only by `da.jm0.io` the way `auth` is, holding the control plane: one `app-template` HelmRelease with a controller per role (web, Horizon worker, scheduler, Redis) so every pod carries the `app.kubernetes.io/name: coolify` label the database NetworkPolicy matches, an `HTTPRoute` on `envoy-external` for the UI and the Reverb websocket port gated by an Envoy `SecurityPolicy` against the authentik proxy outpost, an ungated sibling route for the outpost's own paths and the signature-checked git webhooks, a third route that holds the in-browser terminal, the API, and Horizon to the lab, management, and ZeroTier ranges on top of the gate, and an `ExternalSecret` for `APP_KEY`, the Pusher triple, and the database and Redis credentials.
  This is the same two-route shape the arr apps use, with Coolify's built-in authentik OAuth provider for the login behind the gate.
  It gets its own namespace rather than joining `home` because it holds root on every runner, and a namespace is the cheapest boundary a future Cilium grant can select without catching anything else.
- **New `coolify-db.ks.yaml`** attaching the existing `kubernetes/components/cnpg-database` component for the control plane's Postgres.
  The Postgres and Redis containers upstream ships are dropped.
- **Upstream self-update is disabled** (`AUTOUPDATE=false`, a first-class setting read in `config/constants.php`).
  The image is pinned by digest in the HelmRelease; a version bump is a commit.
- **No `.env` file is generated by Coolify.**
  The 13-line `.env.production` template becomes rendered configuration: secrets from ESO, literals in the manifest.
  Nothing in the control plane is writable state except what CNPG holds.
- **The runner SSH keypair is generated once and committed as a pair**: the private key in a sops file under `kubernetes/clusters/da.jm0.io/config/` that Flux decrypts, and the public key as a plaintext file beside the runner aspect.
  A Flux-gated job loads the private key into Coolify's key store through its API; the public key is read at evaluation into every runner's authorized keys.
  Both halves come from one `ssh-keygen` and land in one commit, so there is no second source to drift from.
- **New parametric aspect `<rbn/system/virtualization/coolify-runner>`**, a sibling of `talos.nix`: one NixVirt domain per compute node, bridged into a VLAN, booting a NixOS guest that is also a first-class host under `modules/hosts/` named `da-cfy-<N>`, where `N` is the compute node's own suffix (`da-vcx-1` hosts `da-cfy-1`).
  The guest declares `virtualisation.docker` with the address pool and log rotation the upstream installer would have written to `daemon.json`, `openssh` with root key-only login, and the committed public key — a public key is the only thing that crosses from outside.
  Instantiated on `da-vcx-1` now; `da-vcx-3` and `da-vcx-4` when they are deployed, `da-vcx-2` never while it is the Windows machine.
- **Development URLs `*.cfy-<N>.${DC_DOMAIN}` per runner** on the internal gateway: a per-cluster patch adds each runner's wildcard as a SAN on the existing `wildcard-tls` certificate, and the per-cluster tree gains one `HTTPRoute` and one selector-less `Service` with an `EndpointSlice` per runner, plus one router DNS record per runner pointing at the internal gateway.
  Runner proxies serve plain HTTP and never request certificates.
- **New Coolify tunnel** in `tofu/`, instantiating the existing `tofu/cloudflare/tunnel` module, with one ingress rule and one proxied CNAME per vanity hostname, each routing straight to the owning runner on port 80.
  Its connector runs in `kubernetes/apps/coolify/` and consumes the tunnel token from 1Password through ESO, exactly as the identity-provider tunnel does.
  The identity-provider tunnel is not reused: its own note declares it IdP-only because connector placement is a property of the tunnel.
- **Removal of `packages/by-name/co/coolify/`**, an empty tracked placeholder that threw a syntax error for anyone forcing `pkgs.rbn`.

## Capabilities

### New Capabilities

- `coolify-control-plane`: the in-cluster dispatcher — what it holds and what it refuses to run, its stateless shape and role split, the secret and SSH-key contract, the self-update and image-pin rule, its authentication gate, the one bypass it permits, the surfaces held to operator networks, and the boundary between dispatch and execution.
- `coolify-runner`: the disposable execution guest — what a runner contains and must not contain, its identity and key contract, why it is a VM and not a user, the traffic it accepts, and the invariant that no runner is ever special.
- `coolify-app-ingress`: how a deployed application is reached — the per-runner development URL on the internal gateway, the vanity hostname through the Coolify tunnel, where TLS terminates on each path, and the rule that nothing becomes public without an infrastructure commit.

### Modified Capabilities

None.
Removing the placeholder changes no `package-scope` requirement, and nothing new lands at the repository root, so `repo-layout` is untouched.

## Impact

**Affected systems**

- `kubernetes/apps/coolify/` — new; `kubernetes/clusters/da.jm0.io/apps/kustomization.yaml` selects it.
  `en.jm0.io` is deliberately not wired up.
- `kubernetes/clusters/da.jm0.io/` — gains the runner keypair sops file, the runner `HTTPRoute`s, `Service`s and `EndpointSlice`s, and the patch that adds runner SANs to `wildcard-tls`.
  These name topology, so they live in the per-cluster tree rather than under `apps/`.
- `cloudnative-pg` (namespace `databases`), `onepassword-connect` (namespace `external-secrets`), `envoy-config` (namespace `network`), `certificates` (namespace `network`), and the authentik proxy outpost (namespace `auth`) become `dependsOn` edges.
- `tofu/authentik/` — gains a proxy provider and application for the Coolify UI, discovered from the route's `authentik.rbn/*` labels like the arr apps, and an OAuth2 provider whose client secret lands in 1Password for one-time entry into Coolify's OAuth settings.
- 1Password vault `Homelab` — a new item `coolify` holding `APP_KEY`, the Pusher triple, and `REDIS_PASSWORD`; tofu-managed items `cf-tunnel-coolify` for the tunnel connector token and the authentik OAuth client credentials.
- `modules/system/virtualization/coolify-runner.nix` and `coolify-runner.pub` — new; `modules/hosts/da-vcx-1/da-vcx-1.nix` includes the aspect; a new guest host `modules/hosts/da-cfy-1/`.
- `tofu/` — the Coolify tunnel and its per-vanity-hostname records, per-runner router DNS records and DHCP reservations now; the runner VLAN and its egress rules in a later change (see Non-goals).

**Dependencies this deliberately avoids**

- **No Docker on any hypervisor or cluster node.**
  The daemon lives only inside runner guests.
  This repository has never configured `virtualisation.docker` or `oci-containers` anywhere, and this change keeps it that way outside the guests.
- **No sops on a runner, and no 1Password in the key path.**
  The runner needs only a public key, which is plaintext in the repository.
  The private key reaches the cluster by the Flux-decrypted sops path that already bootstraps 1Password Connect, so the key never has a copy outside the repository to fall out of sync with.
- **No WAN ingress to any runner, and no per-runner tunnel.**
  Both ingress paths enter a runner on port 80 from inside the cluster, so a runner's eventual firewall is "port 22 from the control plane, port 80 from the cluster, egress for image pulls".
- **No Advanced Certificate Manager.**
  Cloudflare's free certificate covers an apex and one wildcard level, which is why vanity hostnames ride the tunnel and three-label development URLs do not.

**Risks**

- **`Server` id 0 cannot be deleted.**
  `Server::isCoolifyHost()` is `ip === 'host.docker.internal' || id === 0`, the UI hides its danger zone, and `ProductionSeeder` creates it unless `isCloud()`.
  In a pod that row is permanently unreachable.
  Either `SELF_HOSTED=false` skips seeding it, at the cost of whatever hosted-product surface that flag enables, or the row stays red forever and its per-minute health jobs must be shown harmless.
  This is a spike, not a decision, and the design records it as open.
- **`APP_KEY` is the whole instance.**
  It encrypts every stored SSH key and every deployed app's environment in Postgres.
  Its 1Password item is the disaster-recovery artifact; a CNPG backup without it is noise.
- **Keys and multiplexing sockets share a directory.**
  Coolify writes both private keys and SSH ControlMaster sockets under `storage/app/ssh`.
  Keys are materialised from Postgres and sockets are scratch, so the directory is an `emptyDir` and the control plane has no PVC; `SSH_MUX_ENABLED` is the fallback if the socket path misbehaves.
- **Postgres major.**
  Upstream pins `postgres:15-alpine`; the CNPG component's default major must be checked against Coolify's migrations before the cluster is created, because a CNPG major is not something to change afterwards.
- **Forwarded scheme.**
  Both ingress paths hand the runner's proxy plain HTTP, so applications see `https` only if that proxy trusts `X-Forwarded-Proto` from the gateway and the tunnel connector.
  Coolify's generated proxy configuration may not trust them by default; it is editable, and this is verified before the first vanity hostname.
- **A VM bounds code execution, not network reach.**
  A root shell in a runner still reaches whatever its NIC reaches.
  The runner VLAN and its egress policy are the real control and are deferred, not forgotten (Non-goals).

**Non-goals**

- **Public development URLs.**
  `*.cfy-<N>.${DC_DOMAIN}` is three labels under the zone apex, which Cloudflare's free certificate does not cover.
  A prototype that needs to be public gets a vanity hostname; if that ever changes, Advanced Certificate Manager is the lever, in its own change.
- **Moving an application between runners.**
  Its tunnel rule and its development URL both name the runner; a move is an edit, not a feature.
- **Runner network isolation.**
  The runner VLAN, firewall, and egress rules are `tofu` work scheduled after the VMs and clusters exist.
- **A native Nix package of Coolify.**
  Rejected above; recorded so nobody reopens it.
- **Coolify's built-in database provisioning for deployed apps.**
  Prototypes that need state should point at CNPG, which keeps the runners genuinely disposable; the DSN hand-off is its own design later.
- **Cilium network policies for the control plane pods.**
  Lockdown is opt-in per pod and the cluster's policy contract forbids prophylactic grants; observe the real egress set (runner IPs on `:22`, GitHub, container registries) in audit mode first, in its own change.
- **Deploying to `en.jm0.io`**, or any runner outside `da`.
