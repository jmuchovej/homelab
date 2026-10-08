## ADDED Requirements

### Requirement: Infra-acting tooling is placed by lifecycle phase

Tooling that acts on infrastructure SHALL be placed by the lifecycle phase it serves.
Tooling that takes a target from bare metal or factory state to the point where its everyday tool can configure it SHALL live under `bootstrap/<target>/`, and each such directory SHALL name the tool it hands off to.
Tooling that configures a target already reachable by its everyday tool SHALL live in the tree of the tool doing the configuring, NOT the tree of the target being configured, and SHALL NOT live under `bootstrap/`.
Those trees are: Kubernetes manifests under `kubernetes/`, Nix under `modules/` and `packages/`, Hubitat drivers and apps under `hubitat/`, and everything manageable by OpenTofu under `tofu/`.

OpenTofu configuration SHALL appear only under `tofu/` for the configuration phase or `bootstrap/` for the bootstrap phase, and SHALL NOT appear in any other tree.
A target that OpenTofu configures — the MikroTik relays and Authentik among them — is therefore declared under `tofu/` even where a tree named for that target exists elsewhere.

This requirement governs only tooling that acts on infrastructure.
Trees that hold no tooling — `docs/`, `assets/`, `mikrotik/` (topology diagrams and reference documents), `src/`, `secrets/`, `openspec/`, `vendor/` — are outside its scope and are governed by their own requirements or by none.

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

## MODIFIED Requirements

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
