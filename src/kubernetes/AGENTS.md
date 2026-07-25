# src/kubernetes — Flux-managed cluster manifests

GitOps tree for the K3s clusters, one per cluster keyed by full domain (`clusters/da.jm0.io`, `clusters/en.jm0.io`). A NixOS-managed `FluxInstance` (`src/modules/services/kubernetes/kubernetes.nix`) syncs this repo per cluster — its sync path is `src/kubernetes/clusters/${host.dc-domain}/flux`, a dir holding **only** the root `cluster-apps.ks.yaml` (so Flux actually applies it — a `kustomization.yaml` beside it would shadow it and silently drop its HelmRelease patch). That root reconciles `clusters/<domain>/apps`, whose selection fans out to the shared `core/` bundle plus the cluster's own apps.

## Documentation policy

A manifest carries a comment only when it is load-bearing at that exact line:

- an action marker tied to the line ("DELETE this line once ...", "STAGED — not yet in kustomization.yaml, needs X first")
- a constraint a naive edit at that spot would silently violate and that cannot be inferred from the surrounding YAML

Everything else — rationale, architecture, cross-file wiring, operational context — lives in the nearest existing ancestor `AGENTS.md`. Commenting freely while drafting is fine; the pre-commit sweep (root `AGENTS.md`, "Comments vs AGENTS.md") lifts anything non-load-bearing there. Deeper directory-local `AGENTS.md` files (like `components/`) are architected deliberately when a directory accrues persistent decision context — never created as a side effect of comment cleanup.

The rare `# yaml-language-server: $schema=…` modelines (see Schemas below) are tooling, not comments — keep them.

## Schemas

Validation comes from [k8s-schemas.home-operations.com](https://k8s-schemas.home-operations.com), wired through **filename globs in `.zed/settings.json`** (`yaml.schemas`) — the content-naming convention means the filename determines the kind, so manifests need no per-file annotation. The URL derives mechanically from `apiVersion` + `kind`:

| apiVersion shape         | URL                                       |
| ------------------------ | ----------------------------------------- |
| `<group>/<version>`      | `<group>/<lowercase-kind>_<version>.json` |
| `<version>` (core group) | `core/<lowercase-kind>_<version>.json`    |

To search interactively: `https://k8s-schemas.home-operations.com/#q=<query>` (client-side; from a shell, derive the URL from the table and verify with `curl -sI`).

Inline `# yaml-language-server: $schema=…` modelines (per **document**, right after `---`; they override the globs) are used ONLY where the filename can't determine a single kind:

- multi-kind files: `envoy.yaml`, `echo.yaml`, `cilium-bgp.yaml`
- kind-deviant kustomizations: `components/cnpg-import/kustomization.yaml` (a `Component`, not the glob-assumed v1beta1 `Kustomization`)

Nothing else carries schema comments. (yls accepts both `# yaml-language-server: $schema=…` and the IntelliJ-style `# $schema: …`; an inline `$schema` PROPERTY also works but becomes part of the applied object — unresolved whether kustomize/SSA tolerate it, investigate before adopting.) Kustomize patch files (`patch-*.yaml`) are partial documents and get neither globs nor modelines.

Adding a new content-named manifest type = one glob line in `.zed/settings.json` (which is also the single place to update when filenames change, e.g. a kebab-case rename).

## Layout

```
clusters/<domain>/                  per-cluster root (dir name == host.dc-domain, e.g. da.jm0.io)
  flux/
    cluster-apps.ks.yaml            root Flux Kustomization (HelmRelease patch); the ONLY file
                                    in the FluxInstance sync dir; path → ../apps
  apps/kustomization.yaml           selection: ../../../core + this cluster's app dirs
  config/                           cluster-scoped in-cluster resources (RuntimeClasses, etc.)
                                    + <domain>.sops.yaml — Flux-decrypted per-cluster secrets.
                                    Future: awaits a dedicated flux age key (NixOS-seeded).
core/kustomization.yaml             shared-infra bundle every cluster includes
apps/<group>/                       one directory per namespace (the catalog)
  namespace.yaml
  kustomization.yaml                core namespaces only: namespace.yaml + app ks list
  <app>/
    kustomization.yaml              per-site apps only: namespace-stamped wrapper so the
                                    app is individually selectable per cluster
    <app>.ks.yaml                   Flux Kustomization(s) for the app
    app/                            manifests (kustomization.yaml + resources)
components/                         reusable cross-app building blocks → components/AGENTS.md
```

- Cluster selection is explicit, not directory-scanned. `core/kustomization.yaml` lists the shared-infra namespace dirs; each `clusters/<domain>/apps/kustomization.yaml` lists `../../../core` plus this cluster's apps. Core namespaces are selected whole (namespace-level, via their `apps/<ns>/kustomization.yaml`); per-site namespaces (`media`, `home-automation`, `local-ai`, `home`, `games`) are selected per-app via `apps/<ns>/<app>/` wrappers, so a namespace can split across clusters. Cross-directory refs (`../../../apps/<ns>/namespace.yaml`) rely on Flux's `LoadRestrictionsNone` — `kubectl kustomize` needs `--load-restrictor LoadRestrictionsNone` to build them locally.
- A `_` prefix on a namespace dir (e.g. `_external-secrets`) marks it as absent from cluster-settings seeding — it's seeded instead by the onepassword-connect template and needs no `DC_DOMAIN` vars. The seeded set is the explicit `core-namespaces` + per-datacenter `site-namespaces` lists in `kubernetes.nix` (which must track each cluster's Flux selection); the k8s namespace itself is the unprefixed name.
- One concern per Flux Kustomization. When an app has a CRD-providing and a CRD-consuming half (operator vs config, controller vs issuers, app vs db), split them into sibling `*.ks.yaml` files linked by `dependsOn` so the CRDs exist before anything instantiates them. Current examples: `cert-manager` → `issuers`, `envoy-gateway` → `envoy-config`, `cloudnative-pg` → per-app `*-db`.

