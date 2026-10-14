## ADDED Requirements

### Requirement: Vendored schemas live beside the manifests they validate

Every JSON schema the repository vendors for bootstrap material SHALL live under the `bootstrap/<target>/schemas/` directory of the target whose files it validates, and no repository-root tree SHALL exist to hold vendored schemas.
Each such directory SHALL carry a `SOURCES.json` recording, per schema file, the upstream URL it was fetched from and the upstream version that URL pins where the schema is versioned.

Each target SHALL refresh its own schemas through a recipe of its own `bootstrap/` submodule, and that recipe SHALL read only files within its own target directory.
No target's refresh recipe SHALL read another target's files to decide what to fetch.

Manifests SHALL reference their schema by a path relative to the manifest, and the build check SHALL read the same files, so that an editor and the build validate against identical schemas.
Vendoring SHALL remain the mechanism rather than fetching at build time, because the build sandbox has no network.

#### Scenario: Schemas are reachable from the manifest without leaving the tree

- **WHEN** a bootstrap manifest's schema modeline is resolved relative to that manifest
- **THEN** it names a file under the same `bootstrap/<target>/schemas/` directory, and no modeline resolves outside `bootstrap/<target>/`

#### Scenario: No repository-root schema tree remains

- **WHEN** the repository is searched for vendored schema files
- **THEN** every one is found under a `bootstrap/<target>/schemas/` directory, and `vendor/` does not exist

#### Scenario: Each target refreshes only its own schemas

- **WHEN** a target's schema-refresh recipe runs
- **THEN** it writes only into its own `bootstrap/<target>/schemas/`, and it reads no file belonging to another target to choose a version

### Requirement: Kubernetes schema pin follows the shipped k3s version

The Kubernetes API schemas vendored for the seed manifests SHALL be those of the Kubernetes version the clusters actually run, taken from the version of the k3s package the Kubernetes server aspect deploys.
The repository SHALL expose that version so the refresh recipe can read it without evaluating a named host, so that no host is privileged as the one the schema pin is derived from.

The host's system build SHALL fail when the vendored Kubernetes schema version disagrees with the deployed k3s version, naming the recipe that resolves it.
This is the same ratchet the Cilium values schema already has against the Cilium chart pin.

#### Scenario: Schema pin follows a k3s bump

- **WHEN** the k3s version the Kubernetes server aspect deploys changes and the vendored schemas are not refreshed
- **THEN** the server host's system build fails naming the schema-refresh recipe, before anything is deployed

#### Scenario: Pin is derived without naming a host

- **WHEN** the schema-refresh recipe determines which Kubernetes schema version to fetch
- **THEN** it obtains the k3s version from a repository-level output, and no host name appears in how that version is resolved

## MODIFIED Requirements

### Requirement: Bootstrap material lives in one tree

All bootstrap material SHALL live under the repository-root `bootstrap/` directory, one subdirectory per target: `bootstrap/nix/` (NixOS installer image and host install), `bootstrap/kubernetes/` (cluster seed manifests, their vendored schemas, and their build check), `bootstrap/mikrotik/` (RouterOS first-boot script and recipes), and `bootstrap/talos/` (Talos machine-config base and its vendored schema).
No bootstrap material SHALL live under `modules/`, `mikrotik/`, or `src/`.
Each subdirectory SHALL be self-contained: it SHALL NOT contain symlinks into other parts of the repository, and SHALL reach repo-root files (`secrets/`, `topology.yaml`, `modules/hosts/<host>/`) by a path derived from its own location or from `inputs.self`.
A subdirectory SHALL NOT read another `bootstrap/` subdirectory's files.

#### Scenario: Every target has exactly one home

- **WHEN** the repository is searched for bootstrap recipes, the installer-ISO host definition, the RouterOS first-boot script, the cluster seed manifests, and the Talos machine config
- **THEN** each is found only under its `bootstrap/<target>/` directory, and `modules/hosts/bootstrap/`, `mikrotik/bootstrap/`, and `src/homelab/commands/_bootstrap.py` do not exist

#### Scenario: No symlinks inside the tree

- **WHEN** `bootstrap/` is listed recursively
- **THEN** it contains no symbolic links

#### Scenario: No subdirectory reaches into another

