---
paths:
  - "src/kubernetes/components/cnpg-replica/**"
---

# cnpg-replica — cross-DC warm standby

A CNPG `Cluster` in continuous recovery, streaming from a primary in **another datacenter**. Consumed as the `spec.path` of a per-app Flux Kustomization, exactly like `cnpg-database` — same `dependsOn` (`cloudnative-pg` in `databases`, `onepassword-connect` in `external-secrets`).

The one consumer is `apps/auth/authentik/replica`, so `id.${DOMAIN}`'s database survives the loss of da. Do not attach this to an app just because it has a database: it costs a continuous WAN stream and a promotion runbook, and it buys nothing unless that app must outlive its own datacenter.

| Variable      | Meaning                                                                      |
| ------------- | ---------------------------------------------------------------------------- |
| `APP`         | app name — same value as on the primary; names db, role, `${APP}-db` cluster |
| `DB_SIZE`     | PVC size; must be ≥ the primary's                                            |
| `SOURCE_NAME` | local alias for the source in `externalClusters` (e.g. `authentik-db-da`)    |
| `SOURCE_HOST` | the primary's reachable address — its LoadBalancer VIP, not a service DNS    |
| `SOURCE_ITEM` | 1Password item holding the pushed replication identity                       |

## A replica cluster is read-only

Per the CNPG docs: _"no changes to the database, including the catalog and global objects like roles or databases, are permitted."_ The app that owns this database **cannot run against it**. That is why en carries the database but not authentik's HelmRelease — Postgres has no multi-primary, so "replicated so it's always up" means warm standby plus a deliberate promotion, never active-active.

## Why this needs the DCs renumbered

Both sites ran lab `10.69.0.0/16` with nodes at `10.69.11.1` and LB pools at `10.69.1.0/24`, so `SOURCE_HOST` was ambiguous — en would have resolved da's DB VIP to its own. Each DC now holds a unique `/16` (da `10.32.0.0/16`, en `10.36.0.0/16`) and ZeroTier carries a managed route for each, so the primary is reachable at a real service address rather than a NodePort on an overlay IP.

## Certificates: a live sync, not a copy

`streaming_replica` authenticates with a **client certificate**, so the replica needs the source's `<cluster>-replication` (tls.crt/tls.key) and `<cluster>-ca` (ca.crt). CNPG renews that client cert **7 days before a 90-day expiry**. A one-time copy therefore works for about a quarter and then breaks replication silently, which is the worst possible failure shape.

So the primary runs a `PushSecret` into 1Password and the replica an `ExternalSecret` back out, both on a 1h interval — three orders of magnitude inside the renewal margin. 1Password fields are single-line, so the push base64-encodes and the pull `b64dec`s.

The pulled secrets are deliberately named `${APP}-db-source-*`, **not** `${APP}-db-ca` / `${APP}-db-replication`. Those names belong to the certs CNPG issues for the replica itself; colliding on them makes the operator treat the source's material as its own.

`sslmode` is `verify-ca`, not `verify-full`: the source's server certificate carries SANs for `<cluster>-rw.<ns>.svc`, not for the LoadBalancer address the replica dials, so hostname verification cannot pass. The CA is private to this cluster pair and the transport is an encrypted overlay. To reach `verify-full`, add the dialed name to the primary's `spec.certificates.serverAltDNSNames` and give the replica's cluster a DNS record that resolves it.

## Promotion

This is a **standalone replica** (`replica.enabled`), not a distributed topology with promotion tokens. Token-based switchover is for a planned handover with both sides healthy; the case this exists for is da being gone, where there is nothing to demote. Promotion is therefore one field:

1. `replica.enabled: false` on the replica Cluster. It exits recovery and becomes a normal read-write primary, keeping its data.
2. Add `../../../apps/auth` to the surviving cluster's `apps/kustomization.yaml` so authentik's HelmRelease lands next to the now-writable database.
3. Repoint `id.${DOMAIN}` — the Cloudflare tunnel connector and the DNS record both currently target da.
4. Move the `PushSecret` with the primary role. Only the primary may push; two clusters pushing the same 1Password item fight over it.

**This is one-way.** Once promoted, the old primary's data has diverged and cannot be re-attached by flipping the field back — recovering da means re-bootstrapping it as a replica of en, which is a fresh `pg_basebackup`. Treat promotion as a decision, not a toggle.

An untested runbook is a wish. Exercise this deliberately — promote en, confirm authentik serves, then rebuild en as a replica — before relying on it in an actual outage.
