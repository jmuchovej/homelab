## MODIFIED Requirements

### Requirement: OpenTofu lives under `tofu/`

The repository SHALL keep all OpenTofu root modules, child modules, justfile modules, and their `secrets` and `topology.yaml` symlinks under `tofu/`.
The symlinks SHALL resolve to the repo-root `secrets/` directory and `topology.yaml` file.
Provider caches SHALL live alongside the root module in `tofu/`.
State SHALL NOT, and is governed by the `tofu-state` capability instead; the local state files that remain in `tofu/` are retained rollback copies, not the authoritative state.

#### Scenario: Plan is a no-op after the move

- **WHEN** `tofu plan` is run inside `tofu/` immediately after the move
- **THEN** it reports no changes, and every `sops_file` data source resolves its `${path.root}/secrets/...` and `${path.root}/topology.yaml` input

#### Scenario: Justfile recipes reach secrets

- **WHEN** a `just authentik ...` or `just mikrotik ...` recipe reads a sops file
- **THEN** it resolves to a file under the repo-root `secrets/` directory
