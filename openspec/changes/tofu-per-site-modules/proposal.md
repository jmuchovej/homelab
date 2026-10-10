## Why

The OpenTofu root module in `tofu/` is 19 top-level files and about 1,565 lines, and most of that is the same thing written twice: da and en each carry their own relay wiring, their own apex and wildcard DNS records, their own HTTPRoute-discovery data sources, and their own 60-block import file, differing only in the site name.
Every third site would copy all of it again, 112 `import` and `moved` blocks that already landed in state are still evaluated on every plan, and the public DNS for both sites still points at relay DDNS names through WAN port-forwards when a Cloudflare tunnel per site would retire both.
This change supersedes `tofu-root-at-repo-root`, whose premise (move the root module to the repository root) is dropped; its state-stability gate, its kubernetes discovery module, and its one-shot block retirement are carried forward.

## What Changes

- The root module stays in `tofu/` and shrinks to six top-level files, each with one job: `main.tofu` (backend, providers, shared and per-relay sops reads, `local.domain`), `holonet.tofu` (overlay catalog, holonet DNS, and the ZeroTier network absorbed from `zerotier.tofu`), `cloudflare.tofu` (zone, R2 state bucket, IdP tunnel), `authentik.tofu` (the authentik module instance), and one `<site>.tofu` per datacenter holding that site's relay, discovery, and tunnel instances.
- New child module `tofu/kubernetes/`, one instance per site bound to that site's `kubernetes` provider alias: discovers `authentik.rbn/enabled=true` HTTPRoutes and, for remote sites, reads the `authentik-remote-cluster` ServiceAccount token and emits the kubeconfig.
  It replaces the hand-duplicated per-site data sources in `ak.discovery.tofu` and `ak.service-connections.tofu`.
  The "only apps seen at more than one site get a `-<site>` suffix" rule moves into the authentik module, which owns the slugs it names.
- New child module `tofu/cloudflare/tunnel/`: a remotely-managed Cloudflare tunnel, its ingress config, one proxied CNAME per ingress hostname, and a 1Password item holding the connector token read back from Cloudflare.
  Three instances: `idp` (the existing `id.<root>` tunnel) and one per site fronting that site's `envoy-external` gateway for `<site>.<root>` and `*.<site>.<root>`.
- **BREAKING (public ingress)**: each site's apex and wildcard records switch from an unproxied CNAME to the relay's DDNS name to a proxied CNAME to that site's tunnel.
  The relays' WAN dst-nat for 80 and 443 and the hairpin rules are removed (`enable-hairpin = false`), so no inbound port is reachable from the Internet.
  IP Cloud stays enabled on each relay01 because its DDNS name is also the wg-holonet break-glass endpoint.
- **BREAKING (IdP tunnel)**: the IdP tunnel is recreated once, because the module no longer passes a tunnel secret.
  Cloudflare generates the secret for a remotely-managed tunnel and the provider reads the connector token back, so the hand-assembled token and the `cloudflare.tunnel-secret` sops key go away.
  The recreate rewrites the 1Password item, ESO resyncs it, and the da connector restarts; `id.<root>` is unreachable for the duration.
- The four RouterOS CNAME records at root (`routeros_ip_dns_record.<site>-apex` and `-wildcard`) are deleted: the mikrotik module's split-horizon A record already answers `<site>.<root>` and every subdomain with the VIP.
- Retire one-shot blocks that are already in state: 107 `import` blocks (`da.mikrotik-imports.tofu`, `en.mikrotik-imports.tofu`, the authentik imports in `ak.tofu`, the ZeroTier network import, the R2 bucket import) and the 5 `moved` blocks in `ak.moved.tofu`.
  Every target is verified present in state before deletion.
  New `moved` blocks introduced by this change are retired the same way once applied.
