## MODIFIED Requirements

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
