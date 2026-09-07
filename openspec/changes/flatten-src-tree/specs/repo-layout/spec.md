## Purpose

Defines the top-level directory contract of the repository so that external consumers (Flux on the clusters, `just` recipes, flake module discovery, editor schema mapping, OpenTofu secret and state lookups) can rely on stable, root-relative paths.

## ADDED Requirements

### Requirement: Tool trees live at the repository root

The repository SHALL place each tool-specific tree directly under the repository root: Nix modules under `modules/`, Flux manifests under `kubernetes/`, OpenTofu under `tofu/`, MikroTik bootstrap material under `mikrotik/`, cluster seed manifests under `bootstrap/`, and the shared network topology at `topology.yaml`. No tool-facing path SHALL carry a `src/` prefix.

#### Scenario: Flake discovers modules from the root

- **WHEN** the flake is evaluated
- **THEN** it imports its module tree from `./modules` and every host, home, and dev shell output evaluates identically to before the move

#### Scenario: Root justfile modules resolve

- **WHEN** `just --list` is run at the repository root
- **THEN** the `bootstrap`, `mikrotik`, and `authentik` modules load from `modules/hosts/bootstrap/justfile`, `tofu/mikrotik.just`, and `tofu/authentik.just` without error

#### Scenario: Nix reads repo data files from root-relative paths

- **WHEN** a module resolves `topology.yaml`, a host's `facter.json`, or a `bootstrap/` seed file through `inputs.self`
- **THEN** the path is `<self>/topology.yaml`, `<self>/modules/hosts/<host>/facter.json`, or `<self>/bootstrap/...` and the file is found

### Requirement: Python package is the sole occupant of `src/`

The repository SHALL keep the `homelab` Python package at `src/homelab/` and SHALL NOT place any non-Python tree under `src/`.

#### Scenario: uv build still finds the package

- **WHEN** `uv sync` or `uv run homelab --help` is run
- **THEN** the package resolves from `src/homelab` with no change to `pyproject.toml`

#### Scenario: src contains only the package

- **WHEN** the tree under `src/` is listed after the change
- **THEN** it contains `homelab/` and nothing else

### Requirement: OpenTofu lives under `tofu/`

The repository SHALL keep all OpenTofu root modules, child modules, justfile modules, and their `secrets` and `topology.yaml` symlinks under `tofu/`. The symlinks SHALL resolve to the repo-root `secrets/` directory and `topology.yaml` file. Local state and provider caches SHALL live alongside the root module in `tofu/`.

#### Scenario: Plan is a no-op after the move

- **WHEN** `tofu plan` is run inside `tofu/` immediately after the move, with state and `.terraform/` relocated
- **THEN** it reports no changes, no re-initialization is required, and every `sops_file` data source resolves its `${path.root}/secrets/...` and `${path.root}/topology.yaml` input

#### Scenario: Justfile recipes reach secrets

- **WHEN** a `just authentik ...` or `just mikrotik ...` recipe reads a sops file
- **THEN** it resolves to a file under the repo-root `secrets/` directory

### Requirement: Flux paths are root-relative without a `src/` prefix

Every Flux `Kustomization` `spec.path` in the repository SHALL begin with `./kubernetes/`, and each cluster's `FluxInstance` sync path SHALL be `kubernetes/clusters/<dc-domain>/flux`.

#### Scenario: Root Kustomizations reconcile from the new path

- **WHEN** a cluster's `FluxInstance` sync path is `kubernetes/clusters/<dc-domain>/flux` and the GitRepository artifact contains the flattened tree
- **THEN** `cluster-config` and `cluster-apps` reconcile successfully and every child Kustomization's `spec.path` resolves inside the artifact

#### Scenario: No stale prefix remains

- **WHEN** the manifests under `kubernetes/` are searched for `src/kubernetes`
- **THEN** there are zero matches

#### Scenario: Offline build matches live

- **WHEN** `flux-local build` (or `kustomize build`) is run against `kubernetes/clusters/<dc-domain>/flux` from the repo root
- **THEN** every referenced path exists and the build succeeds for both clusters

### Requirement: Repo tooling patterns match the flattened tree

Path patterns in repo-root tooling (`.sops.yaml` creation rules, `.gitignore` negations, `.envrc` watch paths, `.zed/settings.json` schema globs, and pre-commit hook `files`/`excludes` regexes) SHALL match paths under `kubernetes/` and `modules/` and SHALL NOT reference `src/kubernetes` or `src/modules`.

#### Scenario: sops picks the cluster recipient rule

- **WHEN** a file matching `kubernetes/clusters/<dc-domain>/**/*.sops.yaml` is encrypted
- **THEN** the creation rule for that cluster's Flux age key applies, and existing encrypted files decrypt without being re-encrypted

#### Scenario: Pre-commit schema check still targets manifests

- **WHEN** the `check-k8s-schemas` hook runs on all files
- **THEN** it validates YAML under `kubernetes/` and still skips `blueprints/`, `resources/`, `patch-*`, `*.sops.yaml`, and the Home Assistant config directory

#### Scenario: Editor schema mapping applies

- **WHEN** a file such as `kubernetes/apps/<ns>/<app>/app/helm-release.yaml` is opened in Zed
- **THEN** the matching home-operations JSON schema is associated with it
