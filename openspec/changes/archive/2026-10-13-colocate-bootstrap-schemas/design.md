## Context

See proposal.md — Why.

Mechanics that shape the approach:

The schema files have already been copied into `bootstrap/kubernetes/schemas/` and `bootstrap/talos/schemas/` in the working tree, byte-identical to `vendor/schemas/`, and the Kubernetes manifests' modelines already read `./schemas/…`.
`bootstrap/kubernetes/justfile` exists as a half-finished port that cannot run: unterpolated `"($raw)/…"` strings where nushell needs `$"…"`, an undefined `$kube_v`, `$schemas` referenced as a nu variable when it is only a `just` variable, `$cilium_version`/`$talos_version` in the final `print` after the bindings were renamed to `_v`, and a `topology :=` derived from `justfile_directory()` that is both unused and contrary to the tree's convention.
`bootstrap/talos/justfile` is a zero-byte file that `bootstrap/justfile` already declares as a module.
So this change finishes a started move rather than beginning one.

Only one `vendor/` reference survives outside the Nix check: the modeline at `bootstrap/talos/machineconfig.yaml:1`.
`bootstrap/kubernetes/checks.nix` holds the other six.

Of the vendored Kubernetes API schemas, only `namespace-v1.json` is actually exercised by the build: `checks.nix` runs `kubeconform -strict -skip Secret`, and the remaining kinds (`HelmChart`, `FluxInstance`) resolve from the CRDs-catalog files, which track `main` and carry no version.
`secret-v1.json` is vendored for the editor modeline on `flux-agekey.yaml` alone.
That bounds the blast radius of catching the pin up from `1.33.1` to `1.35.8`.

## Goals / Non-Goals

**Goals:**

- Each `bootstrap/<target>/` directory becomes readable and refreshable without reference to any sibling.
- The Kubernetes schema version becomes a derived value with a build-time ratchet, not a literal someone must remember to bump.
- `just k8s …` keeps working as the operator's Kubernetes entry point, pointing at the tree that actually holds Kubernetes configuration.

**Non-Goals:**

- Changing which schemas are vendored, or adding schema coverage for kinds not currently validated.
- Touching the `kubernetes/` GitOps tree's own schema story, which uses remote `k8s-schemas.home-operations.com` URLs and a pre-commit hook rather than vendoring.
- Reconciling the Talos-shipped Kubernetes version with the k3s one.
  The Talos _config_ schema is versioned by Talos release, not by Kubernetes version, so the two pins are independent.
- Bringing the `cf` submodule, which holds placeholders only, into the justfile-module requirement.

## Decisions

### Per-target schema directories, each with its own `SOURCES.json`

Alternative considered: one shared `bootstrap/schemas/`, which keeps a single refresh recipe and a single manifest of sources.
Rejected because it reintroduces the thing being removed — a directory no single target owns — and because the two targets' schemas are versioned by unrelated upstreams, so a shared `SOURCES.json` would need per-entry provenance anyway.

### Two refresh recipes, one per target

`just bootstrap k8s update-schemas` fetches the Kubernetes set; `just bootstrap talos update-schemas` fetches the Talos config schema from the minor derived from `machine.install.image`.
Alternative considered: keep one recipe under `bootstrap/kubernetes/` that writes into both trees, as the current half-port's `bootstrap_talos := bootstrap_kubes / "../talos"` does.
Rejected: that cross-tree reach is precisely what the self-containment clause forbids, and it makes the Kubernetes recipe fail for a reason owned by Talos.

### `kube_v` comes from a `flake.k3s-version` passthru

flake-parts declares its top-level `flake` option with a freeform type (`lazyAttrsOf (unique raw)`), so a flake module may set `flake.k3s-version = inputs.nixpkgs.legacyPackages.x86_64-linux.k3s.version` and the recipe reads it with `nix eval --raw .#k3s-version`.
The `+k3sN` suffix is stripped to get the upstream Kubernetes version; `v1.35.8-standalone-strict` exists in `yannh/kubernetes-json-schema`, so the full patch version is usable and no minor-only truncation is needed.

Alternatives considered:

