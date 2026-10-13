## 1. Expose the k3s version to tooling

- [ ] 1.1 Add a flake module setting `flake.k3s-version` from `inputs.nixpkgs.legacyPackages.x86_64-linux.k3s.version`, and verify `nix eval --raw .#k3s-version` prints `1.35.8+k3s1` (or whatever the locked nixpkgs ships) in under a second on a warm cache
- [ ] 1.2 Verify the passthru agrees with the deployed value by checking `nix eval --raw .#nixosConfigurations.da-vcx-1.config.services.k3s.package.version` returns the same string

## 2. Finish the Kubernetes bootstrap justfile

- [ ] 2.1 Rewrite `bootstrap/kubernetes/justfile` to the tree's convention — `root := parent_directory(parent_directory(source_directory()))`, a `[private] default` listing recipe, `[doc(...)]` on `update-schemas` — and verify `just --list bootstrap k8s` lists `update-schemas` and `just -f bootstrap/kubernetes/justfile --list` succeeds standalone
- [ ] 2.2 Fix the five defects in `update-schemas`: `$"…"` interpolation on the URL bases, `$kube_v` read from `nix eval --raw .#k3s-version` with the `+k3sN` suffix stripped, a nu-scope `let schemas = "{{ schemas_dir }}"`, the renamed `$cilium_v`/`$talos_v` in the final `print`, and removal of the unused `topology :=`
- [ ] 2.3 Drop the Talos source entry and the `bootstrap_talos` cross-tree variable, and verify by grep that the file names no path outside `bootstrap/kubernetes/` except the repo root
- [ ] 2.4 Record a `version` field on the Kubernetes API entries in `SOURCES.json` holding the stripped k3s version, matching the `{version, url}` shape `cilium-values.json` already uses
- [ ] 2.5 Run `just bootstrap k8s update-schemas` and verify the only files whose content changes are `namespace-v1.json` and `secret-v1.json` (now `v1.35.8-standalone-strict`), with `cilium-values.json`, `fluxinstance_v1.json`, and `helmchart_v1.json` byte-identical to what is committed

## 3. Create the Talos bootstrap justfile

- [ ] 3.1 Write `bootstrap/talos/justfile` with the same conventions and an `update-schemas` recipe deriving the Talos minor from `machine.install.image` in its own `machineconfig.yaml`, and verify `just --list bootstrap talos` lists it and the standalone invocation succeeds
- [ ] 3.2 Run `just bootstrap talos update-schemas` and verify `bootstrap/talos/schemas/talos-config.json` is byte-identical to the committed copy and a `bootstrap/talos/schemas/SOURCES.json` is written carrying only the Talos entry
- [ ] 3.3 Remove the `talos-config.json` entry from `bootstrap/kubernetes/schemas/SOURCES.json` and verify no `bootstrap/kubernetes/` file mentions Talos

## 4. Repoint the build check and the last modeline

- [ ] 4.1 Replace the six `${inputs.self}/vendor/schemas/…` paths in `bootstrap/kubernetes/checks.nix` with tree-relative `./schemas/…`, and verify by grep that no `vendor` string remains in the file
- [ ] 4.2 Add a `k3s-version` parameter to `checks.nix` and an assertion comparing it against `."namespace-v1.json".version` in `SOURCES.json`, failing with a message naming `just bootstrap k8s update-schemas`, modelled on the existing Cilium chart-version block
- [ ] 4.3 Pass `k3s-version = config.services.k3s.package.version;` at the `checks.nix` call site in `modules/services/kubernetes/kubernetes.nix`
- [ ] 4.4 Change `bootstrap/talos/machineconfig.yaml:1` to `# $schema: ./schemas/talos-config.json` and verify no `$schema` modeline anywhere under `bootstrap/` resolves outside its own target directory
- [ ] 4.5 Build a server host (`nix build .#nixosConfigurations.da-vcx-1.config.system.build.toplevel`) and verify the bootstrap-manifest check passes; if `kubeconform -strict` reports a `Namespace` finding from the schema bump, fix the manifest and record what changed

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
