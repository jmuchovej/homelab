## MODIFIED Requirements

### Requirement: Bootstrap material lives in one tree

All bootstrap material SHALL live under the repository-root `bootstrap/` directory, one subdirectory per target: `bootstrap/nix/` (NixOS installer image and host install), `bootstrap/kubernetes/` (cluster seed manifests, their vendored schemas, and their build check), `bootstrap/mikrotik/` (RouterOS first-boot script and recipes), and `bootstrap/talos/` (Talos machine-config base and its vendored schema).
No bootstrap material SHALL live under `modules/`, `mikrotik/`, or `src/`.
Each subdirectory SHALL be self-contained: it SHALL NOT contain symlinks into other parts of the repository, and SHALL reach repo-root files (`secrets/`, `topology.toml`, `modules/hosts/<host>/`) by a path derived from its own location or from `inputs.self`.
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

### Requirement: MikroTik device reaches tofu-manageable state

The MikroTik recipes SHALL take a device at its factory address to a state OpenTofu can manage: the rendered first-boot script SHALL set the identity, management VLAN address, role-specific L3 setup, the `terraform` user with the password OpenTofu uses, the admin SSH key, the holonet TLS certificate, and SSL-only REST.
Role and trunk ports SHALL come from `topology.toml`; the root and terraform passwords and the optional SSH host key SHALL come from `secrets/hosts/<dc>-<relay>.sops.yaml` and from no other file.
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

- **WHEN** `topology.toml` has no `router` or `switch` role for `<dc>-<relay>`
- **THEN** `render` exits non-zero naming the key, and nothing is uploaded

#### Scenario: Trunk ports are read from the TOML topology

- **WHEN** `just bootstrap mikrotik render <dc> <relay>` runs for a relay whose `topology.toml` entry lists `trunks`
- **THEN** the rendered script's trunk ports are exactly those entries, in order, and a relay with no `trunks` renders with none