## `<app>.ks.yaml` conventions

- `interval: 1h`, `prune: true`, `sourceRef` = the `flux-system` GitRepository, `wait: true` unless there's a reason not to.
- `targetNamespace` set on the ks — omit it only when the tree contains cluster-scoped or explicitly-namespaced resources (then say so; see `envoy-config` for the shape).
- `dependsOn` encodes real ordering: CRD providers, `onepassword-connect` (namespace `external-secrets`) for anything with an `ExternalSecret`, and `envoy-config` (namespace `network`) for anything with an `HTTPRoute`.
- `postBuild.substituteFrom` the `cluster-settings` `Secret` for domain-ish vars; `postBuild.substitute` for literal per-app vars (component parameters).

## Inherited HelmRelease defaults

`cluster-apps` patches every child Kustomization so its HelmReleases get `install.crds: CreateReplace`, `upgrade.crds: CreateReplace`, and `upgrade.remediation.retries: 2`. Do not repeat these in app HelmReleases.

## Substitution variables

The `cluster-settings` `Secret` (seeded by the NixOS `k3s` aspect into each namespace this cluster deploys — `core-namespaces` + the datacenter's `site-namespaces` in `kubernetes.nix`) provides `${DATACENTER}`, `${DC_DOMAIN}`, `${DOMAIN}`. These are **plaintext identity**, not secrets — sourced from the `host` schema (`host.datacenter`/`host.dc-domain`/`host.domain`), not sops (access control, not obscurity, is the boundary; the repo is public anyway). Component parameters (`${APP}`, `${DB_SIZE}`, …) are per-app literals set in the attaching `ks.yaml` — see `components/AGENTS.md`.

## Images & charts

- HelmReleases use `chartRef` → a per-app-named OCIRepository (`home-ops` convention), one per app dir.
- Prefer `ghcr.io/home-operations/*` images; they run rootless — use `securityContext`, never `PUID`/`PGID`.
- Docker Hub images pull through the `gcr` mirror (`mirror.gcr.io`) to dodge anonymous rate limits.

## Secrets

External Secrets Operator + 1Password Connect: `ClusterSecretStore` `onepassword-connect`, vault `Homelab`. The Connect credentials `Secret` and `cluster-settings` are seeded out-of-band from sops by the NixOS `k3s` aspect — nothing in this tree bootstraps them. Apps declare `ExternalSecrets` in their `app/` dir.

## Networking

- LoadBalancer IPs come from the Cilium LB-IPAM pool `10.69.1.0/24` (excluded from the lab DHCP range in topology.yaml — keep it that way), advertised to the MikroTik router as /32s over iBGP (AS 64512). Per-app DB LBs live at `10.69.1.5x`. The BGP CRs live in `apps/network/cilium-bgp`; Cilium itself (CNI + `bgpControlPlane`) is NixOS-managed.
- Ingress is Envoy Gateway (namespace `network`): `envoy-external` (`10.69.1.1`) is WAN-reachable, `envoy-internal` (`10.69.1.2`) is LAN-only by construction (WAN DNATs only target .1.1). Apps choose exposure via their `HTTPRoute`'s `parentRef`. Caveat: internal-only hostnames need their own router DNS record → `10.69.1.2` (no public record; the split-horizon wildcard targets .1.1) until an internal-DNS story lands.
- TLS terminates at the gateway with a wildcard Let's Encrypt cert (`cert-manager`, DNS-01 via Cloudflare) — apps do not manage certificates.