- Remove `ak.variables.tofu`: with the authentik imports gone, the only consumer of `authentik-builtins` is the authentik module's permission lookup, so the module reads `tofu/authentik.auto.tfvars.json` itself (guarded by `fileexists`).
- Kubernetes side: the `cloudflare-tunnel` app becomes one cloudflared connector Deployment per tunnel per cluster (da runs `idp` and `envoy-external`, en runs `envoy-external`), each reading its token from the 1Password item tofu writes.
- Delete the untracked sketch relics in the main checkout that this change supersedes: the repo-root `main.tofu` and empty `terraform.tfstate`, `tofu/cloudflare/main.tofu`, `tofu/cloudflare/da.tofu`, `tofu/cloudflare/configure-r2/`, and `tofu/authentik/kube-service-connection/`.
  `tofu/kubernetes/main.tofu` and `tofu/cloudflare/tunnel/main.tofu` are kept and corrected.
- `tofu/AGENTS.md`: the Layout section is rewritten for the six-file root, the leaf-module rule, "provider blocks only in `main.tofu`", the one-shot retirement policy, and the discovery-file read; the public-ingress section is added; landmine sections are unchanged.
- The superseded `tofu-root-at-repo-root` change is deleted with this proposal, not archived: none of its tasks were started and its spec delta never applied.

## Capabilities

### New Capabilities

- `tofu-root-module`: the shape of the OpenTofu root module in `tofu/` — the bounded top-level file set, where provider configuration lives, how a site is added, what a child module may and may not own, and when one-shot `import` and `moved` blocks are retired.
- `public-ingress`: how a hostname under a site's domain is reached from the Internet — through a per-site Cloudflare tunnel into that site's gateway, with no inbound WAN port, with the connector token flowing from Cloudflare through OpenTofu and 1Password to the cluster, and with LAN clients still resolving directly to the site VIP.

### Modified Capabilities

- None.
  `repo-layout`'s "OpenTofu lives under `tofu/`" requirement holds as written; `tofu-state` is untouched.

## Impact

- **Live infrastructure**: planned state changes are limited to: the IdP tunnel and its config replaced (new tunnel id); the `id.<root>` record, four site records, and the IdP 1Password item moved into module addresses, with the four site records changing content and `proxied`; two new tunnels, their configs, and two new 1Password items created; the four RouterOS CNAMEs destroyed; and the hairpin and WAN dst-nat resources on `da-relay01` and `en-relay01` destroyed.
  The 436 other RouterOS resources, the authentik tree, the ZeroTier network and members, the holonet A records, and the R2 bucket resources keep their addresses and show no diff.
- **State**: stays on R2 under the `tofu-state` capability.
  `moved` blocks carry the renamed resources; a plan that proposes any replace other than the IdP tunnel pair is a stop.
- **Secrets**: `cloudflare.tunnel-secret` is removed from `secrets/secrets.sops.yaml` after the IdP recreate.
  Three 1Password items in vault Homelab (`cf-tunnel-idp`, `cf-tunnel-da`, `cf-tunnel-en`) are written by tofu and read by ESO by title.
- **Kubernetes**: `kubernetes/apps/network/cloudflare-tunnel/` is restructured into per-tunnel instances; `kubernetes/clusters/da.jm0.io/apps/kustomization.yaml` and the en equivalent select them.
  The `envoy-external` gateway, its wildcard certificate, and every HTTPRoute are unchanged.
- **Relays**: `enable-hairpin` flips to false on both relay01s, removing six NAT rules and two address lists each; `enable-ip-cloud` stays true.
  Nothing else in `tofu/mikrotik/` changes.
- **Main checkout working copy**: the sketch files listed above are deleted; `tofu/servarr/` and `tofu/.scratch/` are not touched.
- **Not touched**: resource definitions inside `tofu/authentik/` beyond the two input changes, `tofu/vault/`, the `terraform` RouterOS user, `.sops.yaml` rules, the just recipes, wg-holonet, relay port maps and wifi profiles.
