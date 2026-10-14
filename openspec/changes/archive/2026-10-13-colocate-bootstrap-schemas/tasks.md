## 1. Expose the k3s version to tooling

- [x] 1.1 Add a flake module setting `flake.k3s-version` from `inputs.nixpkgs.legacyPackages.x86_64-linux.k3s.version`, and verify `nix eval --raw .#k3s-version` prints `1.35.8+k3s1` (or whatever the locked nixpkgs ships) measurably faster than the host-config route on a warm cache (measured: 1.3 s vs 2.6 s)
- [x] 1.2 Verify the passthru agrees with the deployed value by checking `nix eval --raw .#nixosConfigurations.da-vcx-1.config.services.k3s.package.version` returns the same string

## 2. Finish the Kubernetes bootstrap justfile

- [x] 2.1 Rewrite `bootstrap/kubernetes/justfile` to the tree's convention — `root := parent_directory(parent_directory(source_directory()))`, a `[private] default` listing recipe, `[doc(...)]` on `update-schemas` — and verify `just --list bootstrap k8s` lists `update-schemas` and `just -f bootstrap/kubernetes/justfile --list` succeeds standalone
- [x] 2.2 Fix the five defects in `update-schemas`: `$"…"` interpolation on the URL bases, `$kube_v` read from `nix eval --raw .#k3s-version` with the `+k3sN` suffix stripped, a nu-scope `let schemas = "{{ schemas_dir }}"`, the renamed `$cilium_v`/`$talos_v` in the final `print`, and removal of the unused `topology :=`
- [x] 2.3 Drop the Talos source entry and the `bootstrap_talos` cross-tree variable, and verify by grep that the file names no path outside `bootstrap/kubernetes/` except the repo root
- [x] 2.4 Record a `version` field on the Kubernetes API entries in `SOURCES.json` holding the stripped k3s version, matching the `{version, url}` shape `cilium-values.json` already uses
- [x] 2.5 Run `just bootstrap k8s update-schemas`, then `jj fix` the schema directory, and diff every file against the committed copy

  The acceptance signal in this task as first written was wrong in two ways, both benign:

  - A raw fetch can never be byte-identical to what is committed, because treefmt prettifies the vendored JSON.
    The comparison is only meaningful after `jj fix`.
  - The CRDs-catalog files track `main` and carry no version, so they drift whenever upstream does.
    `helmchart_v1.json` gained two additive optional properties (`forceConflicts`, `serverSide`); additive and optional cannot break `kubeconform -strict` on existing manifests.

  Observed after formatting: `cilium-values.json`, `fluxinstance_v1.json`, `namespace-v1.json`, and `secret-v1.json` are all byte-identical to the committed copies, and `helmchart_v1.json` differs only by those two properties.
  The core-v1 `Namespace` and `Secret` schemas are unchanged between `v1.33.1` and `v1.35.8`, so the two-minor catch-up is a content no-op — the headline risk recorded in design.md does not materialise.

## 3. Create the Talos bootstrap justfile

- [x] 3.1 Write `bootstrap/talos/justfile` with the same conventions and an `update-schemas` recipe deriving the Talos minor from `machine.install.image` in its own `machineconfig.yaml`, and verify `just --list bootstrap talos` lists it and the standalone invocation succeeds
- [x] 3.2 Run `just bootstrap talos update-schemas` and verify `bootstrap/talos/schemas/talos-config.json` is byte-identical to the committed copy and a `bootstrap/talos/schemas/SOURCES.json` is written carrying only the Talos entry

  Identical after `jj fix`, as in 2.5; the fetched bytes need formatting before the comparison means anything.
  `SOURCES.json` records the full image pin (`1.13.7`) against the minor-versioned URL (`v1.13`), since Siderolabs publishes the schema per minor.

