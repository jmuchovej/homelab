## Purpose

Defines how each kind of infrastructure in the homelab is brought from nothing to the point where its normal management tool takes over: NixOS hosts until `deploy`/`nh` can reach them, MikroTik devices until OpenTofu can configure them, Kubernetes clusters until Flux syncs from the repository, and Talos guests until the host aspect can seed them.
Also fixes where that material lives and how it is reached.

## ADDED Requirements

### Requirement: Bootstrap material lives in one tree

All bootstrap material SHALL live under the repository-root `bootstrap/` directory, one subdirectory per target: `bootstrap/nix/` (NixOS installer image and host install), `bootstrap/kubernetes/` (cluster seed manifests and their build check), `bootstrap/mikrotik/` (RouterOS first-boot script and recipes), and `bootstrap/talos/` (Talos machine-config base).
No bootstrap material SHALL live under `modules/`, `mikrotik/`, or `src/`.
Each subdirectory SHALL be self-contained: it SHALL NOT contain symlinks into other parts of the repository, and SHALL reach repo-root files (`secrets/`, `topology.yaml`, `modules/hosts/<host>/`) by a path derived from its own location or from `inputs.self`.

#### Scenario: Every target has exactly one home

- **WHEN** the repository is searched for bootstrap recipes, the installer-ISO host definition, the RouterOS first-boot script, the cluster seed manifests, and the Talos machine config
- **THEN** each is found only under its `bootstrap/<target>/` directory, and `modules/hosts/bootstrap/`, `mikrotik/bootstrap/`, and `src/homelab/commands/_bootstrap.py` do not exist

#### Scenario: No symlinks inside the tree

- **WHEN** `bootstrap/` is listed recursively
- **THEN** it contains no symbolic links

### Requirement: Root just entry point

The root justfile SHALL expose a `bootstrap` module loaded from `bootstrap/justfile`, which SHALL expose `nix` and `mikrotik` submodules.
Recipes SHALL be invocable through the root justfile (`just bootstrap <target> <recipe> …`) and SHALL NOT invoke `just` recursively; multi-step flows SHALL be expressed as recipe dependencies.
The host hardware-report capture (`facter`) SHALL be a recipe of the `nix` submodule and SHALL NOT exist in the root justfile.

#### Scenario: Modules list

- **WHEN** `just --list bootstrap`, `just --list bootstrap nix`, and `just --list bootstrap mikrotik` are run at the repository root
- **THEN** each succeeds, `nix` lists `test`, `make`, `sync`, `install-ventoy`, `facter`, and `install`, and `mikrotik` lists `render`, `upload`, `install-ssh-key`, `reset`, `wait`, and `run`

#### Scenario: Root facter is gone

- **WHEN** `just --list` is run at the repository root
- **THEN** no `facter` recipe is listed at the root, and `just --list mikrotik` still lists the OpenTofu REST helpers

### Requirement: Flake discovery of bootstrap Nix

The flake SHALL auto-discover flake modules from `bootstrap/nix/` in addition to `modules/`.
Nothing else under `bootstrap/` SHALL be auto-discovered; Nix consumers of `bootstrap/kubernetes/` and `bootstrap/talos/` SHALL reference those files by path through `inputs.self`.

#### Scenario: Installer host is discovered from the bootstrap tree

- **WHEN** the flake is evaluated with `modules/hosts/bootstrap/` absent
- **THEN** `nixosConfigurations.bootstrap` exists and its ISO image derivation evaluates

#### Scenario: Seed data stays inert

- **WHEN** a `.nix` file under `bootstrap/kubernetes/` or `bootstrap/talos/` is added or changed
- **THEN** it is not imported as a flake module; it affects evaluation only through the aspects that import it by path

### Requirement: NixOS installer image

The repository SHALL build a bootable NixOS installer image for `x86_64-linux` that accepts SSH as `root` and `lab` using the `iso-key` public key tracked at `secrets/keys/iso-key.pub`, keeps `root`'s shell POSIX-compatible so `nixos-anywhere` can copy a closure into it, prints a banner naming the host-install command, and offers the rescue helpers for the repository's impermanence layout.
A recipe SHALL build it (locally or on a named remote builder) and another SHALL copy it onto a mounted Ventoy data partition under a stable filename.

#### Scenario: Image builds from a clean checkout

- **WHEN** `just bootstrap nix test` is run on a fresh clone with no untracked files
- **THEN** the ISO image derivation path is printed and no "file not found" error is raised for the iso-key public key

#### Scenario: Banner names the real command

- **WHEN** the installer image boots and a shell is opened
- **THEN** the banner's install instruction is `just bootstrap nix install <name> <addr>` and the command it names exists

#### Scenario: Private key is never tracked

- **WHEN** the version-control ignore rules are evaluated for `secrets/keys/iso-key` and `secrets/keys/iso-key.pub`
- **THEN** the private key is ignored and the public key is tracked

### Requirement: NixOS host install

A recipe SHALL install a named host onto a target reachable as `root@<addr>` (booted from the installer image or any Linux `nixos-anywhere` can kexec).
It SHALL refuse a host name that has no `modules/hosts/<name>/<name>.nix`; refuse to proceed without an interactive confirmation unless a `--yes`-style flag is given; stage the host's ed25519 SSH host key, decrypted from `secrets/hosts/<name>.sops.yaml`, as `/etc/ssh/ssh_host_ed25519_key` and `.pub` on the target so sops-nix derives the host's age identity on first boot; merge any committed `modules/hosts/<name>/root/` tree into the same staging area; write the hardware report to `modules/hosts/<name>/facter.json`; authenticate with the iso-key private key taken from an explicit path or a default location; and wait for the installed host to answer on SSH before reporting success.
The recipe SHALL NOT depend on the Python CLI.

