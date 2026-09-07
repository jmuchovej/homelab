## Why

`src/` currently holds five unrelated trees (Nix modules, Flux manifests, OpenTofu, MikroTik bootstrap, a Python CLI) plus `topology.yaml`, so every tool-facing path in the repo carries a meaningless `src/` prefix and the one directory that is _named_ for a tool (`terraform`) names the wrong one. The Python package is the only thing that benefits from a `src/` layout (`uv_build` defaults to `src/<module>`), and it is on its way out. Flattening now, while the Kubernetes and OpenTofu trees are still small enough to move in one commit, avoids carrying the prefix into every new Flux Kustomization, justfile recipe, and doc.

## What Changes

- **BREAKING** Move `src/modules/` to `modules/`, `src/kubernetes/` to `kubernetes/`, `src/mikrotik/` to `mikrotik/`, and `src/topology.yaml` to `topology.yaml`. The flake's `import-tree` root becomes `./modules`.
- **BREAKING** Move `src/terraform/` to `tofu/` (rename, not just relocate). The two justfile modules it ships (`mikrotik.just`, `authentik.just`) and its `secrets`/`topology.yaml` symlinks move with it and are re-pointed.
- **BREAKING** Every Flux `Kustomization` `spec.path` that reads `./src/kubernetes/...` becomes `./kubernetes/...` (59 files across `kubernetes/clusters/**` and `kubernetes/apps/**`). The live `FluxInstance` sync path on each cluster must change in lockstep.
- Move the untracked, work-in-progress `src/bootstrap/` seed tree to `bootstrap/`, update the Nix references that read from it, and set the new Flux sync path in its `flux-instance.yaml` if that file exists on disk.
- Update every repo-root path that encodes the old layout: root `justfile` `mod` lines and `facter` recipe, `.envrc` `watch_file`, `.gitignore` negation, `.sops.yaml` cluster `path_regex` rules, `.zed/settings.json` YAML schema globs, the `check-k8s-schemas` pre-commit `files`/`excludes` regexes, and the Nix sources that build paths from `inputs.self` (`kubernetes.nix`, `zerotier.nix`, `talos.nix`, `nix-builders.nix`).
- Regenerate `flake.nix` via `just regen` after changing `flake-file.outputs` in `modules/inputs.nix`; the file is generated and must not be hand-edited.
- Rewrite comments, AGENTS.md headings, and `.tofu` description strings that cite `src/...` or `src/terraform/...` so docs match the tree.
- `src/homelab/` stays exactly where it is, as does `pyproject.toml`; `src/` becomes the Python-only directory.

## Capabilities

### New Capabilities

- `repo-layout`: the top-level directory contract that external consumers (Flux on the clusters, `just` recipes, the flake's module discovery, editor schema mapping, OpenTofu state and secret lookups) depend on. Defines which trees live at the repo root, that OpenTofu lives under `tofu/`, that the Python package is the sole occupant of `src/`, and that every Flux path is relative to the repo root without a `src/` prefix.

### Modified Capabilities

- None. `openspec/specs/` is empty; no existing capability changes.

## Impact

- **Flux / live clusters (`da.jm0.io`, `en.jm0.io`)**: the `GitRepository`-rooted paths change. Until the `FluxInstance` `sync.path` on each cluster is updated, Flux will fail to find the new root directory and stall on the last good commit; nothing is pruned, but nothing reconciles either. This is the only step with a production blast radius and needs to be sequenced with the merge.
- **OpenTofu state and caches**: `src/terraform/` holds ignored, untracked files (`terraform.tfstate` and backups, `.terraform/`, `authentik.auto.tfvars.json`, `.scratch/`) and one untracked-but-not-ignored source file (`da.cloudflare-tunnel.tofu`). `git mv` will not carry these; they must be moved by hand in the main checkout, and `tofu plan` must be clean afterward.
- **Nix evaluation**: `flake.nix` (generated), `modules/inputs.nix`, `modules/defaults.nix` (unchanged, uses relative paths), and four modules that build absolute paths from `inputs.self`. `nix flake check` and host evaluations are the gate.
- **Dev tooling**: root `justfile` modules, `.envrc`, pre-commit regexes in `checks.nix`, Zed YAML schema globs, `.sops.yaml` creation rules (no re-encryption needed; recipients are unchanged), `.gitignore`.
- **Docs**: AGENTS.md files under `modules/`, `kubernetes/`, and `modules/secrets/`; `.tofu` descriptions and comments. Untracked docs in the main checkout (`AGENTS.md`, `docs/`, `plans/`) also cite `src/` paths but are outside the repo and outside this change.
- **Not touched**: `src/homelab/`, `pyproject.toml`, `uv.lock`, `vendor/`, `secrets/`, `skills/`, the `terraform` formatter block in `treefmt.nix` (that is treefmt-nix's program name, not a path), and the `.github/workflows/flux-local.yaml` paths (already `kubernetes/**`, though they point at a `flux/cluster` layout this repo does not use; pre-existing).
