## Context

See proposal.md for motivation.
The facts that shape the approach:

- `provider` blocks, `module` instances, `import` blocks, and `moved` blocks are root-only constructs, and a `module` block cannot `for_each` over instances that need different provider aliases.
  The three relay instances, the two per-site discovery instances, and the three tunnel instances are therefore spelled out in the root; the lower bound on root content is those eight blocks plus providers.
- Today's root module in `tofu/` is 18 files and 1,606 lines.
  By job: provider setup (`main.tofu`, `sops.tofu`, `op.tofu`, `cloudflare.tofu`, and provider blocks inside `ak.tofu`, `ak.discovery.tofu`, `da.mikrotik.tofu`, `en.mikrotik.tofu`), network definition (`holonet.tofu`, `zerotier.tofu`), per-site instances and records (`da.mikrotik.tofu`, `en.mikrotik.tofu`, `da.cloudflare.tofu`, `en.cloudflare.tofu`, `da.openbao.tofu`), authentik wiring (`ak.tofu`, `ak.discovery.tofu`, `ak.service-connections.tofu`, `ak.variables.tofu`), Cloudflare one-offs (`cf.idp-tunnel.tofu`), and one-shot blocks (107 `import` across five files, 5 `moved` in `ak.moved.tofu`).
- The per-site duplication is exact modulo the site name: `da.cloudflare.tofu` and `en.cloudflare.tofu` are the same four records; `ak.discovery.tofu` carries a namespace and an HTTPRoute data source per site because a data source cannot pick its provider by key; `ak.service-connections.tofu` is en-only today and would be copied for every further remote site.
- Public ingress today: Cloudflare `<site>.<root>` and `*.<site>.<root>` are unproxied CNAMEs to the relay01 IP Cloud DDNS name; the relay forwards WAN 80 and 443 to the site VIP (`n03`, `n04` in `tofu/mikrotik/firewall.nat.tofu`) and hairpins LAN traffic to its own WAN address (`n09` to `n12`), all behind `enable-hairpin`.
  LAN clients already resolve the site domain to the VIP through the mikrotik module's `routeros_ip_dns_record.dc-vip-split-horizon` (`match_subdomain = true`), which makes the four root-level `routeros_ip_dns_record.<site>-apex` and `-wildcard` CNAMEs redundant.
- The IdP tunnel (`cf.idp-tunnel.tofu`) is remotely managed (`config_src = "cloudflare"`) but was created with an explicit `tunnel_secret` from sops, and its connector token is assembled by hand as `base64({a, t, s})` and written to the 1Password item `cf-tunnel-idp`, which `kubernetes/apps/network/cloudflare-tunnel/app/external-secret.yaml` reads by title.
  On the locked provider (cloudflare 5.20.0) `tunnel_secret` is optional and documented as the password for a locally-managed tunnel, and the `cloudflare_zero_trust_tunnel_cloudflared_token` data source returns the connector token for a tunnel id.
- Each cluster runs an `envoy-external` Gateway at `${LB_PREFIX}.1` with the `wildcard-tls` certificate for `${DC_DOMAIN}` and `*.${DC_DOMAIN}`, and an HTTP listener that 301s to HTTPS.
  Flux substitutes `DATACENTER`, `DC_DOMAIN`, `DOMAIN`, and `LB_PREFIX` per cluster.
  The `cloudflare-tunnel` app is selected only by `kubernetes/clusters/da.jm0.io/apps/kustomization.yaml`.
- Each relay01's IP Cloud DDNS name is also the `ddns` endpoint for that relay in `topology.yaml`, consumed by `holonet.tofu` as the wg-holonet endpoint for public-routable peers.
  wg-holonet is dormant break-glass, not deleted.