#### Scenario: Unknown host is refused

- **WHEN** `just bootstrap nix install nope 10.0.0.9` is run
- **THEN** it exits non-zero naming the missing `modules/hosts/nope/nope.nix` before contacting the target

#### Scenario: Host key is staged in OpenSSH format

- **WHEN** the staging directory is inspected just before `nixos-anywhere` runs
- **THEN** `etc/ssh/ssh_host_ed25519_key` is mode 0600 in OpenSSH private-key format, its `.pub` matches it, and both derive from the `host-key` value in the host's sops file

#### Scenario: Install completes

- **WHEN** the recipe is run with confirmation for an existing host against a booted installer
- **THEN** `nixos-anywhere` runs with `--flake .#<name>`, `--generate-hardware-config nixos-facter modules/hosts/<name>/facter.json`, and the staged `--extra-files`, the recipe returns only after the host answers on port 22, and `facter.json` is written

#### Scenario: Hardware report capture

- **WHEN** `just bootstrap nix facter <host> [ssh-target]` is run for an installed host
- **THEN** a valid JSON report is written to `modules/hosts/<host>/facter.json`, and an empty or invalid report leaves the existing file untouched

### Requirement: MikroTik device reaches tofu-manageable state

The MikroTik recipes SHALL take a device at its factory address to a state OpenTofu can manage: the rendered first-boot script SHALL set the identity, management VLAN address, role-specific L3 setup, the `terraform` user with the password OpenTofu uses, the admin SSH key, the holonet TLS certificate, and SSL-only REST.
Role and trunk ports SHALL come from `topology.yaml`; the root and terraform passwords and the optional SSH host key SHALL come from `secrets/hosts/<dc>-<relay>.sops.yaml` and from no other file.
The admin public key SHALL come from an operator-supplied path with a documented default.
The `wait` step SHALL succeed only when the device answers the REST API over validated TLS at its management address as the `terraform` user with that same password.

#### Scenario: Render reads one secret source

- **WHEN** `just bootstrap mikrotik render <dc> <relay>` runs
- **THEN** the rendered script is written with mode 0600, contains no unexpanded `${…}` placeholders, and the only sops file read is `secrets/hosts/<dc>-<relay>.sops.yaml`

#### Scenario: Wait uses the same password as render

- **WHEN** `just bootstrap mikrotik wait <dc> <relay>` polls the device
- **THEN** the credential it presents is the `tofu-password` from `secrets/hosts/<dc>-<relay>.sops.yaml`, and `secrets/<dc>.sops.yaml` is not read

#### Scenario: Full chain

- **WHEN** `just bootstrap mikrotik run <dc> <relay> [ip]` is run against a factory-reset device
- **THEN** render, upload, admin-key install, reset, and wait execute in that order as recipe dependencies, and success means `tofu plan` can authenticate to the device

#### Scenario: Missing topology role is an error

- **WHEN** `topology.yaml` has no `router` or `switch` role for `<dc>-<relay>`
- **THEN** `render` exits non-zero naming the key, and nothing is uploaded

### Requirement: Kubernetes cluster seeds from NixOS until Flux syncs

Deploying a NixOS host that includes the Kubernetes server aspect SHALL yield a cluster that, without any manual step, installs the CNI, installs the Flux operator, applies a FluxInstance whose sync source is this repository at `kubernetes/clusters/<dc-domain>/flux`, and holds the cluster's sops age key in the `flux-system/sops-age` Secret.
The seed manifests SHALL be read by path from `bootstrap/kubernetes/`, SHALL validate against their vendored schemas as part of the host's system build, and SHALL be the single source for any NixOS aspect that seeds a cluster, whether the cluster runs on the host (k3s) or in a guest the host provisions (Talos).

#### Scenario: Fresh server reaches GitOps

- **WHEN** a server host is deployed from a clean checkout
- **THEN** the FluxInstance becomes Ready, the `flux-system` GitRepository fetches an artifact from the repository's default branch, and the root Kustomization reconciles `kubernetes/clusters/<dc-domain>/flux`

#### Scenario: Invalid seed manifest fails the build

- **WHEN** a seed manifest under `bootstrap/kubernetes/` violates its schema, or the Cilium chart pin disagrees with the vendored values schema
- **THEN** the server host's system build fails with the kubeconform or schema-version message, before anything is deployed

#### Scenario: Seed tree is shared by consumers

- **WHEN** the Kubernetes server aspect and the Talos guest aspect are inspected for where they obtain seed manifests
- **THEN** both reference `inputs.self + "/bootstrap/…"` and neither carries a private copy of a seed manifest

### Requirement: Talos machine-config base

The non-secret half of a Talos control-plane machine config SHALL live at `bootstrap/talos/machineconfig.yaml` with `@marker@` placeholders for cluster identity, endpoint, and hostname.
The Talos guest aspect SHALL render it by path, merge the cluster PKI from sops at activation (never into the Nix store), and validate the merged result as part of the host's system build.
The Talos image pin in that file SHALL be the value `just k8s update-schemas` reads to choose the vendored schema version.

#### Scenario: Rendered base validates

- **WHEN** a host including a Talos guest aspect is built
- **THEN** the build runs `talosctl validate` on the base merged with throwaway secrets and fails if the config is invalid

#### Scenario: Schema pin follows the image pin

- **WHEN** `just k8s update-schemas` runs
- **THEN** the Talos schema it vendors matches the minor version of `machine.install.image` in `bootstrap/talos/machineconfig.yaml`