- `nix eval .#nixosConfigurations.<host>.config.services.k3s.package.version` — correct and 2.6 s warm, but hardcodes one host as the privileged source of a cluster-wide fact, and is minutes cold.
- `nix eval --impure --expr '(builtins.getFlake (toString ./.)).inputs.nixpkgs…'` — host-independent and verified to return the same string, but `--impure --expr` bypasses the eval cache, so it pays the full lock-resolution cost on every run.
- A recipe argument defaulting to the value already in `SOURCES.json`, leaving the build check as the only enforcer — no eval at all, but it makes the operator transcribe a version that the repository can compute.

A passthru does mean `nix flake show` lists an output no schema knows about; that is a cosmetic warning, not an error.

### The build check, not the passthru, is the authority

`checks.nix` compares the version recorded in `bootstrap/kubernetes/schemas/SOURCES.json` against `config.services.k3s.package.version`, passed in from the call site in `modules/services/kubernetes/kubernetes.nix` where `config` is already in scope.
This mirrors the Cilium chart-version ratchet already in that file and gives the same failure mode: a nixpkgs bump that moves k3s fails the host build with a message naming the recipe.

Deriving the passthru from `inputs.nixpkgs` while asserting against the host's `config.services.k3s.package` is deliberate.
Today nothing overrides `services.k3s.package`, so the two agree.
If a host ever pins its own k3s, they diverge and the build fails loudly rather than silently validating that host's manifests against another version's schema.

### `SOURCES.json` records the Kubernetes version per file

The Kubernetes API entries gain a `version` field holding the stripped k3s version, the same `{version, url}` shape `cilium-values.json` already uses, so the check reads it with the same `yq` expression rather than parsing a version back out of a URL.

### Schema paths in `checks.nix` become tree-relative

`${inputs.self}/vendor/schemas/x.json` becomes `./schemas/x.json`.
The file reaching through `inputs.self` for something sitting beside it was only necessary while the schemas lived elsewhere.

### `kubeconfig` moves and the module is renamed

`kubeconfig` goes to `kubernetes/justfile` — it configures clusters that are already reachable, so by the lifecycle-phase rule it belongs to the configuring tool's tree.
With `mod k8s` freed by deleting `modules/services/kubernetes/justfile`, `mod pvc` is renamed `mod k8s`: the module will hold `kubeconfig` alongside the PVC recipes, so a name describing only volumes would be wrong, and the rename preserves the `just k8s …` prefix operators already use.

Two mechanical details: `kubernetes/justfile` sets `script-interpreter` to bash file-wide, so `kubeconfig` needs an explicit `[script("nu")]`; and its repo root is `parent_directory(source_directory())` — one level, not the two the `bootstrap/*/` justfiles use.

### The schema bump rides along rather than being deferred

Catching `1.33.1` up to `1.35.8` is not separable: the point of deriving the version is that the vendored files follow it.
Doing it in a later change would mean landing a ratchet that fails the build immediately.

## Risks / Trade-offs

- **Two Kubernetes minors of schema drift surface new `kubeconform -strict` findings in the seed manifests** → The only seed kind validated against the bumped set is `Namespace`, and `Secret` is explicitly skipped, so the exposure is small.
  Refetch and run the check before any other edit, so a finding is attributable to the bump rather than to the move.
- **`nix flake show` and `nix flake check` report `k3s-version` as an unrecognized output** → Cosmetic; no consumer reads flake outputs by enumeration.
- **The half-finished `bootstrap/kubernetes/justfile` has never been executed, so its fixes are unverified beyond reading** → Run both `update-schemas` recipes and diff the result against the committed schema files; byte-identical output for the unchanged sources is the acceptance signal.
- **Operators with `just k8s update-schemas` in muscle memory get a recipe-not-found error** → `just k8s --list` shows the new set, and the build check's failure message names the new path.
- **A host that later pins `services.k3s.package` diverges from the passthru** → The check fails the build rather than validating silently; accepted as the correct direction.

## Migration Plan

1. Finish the two justfiles and refresh both schema sets; confirm the only content change is the Kubernetes API files moving to `1.35.8`.
2. Repoint `checks.nix` and the last modeline, add the k3s-version passthru and assertion, and build a server host.
   Resolve any kubeconform finding from the bump here.
3. Move `kubeconfig`, rename the justfile module, delete `modules/services/kubernetes/justfile`.
4. Update `bootstrap/AGENTS.md`, delete `modules/services/kubernetes/AGENTS.md`, fix the recipe-name strings.
5. Delete `vendor/` only once nothing references it and the host build is green.

Rollback is a revert: nothing here changes deployed state, and every consumer is either a build-time check or an operator recipe.
