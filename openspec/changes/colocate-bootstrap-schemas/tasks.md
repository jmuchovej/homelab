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

- [ ] 5.1 Temporarily edit the `version` in `bootstrap/kubernetes/schemas/SOURCES.json`, rebuild, and verify the host build fails naming `just bootstrap k8s update-schemas`; restore the correct value afterwards

## 6. Move kubeconfig into the GitOps tree

- [ ] 6.1 Move the `kubeconfig` recipe into `kubernetes/justfile` with an explicit `[script("nu")]`, its repo root as `parent_directory(source_directory())`, and `topology := root / "topology.yaml"`; verify `just pvc kubeconfig --help`-equivalent listing shows it and that it still resolves `topology.yaml` correctly
- [ ] 6.2 Delete `modules/services/kubernetes/justfile` and the root justfile's `mod k8s`, rename `mod pvc` to `mod k8s`, and verify `just --list k8s` lists `kubeconfig`, `protect`, `classes`, and `migrate-class` and that `just --list` no longer offers `pvc`
- [ ] 6.3 Run `just k8s kubeconfig` against one reachable cluster and verify `~/.kube/config.d/<dc>.yaml` is written with the same content as before the move

## 7. Documentation and recipe-name strings

- [ ] 7.1 Move the schema vendoring and `linkFarm` narrative from `modules/services/kubernetes/AGENTS.md` into `bootstrap/AGENTS.md`, updating its directory table rows for `kubernetes/` and `talos/` to name `schemas/` and replacing the forward-reference at the end; delete `modules/services/kubernetes/AGENTS.md`
- [ ] 7.2 Delete the now-dangling `.agents/rules/nix-services-kubernetes.md` symlink and its `.claude/rules/` counterpart, and verify no symlink under either directory is broken
- [ ] 7.3 Update the `just k8s update-schemas` strings in `bootstrap/kubernetes/cilium-values.yaml` and `bootstrap/talos/machineconfig.yaml` to the per-target recipe names
- [ ] 7.4 Verify every repo Markdown file this change touches follows one-sentence-per-line, and run the project formatting pipeline (`jj fix`, plus `prek run` if hooks cover these paths)

## 8. Retire the vendor tree

- [ ] 8.1 Verify by grep that no file outside `openspec/changes/archive/` references `vendor/schemas` or a repo-root `vendor/`, then delete `vendor/`
- [ ] 8.2 Rebuild the server host and run both `update-schemas` recipes once more from a clean checkout state, verifying the build is green and the schemas are unchanged

## 9. Sync the specs

- [ ] 9.1 Fold the `bootstrap` and `repo-layout` deltas into `openspec/specs/`, confirming the `repo-layout` edit does not collide with the in-flight `docs-site-multi-domain` delta (which modifies a different requirement), and verify `openspec validate --strict` passes
