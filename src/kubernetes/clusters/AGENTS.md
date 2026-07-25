# src/kubernetes/clusters — per-cluster roots

One directory per cluster, keyed by full domain (`da.jm0.io`, `en.jm0.io`). The
NixOS `FluxInstance` (`modules/services/kubernetes/kubernetes.nix`) syncs
`clusters/${host.dc-domain}/flux` per host.

```
<domain>/
  flux/
    cluster-apps.ks.yaml    root Flux Kustomization (HelmRelease patch) → ../apps.
                            The ONLY .yaml the sync applies; a kustomization.yaml
                            here would shadow it and drop the patch.
    age-key.pub             PUBLIC flux sops recipient (record; the live copy is
                            the .sops.yaml anchor). Staged until generated.
    cluster-config.ks.yaml  (create when enabling Flux sops) → ../config, with
                            decryption. See "Flux sops bootstrap".
  apps/kustomization.yaml   app selection: ../../../core + this cluster's apps
  config/                   cluster-scoped in-cluster resources (RuntimeClasses,
                            NetworkPolicies) + <domain>.sops.yaml (Flux-decrypted
                            per-cluster secrets). Empty until "Flux sops bootstrap".
```

## Two sops layers — keep them straight

- **NixOS layer** (`secrets/*.sops.yaml`) — encrypted to **host** age keys; NixOS
  decrypts at activation and seeds bootstrap Secrets via `kubectl apply`.
- **Flux layer** (`clusters/<domain>/config/*.sops.yaml`) — encrypted to a
  dedicated **per-cluster flux** age key; `kustomize-controller` decrypts it
  in-cluster using the `sops-age` Secret. The flux key's _private_ half lives in
  the NixOS layer (`secrets.sops.yaml` → `kubernetes/flux/<dc-domain>/age-key`),
  so NixOS can seed it — the only bridge between the layers. Keys are per-cluster
  on purpose: da/en share vaults but waypoints/fare use different ones, so each
  cluster's 1Password Connect **credentials** must stay isolated even though the
  Connect **app** (in `core/`) is shared.

## What actually bootstraps a cluster

The irreducible externally-injected secret is **one**: the flux `agekey`
(NixOS-seeded). With Flux sops enabled, everything else flows in-tree:

1. NixOS seeds `sops-age` (from `kubernetes/flux/<dc-domain>/age-key`) →
2. Flux decrypts this cluster's `config/op-connect.sops.yaml` → the three
   1Password Connect secrets (`1password-credentials.json`, `op-connect-ro`,
   `op-connect-rw`) →
3. 1P Connect server + ESO `ClusterSecretStore`s come up →
4. every other secret is an `ExternalSecret` from 1Password.

(Without Flux sops — `flux-sops-enabled = false`, the default — NixOS seeds those
three op secrets directly from `secrets/<dc>.sops.yaml` and nothing lives in the
Flux layer. That's the current state.)

## Flux sops bootstrap (per cluster, e.g. `da.jm0.io`)

The per-cluster flux **private** keys already live in `secrets.sops.yaml` under
`kubernetes/flux/<dc-domain>/age-key` (all four clusters pre-generated). These
steps turn decryption on — do the set together, they're coupled.

1. **Register the public recipient:**
   - `.sops.yaml`: uncomment `- &da-flux age1...` (real value) **and** the
     `clusters/da.jm0.io/...` creation rule.
   - `clusters/da.jm0.io/flux/age-key.pub`: replace the placeholder.
2. **Fill this cluster's creds** — `cp config/op-connect.sops.yaml.example
config/op-connect.sops.yaml`, replace the REPLACE_ME values (three Secrets:
   `onepassword-connect-credentials`, `op-connect-ro`, `op-connect-rw`), then
   `sops -e -i config/op-connect.sops.yaml` — the creation rule encrypts to
   `john` + `da-flux`. `config/kustomization.yaml` already references it. (Per-
   cluster: da/en share vaults, waypoints/fare don't.)
3. **Engage decryption** — rename the scaffolded
   `clusters/da.jm0.io/flux/cluster-config.ks.yaml.example` →
   `cluster-config.ks.yaml`; it's a second `.yaml` in `flux/`, so the sync applies
   it alongside cluster-apps, reconciling `config/` with `decryption: sops-age`.
4. **Make Connect wait for the creds** — add `cluster-config` to the `dependsOn`
   of `apps/_external-secrets/onepassword-connect/onepassword-connect.ks.yaml`
   (alongside `external-secrets`), so the shared Connect server + stores don't
   start before this cluster's creds are decrypted.
5. **Flip the source of truth — both together, or the op secrets get seeded twice
   (NixOS + Flux) and fight:** set `flux-sops-enabled = true` in `kubernetes.nix`
   AND remove the NixOS op-seeding — the three `get-secret config
"1password/connect-*"` lines, the `onepassword-connect.yaml`
   template/apply/restartTrigger, and its `system.checks` entry.
6. **Deploy:** `nh os switch` (seeds `sops-age` from
   `kubernetes/flux/<dc-domain>/age-key`) → Flux decrypts `config/` → 1P Connect →
   ESO. Repeat per cluster.
