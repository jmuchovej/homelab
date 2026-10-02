## MODIFIED Requirements

### Requirement: Tool trees live at the repository root

The repository SHALL place each tool-specific tree directly under the repository root: Nix modules under `modules/`, Flux manifests under `kubernetes/`, OpenTofu under `tofu/`, MikroTik bootstrap material under `mikrotik/`, container image sources under `containers/`, cluster seed manifests under `bootstrap/`, and the shared network topology at `topology.yaml`.
No tool-facing path SHALL carry a `src/` prefix.

#### Scenario: Flake discovers modules from the root

- **WHEN** the flake is evaluated
- **THEN** it imports its module tree from `./modules` and every host, home, and dev shell output evaluates identically to before the move

#### Scenario: Root justfile modules resolve

- **WHEN** `just --list` is run at the repository root
- **THEN** the `bootstrap`, `mikrotik`, and `authentik` modules load from `modules/hosts/bootstrap/justfile`, `tofu/mikrotik.just`, and `tofu/authentik.just` without error

#### Scenario: Nix reads repo data files from root-relative paths

- **WHEN** a module resolves `topology.yaml`, a host's `facter.json`, or a `bootstrap/` seed file through `inputs.self`
- **THEN** the path is `<self>/topology.yaml`, `<self>/modules/hosts/<host>/facter.json`, or `<self>/bootstrap/...` and the file is found

#### Scenario: Relative paths into the repo root keep their target

- **WHEN** a module under `modules/` reaches the repo root by a relative path or symlink (the `bootstrap` host's `secrets/keys/iso-key.pub`, the `networking/topology.yaml` link)
- **THEN** the path still resolves to the repo-root `secrets/` directory or `topology.yaml`, with no hop into a parent of the repository

#### Scenario: Container sources live in their own root tree

- **WHEN** an image is built for a cluster workload that has no upstream-published image
- **THEN** its build context is a directory under `containers/<image-name>/` at the repository root, and it is not nested inside `kubernetes/`, `modules/`, or `packages/`

## ADDED Requirements

### Requirement: Container images are built from the repository and consumed by digest

Each directory under `containers/` SHALL be a self-contained image build context whose name matches the published image name.
Images SHALL be published to a registry and referenced from Kubernetes manifests by an immutable tag-plus-digest pair, never by a floating tag alone.

#### Scenario: Build context is self-contained

- **WHEN** an image under `containers/<name>/` is built
- **THEN** the build succeeds with `containers/<name>/` as its context and requires no file from elsewhere in the repository

#### Scenario: Workloads pin a digest

- **WHEN** a manifest references an image built from `containers/`
- **THEN** the reference carries both a version tag and a digest, matching the pinning convention used for third-party images in the same tree
