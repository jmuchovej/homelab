---
paths:
  - "src/terraform/**"
---

# src/terraform — OpenTofu infra (MikroTik, Cloudflare, Authentik, ZeroTier)

Single root module. Providers are pinned in `__main__.tofu`; per-datacenter
domains derive there (`local.domain.{root,da,en}` from the Cloudflare zone).

## Layout

- `<dc>.<domain>.tofu` — per-site resources (`da.mikrotik.tofu`,
  `en.consul.tofu`, `mk.da.dns.tofu`); site-agnostic files are just
  `<domain>.tofu` (`cloudflare.tofu`, `holonet.tofu`, `zerotier.tofu`).
- Domain directories (`authentik/`, `cloudflare/`, `consul/`, `mikrotik/`,
  `servarr/`, `vault/`, `modules/`) hold modules/templates; `modules/mikrotik/`
  is the shared RouterOS module (incl. `bgp.tofu` peering back at k8s).
- `secrets` → symlink to the repo-root `secrets/` (read via the
  `carlpett/sops` provider); `topology.yaml` → symlink to `src/topology.yaml`.
- `*.just` files (`authentik.just`, `mikrotik.just`) are included by the root
  justfile.
- **State is local** (`terraform.tfstate` in this directory, plus manual
  `.bak` snapshots). There is no remote backend — treat state files as
  precious, never delete or migrate them casually.

## Workflow

Always `just tofu-plan` / `just tofu-apply` (from repo root), never bare
`tofu` — the recipes bake in `-parallelism=1` (RouterOS REST is flaky under
concurrency) and `-compact-warnings` (provider 1.99.1 lags RouterOS schema on
read-only fields; the warnings are benign). Pass-through args work:
`just tofu-apply -target=module.da-relay01`.

## RouterOS provider landmines

- **"Plugin did not respond" crashes are NOT concurrency** — they hit at
  `-parallelism=1` too. Causes: a stale cached provider binary
  (`rm -rf .terraform/providers && tofu init`) and perpetual-diff updates
  tripping provider bugs (fix per-resource, e.g. `ignore_changes`).
- Keep RouterOS ≤ **7.21.4 LTS** — 7.23.x is unsupported by the provider.
- **Wifi self-disconnect**: applying `routeros_wifi` changes from a laptop on
  the target relay's wifi restarts the wifi controller mid-apply →
  `connection reset by peer`. Use `-target`, or apply from a host that
  doesn't depend on that relay's wifi.
- BGP timers: pin `keepalive_time` on the RouterOS **connection** resource
  (not just the template), or Cilium sessions flap with hold-timer-expired.
- **A failed update still lands in state.** When the REST call errors, the
  provider returns the _planned_ value anyway, so tofu records a change the
  device never made. The next plan is clean while reality has drifted — and
  because the error is per-resource, the rest of the apply proceeds around it.
  After any partially-failed apply, verify against the device (`curl -k -u
terraform:<pw> https://<relay>/rest/<path>`) before trusting a plan; treat
  the clean plan as the symptom, not the all-clear.

## Partial applies split a device against itself

A single relay is many resources with no edges between them, so one failure
leaves the rest applied. The dangerous pairs are the ones that only agree
because they read the same `topology.yaml` literal — nothing in the graph
knows they must move together. The 2026-09-18 renumber hit exactly this: the
lab `routeros_ip_address` failed while its pool and DHCP network applied, so
both relays handed out leases pointing at a gateway that did not exist and
every node on the VLAN lost its default route (including the k8s nodes, which
took Tailscale and ZeroTier down with them, leaving only the relays
reachable).

Where a device-side invariant spans resources, spell it out with `depends_on`
so a failure skips the dependents instead of stranding clients — the DHCP pool
and server network now depend on `routeros_ip_address.vlan_primary` for this
reason. When adding a resource that hands clients addressing, ask what must
already exist on the device for that config to be valid, and encode it.

## Control-plane access

Direction of travel: ZeroTier as the management path (native on RouterOS);
wg-holonet is break-glass — disable, don't delete. Mind the self-lockout
ordering when touching either.
