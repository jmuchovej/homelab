---
paths:
  - "kubernetes/components/cnpg-import/**"
---

# cnpg-import

One-off migration bootstrap: patches a `cnpg-database` Cluster so its first `initdb` imports `${APP}` from an existing postgres at `${HOST}`. The original migration read the NixOS instance on da-vcx-1 / 10.69.11.1; the one remaining consumer reads another in-cluster CNPG Cluster. The source is only ever read; rollback = keep using the source DB.

## Source-side (NixOS) prerequisites

The import dumps as the app's own role (it owns its DB — no superuser crosses the network), authenticating with the **shared** password from the 1Password item `postgres`, field `password`.

1. Set the password on each migrating role (same value for all — the per-app boundary is the NetworkPolicy, not the password):

   ```bash
   sudo -u postgres psql -c "ALTER ROLE authentik PASSWORD '<1P postgres/password>';"
   # repeat per app as each migrates, e.g.:
   # sudo -u postgres psql -c "ALTER ROLE hass PASSWORD '<same value>';"
   ```

2. Network access (already in `modules/services/postgres.nix`): a blanket pg_hba — `host all all 10.244.0.0/16 scram-sha-256` — so NO per-app lines are needed; scram is the gate, and roles without a password set can't authenticate at all. pg_hba's origin matching doubles as the ACL, so the firewall port can be open broadly:

   ```nix
   networking.firewall.allowedTCPPorts = [ 5432 ];
   ```

   Debug note: if the import fails with "no pg_hba entry for host 10.69.11.1", the pod's source IP got masqueraded to the node IP — add that /32 as another scram line.

## Idempotency semantics

The import is single-shot BY CONSTRUCTION: CNPG consults `bootstrap` only when creating a cluster from nothing (empty PVC). It never re-runs across restarts/reboots/reconciles. The only re-run trigger is delete+recreate of the Cluster/PVC — guarded two ways:

- the `cnpg-database` base sets `prune: disabled` on the Cluster, so Flux can never delete a database (and thereby arm a re-bootstrap);
- once the NixOS source is retired, its removed pg_hba entries make any zombie re-import fail LOUDLY at connect. (A "graceful" failure here would be silent data loss — empty DB, app runs migrations; loud is correct.)

## Lifecycle — remove it as soon as the app has migrated

After first bootstrap the import is inert **for that cluster** — CNPG never re-reads `bootstrap` for a live Cluster. It is _not_ inert for a new one: a second cluster bootstraps from nothing, re-runs the import, and fails against a source it has no reason to reach. en hit exactly this on 2026-09-17 — `No route to host` to 10.69.11.1, leaving `hass-db` stuck in `Cluster is unrecoverable` and blocking home-assistant's recorder.

So drop the component from an app's ks as soon as that app has migrated. Do **not** defer it to the commit that wires backups/recovery: that was written when this repo had one cluster, and deferral now plants a guaranteed bootstrap failure in every cluster added later.

`homebox` is the only remaining consumer, and deliberately so — its source is the retired in-cluster `home-automation` cluster (a namespace move; CNPG clusters can't cross namespaces), not the NixOS instance, and it carried post-migration changes. Delete that source cluster deliberately once proven, drop the component from `homebox-db.ks.yaml`, then delete this whole directory.