- **WHEN** a `bootstrap/<target>/` directory is inspected for the paths it reads
- **THEN** every path is within its own directory or is a repo-root file, and none names a sibling target

### Requirement: Root just entry point

The root justfile SHALL expose a `bootstrap` module loaded from `bootstrap/justfile`, which SHALL expose `nix`, `mikrotik`, `k8s`, and `talos` submodules.
Recipes SHALL be invocable through the root justfile (`just bootstrap <target> <recipe> …`) and SHALL NOT invoke `just` recursively; multi-step flows SHALL be expressed as recipe dependencies.
The host hardware-report capture (`facter`) SHALL be a recipe of the `nix` submodule and SHALL NOT exist in the root justfile.
No bootstrap-phase recipe SHALL be reachable through a module loaded from a configuration-phase tree.

#### Scenario: Modules list

- **WHEN** `just --list bootstrap`, `just --list bootstrap nix`, and `just --list bootstrap mikrotik` are run at the repository root
- **THEN** each succeeds, `nix` lists `test`, `make`, `sync`, `install-ventoy`, `facter`, and `install`, and `mikrotik` lists `render`, `upload`, `install-ssh-key`, `reset`, `wait`, and `run`

#### Scenario: Schema refresh is reachable per target

- **WHEN** `just --list bootstrap k8s` and `just --list bootstrap talos` are run at the repository root
- **THEN** each succeeds and lists an `update-schemas` recipe

#### Scenario: Root facter is gone

- **WHEN** `just --list` is run at the repository root
- **THEN** no `facter` recipe is listed at the root, and `just --list mikrotik` still lists the OpenTofu REST helpers

### Requirement: Kubernetes cluster seeds from NixOS until Flux syncs

Deploying a NixOS host that includes the Kubernetes server aspect SHALL yield a cluster that, without any manual step, installs the CNI, installs the Flux operator, applies a FluxInstance whose sync source is this repository at `kubernetes/clusters/<dc-domain>/flux`, and holds the cluster's sops age key in the `flux-system/sops-age` Secret.
The seed manifests SHALL be read by path from `bootstrap/kubernetes/`, SHALL validate against the schemas vendored alongside them in `bootstrap/kubernetes/schemas/` as part of the host's system build, and SHALL be the single source for any NixOS aspect that seeds a cluster, whether the cluster runs on the host (k3s) or in a guest the host provisions (Talos).

#### Scenario: Fresh server reaches GitOps

- **WHEN** a server host is deployed from a clean checkout
- **THEN** the FluxInstance becomes Ready, the `flux-system` GitRepository fetches an artifact from the repository's default branch, and the root Kustomization reconciles `kubernetes/clusters/<dc-domain>/flux`

#### Scenario: Invalid seed manifest fails the build

- **WHEN** a seed manifest under `bootstrap/kubernetes/` violates its schema, or the Cilium chart pin disagrees with the vendored values schema, or the deployed k3s version disagrees with the vendored Kubernetes schema version
- **THEN** the server host's system build fails with the kubeconform or schema-version message, before anything is deployed

#### Scenario: Seed tree is shared by consumers

- **WHEN** the Kubernetes server aspect and the Talos guest aspect are inspected for where they obtain seed manifests
- **THEN** both reference `inputs.self + "/bootstrap/…"` and neither carries a private copy of a seed manifest

### Requirement: Talos machine-config base

The non-secret half of a Talos control-plane machine config SHALL live at `bootstrap/talos/machineconfig.yaml` with `@marker@` placeholders for cluster identity, endpoint, and hostname.
The Talos guest aspect SHALL render it by path, merge the cluster PKI from sops at activation (never into the Nix store), and validate the merged result as part of the host's system build.
The Talos image pin in that file SHALL be the value the `talos` submodule's `update-schemas` recipe reads to choose the vendored schema version, and SHALL be read by no other target's recipe.

#### Scenario: Rendered base validates

- **WHEN** a host including a Talos guest aspect is built
- **THEN** the build runs `talosctl validate` on the base merged with throwaway secrets and fails if the config is invalid

#### Scenario: Schema pin follows the image pin

- **WHEN** `just bootstrap talos update-schemas` runs
- **THEN** the Talos schema it vendors into `bootstrap/talos/schemas/` matches the minor version of `machine.install.image` in `bootstrap/talos/machineconfig.yaml`
