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

## Control-plane access

Direction of travel: ZeroTier as the management path (native on RouterOS);
wg-holonet is break-glass — disable, don't delete. Mind the self-lockout
ordering when touching either.
