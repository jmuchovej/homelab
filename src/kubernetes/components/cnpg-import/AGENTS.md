# cnpg-import

One-off migration bootstrap: patches a `cnpg-database` Cluster so its first `initdb` imports `${APP}` from the NixOS postgres (`${HOST}`, normally da-vcx-1 / 10.69.11.1). The source is only ever read; rollback = keep using the NixOS DB.

## Source-side (NixOS) prerequisites

The import dumps as the app's own role (it owns its DB — no superuser crosses the network), authenticating with the **shared** password from the 1Password item `postgres`, field `password`.

1. Set the password on each migrating role (same value for all — the per-app boundary is the NetworkPolicy, not the password):

   ```bash
   sudo -u postgres psql -c "ALTER ROLE authentik PASSWORD '<1P postgres/password>';"
   # repeat per app as each migrates, e.g.:
   # sudo -u postgres psql -c "ALTER ROLE hass PASSWORD '<same value>';"
   ```

2. Network access (already in `src/modules/services/postgres.nix`): a blanket pg_hba — `host all all 10.244.0.0/16 scram-sha-256` — so NO per-app lines are needed; scram is the gate, and roles without a password set can't authenticate at all. pg_hba's origin matching doubles as the ACL, so the firewall port can be open broadly:

   ```nix
   networking.firewall.allowedTCPPorts = [ 5432 ];
   ```

   Debug note: if the import fails with "no pg_hba entry for host 10.69.11.1", the pod's source IP got masqueraded to the node IP — add that /32 as another scram line.

## Idempotency semantics

The import is single-shot BY CONSTRUCTION: CNPG consults `bootstrap` only when creating a cluster from nothing (empty PVC). It never re-runs across restarts/reboots/reconciles. The only re-run trigger is delete+recreate of the Cluster/PVC — guarded two ways:

- the `cnpg-database` base sets `prune: disabled` on the Cluster, so Flux can never delete a database (and thereby arm a re-bootstrap);
- once the NixOS source is retired, its removed pg_hba entries make any zombie re-import fail LOUDLY at connect. (A "graceful" failure here would be silent data loss — empty DB, app runs migrations; loud is correct.)

## Lifecycle — no dedicated removal commit needed

After first bootstrap the import block is inert (CNPG never re-reads `bootstrap` for a live cluster), and `prune: disabled` means re-bootstrap requires deliberate human action — so leaving `../cnpg-import` in an app's ks indefinitely is safe. Remove it opportunistically, folded into the commit that wires **backups/recovery** for that app (it edits the same `bootstrap` block anyway) — never as its own commit. Once the last app has migrated off the NixOS postgres, delete this whole component.
