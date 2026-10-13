## MODIFIED Requirements

### Requirement: Infra-acting tooling is placed by lifecycle phase

Tooling that acts on infrastructure SHALL be placed by the lifecycle phase it serves.
Tooling that takes a target from bare metal or factory state to the point where its everyday tool can configure it SHALL live under `bootstrap/<target>/`, and each such directory SHALL name the tool it hands off to.
Tooling that configures a target already reachable by its everyday tool SHALL live in the tree of the tool doing the configuring, NOT the tree of the target being configured, and SHALL NOT live under `bootstrap/`.
Those trees are: Kubernetes manifests under `kubernetes/`, Nix under `modules/` and `packages/`, Hubitat drivers and apps under `hubitat/`, and everything manageable by OpenTofu under `tofu/`.

OpenTofu configuration SHALL appear only under `tofu/` for the configuration phase or `bootstrap/` for the bootstrap phase, and SHALL NOT appear in any other tree.
A target that OpenTofu configures — the MikroTik relays and Authentik among them — is therefore declared under `tofu/` even where a tree named for that target exists elsewhere.

Data a tool reads SHALL be placed by the same rule as the tool: it SHALL live in the tree of the phase that consumes it rather than in a tree of its own.
No repository-root tree SHALL exist solely to hold material vendored for one phase's use.

This requirement governs only tooling that is a target's normal management path.
Trees that hold none — `docs/`, `assets/`, `mikrotik/` (topology diagrams and reference documents), `plans/`, `scripts/` (one-off migrations and operator checks), `skills/`, `claude-project/`, `src/`, `secrets/`, `openspec/` — are outside its scope and are governed by their own requirements or by none.
A tool that becomes a target's normal management path SHALL move into that target's configuring tool tree rather than remaining an ad-hoc script.

Because a purpose rule is weaker to verify than a path rule, the permitted OpenTofu root modules SHALL be enumerated rather than inferred: exactly one per phase, `tofu/` for the configuration phase and `bootstrap/` for the bootstrap phase.
A phase SHALL NOT hold more than one root module, so that `import`, `moved` and `backend` blocks — which OpenTofu permits only in a root module — are declared once per phase.

#### Scenario: A bootstrap target declares what it hands off to

- **WHEN** a directory under `bootstrap/` is inspected
- **THEN** it covers getting one target to a configurable state, and the tool that takes over from it is named

#### Scenario: Configuration-phase work is not placed under bootstrap

- **WHEN** tooling that configures an already-reachable target is placed
- **THEN** it lives in that tool's own tree, and `bootstrap/` contains no configuration-phase tooling for that target

#### Scenario: Bootstrap-phase work is not placed in a configuring tree

- **WHEN** a tree that exists to configure already-reachable targets is inspected for bootstrap-phase tooling
- **THEN** it contains none, and `modules/services/kubernetes/justfile` does not exist

#### Scenario: Vendored data sits with the phase that reads it

- **WHEN** the repository root is listed
- **THEN** no tree exists whose only purpose is holding material vendored for one phase, and `vendor/` is absent

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