- [x] 3.3 Remove the `talos-config.json` entry from `bootstrap/kubernetes/schemas/SOURCES.json` and verify no `bootstrap/kubernetes/` file mentions Talos

  Already satisfied by 2.5: the regenerated `SOURCES.json` dropped the entry because the recipe no longer lists it.
  The surviving `talos` strings under `bootstrap/kubernetes/` are a comment explaining the absence and an unrelated note about Talos KubePrism in `cilium-values.yaml`.

## 4. Repoint the build check and the last modeline

- [x] 4.1 Replace the six `${inputs.self}/vendor/schemas/…` paths in `bootstrap/kubernetes/checks.nix` with tree-relative `./schemas/…`, and verify by grep that no `vendor` string remains in the file

  The surviving `vendor` matches are all the word "vendored" in prose; no path references remain.
  `inputs` became an unused argument once the last one went, so it is dropped from the signature and the call site.

- [x] 4.2 Add a `k3s-version` parameter to `checks.nix` and an assertion comparing it against `."namespace-v1.json".version` in `SOURCES.json`, failing with a message naming `just bootstrap k8s update-schemas`, modelled on the existing Cilium chart-version block
- [x] 4.3 Pass `k3s-version = config.services.k3s.package.version;` at the `checks.nix` call site in `modules/services/kubernetes/kubernetes.nix`
- [x] 4.4 Change `bootstrap/talos/machineconfig.yaml:1` to `# $schema: ./schemas/talos-config.json` and verify no `$schema` modeline anywhere under `bootstrap/` resolves outside its own target directory
- [x] 4.5 Build the check derivation on an x86_64-linux remote builder and verify it passes

  `nix build` cannot address `system.checks` directly because it is a list, and `--impure --expr getFlake` on a local path copies the whole repo as a `path:` input.
  Resolve the drvPath instead: `nix eval --raw '.#nixosConfigurations.da-vcx-1.config.system.checks' --apply 'cs: (builtins.head (builtins.filter (c: c.name == "check-k8s-bootstrap-manifests") cs)).drvPath'`, then build `"$drv^*"`.

  Result: `Summary: 3 resources found in 3 files - Valid: 3, Invalid: 0, Errors: 0, Skipped: 0`, `ok -- validation done`, and both version ratchets clear.
  No `kubeconform -strict` finding from the schema bump, as 2.5 predicted.
  Also silenced the `yq -p json` deprecation warning on both ratchet reads (`-o yaml`); one of the two was pre-existing, the other I had just added.

## 5. Deliberately break the ratchet to prove it

- [x] 5.1 Temporarily edit the `version` in `bootstrap/kubernetes/schemas/SOURCES.json`, rebuild, and verify the host build fails naming `just bootstrap k8s update-schemas`; restore the correct value afterwards

  Set back to `1.33.1`; the build failed with exit code 1 and
  `k3s ships kubernetes 1.35.8 but vendored API schemas are for 1.33.1 — run 'just bootstrap k8s update-schemas'`.
  Note the ordering: kubeconform still reports all 3 resources valid, because the old core-v1 schema is a valid schema — the ratchet is what catches the staleness, not the validation.
  Restored and rebuilt green; `jj diff` confirms the file is identical to what was committed.

## 6. Move kubeconfig into the GitOps tree

