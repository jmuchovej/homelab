---
paths:
  - "tofu/**"
---

# tofu — OpenTofu infra (MikroTik, Cloudflare, Authentik, ZeroTier)

Single root module.
Providers and the state backend are pinned in `main.tofu`; per-datacenter domains derive there (`local.domain.{root,da,en}` from the Cloudflare zone).

## Layout

- `<dc>.<domain>.tofu` — per-site resources (`da.mikrotik.tofu`, `en.consul.tofu`, `mk.da.dns.tofu`); site-agnostic files are just `<domain>.tofu` (`cloudflare.tofu`, `holonet.tofu`, `zerotier.tofu`).
- Domain directories (`authentik/`, `cloudflare/`, `consul/`, `mikrotik/`, `servarr/`, `vault/`, `modules/`) hold modules/templates; `modules/mikrotik/` is the shared RouterOS module (incl. `bgp.tofu` peering back at k8s).
- `secrets` → symlink to the repo-root `secrets/` (read via the `carlpett/sops` provider); `topology.yaml` → symlink to `topology.yaml`.
- `*.just` files (`authentik.just`, `mikrotik.just`) are included by the root justfile.
- `justfile` holds the recipes; it is loaded as `mod tofu "tofu/justfile"` from the root justfile, which is why `just` runs them with `tofu/` as the working directory.
- **State is remote**, at `tofu/terraform.tfstate` in the Cloudflare R2 bucket `rbn`, encrypted with OpenTofu native state encryption and locked through the `s3` backend's `use_lockfile`.
  The `terraform.tfstate*` files still in this directory are plaintext rollback copies, not the authoritative state — OpenTofu empties the live local file once a remote backend owns the state.

## Workflow

Always `just tofu::plan` / `just tofu::apply`, never bare `tofu` — the recipes bake in `-parallelism=1` (RouterOS REST is flaky under concurrency) and `-compact-warnings` (the routeros provider lags RouterOS schema on read-only fields; the warnings are benign).
Pass-through args work: `just tofu::apply -target=module.da-relay01`.

Bare `tofu` does not merely skip those defaults, it cannot reach state at all.
Backend configuration is evaluated before any provider or data source, so the sops provider cannot supply it; the R2 credentials, the endpoint, and the state-encryption passphrase arrive as environment variables from `secretspec run --scope tofu`, which the recipes wrap.
Resolution is scoped rather than whole-profile deliberately: secretspec strips out-of-scope secrets from the child environment, so a tofu run's provider plugins never see unrelated project secrets.

`enforced = true` is set on the encryption config, so a missing or wrong passphrase fails the run instead of silently writing plaintext.
`TOFU_STATE_FALLBACK=1` is the only configuration permitted to read _unencrypted_ state, and exists for exactly two jobs: migrating plaintext state in, and re-encrypting under a rotated passphrase.
Never set it as a matter of habit — OpenTofu warns `Unencrypted method configured` whenever it is active, and that warning's absence is how you confirm the steady-state config is in force.

Two constraints govern the R2 bucket, and violating either is silently destructive:

- The bucket-lock rule's prefix must never cover `tofu/terraform.tfstate` or `tofu/terraform.tfstate.tflock`.
  Locks forbid overwrites, and tofu overwrites the live key on every write and churns the lock object on every operation, so a rule with an empty prefix — which scopes to the whole bucket — bricks every apply.
- Lock retention must stay shorter than the lifecycle expiry.
  Locks take precedence over lifecycle rules, so an indefinite lock under a delete rule means the delete never fires and the snapshot prefix grows without bound.

`rbn` is a shared, general-purpose bucket, so every key this repo writes stays under the `tofu/` prefix, and both `cloudflare_r2_bucket_lifecycle` and `cloudflare_r2_bucket_lock` hold the bucket's _complete_ rule list — declaring either one drops every rule it does not name.

## RouterOS provider landmines

- **"Plugin did not respond" crashes are NOT concurrency** — they hit at `-parallelism=1` too.
  Causes: a stale cached provider binary (`rm -rf .terraform/providers && tofu init`) and perpetual-diff updates tripping provider bugs (fix per-resource, e.g. `ignore_changes`).
