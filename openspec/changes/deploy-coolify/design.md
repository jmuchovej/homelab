## Context

See `proposal.md` — Why, and "What this is — and what it is not" for the findings that split Coolify into a dispatcher, a set of runners, and two ingress paths.

The constraints that actually shape the design:

- **The control plane's only privileged primitive is `ssh`.**
  `instant_remote_process()` → `SshMultiplexingHelper::generateSshCommand()` builds `ssh -o ControlMaster=auto -o ControlPath=<mux> -o ControlPersist=… <user>@<ip>` for every operation, and the production Compose file mounts no Docker socket into the `coolify` container.
- **Upstream already runs the dispatch-only shape** as its hosted product (`SELF_HOSTED=false`), and the image is role-aware: `COOLIFY_CONTAINER_ROLE` is read by s6 `run` scripts that sleep the Horizon and scheduler services unless the container has the `worker`/`horizon` or `scheduler`/`scheduler-worker` role.
  Roles are comma-separated.
- **Database and cache hosts are plain configuration.**
  `config/database.php` reads `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`, and `REDIS_HOST`/`REDIS_PORT`/`REDIS_PASSWORD`, including optional read/write splits.
  Upstream pins `postgres:15-alpine` and `redis:7-alpine`.
- **Coolify's own configuration is 13 variables** (`.env.production`): seven generated secrets (`APP_ID`, `APP_KEY`, `DB_PASSWORD`, `REDIS_PASSWORD`, `PUSHER_APP_ID`, `PUSHER_APP_KEY`, `PUSHER_APP_SECRET`), three bootstrap-only admin fields, and literals.
  `AUTOUPDATE` is read by `config/constants.php`; `SSH_MUX_ENABLED` exists as a switch.
- **Private keys are API-loadable and database-resident.**
  `routes/api.php` exposes `POST /api/v1/security/keys` behind `api.ability:write`; keys are stored encrypted under `APP_KEY` and materialised to `storage/app/ssh/keys` by the application, which tests that directory for writability at boot.
- **Elevation on a runner is a string rewriter, not a permission set.**
  `parseCommandsByLineForSudo()` prefixes `sudo ` onto every generated line and after every unquoted pipe; the documented non-root rule is `NOPASSWD: ALL`.
  A runner is therefore root-equivalent to whoever holds the control plane's key, and the machine boundary is the only one that exists.
- **`Server` id 0 is permanent.**
  `Server::isCoolifyHost()` is `ip === 'host.docker.internal' || id === 0`, the sidebar hides its danger zone, and `ProductionSeeder` creates it unless `isCloud()`.
- **Application domains carry a scheme.**
  Upstream docs: an `https://` domain makes the runner's proxy request and renew a certificate; an `http://` domain "creates an HTTP route" and requests nothing.
  A server's **Wildcard Domain** setting is the template from which new applications get their generated hostname.
- **Gateway API wildcards are suffix matches across labels** — `*.example.com` "would match both `test.example.com`, and `foo.test.example.com`" — while X.509 wildcards match exactly one label.
  The cluster's `wildcard-tls` is issued for `${DC_DOMAIN}` and `*.${DC_DOMAIN}`; both Gateways' HTTPS listeners carry no `hostname` and reference that one Secret.
  A second HTTPS listener on the same port must carry a `hostname`, and one as broad as `*.${DC_DOMAIN}` would take every lab SNI away from the catch-all.
- **Cloudflare's free certificate covers an apex and one wildcard level.**
  A proxied three-label name under the zone needs Advanced Certificate Manager.
- **The tunnel pattern exists twice over.**
  `tofu/cloudflare/tunnel/main.tofu` is a module taking `ingress-rules` and writing the connector token to 1Password; `tofu/cf.idp-tunnel.tofu` is its hand-rolled predecessor, whose note declares the identity tunnel IdP-only because "connector placement is a property of the tunnel".
  `apps/network/cloudflare-tunnel` is the connector shape: two `cloudflared` replicas, remotely managed config, token from ESO, `http2` transport pinned.