- [x] 6.1 Move the `kubeconfig` recipe into `kubernetes/justfile` with an explicit `[script("nu")]`, its repo root as `parent_directory(source_directory())`, and `topology := root / "topology.yaml"`; verify the listing shows it and that it still resolves `topology.yaml` correctly
- [x] 6.2 Delete `modules/services/kubernetes/justfile` and the root justfile's `mod k8s`, rename `mod pvc` to `mod k8s`, and verify `just --list k8s` lists `kubeconfig`, `protect`, `classes`, and `migrate-class` and that `just --list` no longer offers `pvc`
- [x] 6.3 Run `just k8s kubeconfig` against one reachable cluster and verify `~/.kube/config.d/<dc>.yaml` is written with the same content as before the move

  Run with `HOME` pointed at a scratch directory (nushell's `$nu.home-dir` follows `$env.HOME`) and the real `~/.ssh` symlinked in, rather than against live state.
  The produced `da.yaml` is byte-identical to the committed live one, and `~/.kube/` timestamps are unchanged.

  **Why it was not run against live state — a pre-existing hazard this surfaced, NOT introduced by this change:**
  the recipe treats any `~/.kube/config` with a non-empty `.clusters` as a pre-multicluster leftover and `mv`s it to `~/.kube/config.pre-multicluster`.
  That assumption held when the recipe was written, but `~/.kube/config` now holds `kind-outpost` and `orbstack` — local dev clusters that write themselves there.
  Running it today would destroy those two cluster definitions and overwrite the existing July backup in one step.
  Out of scope here; raised separately.

## 7. Documentation and recipe-name strings

- [x] 7.1 Move the schema vendoring and `linkFarm` narrative from `modules/services/kubernetes/AGENTS.md` into `bootstrap/AGENTS.md`, updating its directory table rows for `kubernetes/` and `talos/` to name `schemas/` and replacing the forward-reference at the end

  **This task was wrong to say "delete `modules/services/kubernetes/AGENTS.md`".**
  Only its last two lines were about vendoring; the rest documents that aspect's own `@marker@` substitution, sops-placeholder, and `render-yaml` patterns, which still live there.
  Deleting the file would have destroyed accurate guidance.
  The vendoring paragraph is replaced by a pointer plus the one fact the aspect still owes the check (`k3s-version` at the call site).

- [x] 7.2 Verify no symlink under `.agents/rules/` or `.claude/rules/` is broken

  Moot as rewritten: keeping `modules/services/kubernetes/AGENTS.md` keeps `nix-services-kubernetes.md` valid, so nothing to delete.
  Confirmed no broken symlinks under either directory.

- [x] 7.3 Update the `just k8s update-schemas` strings in `bootstrap/kubernetes/cilium-values.yaml` and `bootstrap/talos/machineconfig.yaml` to the per-target recipe names

  Also dropped a false claim from the `machineconfig.yaml` comment: it said "the build check fails if the vendored schema lags this pin", but `modules/system/virtualization/talos.nix:232-236` deliberately validates with `talosctl validate` rather than the vendored schema, so no Talos version ratchet exists.
  Only the Kubernetes side has one.

- [x] 7.4 Verify every repo Markdown file this change touches follows one-sentence-per-line, and run the project formatting pipeline (`jj fix`, plus `prek run` if hooks cover these paths)

## 8. Retire the vendor tree

- [x] 8.1 Verify by grep that no file outside `openspec/changes/archive/` references `vendor/schemas` or a repo-root `vendor/`, then delete `vendor/`

  Before deleting, diffed every file against its new home: all identical except `helmchart_v1.json` (the two additive upstream properties from 2.5), and the union of the two new `SOURCES.json` files has the same key set as the old one.
  Nothing was lost in the split.

- [x] 8.2 Rebuild the server host and run both `update-schemas` recipes once more from a clean checkout state, verifying the build is green and the schemas are unchanged

  Both recipes re-run with `vendor/` gone produce schemas byte-identical to what is committed, and the check rebuilds green (`Valid: 3, Invalid: 0`).

## 9. Sync the specs

- [x] 9.1 Fold the `bootstrap` and `repo-layout` deltas into `openspec/specs/`, confirming the `repo-layout` edit does not collide with the in-flight `docs-site-multi-domain` delta (which modifies a different requirement), and verify `openspec validate --strict` passes

  No collision: `docs-site-multi-domain` modifies _Tool trees live at the repository root_, this change modifies _Infra-acting tooling is placed by lifecycle phase_.
  Merged preserving each main spec's existing scenario order rather than adopting the delta's ordering, so the diff is additive where possible.
  `openspec validate --specs` reports 5 passed, 0 failed; no delta operation headers leaked into the main specs; `bootstrap` keeps a single `## Requirements` section.