- The main checkout's working copy carries the user's sketch: a repo-root `main.tofu` inlining providers plus `module.en-relay01`, `module.kubernetes-da`, `module.kubernetes-en`, `module.en-service-connection`; `tofu/kubernetes/main.tofu` (discovery per site, with a `data.data.` typo); `tofu/cloudflare/{main,da}.tofu` (references `module.da-relay01`, `routeros.da-relay01`, and `local.catalog`, none visible to a child module); `tofu/cloudflare/tunnel/main.tofu` (a generic tunnel module with `vars.` typos and the wrong config resource name); `tofu/cloudflare/configure-r2/` (two empty files); and `tofu/authentik/kube-service-connection/main.tofu`, which creates an `authentik_service_connection_kubernetes` that `module.authentik` already creates in `apps.outposts.tofu`.
- State is on R2, encrypted, reachable only through `just tofu::plan` and `just tofu::apply`, which resolve credentials through secretspec and so need an attended session.
- The repo's agent hooks reject writes whose content contains a literal parent-directory path segment, so this document names paths in words where a relative hop would otherwise appear.

## Goals / Non-Goals

**Goals:**

- Six top-level files in `tofu/`, each with one job, and the count grows only with the number of sites.
- Shared per-site behavior declared once, in a child module, instanced per site.
- No unplanned replace: the only replace in the cutover plan is the IdP tunnel pair, and every other address change is a `moved`.
- No inbound WAN port once the tunnels are live, and no tunnel secret anywhere but Cloudflare, encrypted state, and 1Password.
- No new pass-through layers: a child module exists only where it owns resources or data for more than one call site.

**Non-Goals:**

- Moving relay data (port maps, wifi profiles, static leases, BGP peers) into `topology.yaml`.
  That is the next lever for the site files, and it is a schema change with its own review.
- Deleting wg-holonet or disabling IP Cloud.
- Bringing the two tunnels that live outside this repository under tofu.
- Touching `tofu/servarr/`, `tofu/vault/`, or any authentik resource beyond the two input changes below.
- Changing the just recipes, the `tofu/secrets` and `tofu/topology.yaml` symlinks, or anything governed by `tofu-state`.

## Decisions

### D1. The root module stays in `tofu/`; six files split by job.

`tofu-root-at-repo-root` wanted the repository root as the root module so that bare `tofu` worked without `cd`.
That motive is gone: every invocation now goes through `just tofu::plan` and `just tofu::apply`, which the `tofu-state` capability requires, and `just` runs them with `tofu/` as the working directory.
Moving the root would cost a lock-file move, a provider re-init, and a rewrite of every `${path.root}` reference for no reduction in the thing that actually hurts, which is the duplicated content.

The six files and their jobs are in the `tofu-root-module` spec.
`main.tofu` absorbs `sops.tofu`, `op.tofu`, `cloudflare.tofu`, and every provider block now scattered across `ak.tofu`, `ak.discovery.tofu`, and the two `*.mikrotik.tofu` files, so "where are credentials configured" has one answer.
`cloudflare.tofu` absorbs `cf.idp-tunnel.tofu` and takes the zone from the old `cloudflare.tofu`; `authentik.tofu` is `ak.tofu` minus its 46 imports; `holonet.tofu` absorbs `zerotier.tofu` (D3 of the superseded change, kept).
It does **not** absorb `cf.r2-state.tofu`: R2 provisioning moved to the bootstrap-phase root module, because editing bucket configuration needs account-level `Workers R2 Storage Write` and the configuration-phase token should not carry it. That file is already gone from `tofu/`.
Alternative: one `main.tofu` holding everything, about 600 lines mixing credentials with relay port maps.
Rejected for the same reason as before: every change to a relay would edit the file that holds every provider.

### D2. Leaf modules composed in the site files, not one wrapper module per site.

A `tofu/site/` wrapper instanced per DC would make the root two files, but every RouterOS resource would gain a path segment (`module.da.module.relay01...`), needing three module-level `moved` blocks over 436 resources, and the wrapper would need `configuration_aliases` for a second relay that only da has.
Instead `<site>.tofu` composes three leaf modules directly: `tofu/mikrotik/` (unchanged), `tofu/kubernetes/` (new), and `tofu/cloudflare/tunnel/` (new).
A site file is then one locals block (lab hosts, port maps) and four or five module blocks.
The relay instance addresses `module.da-relay01`, `module.da-relay02`, and `module.en-relay01` do not change.

