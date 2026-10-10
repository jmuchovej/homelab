# repo-layout Specification

## Purpose

Defines the top-level directory contract of the repository so that external consumers (Flux on the clusters, `just` recipes, flake module discovery, editor schema mapping, OpenTofu secret and state lookups) can rely on stable, root-relative paths.

## Requirements

### Requirement: Tool trees live at the repository root

The repository SHALL place each tool-specific tree directly under the repository root: Nix modules under `modules/`, Flux manifests under `kubernetes/`, OpenTofu under `tofu/`, all bootstrap material (installer image and host install, MikroTik first-boot, cluster seed manifests, Talos machine-config base) under `bootstrap/`, MikroTik topology diagrams and reference documents under `mikrotik/`, Hubitat libraries and drivers under `hubitat/`, and the shared network topology at `topology.yaml`.
No tool-facing path SHALL carry a `src/` prefix.

#### Scenario: Flake discovers modules from the root

- **WHEN** the flake is evaluated
- **THEN** it imports its module tree from `./modules` and `./bootstrap/nix`, and every host, home, and dev shell output evaluates identically to before the move

#### Scenario: Root justfile modules resolve

- **WHEN** `just --list` is run at the repository root
- **THEN** the `bootstrap`, `mikrotik`, `authentik`, and `hubitat` modules load from `bootstrap/justfile`, `tofu/mikrotik.just`, `tofu/authentik.just`, and `hubitat/justfile` without error

#### Scenario: Nix reads repo data files from root-relative paths

- **WHEN** a module resolves `topology.yaml`, a host's `facter.json`, a `bootstrap/` seed file, or the installer image's `secrets/keys/iso-key.pub` through `inputs.self`
- **THEN** the path is `<self>/topology.yaml`, `<self>/modules/hosts/<host>/facter.json`, `<self>/bootstrap/...`, or `<self>/secrets/keys/iso-key.pub` and the file is found

#### Scenario: Relative paths into the repo root keep their target

- **WHEN** a module under `modules/` reaches the repo root by a relative path or symlink (the `networking/topology.yaml` link)
- **THEN** the path still resolves to the repo-root `topology.yaml`, with no hop into a parent of the repository

#### Scenario: Hubitat bundles are reachable by URL

- **WHEN** a driver under `hubitat/drivers/<driver>/` declares its `importUrl`
- **THEN** the URL is the raw GitHub URL of `hubitat/drivers/<driver>/<driver>.bundled.groovy` on the repository's default branch, with no `src/` segment

### Requirement: Infra-acting tooling is placed by lifecycle phase

Tooling that acts on infrastructure SHALL be placed by the lifecycle phase it serves.
Tooling that takes a target from bare metal or factory state to the point where its everyday tool can configure it SHALL live under `bootstrap/<target>/`, and each such directory SHALL name the tool it hands off to.
Tooling that configures a target already reachable by its everyday tool SHALL live in the tree of the tool doing the configuring, NOT the tree of the target being configured, and SHALL NOT live under `bootstrap/`.
Those trees are: Kubernetes manifests under `kubernetes/`, Nix under `modules/` and `packages/`, Hubitat drivers and apps under `hubitat/`, and everything manageable by OpenTofu under `tofu/`.

OpenTofu configuration SHALL appear only under `tofu/` for the configuration phase or `bootstrap/` for the bootstrap phase, and SHALL NOT appear in any other tree.
A target that OpenTofu configures — the MikroTik relays and Authentik among them — is therefore declared under `tofu/` even where a tree named for that target exists elsewhere.

This requirement governs only tooling that is a target's normal management path.
Trees that hold none — `docs/`, `assets/`, `mikrotik/` (topology diagrams and reference documents), `plans/`, `scripts/` (one-off migrations and operator checks), `skills/`, `claude-project/`, `src/`, `secrets/`, `openspec/`, `vendor/` — are outside its scope and are governed by their own requirements or by none.
A tool that becomes a target's normal management path SHALL move into that target's configuring tool tree rather than remaining an ad-hoc script.

Because a purpose rule is weaker to verify than a path rule, the permitted OpenTofu root modules SHALL be enumerated rather than inferred: exactly one per phase, `tofu/` for the configuration phase and `bootstrap/` for the bootstrap phase.
A phase SHALL NOT hold more than one root module, so that `import`, `moved` and `backend` blocks — which OpenTofu permits only in a root module — are declared once per phase.

