## Why

The JSON schemas that gate the bootstrap manifests live at repo-root `vendor/schemas/`, one flat directory away from both trees that consume them, and the recipe that refreshes them lives in `modules/services/kubernetes/justfile` — a configuration-phase tree.
That split contradicts the `repo-layout` lifecycle-phase requirement twice over: a bootstrap-phase tool sits under `modules/`, and `vendor/` exists only as an exemption in that requirement's out-of-scope list.

It has also allowed a silent drift.
The vendored Kubernetes schemas are pinned at `v1.33.1-standalone-strict` while the k3s the clusters actually run is `1.35.8+k3s1`, because nothing ties the schema pin to the shipped k3s version the way the Cilium values schema is already tied to the chart pin.

## What Changes

- Schemas move from `vendor/schemas/` to `bootstrap/kubernetes/schemas/` and `bootstrap/talos/schemas/`, each beside the manifests it validates, with its own `SOURCES.json`.
  `vendor/` is deleted.
- `update-schemas` splits in two: `just bootstrap k8s update-schemas` for the Kubernetes schemas and `just bootstrap talos update-schemas` for the Talos config schema.
  Neither reaches into the other's tree, so the Kubernetes recipe stops reading `bootstrap/talos/machineconfig.yaml`.
- The Kubernetes schema version stops being a hardcoded literal and derives from the k3s package the clusters run.
  The bootstrap build check gains an assertion on it, mirroring the Cilium chart-version ratchet it already performs.
- **BREAKING** (operator muscle memory, not deployed state): `just k8s update-schemas` no longer exists.
  `modules/services/kubernetes/justfile` is deleted; its `kubeconfig` recipe moves to `kubernetes/justfile`, the tree of the tool that does the configuring.
  The root justfile's `pvc` module is renamed `k8s`, so `just k8s kubeconfig`, `just k8s protect`, `just k8s classes`, and `just k8s migrate-class` all resolve there.
- Catching up two Kubernetes minor versions of schema may surface new `kubeconform -strict` findings in the seed manifests; fixing those is in scope.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `bootstrap`: the seed-manifest and Talos requirements name where schemas are vendored and which recipe refreshes them; both change, and the Kubernetes schema pin gains a requirement that it follow the shipped k3s version.
- `repo-layout`: the lifecycle-phase requirement drops `vendor/` from its out-of-scope tree list, because the tree ceases to exist.

## Impact

- `bootstrap/kubernetes/`: `justfile` (completed and corrected), `checks.nix` (schema paths become tree-relative; new k3s-version assertion), `cilium-values.yaml` (recipe name in a comment), `schemas/SOURCES.json` (Talos entry removed).
- `bootstrap/talos/`: `justfile` (currently an empty file that `bootstrap/justfile` already declares as a module), `machineconfig.yaml` (last `vendor/` modeline, recipe name in a comment), `schemas/SOURCES.json` (new).
- `modules/services/kubernetes/`: `justfile` and `AGENTS.md` deleted, `kubernetes.nix` passes the k3s version to `checks.nix`.
- `kubernetes/justfile`: gains `kubeconfig`.
- Root `justfile`: `mod k8s` removed, `mod pvc` renamed to `mod k8s`.
- A new flake output exposing the k3s version, so the recipe can read it without evaluating a specific host.
- `bootstrap/AGENTS.md` absorbs the vendoring narrative it currently forwards elsewhere; the `.agents/rules/` and `.claude/rules/` entries are symlinks and follow automatically.
- No deployed state changes.
  Every consumer is a build-time check or an operator recipe.
