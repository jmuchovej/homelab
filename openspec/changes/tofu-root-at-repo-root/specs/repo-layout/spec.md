## MODIFIED Requirements

### Requirement: Tool trees live at the repository root

The repository SHALL place each tool-specific tree directly under the repository root: Nix modules under `modules/`, Flux manifests under `kubernetes/`, OpenTofu child modules under `tofu/` (the OpenTofu root module is the repository root itself), MikroTik bootstrap material under `mikrotik/`, cluster seed manifests under `bootstrap/`, and the shared network topology at `topology.yaml`.
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

#### Scenario: Hubitat bundles are reachable by URL

- **WHEN** a driver under `hubitat/drivers/<driver>/` declares its `importUrl`
- **THEN** the URL is the raw GitHub URL of `hubitat/drivers/<driver>/<driver>.bundled.groovy` on the repository's default branch, with no `src/` segment

## REMOVED Requirements

### Requirement: OpenTofu lives under `tofu/`

**Reason**: The root module moves to the repository root so `tofu` runs there without `cd` or `-chdir`.
The requirement's premise (root module, state, and symlinks all inside `tofu/`) no longer holds.

**Migration**: Replaced by "OpenTofu root module is the repository root" below.
State does not move; the new root selects it through an explicit local backend path.
The `secrets` and `topology.yaml` symlinks under `tofu/` remain for the justfile modules.

## ADDED Requirements

### Requirement: OpenTofu root module is the repository root

The repository root SHALL be the OpenTofu root module.
OpenTofu source files at the repository root SHALL be limited to `main.tofu`, `holonet.tofu`, and one `<site>.tofu` per datacenter site (`da.tofu`, `en.tofu`, and later sites by the same rule).
Every other OpenTofu source file SHALL live under `tofu/` inside a child module directory.
`provider` blocks SHALL appear only in `main.tofu`.
`import` and `moved` blocks SHALL be deleted once every address they target is present in state.
Local state and its backups SHALL live under `tofu/`, selected by an explicit local backend path.
The provider lock file SHALL live at the repository root.
The `tofu/secrets` and `tofu/topology.yaml` symlinks SHALL resolve to the repo-root `secrets/` directory and `topology.yaml` file.

#### Scenario: Bare tofu runs from the repository root

- **WHEN** `tofu init` followed by `tofu plan` is run at the repository root with no `-chdir` and no `cd`
- **THEN** initialisation succeeds against the state under `tofu/`, and the plan reports no changes

#### Scenario: Root file set is bounded

- **WHEN** the repository root is listed for `*.tofu` files
- **THEN** the result is exactly `main.tofu`, `holonet.tofu`, and one `<site>.tofu` per site, and `tofu/` contains no `*.tofu` file outside a child module directory

#### Scenario: Provider configuration has one home

- **WHEN** `holonet.tofu` and every `<site>.tofu` are searched for `provider` blocks
- **THEN** there are zero matches, and every provider alias referenced by a module instance or resource in those files is declared in `main.tofu`

#### Scenario: Secrets and topology resolve without symlinks

- **WHEN** a `sops_file` data source or a `file()` call, in the root module or in a child module, references `${path.root}/secrets/...` or `${path.root}/topology.yaml`
- **THEN** it resolves to the real repo-root file, not through the `tofu/` symlinks

#### Scenario: Site files hold site instances

- **WHEN** a `<site>.tofu` file is read
- **THEN** every module instance and resource in it is bound to that site's provider aliases or names that site in its identity, and no instance for another site appears in it

#### Scenario: One-shot blocks do not accumulate

- **WHEN** every address targeted by an `import` or `moved` block is listed by `tofu state list`
- **THEN** that block is removed before the change is committed, and the next plan still reports no changes

#### Scenario: Authentik discovery file is optional to plan

- **WHEN** `tofu/authentik.auto.tfvars.json` is absent
- **THEN** `tofu plan` still succeeds, with Authentik permission codenames passed through unmapped
- **WHEN** `just authentik discover-all` has written `tofu/authentik.auto.tfvars.json`
- **THEN** the plan maps permission codenames through it exactly as before the move

#### Scenario: Justfile recipes reach secrets

- **WHEN** a `just authentik ...` or `just mikrotik ...` recipe reads a sops file
- **THEN** it resolves to a file under the repo-root `secrets/` directory

#### Scenario: Wrapped recipes carry the RouterOS-safe flags

- **WHEN** `just tofu-plan` or `just tofu-apply` is run at the repository root, with or without pass-through arguments
- **THEN** it runs `tofu plan` or `tofu apply` at the repository root with `-parallelism=1` and `-compact-warnings`, followed by the pass-through arguments
