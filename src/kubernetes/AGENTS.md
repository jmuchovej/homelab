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

External Secrets Operator + 1Password Connect: `ClusterSecretStore` `onepassword-connect`, vault `Homelab`. The one secret NixOS seeds out-of-band from sops is the Flux **sops-age** key; with it, Flux decrypts each cluster's `clusters/<domain>/config/op-connect.sops.yaml` to bring up 1Password Connect, after which apps' `ExternalSecrets` (declared in each `app/` dir) resolve from 1Password.

## Networking

- LoadBalancer IPs come from the Cilium LB-IPAM pool `10.69.1.0/24` (excluded from the lab DHCP range in topology.yaml — keep it that way), advertised to the MikroTik router as /32s over iBGP (AS 64512). Per-app DB LBs live at `10.69.1.5x`. The BGP CRs live in `apps/network/cilium/bgp`; Cilium itself (CNI + `bgpControlPlane`) is NixOS-managed.
- Ingress is Envoy Gateway (namespace `network`): `envoy-external` (`10.69.1.1`) is WAN-reachable, `envoy-internal` (`10.69.1.2`) is LAN-only by construction (WAN DNATs only target .1.1). Apps choose exposure via their `HTTPRoute`'s `parentRef`. Caveat: internal-only hostnames need their own router DNS record → `10.69.1.2` (no public record; the split-horizon wildcard targets .1.1) until an internal-DNS story lands.
- TLS terminates at the gateway with a wildcard Let's Encrypt cert (`cert-manager`, DNS-01 via Cloudflare) — apps do not manage certificates.

## Network policies

`CiliumClusterwideNetworkPolicy` (CCNP) live under `apps/network/cilium/network-policies/` — part of **cilium's definition**, not a standalone app; deployed by the `cilium-network-policies` Flux Kustomization (no `targetNamespace`, since the tree mixes cluster-scoped CCNPs with a `kube-system` CNP). Cilium runs in its **`default` enforcement mode** (`policyEnforcementMode` unset in `cilium-values.yaml`): an endpoint is allow-all **until a policy selects it in a given direction**, then flips to **deny-all-except-allowed** for that direction. A pod therefore locks down the instant it wears its first grant label — lockdown is opt-in, per pod.

**House convention — label grants are `<direction>.rbn/<grant>: allow`.** This matches the repo's existing `<concern>.rbn/<key>` scheme (`authentik.rbn/*`), **not** biohazard's `home.arpa`. Label keys are freeform strings Cilium only string-matches; the `.rbn` prefix is ours by convention. A pod opts in by wearing the label on its **pod template** (the endpoint — not the Deployment/HelmRelease top level). Grants compose: a pod may wear several.

Mechanics baked into the policies (so you don't re-derive them per app):

- **DNS is folded into every egress grant** (`kube-dns:53`), so a locked-down pod always resolves — there is no separate cluster-wide DNS floor (we deliberately did **not** adopt biohazard's cluster-wide kube-dns egress selector, which is a big-bang lockdown). `egress.rbn/dns` is the DNS-_only_ grant (tightest possible egress).
- **Kubelet health probes are unaffected** by ingress lockdown — Cilium's default `allow-localhost=visible` permits host→local-pod.
- `kube-system-allow-all` (a namespaced `CiliumNetworkPolicy`) keeps the system tier permanently open, so a future cluster-wide policy can't strand it.

### Grant registry

Every grant is hand-authored, so this table **is** the catalog — add a row here whenever you add a CCNP to `allow-egress.yaml` / `allow-ingress.yaml` (a new grant = label-selector → allow rule; re-include the `kube-dns:53` block for egress grants).

| Label                  | Direction | Grants                                                                              |
| ---------------------- | --------- | ----------------------------------------------------------------------------------- |
| `egress.rbn/dns`       | egress    | `kube-dns:53` only — self-contained/SQLite apps                                     |
| `egress.rbn/internet`  | egress    | all non-RFC1918 (`0.0.0.0/0` except `10/8`, `172.16/12`, `192.168/16`) + DNS        |
| `egress.rbn/apiserver` | egress    | `kube-apiserver` + `host:6443` (in-cluster controllers) + DNS                       |
| `egress.rbn/lan`       | egress    | lab LAN `10.69.0.0/16` (router/NAS/LAN svcs) + DNS                                  |
| `ingress.rbn/gateway`  | ingress   | Envoy data plane only (`network` ns, `managed-by=envoy-gateway`, `component=proxy`) |
| `ingress.rbn/cluster`  | ingress   | any in-cluster endpoint (Cilium `cluster` entity)                                   |
| `ingress.rbn/world`    | ingress   | public internet (Cilium `world` entity)                                             |

Roll out a first-time lockdown **audit-first**: `cilium endpoint config <id> PolicyAuditMode=Enabled` on the node, watch `hubble observe --verdict AUDIT` for the pod, confirm only the intended flows appear, then disable audit to enforce.