- **Secret tiers, and the Flux key is already dedicated.**
  `.sops.yaml` declares per-cluster `da-flux` and `en-flux` age recipients, and its creation rule for `kubernetes/clusters/<domain>/.*\.sops\.yaml` encrypts to `john`, `lab`, and that cluster's Flux key.
  `k3s-seed-secrets` in `modules/services/kubernetes/kubernetes.nix` renders the Flux private half from the sops secret `kubernetes/flux/<dc-domain>/age-key` and applies it into `flux-system`; that is how `op-connect.sops.yaml` bootstraps 1Password Connect, and any further file under `clusters/<domain>/config/` gets the same recipients and the same decryption.
  tofu reads `data.sops_file.secrets` and derives 1Password items from it; apps consume 1Password through ESO, whose 1Password provider documents only Password and Document item types, matched by item title and field label.
- **Edge authentication is a house pattern, not a future.**
  The arr apps on `envoy-external` carry an Envoy `SecurityPolicy` whose `extAuth` forwards the cookie to the tofu-managed authentik proxy outpost (`${AK_OUTPOST_PROXY}` in `auth`, path `/outpost.goauthentik.io/auth/envoy`), plus a deliberately untargeted sibling `HTTPRoute` for `/outpost.goauthentik.io` and any path that authenticates itself.
  Discovery keys on the gated route's name and `authentik.rbn/*` labels.
  Coolify ships `authentik` among its OAuth providers (`OauthSettingSeeder`) and has `disable_registration_when_oauth_enabled`; its API is bearer-token authenticated with per-token abilities, and `routes/webhooks.php` carries the git-provider event endpoints that validate their own signatures.
- **Both browser websockets are same-origin when the UI is served on 443.**
  The UI opens two: Reverb (live logs, status, notifications; container port 6001, path `/app/<key>`) and the terminal (a shell into containers and runners; container port 6002, path `/terminal/ws`).
  `getRealtime()` returns no port when the page was loaded without one, so Echo connects to `wss://<host>/app/<key>`; `terminal.js` drops its `:6002` when `window.location.port` is empty, and `window.terminalConfig` (from `TERMINAL_HOST`/`TERMINAL_PORT`/`TERMINAL_PROTOCOL`) can override the host.
  The upstream compose publishes 6001 and 6002 for the bare-Docker install only.
- **Envoy Gateway can hold a route to client networks.**
  `SecurityPolicy.authorization` takes `defaultAction` and `rules[].principal.clientCIDRs`; it evaluates the connection's source address unless a `ClientTrafficPolicy` sets `clientIPDetection`.
- **Cluster contract** (`kubernetes/AGENTS.md`, `kubernetes/components/cnpg-database/AGENTS.md`): app-template HelmReleases via per-app `OCIRepository`, digest-pinned images, per-site namespaces selected per cluster, CNPG through the `cnpg-database` component whose NetworkPolicy admits only pods labelled `app.kubernetes.io/name: ${APP}`, no node or topology names in the shared tree, Envoy Gateway ingress with `envoy-external` WAN-reachable and `envoy-internal` LAN-only, no prophylactic Cilium grants, every storage class `reclaimPolicy: Delete`.
- **Hypervisor contract** (`modules/system/virtualization/talos.nix`): a parametric `__functor` aspect under `rbn.system._.virtualization`, NixVirt domain with a `mk-uuid`-derived UUID and MAC, a qcow2 under `/warp/vms/`, a real bridge rather than `virbr0`, secrets reaching the guest off-store.
  The Talos guest is seeded by a nocloud ISO because it is not NixOS; that machinery is the part a NixOS guest does not need.

## Goals / Non-Goals

**Goals:**

- A control plane with no writable state outside CNPG, so a pod is replaceable and the disaster-recovery set is one 1Password item, one sops file, and one database.
- Runners that are identical, carry nothing precious, and can be destroyed and re-minted from the flake without touching the control plane.
- Exactly one place the version lives: the image digest in the HelmRelease.
- Exactly one source for the runner identity: a keypair generated once and committed as a pair, with no copy anywhere that can drift.
- Nothing deployed through Coolify is reachable from the internet until a tofu commit says so.