### D3. `tofu/kubernetes/`: one data-only instance per site.

Carried from the superseded change's D5.
The module takes `site` and an optional `api-server` (the ZeroTier address of that site's API server, non-null only for remote sites) and outputs `routes` (the per-app attribute object `ak.discovery.tofu` builds today, keyed by route name, with `site` set, not yet suffixed) and `authentik-kubeconfig` (sensitive; the kubeconfig assembled from the `authentik-remote-cluster` ServiceAccount secret with the existing postcondition, or `null` when `api-server` is null, with the secret read on `count`).
`module.authentik` gains a `routes-by-site` input and derives the multi-site `-<site>` keying rule itself, replacing the `discovered-apps` variable; `remote-clusters` and `remote-cluster-kubeconfigs` keep their shape and the root builds them from the module outputs.
The service-connection resource stays in `module.authentik`, which already creates it; the sketch's `kube-service-connection` module is deleted rather than moved into state for no gain.
State effect: nil, these are data sources.

### D4. `tofu/cloudflare/tunnel/`: a tunnel owns its DNS records and its connector token.

The module takes `account-id`, `name`, `ingress` (a list of `{hostname, service, origin-server-name}`), `zone-id`, `op-vault`, and `op-title`.
It creates the tunnel (`config_src = "cloudflare"`, no `tunnel_secret`), the tunnel config with the ingress list plus a trailing `http_status:404`, one proxied CNAME per ingress hostname pointing at `<tunnel-id>.cfargotunnel.com`, reads the token through `data.cloudflare_zero_trust_tunnel_cloudflared_token`, and writes it to a 1Password `password` item whose note names the tunnel and the consuming app.
Putting the CNAMEs in the module is the dedupe: the IdP tunnel's `id.<root>` record and each site's apex and wildcard records are the same shape, keyed by hostname, so the per-site DNS files disappear entirely rather than becoming a `for_each` at root.

Instances:

- `module.tunnel-idp` in `cloudflare.tofu`: `id.<root>` to `http://authentik-server.auth.svc.cluster.local:80`, item `cf-tunnel-idp`.
  `moved` blocks carry the config and the record and the 1Password item from their root addresses; the tunnel resource itself is replaced (D5).
- `module.tunnel-<site>` in each `<site>.tofu`: `<site>.<root>` and `*.<site>.<root>` to that site's `envoy-external` gateway over HTTPS with `origin-server-name = <site>.<root>` so SNI matches the wildcard certificate, item `cf-tunnel-<site>`.
  `moved` blocks carry `cloudflare_dns_record.<site>-apex` and `-wildcard` into `module.tunnel-<site>.cloudflare_dns_record.this["<hostname>"]`, so the cutover is an in-place content and `proxied` update with no DNS gap, not a destroy and create.

Alternatives: a `for_each`-over-site pair of records at root (two resources, four `moved`, but the IdP record stays separate and the tunnel still needs its own module); records pushed into `tofu/mikrotik/` through the catalog (the relay knows nothing about the tunnel).
Rejected: the thing the record points at is the tunnel, so the tunnel owns it.

### D5. No tunnel secret anywhere; the IdP tunnel is recreated once.

With `tunnel_secret` omitted Cloudflare generates the secret for a remotely-managed tunnel, and the token data source returns the connector token, so the hand-assembled `base64({a, t, s})` and the `cloudflare.tunnel-secret` sops key have no reason to exist.
The IdP tunnel was created with the secret set; dropping the argument is expected to force a replacement.
Accepted: the new tunnel id flows into the record (in-module, same apply), the 1Password item is rewritten, ESO resyncs within its refresh interval, and the da connector restarts with the new token.
`id.<root>` is down from the apply until the connector reconnects.
Alternative: an optional `tunnel-secret` input that only the IdP instance passes, making its migration a pure `moved` and deferring the recreate.
Rejected by the user: carrying the secret for one instance keeps the sops key and the double store alive for a one-line change later.

### D6. Cutover order: tunnel up, records flipped, then NAT closed.

Each site's cutover is three applies, in order, with a verification between each:

1. Tofu creates the site tunnel, its config, and the 1Password item; the site records stay on DDNS because they are not yet in the module.
   Verify the item exists and the tunnel is `inactive`.
2. Flux reconciles the site's `envoy-external` connector from the new item.
   Verify the tunnel is `healthy` and a request through `<tunnel-id>.cfargotunnel.com` with the site host header returns the gateway's response.
3. Tofu applies the `moved` blocks and the record update, flipping both records to the tunnel.
   Verify public resolution and a public request to a known app.
4. Only then `enable-hairpin = false` on that site's relay01, removing `n03`, `n04`, `n09` to `n12`, and the `no-hairpin-dst` list.
   Verify a WAN probe of 443 is refused and a LAN client still reaches the VIP.

Step 1 and 3 are separate because a `moved` into a module instance that does not exist yet is a replace, and because the records must not point at a tunnel with no connector.
The four RouterOS CNAME deletions ride with step 4; LAN resolution does not depend on them.

### D7. Connector per tunnel per cluster, selected by cluster.

`kubernetes/apps/network/cloudflare-tunnel/` becomes two app directories under one namespace: `idp/` (today's manifests, da only) and `envoy-external/` (the same chart with `cf-tunnel-${DATACENTER}` as the ExternalSecret key and `envoy-external` in the release name), each with its own `.ks.yaml`.
da selects both; en selects `envoy-external` only.
The connector Deployment keeps `TUNNEL_TRANSPORT_PROTOCOL: http2`, the two replicas, and the spread constraint; nothing about cloudflared's invocation changes because the ingress config stays remote.
Alternative: one Deployment running two tunnels.
Rejected: cloudflared runs one tunnel per process, and the spec requires one item per Deployment.

### D8. Applied one-shot blocks are deleted after a per-address check against state.

Carried from the superseded change's D6.
It no longer covers the R2 bucket import, which left with `cf.r2-state.tofu` when provisioning moved to the bootstrap root; that import is the bootstrap module's concern and is already applied there.
The check: extract every `to =` address from the six files, expand the three `for_each` imports from `local.da-ports.relay01` (ether keys only), `local.da-ports.relay02`, and `local.en-ports.relay01`, and require each to appear in `tofu state list`.
Any miss keeps that block and stops the change.
The `moved` blocks this change introduces (the IdP config, record, and item; the four site records) are retired in a follow-up commit once the cutover plan is clean, per the `tofu-root-module` spec.

### D9. The authentik module reads `tofu/authentik.auto.tfvars.json` itself.

Carried from the superseded change's D7, unchanged in substance.
`permissions` becomes a local built as `fileexists(p) ? jsondecode(file(p))["authentik-builtins"]["permissions"] : {}` with `p = "${path.root}/authentik.auto.tfvars.json"` (the root is `tofu/`, so no `tofu/` prefix); the `permissions` variable, the root `authentik-builtins` variable, and `ak.variables.tofu` go away.
The file keeps its name because `*.tfvars.json` is already gitignored and the just recipe writes it there.

### D10. Sops reads collapse to two `for_each` data sources.

`data.sops_file.shared` iterates `{da, en, secrets, authentik, users, topology}` and `data.sops_file.relay` iterates `keys(local.topology.network)`, so adding a relay or a shared file adds no data source.
The authentik module keeps its own four `sops_file` reads: it is a child module and must not reach into root data.
Provider blocks for the three relays reference `data.sops_file.relay["<relay>"].data["tofu-password"]`.
Addresses of data sources are not in state, so this is free.

### D11. `tofu/AGENTS.md` is rewritten in the same change.

Its Layout section describes the six-file root, the leaf-module rule, "provider blocks only in `main.tofu`", the one-shot retirement policy, the discovery-file read, and the sketch relics' absence; a new "Public ingress" section records the tunnel-per-site model, the token flow, the IP Cloud dependency on wg-holonet, and the cutover order as a constraint for any future site.
The landmine and authentik sections are unchanged.
The comment in `modules/services/zerotier.nix` that names `tofu/zerotier.tofu` is updated to `tofu/holonet.tofu`, and the one in `kubernetes/apps/network/cloudflare-tunnel/app/external-secret.yaml` that names `tofu/da.cloudflare-tunnel.tofu` moves with the manifest and names the tunnel module.

## Risks / Trade-offs

- [The IdP tunnel replace leaves `id.<root>` down longer than the connector restart] → The ExternalSecret refresh interval bounds the gap; it is forced with a `reconcile` annotation immediately after the apply, and the apply is run in an attended session with the authentik login flow checked afterwards.
  If `tofu plan` shows an in-place update instead of a replace, nothing is lost.
- [Public records flip to a tunnel whose connector is not serving] → D6 orders the connector before the flip and gates on the tunnel's `healthy` status and a request through the tunnel id.
- [The site records are destroyed and recreated instead of moved] → The `moved` blocks target the module instance's keyed address; task verification requires the plan to show exactly two in-place updates per site and no destroy of a `cloudflare_dns_record`.
- [Hairpin removal strands a LAN client that was reaching the VIP through the WAN address] → LAN clients resolve the site domain to the VIP through the router's split-horizon record, which is unchanged and verified before NAT is closed; a client with a hard-coded public address was never supported.
- [Cloudflare proxying changes what the gateway sees] → The connector forwards the original host header, the gateway terminates TLS with the wildcard certificate, and the HTTPRoutes match on hostname, so routing is unchanged; `origin-server-name` is set because the origin is addressed by service name, not by the public hostname.
  Source IPs become Cloudflare's, which affects only anything keyed on client address; nothing in the repo is.
- [An `import` target is missing from state and its block is deleted anyway] → D8's per-address check runs before any deletion and refuses on the first miss.
- [`for_each` in `module.authentik` keys off a module output] → The keys are HTTPRoute names read from data sources at plan time, exactly as today; the module boundary adds nothing.
- [A plan needs both clusters reachable over ZeroTier] → Unchanged from today.
- [The connector token in state] → State is encrypted under `tofu-state`; the token was already in state as the 1Password item's `password`.

## Migration Plan

1. Worktree: restructure the root module, create the two child modules, adjust the authentik module inputs, delete the retired files and the sketch relics, add the `moved` blocks, split the Kubernetes app, rewrite the rule.
   `tofu init -backend=false` and `tofu validate` are the worktree checks; the worktree has no state.
2. Main checkout, attended: `just tofu::plan` must show only the planned set from the proposal's Impact (IdP replace, moves, two tunnels created, four RouterOS CNAMEs destroyed) and nothing on relay, authentik, ZeroTier, holonet, or R2 resources.
   Any other destroy or replace is a stop.
3. Apply D6 step by step, da first, then en.
   The hairpin flip is a separate commit so it can be reverted alone.
4. Delete `cloudflare.tunnel-secret` from sops and the retired `moved` blocks in a final commit once the plan is clean.
5. Rollback before step 3 is a `jj` restore; state has not been touched.
   Rollback after a site's flip is reverting that site's `moved` blocks and record change in tofu and re-enabling hairpin; the old DDNS name and NAT rules come back on the next apply.

## Open Questions

- The stable name of each cluster's `envoy-external` gateway Service, which the tunnel ingress targets.
  Envoy Gateway generates the Service name unless the `EnvoyProxy` sets it; the implementation reads the live Service and either pins its name in the `EnvoyProxy` or adds a selector Service, and the tunnel's `service` input follows.
  Deferrable: it changes one string in each site file and nothing in the specs or the approach.
- Whether dropping `tunnel_secret` on the IdP tunnel plans as a replace or an in-place update.
  Deferrable: both are accepted; only the outage window differs.