- Keep RouterOS ≤ **7.21.4 LTS** — 7.23.x is unsupported by the provider.
- **Wifi self-disconnect**: applying `routeros_wifi` changes from a laptop on the target relay's wifi restarts the wifi controller mid-apply → `connection reset by peer`.
  Use `-target`, or apply from a host that doesn't depend on that relay's wifi.
- BGP timers: pin `keepalive_time` on the RouterOS **connection** resource (not just the template), or Cilium sessions flap with hold-timer-expired.
- **A failed update still lands in state.**
  When the REST call errors, the provider returns the _planned_ value anyway, so tofu records a change the device never made.
  The next plan is clean while reality has drifted — and because the error is per-resource, the rest of the apply proceeds around it.
  After any partially-failed apply, verify against the device (`curl -k -u terraform:<pw> https://<relay>/rest/<path>`) before trusting a plan; treat the clean plan as the symptom, not the all-clear.

## Partial applies split a device against itself

A single relay is many resources with no edges between them, so one failure leaves the rest applied.
The dangerous pairs are the ones that only agree because they read the same `topology.yaml` literal — nothing in the graph knows they must move together.
The 2026-09-18 renumber hit exactly this: the lab `routeros_ip_address` failed while its pool and DHCP network applied, so both relays handed out leases pointing at a gateway that did not exist and every node on the VLAN lost its default route (including the k8s nodes, which took Tailscale and ZeroTier down with them, leaving only the relays reachable).

Where a device-side invariant spans resources, spell it out with `depends_on` so a failure skips the dependents instead of stranding clients — the DHCP pool and server network now depend on `routers_ip_address.vlan_primary` for this reason.
When adding a resource that hands clients addressing, ask what must already exist on the device for that config to be valid, and encode it.

## authentik is one instance, many sites

Core (server, worker, database) runs only at da.
Other sites install the `authentik-remote-cluster` chart — RBAC only — and da's authentik reaches their Kubernetes API to deploy **outposts into them**.
An app at another site authenticates against an outpost in its own cluster, so there is never a second authentik, second database, or second signing keypair.

Everything cross-site is addressed over **ZeroTier**, the only link between the datacenters and only at node level: a lab address is not routable from another site, and the ZeroTier address is an explicit `--tls-san` while lab IPs are in the apiserver cert only because k3s adds the current node IP.

- **One `kubernetes` provider per DC, `config_context` pinned.**
  An unaliased provider follows whatever context is current, so discovery silently reported one cluster's routes as the whole homelab.
- **Only apps discovered at MORE than one DC are keyed and slugged `<name>-<site>`.**
  The same service at two sites serves two hostnames, so it is two applications with two providers and two OAuth clients, and the slug — not just the map key — has to carry the site, because the slug names the authentik objects and keys the app's credentials in `secrets/authentik.sops.yaml`.
  An app at one site cannot collide and keeps its bare name; suffixing it would rename its objects and sops keys for nothing.
- That split is **derived from where routes are actually discovered**, not declared, so it cannot drift from reality.
  The cost: selecting an existing app into a second cluster renames the first one's slug.
  It surfaces in the plan as a replace, and its sops keys must move with it.
- **Outposts are per site AND type**, each bound to that site's service connection — `local` for da, a remote kubeconfig elsewhere.
  A provider on the wrong site's outpost is proxied by a pod that cannot route to it.
- Renaming an app's key or slug needs a `moved` block (`ak.moved.tofu`), or tofu destroys and recreates the application, discarding its provider and every consent bound to it.
- **`authentik_group.roles` cannot be kept quiet by sorting.** The provider declares it `list(string)`, so tofu compares it positionally, while authentik returns the roles in the order the memberships were created — an order no attribute of the role reproduces, so neither `sort()` on PKs nor ordering by name converges.
  There is no config-level fix: the association exists only on `authentik_group`, there is no per-binding resource, and neither the `authentik_group` nor `authentik_groups` data source exposes `roles`, so the current order cannot even be read back.
  Match the live order by querying the API when you change the set; `ignore_changes = [roles]` is the alternative, at the cost of silently never applying a membership change.
  `users` and `parents` are lists too, so they are the same bug waiting.

## Control-plane access

Direction of travel: ZeroTier as the management path (native on RouterOS); wg-holonet is break-glass — disable, don't delete.
Mind the self-lockout ordering when touching either.