#### Scenario: A bootstrap target declares what it hands off to

- **WHEN** a directory under `bootstrap/` is inspected
- **THEN** it covers getting one target to a configurable state, and the tool that takes over from it is named

#### Scenario: Configuration-phase work is not placed under bootstrap

- **WHEN** tooling that configures an already-reachable target is placed
- **THEN** it lives in that tool's own tree, and `bootstrap/` contains no configuration-phase tooling for that target

#### Scenario: Each phase has at most one OpenTofu root module

- **WHEN** the repository is searched for OpenTofu root modules
- **THEN** at most one is found per phase — one for the configuration phase and one for the bootstrap phase — and no other directory contains root-only constructs

#### Scenario: A target configured by OpenTofu keeps no OpenTofu of its own

- **WHEN** a target that OpenTofu configures also has a tree named for it, such as `mikrotik/`
- **THEN** that tree contains no OpenTofu, and the target's configuration is declared under `tofu/`

#### Scenario: Bootstrap tooling takes whatever form fits its target

- **WHEN** a bootstrap-phase target is automated
- **THEN** the form follows the target — a script or justfile where first-boot predates any API, OpenTofu only where the target exposes one — and reaching for OpenTofu does not require expressing imperative first-boot steps as provisioners

#### Scenario: Trees without a lifecycle phase are unaffected

- **WHEN** a tree that does not act on infrastructure is placed or moved
- **THEN** this requirement imposes no constraint on it

### Requirement: Python package is the sole occupant of `src/`

The repository SHALL keep the `homelab` Python package at `src/homelab/` and SHALL NOT place any non-Python tree under `src/`.

#### Scenario: uv build still finds the package

- **WHEN** `uv sync` or `uv run homelab --help` is run
- **THEN** the package resolves from `src/homelab` with no change to `pyproject.toml`

#### Scenario: src contains only the package

- **WHEN** the tree under `src/` is listed after the change
- **THEN** it contains `homelab/` and nothing else

### Requirement: OpenTofu lives under `tofu/`

The repository SHALL keep the configuration-phase OpenTofu root module, its child modules, its justfile modules, and their `secrets` and `topology.yaml` symlinks under `tofu/`.
The symlinks SHALL resolve to the repo-root `secrets/` directory and `topology.yaml` file.
Provider caches SHALL live alongside the root module in `tofu/`.
State SHALL NOT, and is governed by the `tofu-state` capability instead; the local state files that remain in `tofu/` are retained rollback copies, not the authoritative state.
A bootstrap-phase root module is permitted outside `tofu/` as governed by the lifecycle-phase requirement, and this requirement does not constrain it.

#### Scenario: Plan is a no-op after the move

- **WHEN** `tofu plan` is run inside `tofu/` immediately after the move
- **THEN** it reports no changes, and every `sops_file` data source resolves its `${path.root}/secrets/...` and `${path.root}/topology.yaml` input

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

Path patterns in repo-root tooling (`.sops.yaml` creation rules, `.gitignore` negations, `.envrc` watch paths, `.zed/settings.json` schema globs, pre-commit hook `files`/`excludes` regexes, and the `paths:` frontmatter globs in `rules/*.md`) SHALL match paths under `kubernetes/` and `modules/` and SHALL NOT reference `src/kubernetes` or `src/modules`.

#### Scenario: sops picks the cluster recipient rule

- **WHEN** a file matching `kubernetes/clusters/<dc-domain>/**/*.sops.yaml` is encrypted
- **THEN** the creation rule for that cluster's Flux age key applies, and existing encrypted files decrypt without being re-encrypted

#### Scenario: Pre-commit schema check still targets manifests

- **WHEN** the `check-k8s-schemas` hook runs on all files
- **THEN** it validates YAML under `kubernetes/` and still skips `blueprints/`, `resources/`, `patch-*`, `*.sops.yaml`, and the Home Assistant config directory

#### Scenario: Editor schema mapping applies

- **WHEN** a file such as `kubernetes/apps/<ns>/<app>/app/helm-release.yaml` is opened in Zed
- **THEN** the matching home-operations JSON schema is associated with it

#### Scenario: Agent rule globs match the module tree

- **WHEN** a file under `modules/ai-tools/` is edited in an agent session
- **THEN** the `paths:` glob in `rules/ai-tools.md` (`modules/ai-tools/**`) matches it and the rule applies
