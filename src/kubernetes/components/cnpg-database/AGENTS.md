# cnpg-database — per-app postgres

CNPG `Cluster` + app-user creds (`ExternalSecret`) + `NetworkPolicy`. A plain Kustomization consumed as the `spec.path` of a per-app Flux Kustomization (`<app>-db.ks.yaml`, `targetNamespace` = the app's namespace) that the app's main ks `dependsOn`. The db ks itself must `dependsOn`:

- `cloudnative-pg` (namespace `databases`) — the `Cluster` CRD comes from the operator chart
- `onepassword-connect` (namespace `external-secrets`) — the creds ExternalSecret needs the 1Password store

| Variable  | Meaning                                                                               |
| --------- | ------------------------------------------------------------------------------------- |
| `APP`     | app name — becomes db name, owner role, `${APP}-db` cluster, `${APP}-db-creds` secret |
| `DB_SIZE` | PVC size for the cluster's storage                                                    |

- Single-instance cluster, co-located with the app in its namespace. Storage lands on the default StorageClass (warp-backed local-path). In-cluster DSN host: `${APP}-db-rw.<app-namespace>.svc.cluster.local`.
- The `Cluster` carries `kustomize.toolkit.fluxcd.io/prune: disabled` — Flux may never delete a database. Deleting a `Cluster` deletes its PVCs (CNPG owns them), and a recreate re-runs bootstrap — including any attached `cnpg-import`, which against a live source SUCCEEDS with stale data, worse than failing. Removal is always a deliberate `kubectl delete`.
- **Credentials**: username `${APP}`, password from the 1Password item `postgres` (vault Homelab, field `password`) — deliberately SHARED across all apps as an interim ergonomic choice. The NetworkPolicy is the real per-app boundary; the password is defense-in-depth. OpenBao takes over per-app generation/rotation later (see the openbao-secrets-design memory). If an app also consumes the db password through its own config secret (authentik does), both must resolve to this same 1Password field — one source of truth.
- **NetworkPolicy**: the k8s re-creation of the old Unix-socket peer-auth boundary — only the app's own pods may reach its postgres. Flows, per the CNPG networking docs: app pods → 5432, matched on `app.kubernetes.io/name: ${APP}` (set by both the bjw-s app-template and standard charts, incl. goauthentik); intra-cluster pod traffic (replication, init/import jobs); and the CNPG operator from `databases` on 8000 (instance-manager status) + 5432.