**Non-Goals (design-level, beyond the proposal's):**

- High availability.
  One replica per role; the CNPG cluster is single-instance like every other app's.
- Horizontal scaling of the Horizon worker.
  One worker is plenty for a prototyping tier, and Coolify's own deployment concurrency is a per-server setting.
- Coolify's "Sentinel" metrics agent on runners.
  It is a container Coolify starts over SSH with the Docker socket mounted; it is not disabled, merely not depended on.
- A Coolify-managed proxy on the control plane.
  There is no `Server` there to run one.
- Terminating vanity-hostname TLS anywhere we operate.
  Cloudflare presents the certificate; the origin leg is plain HTTP by design.

## Decisions

### D1: One HelmRelease, four controllers, roles by environment

**Chosen:** a single `app-template` HelmRelease `coolify` with controllers `web`, `worker`, `scheduler`, and `redis`.
The three Coolify controllers run the same digest-pinned image and differ only in `COOLIFY_CONTAINER_ROLE`; the exact role string for a web-only container is read from the image's `s6-overlay/scripts/container-role` at implementation time, and the shape does not depend on it.

**Why:** the three Coolify roles must never run different versions — Horizon serialises job classes into Redis and the scheduler assumes the web tier's migrations have run — and one release with one digest makes skew structurally impossible.
The `cnpg-database` NetworkPolicy matches `app.kubernetes.io/name: ${APP}`, which app-template stamps from the release name, so one release also lets every role reach Postgres without widening the policy.
Splitting roles into controllers keeps a Horizon restart from taking the UI down and keeps the scheduler at exactly one instance, which matters because a duplicated scheduler double-fires every cron.

**Alternatives:**

- _One `all` container_ — simplest, and the fallback if the image turns out to have no web-only role.
  Costs: every restart is a full restart, and no per-role resource limits.
- _A HelmRelease per role_ — three digests to forget to bump together; the label could be forced with `nameOverride`, but the skew hazard is the real objection.
- _Redis as its own release_ — equally valid, since it needs no database label; kept in one release because its state dies with the pod anyway and there is nothing to version independently.

### D2: Postgres from the `cnpg-database` component; Redis on `emptyDir`

**Chosen:** `coolify-db.ks.yaml` attaches `kubernetes/components/cnpg-database` with `APP: coolify`, and `DB_PASSWORD` resolves to the component's shared 1Password `postgres` field, as the component rule requires.
The `redis` controller runs `redis:7` on `emptyDir`, authenticated with `REDIS_PASSWORD` from ESO.

**Why:** CNPG is the house path and makes the database the only durable state.
Redis holds the Horizon queue and cache; losing it on a pod restart drops in-flight deployment jobs, which are re-triggered from the UI, and nothing else.
That is a fair trade for not introducing a PVC whose only job is to survive a restart.

**Alternatives:**

- _Upstream's two containers_ — reintroduces un-backed-up state on an `emptyDir` or two PVCs, for no benefit over CNPG.
- _Redis with a PVC_ — durable queue, one more thing that can be pruned to destruction under `reclaimPolicy: Delete`.

### D3: No PVC on the control plane

**Chosen:** every path upstream bind-mounts under `/data/coolify` becomes an `emptyDir`.
SSH key material is **not** mounted: Coolify stores private keys encrypted in Postgres and materialises them into `storage/app/ssh/keys` itself, so the database is the source of truth and `APP_KEY` is what makes it durable.
ControlMaster sockets under `storage/app/ssh/mux` are scratch by nature.

**Why:** a dispatch-only control plane renders compose files and pulls backups only as transient work; the proposal already rules out using Coolify's database-backup feature.
With keys in Postgres, there is nothing left that needs to outlive the pod.

**Alternatives:**

- _A PVC for `storage/app/ssh`_ — puts unix sockets on a networked volume, which is a known failure mode, and persists keys the database already holds.
- _Mounting the keypair as a read-only secret_ — gives Coolify a directory it expects to write into, and it throws at boot when it cannot.

**Verification owed:** confirm at implementation that the image rewrites `storage/app/ssh/keys` from Postgres on boot; if it only writes on key creation, the `web` controller gets an init step that calls the same code path.

### D4: Configuration is rendered, never generated

**Chosen:** the instance secrets arrive from one `ExternalSecret` (1Password item `coolify`: `APP_ID`, `APP_KEY`, `PUSHER_APP_ID`, `PUSHER_APP_KEY`, `PUSHER_APP_SECRET`, `REDIS_PASSWORD`; plus the component's `postgres` field for `DB_PASSWORD`) through app-template `envFrom`; the literals (`APP_NAME`, `DB_HOST=coolify-db-rw`, `DB_USERNAME=coolify`, `REDIS_HOST`, `PUSHER_BACKEND_PORT`, `AUTOUPDATE=false`, `SELF_HOSTED=true`) are values in the HelmRelease.
`APP_KEY` and the Pusher triple are generated once, by hand, with the same `openssl` incantations the installer uses, and committed to 1Password.
The `ROOT_USER_*` fields are not set; the first registration becomes the admin, and registration is then closed in settings.

**Why:** Nix cannot mint secrets at evaluation, and Coolify's installer is the only other thing that would.
Rendering from ESO is what every other app does, and it removes the installer from the picture entirely.
The runner keypair is deliberately **not** in this item — see D8.

**Verification owed:** Laravel reads process environment, but the image's entrypoint may insist that `/var/www/html/.env` exist.
If it does, the same secret is also projected as a file at that path; the values stay single-sourced.

### D5: `SELF_HOSTED` stays `true`; the id-0 row is tolerated, not fought

**Chosen:** run as a self-hosted instance and accept a permanently unreachable `localhost` server in the UI.
Spike its cost before build-out: the per-minute `ServerCheckJob` family against a `Server` that resolves `host.docker.internal` to nothing must fail quietly and cheaply.

**Why:** `SELF_HOSTED=false` is the documented way to have no local server, but it is also the switch for the hosted product — subscription checks, Horizon pool sizing, and whatever else is gated on `isCloud()`.
Taking that on to hide one red row is the wrong trade unless the spike shows the row is actively harmful.

**Alternatives:**

- _`SELF_HOSTED=false`_ — the fallback if the spike shows noisy failures or wasted worker capacity; its own surface then needs auditing.
- _Deleting the row in Postgres after seeding_ — fights the seeder on every boot and the `id === 0` checks sprinkled through the model.

### D6: A runner is a NixOS host, not an image

**Chosen:** each runner guest is a first-class host under `modules/hosts/`, named `da-cfy-<N>` where `N` is the hosting compute node's suffix, built and deployed with the same `nixos-rebuild --target-host` path as every physical node.
The `<rbn/system/virtualization/coolify-runner>` aspect on the hypervisor declares only the domain: `mk-uuid` identity, stable MAC, `vcpus`/`memory`, a qcow2 under `/warp/vms/`, and the bridge for the runner VLAN.
First boot is from the standard installer ISO with the host's disk layout; there is no seed ISO and no activation-time merge step.

**Why:** Coolify's whole function on a runner is to mutate `/data/coolify` and the Docker state beside it.
An immutable image fights that from the first deployment, and a nocloud seed exists only because Talos is not NixOS.
A guest that is just another host gets `facter`, the deploy tooling, and the module system for free.
Tying `N` to the compute node makes the hostname, the development URL, and the hypervisor include agree without a lookup table, at the cost of ruling out two runners on one node, which nothing wants.

**Alternatives:**

- _`nixos-generators` disk image in the store_ — reproducible first boot, then an impermanence design to protect `/data/coolify` and `/var/lib/docker`.
  Disproportionate for a disposable machine.
- _Talos-style seeded image_ — solves a problem the guest does not have.

### D7: What a runner contains, exhaustively

**Chosen:** `virtualisation.docker` with `daemon.settings` carrying the address pool and the `json-file` log rotation the installer would have written; `openssh` with `PermitRootLogin prohibit-password`, password authentication off, and the committed public key as root's only authorized key; `git`, `curl`, `jq`, `openssl` on the path because Coolify's generated commands call them; a `/data/coolify` tree pre-created with `systemd.tmpfiles`.
Nothing else: no user accounts beyond root and the deploy user, no sops secrets, no mounts of lab storage, no Tailscale or ZeroTier.

**Why:** everything on the runner is reachable by anything Coolify deploys to it.
The way to keep that cheap is for the answer to "what did they get" to be "a Docker daemon and some containers".
The Docker address pool is chosen away from `10.244.0.0/16`, `10.96.0.0/16`, `10.32.0.0/16`, `10.36.0.0/16`, and `10.42.0.0/24`; the `172.16.0.0/12` range is the candidate and is checked against the site plan before use, because the installer's own default of `10.0.0.0/8` would overlap all of them.

**Alternatives:**

- _A non-root `coolify` user with `NOPASSWD: ALL`_ — upstream's "experimental" path, strictly more moving parts for the same privilege, and it routes every command through the sudo rewriter, which is the component with the most upstream churn.
- _A `docker`-group user without sudo_ — fails on the `chown`/`chmod`/`tee` lines Coolify emits, and is root-equivalent anyway.

### D8: One keypair, generated once, committed as a pair

**Chosen:** `ssh-keygen -t ed25519` is run once.
The private key is committed to `kubernetes/clusters/da.jm0.io/config/coolify-runner.sops.yaml`, where the existing creation rule encrypts it to `john`, `lab`, and `da-flux` — **not** to any runner.
Flux decrypts it into a `Secret` in the `coolify` namespace, and a Flux-gated `Job` in the control plane's tree loads it through `POST /api/v1/security/keys`, idempotently on fingerprint.
The public key is committed in plaintext as `modules/system/virtualization/coolify-runner.pub` and read at evaluation into every runner's `authorizedKeys`.
The same keypair is authorized on every runner.

**Why:** both halves come from one command and land in one commit, so there is no second source to synchronise and nothing to drift.
The public half is plaintext because it is public; encrypting it would put secrets infrastructure on the runner to protect nothing, which D7 forbids.
The private half uses the Flux-decrypted sops path rather than 1Password because the key is host-tier infrastructure, which is the tier sops already owns, and because a hand-copied 1Password item is exactly the second source this decision exists to eliminate.
One key per fleet keeps the runner aspect free of per-instance secrets, and the runners are deliberately indistinguishable — a compromised runner yields a key that opens its siblings, all of which are equally disposable, and nothing else.

**Alternatives:**

- _Private key in 1Password, public key as a literal_ — two sources, one of them hand-maintained; a drift check would have been needed.
- _Public key via sops on the runner_ — pointless encryption and a sops dependency on a machine designed to have none.
- _Keypair generated inside Coolify, public half copied out_ — the private key would exist only in Postgres, which is tidy, but then re-minting runners after a database loss requires a new key everywhere; the committed pair survives a database loss.
- _tofu bridge into 1Password_ (`data.sops_file` → `onepassword_item` → ESO) — the same single source with one more hop; unnecessary because the per-cluster Flux decryption path is already keyed and rule-covered.

### D9: One namespace, one cluster, the UI behind authentik

**Chosen:** `kubernetes/apps/coolify/` is a per-site namespace selected only by `clusters/da.jm0.io/apps/kustomization.yaml`, with the same wrapper shape `auth` uses.
The UI is exposed on `envoy-external` in the arr-app shape:

- `HTTPRoute coolify` — `coolify.${DC_DOMAIN}`: the UI on 8080 and Reverb on 6001 under `/app`, targeted by a `SecurityPolicy` whose `extAuth` forwards the cookie to `${AK_OUTPOST_PROXY}`; carries `authentik.rbn/enabled` and the name, group, icon, and access-group annotations discovery expects.
- `HTTPRoute coolify-outpost` — same hostname, deliberately untargeted: `/outpost.goauthentik.io` to the outpost; `/webhooks` to Coolify, which validates each git provider's signature.
- `HTTPRoute coolify-restricted` — same hostname: `/terminal/ws` to the terminal server on 6002, `/api` and `/horizon` to 8080; targeted by a second `SecurityPolicy` that forwards the cookie to the outpost **and** carries an `authorization` block with `defaultAction: Deny` and one allow rule whose `clientCIDRs` are `10.32.0.0/16`, `10.42.0.0/24`, `10.42.32.0/24`, and `10.42.42.0/24` — the lab, the management network, and the ZeroTier mesh.
- Coolify's own `authentik` OAuth provider configured from a tofu-managed OAuth2 provider, so the login behind the gate is a one-click SSO on the same authentik session, and `disable_registration_when_oauth_enabled` closes self-registration.

Only 443 is exposed; both websockets ride the same origin by construction (Context).
In-cluster callers of the API use the namespace `Service`, not the public hostname, so they never meet the CIDR rule.
The UI is never on the Coolify tunnel.

**Why:** the proposal's reason for a dedicated namespace is the credential set it holds; the reason for `da` only is that there is one fleet of runners and they are in `da`.
The UI is root on every runner, which argues for the strongest gate the cluster has, and that gate is the outpost: the identity provider sees every request before Coolify does, exactly as it does for sonarr.
`/webhooks` is the one surface reachable from the WAN without an identity session, because it is how `git push` becomes a deploy, and it authenticates itself by provider signature the same way the arr apps' `/api` relies on `X-Api-Key`.
The terminal is a root shell into runners and the API can do anything the UI can, so both are held to networks we own on top of the gate; the UI and Reverb are external because live logs without the UI's websocket is not a usable UI.
A second control plane in `en` would be a second keyring and a second set of runners, which is a different change.

**Alternatives:**

- _`envoy-internal` only_ — the first draft of this decision.
  Cheaper, but it forces deploys through an in-cluster caller of `/api/v1/deploy` instead of git-provider webhooks, and it protects nothing the outpost does not.
- _Terminal and API fully external behind the outpost_ — one fewer route and policy; rejected because a root shell and a deploy API deserve a network boundary as well as an identity one, and the CIDR rule costs one block.
- _`TERMINAL_HOST` on a hostname that resolves only to `envoy-internal`_ — moves only the terminal; `/api` and `/horizon` would still need the rule, so it adds a hostname for no coverage.
- _Edge gate without Coolify's OAuth provider_ — two unrelated logins and an open registration page behind the first one.
- _Coolify's OAuth provider without the edge gate_ — Coolify's login, API, and realtime endpoints reachable anonymously from the WAN; the outpost is the house answer to that.

### D10: Two ingress paths, split by who presents the certificate

**Chosen:**

- **Development URL.** Each runner's Coolify Wildcard Domain is `http://*.cfy-<N>.${DC_DOMAIN}`, so new applications get `http://<uuid>.cfy-<N>.${DC_DOMAIN}` with no certificate requested.
  A per-cluster patch adds `*.cfy-<N>.${DC_DOMAIN}` to the `wildcard-tls` certificate's `dnsNames`; the existing `envoy-internal` HTTPS listener, having no `hostname`, already admits those names; one `HTTPRoute` per runner routes `*.cfy-<N>.${DC_DOMAIN}` to a selector-less `Service` whose `EndpointSlice` is the runner's address on port 80; one router DNS record per runner points `*.cfy-<N>.${DC_DOMAIN}` at the internal gateway.
- **Vanity hostname.** A Coolify tunnel from the `tofu/cloudflare/tunnel` module carries one ingress rule per vanity hostname, `service = http://<runner-ip>:80`, and one proxied CNAME per hostname to `<tunnel-id>.cfargotunnel.com` in that hostname's zone.
  Its connector runs as a second `cloudflared` deployment in `apps/coolify/`, token from 1Password item `cf-tunnel-coolify` through ESO.
  The application's Coolify domain is set to `http://<vanity>`; the development URL may stay as an additional domain for LAN testing.

**Why:** the two kinds of name have different certificate stories, and each path puts TLS where it is free.
Development URLs are three labels under the apex, which Cloudflare's free certificate cannot cover but cert-manager's wildcard can with one SAN per runner.
Vanity hostnames are an apex or one level, which Cloudflare covers for free and which cert-manager would need a per-zone DNS-01 credential for.
Routing the tunnel straight to the runner rather than through Envoy skips a per-hostname `HTTPRoute`, a certificate Envoy would need to present to `cloudflared`, and the `:80` redirect loop the gateway's HTTP listener would otherwise cause.
Keeping development URLs off the WAN means nothing deployed through Coolify is public until a tofu commit names it.

**Alternatives:**

- _One tunnel for everything_ — development URLs would need Advanced Certificate Manager, and LAN clients would hairpin through Cloudflare.
- _Everything on `envoy-external` with a per-vanity-host certificate_ — one `HTTPRoute` plus one `Certificate` plus a Cloudflare API token scoped to each vanity zone, per promotion, and the lab's WAN DNAT in the path.
- _A per-runner tunnel_ — N tunnels, N tokens, runners needing WAN egress, and still no LAN path.
- _A second HTTPS listener with its own certificate_ — needs a `hostname`; a runner-specific one puts topology in the shared tree, and `*.${DC_DOMAIN}` would steal every lab SNI from the catch-all.
- _A dedicated `Gateway` in the `coolify` namespace_ — clean, but a second Envoy proxy and a second LB address for the sake of one certificate; the SAN patch is cheaper and uses the mechanism the cluster already has for per-cluster values.

### D11: Topology lives in the per-cluster tree

**Chosen:** everything that names a runner — the sops key file, the `wildcard-tls` SAN patch, the per-runner `HTTPRoute`s, `Service`s, and `EndpointSlice`s — lives under `kubernetes/clusters/da.jm0.io/`.
`kubernetes/apps/coolify/` contains only the topology-free control plane: HelmRelease, the three UI `HTTPRoute`s and their two `SecurityPolicy`s, `ExternalSecret`s, key-loading `Job`, and the tunnel connector.

**Why:** the cluster rule is that node names never appear in the shared tree, and a runner's name and address are exactly that kind of fact.
It also keeps "add a runner" to one place: a SAN, a route, a service, a DNS record, a DHCP reservation, all per cluster.

## Risks / Trade-offs

- **Forwarded scheme** → both paths deliver plain HTTP to the runner's proxy, so applications see `https` only if that proxy trusts `X-Forwarded-Proto` from Envoy's and `cloudflared`'s source addresses.
  Mitigation: inspect the generated Traefik configuration on the first runner and set `trustedIPs` through Coolify's proxy-config editor before the first vanity hostname; the setting is per server and persists in `/data/coolify/proxy`.
- **Expired outpost session on a live websocket** → ext-auth runs on the upgrade request, which carries the cookie like any other; once the session lapses, Echo's reconnect receives a login redirect it cannot follow and the UI shows disconnected until a reload.
  Cosmetic and accepted.
- **Source address at the gateway** → the restricted route's CIDR rule evaluates the connection's source address; if the Envoy `LoadBalancer` service SNATs to a node address, every client looks like a node and the rule admits everyone or no one.
  Mitigation: before relying on the restricted route, confirm from Envoy's access log that a LAN client appears as its own address; `externalTrafficPolicy: Local` on the Envoy service is the usual fix, and `clientIPDetection` on a `ClientTrafficPolicy` the alternative when a trusted hop is in front.
  WAN DNAT preserves the client address, so the rule denies WAN clients correctly once LAN clients are seen correctly.
- **One WAN bypass on a root-equivalent surface** → `/webhooks` is reachable from anywhere without an identity session.
  Accepted because provider signatures authenticate it and it is the deploy trigger; `/api` sits behind both the gate and the CIDR rule, and `is_api_enabled` stays off until something needs it, with tokens issued at the narrowest ability that works.
- **Runner addresses are hard-coded twice** → in the `EndpointSlice` and in tunnel rules.
  Mitigation: the address is pinned by a DHCP reservation keyed on the aspect's deterministic MAC, declared in tofu alongside the DNS record, so it changes only by commit.
- **Postgres major mismatch** → the component has no image parameter and runs the operator's default major; upstream is on 15.
  Mitigation: stand the database up and run Coolify's migrations against it in a throwaway namespace first.
  If they fail on a newer major, the component gains an `IMAGE` parameter in a small preceding change rather than a one-off fork.
- **Shared database password** → the component's interim shared `postgres` field means Coolify's `DB_PASSWORD` is every app's password.
  Accepted as the house interim; the component's NetworkPolicy is the boundary, and OpenBao is the planned fix.
- **The tunnel module has never been applied** → `tofu/cloudflare/tunnel/main.tofu` references `vars.` where `var.` is meant and a resource type name that differs from the one `cf.idp-tunnel.tofu` uses.
  Mitigation: the first instantiation will surface this at `tofu validate`; fixing the module is in scope because the Coolify tunnel is its first consumer, and the identity tunnel stays on its hand-rolled file.
- **Pod egress to runners is unrestricted** → the control plane pods wear no Cilium grant yet, by the cluster's policy contract.
  Mitigation: observe in audit mode once the fleet exists, then add a grant to runner addresses on `:22` plus registries, in its own change.
- **A runner's network reach is the lab's** → until the runner VLAN and egress rules land, a root shell in a runner sees `10.32.0.0/16`.
  Accepted and sequenced, per the proposal; the bridge parameter is already the seam the VLAN plugs into, and the eventual inbound rule is already known: `:22` from the control plane, `:80` from the cluster.
- **The id-0 row** → see D5; the spike decides.
- **Flux prune under `reclaimPolicy: Delete`** → the CNPG `Cluster` carries `prune: disabled` from the component; nothing else in the control plane is worth protecting, which is the point of D3.

## Migration Plan

1. Generate once: the 1Password item `coolify` (`APP_ID`, `APP_KEY`, Pusher triple, `REDIS_PASSWORD`, with the installer's own `openssl rand` forms) and the runner keypair (`ssh-keygen -t ed25519`), committing the private key to `clusters/da.jm0.io/config/coolify-runner.sops.yaml` and the public key to `modules/system/virtualization/coolify-runner.pub` in the same change.
2. Land `coolify-db.ks.yaml` and let CNPG create the database; verify Coolify's migrations against the operator's Postgres major in a throwaway namespace (Risks).
3. Add the Coolify proxy provider, application, and OAuth2 provider in `tofu/authentik/` and apply; land the HelmRelease, the three `HTTPRoute`s and two `SecurityPolicy`s, `ExternalSecret`, and key-loading `Job`; select the namespace in `da.jm0.io`.
   Register the first user through the gate, enter the authentik OAuth client into Coolify's settings, enable `disable_registration_when_oauth_enabled`, sign out and back in through authentik; confirm the key appears in Coolify's key store.
   Confirm from Envoy's access log that a LAN client reaches `/terminal/ws` as its own address and a WAN client is refused (Risks) before the terminal is used in anger.
4. Run the D5 spike against the live instance.
5. Build the first runner (`nixos-rebuild build --flake .#da-cfy-1`), add the `coolify-runner` include to `da-vcx-1` with the runner's DHCP reservation and `*.cfy-1.${DC_DOMAIN}` DNS record in tofu, deploy the hypervisor, install the guest from the installer ISO, deploy the guest.
6. Land the per-cluster SAN patch, `HTTPRoute`, `Service`, and `EndpointSlice` for `cfy-1`; confirm `wildcard-tls` reissues with the new SAN.
7. Register `da-cfy-1` in Coolify with Wildcard Domain `http://*.cfy-1.${DC_DOMAIN}`, let its validation install nothing, deploy a static hello-world, and load its development URL over HTTPS from the LAN.
   Check the forwarded scheme the application observes and set the proxy's trusted addresses if needed.
8. Instantiate the Coolify tunnel in tofu with the hello-world's vanity hostname as its first rule, store the connector token, land the connector deployment, and load the vanity hostname from off-LAN.
9. Repeat steps 5–7 per additional compute node as each is deployed.

**Rollback:** removing the namespace from the cluster selection prunes everything except the CNPG `Cluster`, which is deleted deliberately with `kubectl` if the change is abandoned; the per-cluster runner manifests and SAN patch are removed with it.
A runner is removed by dropping its include from the hypervisor host and deleting the qcow2; nothing else on the hypervisor changes.
The tunnel is destroyed in tofu, which also removes its 1Password item.
The 1Password item `coolify` and the sops key file are kept until the CNPG volume is gone, because `APP_KEY` is the only thing that makes the database readable.

## Open Questions

- **Web-only role string** — read from the image at implementation; D1 records the fallback.
- **Docker address pool** — `172.16.0.0/12` pending a check against the site plan; any unused RFC1918 range the lab does not route works equally well.
- **Whether Coolify's generated Traefik configuration already trusts forwarded headers** — decides whether step 7 needs the proxy-config edit; either way the step exists.
- **Whether Coolify's OAuth settings are API-settable** — decides whether the client entry in step 3 is a UI action or part of the key-loading `Job`; the value is durable in Postgres either way.
