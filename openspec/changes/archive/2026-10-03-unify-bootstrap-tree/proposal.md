## Why

Bootstrapping is sharded across four places that disagree with each other: the installer-ISO host and its recipes in `modules/hosts/bootstrap/`, the MikroTik first-boot script and recipes in `mikrotik/bootstrap/` (wired into nothing; the root `just mikrotik` module is the tofu REST helpers), the `nixos-anywhere` driver in `src/homelab/commands/_bootstrap.py` (still pointing at the pre-flatten `src/modules/hosts` path), and a half-made `bootstrap/` tree in the working copy that mixes the only live copies of the Kubernetes seed manifests and Talos machine config with stale duplicates of the ISO and MikroTik material.
Committed `main` references `bootstrap/kubernetes/` and `bootstrap/talos/` from Nix but does not contain them, so the two k3s server hosts cannot evaluate from a clean checkout, and the ISO cannot build because `secrets/keys/iso-key.pub` is untracked.
One tree, one root `just bootstrap` entry point, and every consumer reaching it by path fixes all of this at once.

## What Changes

- **New top-level `bootstrap/` tree, one subdirectory per target:**
  - `bootstrap/nix/`: the installer-ISO den host and aspect (moved from `modules/hosts/bootstrap/bootstrap.nix`) plus a justfile holding the ISO recipes (`test`, `make`, `sync`, `install-ventoy`), the `facter` recipe (moved from the root justfile), and a new `install` recipe that replaces the Python `nixos-anywhere` driver.
  - `bootstrap/kubernetes/`: the k3s seed manifests and `checks.nix`, unchanged in content, now tracked.
  - `bootstrap/mikrotik/`: the RouterOS first-boot script and its recipes (moved from `mikrotik/bootstrap/`), rewritten to locate `secrets/` and `topology.yaml` from the repo root instead of through symlinks, with no nested `just` invocations.
  - `bootstrap/talos/`: the Talos machine-config base, unchanged in content, now tracked.
    Kept as its own directory because `talos.nix` and `just k8s update-schemas` already read it.
  - `bootstrap/justfile` exposing `nix` and `mikrotik` as submodules; `bootstrap/AGENTS.md` (scoped `paths: bootstrap/**`) linked as `.agents/rules/bootstrap.md`.
- **BREAKING (workflow):** flake module discovery walks `./modules` and `./bootstrap/nix`.
  `modules/hosts/bootstrap/` is deleted.
  The `bootstrap` host and aspect keep their names, so `nixosConfigurations.bootstrap` and the `nix-builders` exclusion are unaffected.
- **BREAKING (workflow):** `homelab bootstrap` is removed from the Python CLI along with the `sopsy` dependency (`cryptography` stays; the CA commands use it).
  Installing a host becomes `just bootstrap nix install <host> <addr>`, a nushell recipe that stages the host's SSH key from sops with `ssh-keygen` and runs `nixos-anywhere` from the devshell.
  The ISO banner is corrected to name that command.
- **BREAKING (workflow):** root `just bootstrap …` now routes to `bootstrap/justfile`: ISO and install recipes under `just bootstrap nix …`, MikroTik first-boot under `just bootstrap mikrotik …` (the full chain is `run`, not `bootstrap`).
  Root `just mikrotik …` keeps meaning the tofu REST helpers.
  Root `just facter` is removed.
- `mikrotik/bootstrap/` (justfile, script, `secrets` and `topology.yaml` symlinks) is deleted; `mikrotik/` keeps only the topology diagrams and the two reference documents.
- The MikroTik `wait` step reads the `tofu-password` from the same per-device sops file as `render`, instead of a second copy under `secrets/<dc>.sops.yaml`, so the two can no longer disagree.
  The admin SSH public key is taken from an operator path (default `~/.ssh/id_ed25519.pub`, overridable) instead of an untracked, gitignored file beside the justfile.
- `secrets/keys/iso-key.pub` is tracked (the ISO build reads it); the private `secrets/keys/iso-key` gets an explicit ignore entry so it can never be tracked by accident.
- Comments and rules that cite moved paths are updated: `modules/inputs.nix` (outputs template and comment), `modules/services/kubernetes/AGENTS.md` (which directories import-tree walks), `modules/hosts/AGENTS.md` (the one host that lives outside `modules/hosts/`), `modules/devshell/shells.nix` (`gettext` comment), `tofu/mikrotik/users.tofu` (password-rotation comment).

## Capabilities

### New Capabilities

- `bootstrap`: what bootstrapping each target must achieve and how it is reached: building and syncing the NixOS installer image, installing a NixOS host with `nixos-anywhere` and capturing its hardware report, bringing a MikroTik device from factory state to a tofu-manageable state, seeding a Kubernetes cluster until Flux syncs from the upstream repository, and supplying the Talos machine-config base.
  Also the layout contract: one `bootstrap/<target>/` directory per target, one root `just bootstrap` entry point, Nix consumers reach seed data by path, and only `bootstrap/nix/` is auto-discovered as flake modules.

### Modified Capabilities

- `repo-layout`: the "Tool trees live at the repository root" requirement changes in three places: all bootstrap material lives under `bootstrap/` (the `mikrotik/` clause narrows to diagrams and reference docs), the flake imports its module tree from `./modules` and `./bootstrap/nix`, and the root `bootstrap` just module loads from `bootstrap/justfile`.
  The scenario about relative paths into the repo root drops the `bootstrap` host example, since that file now reads `secrets/keys/iso-key.pub` through `inputs.self`.
  The in-flight `tofu-root-at-repo-root` change modifies the same requirement (its OpenTofu clause); whichever archives second must merge the other's wording.

## Impact

- **Nix evaluation**: `nixosConfigurations.bootstrap` evaluates from `bootstrap/nix/iso.nix`; `da-vcx-1` and `en-t65-1` evaluate from a clean checkout once `bootstrap/kubernetes/` is tracked.
  `flake.nix` is regenerated by `nix run .#write-flake` after the `flake-file.outputs` template changes.
  No host other than `bootstrap` changes its closure.
- **Just surface**: `just bootstrap nix {test,make,sync,install-ventoy,facter,install}`, `just bootstrap mikrotik {render,upload,install-ssh-key,reset,wait,run}`.
  `just k8s update-schemas` keeps reading `bootstrap/kubernetes/cilium.yaml` and `bootstrap/talos/machineconfig.yaml` unchanged.
- **Python CLI**: `homelab` loses the `bootstrap` command; `pyproject.toml` drops `sopsy`; `uv.lock` is regenerated.
  `cryptography`, the CA commands, and the hubitat workspace member are untouched.
- **Devshell**: gains `nixos-anywhere` (pinned by nixpkgs, replacing `nix run github:nix-community/nixos-anywhere`).
  `gettext` stays for the MikroTik `envsubst` step.
- **Secrets**: no values change.
  One public key becomes tracked; `.gitignore` gains one line.
  The per-device sops files (`secrets/hosts/<dc>-<relay>.sops.yaml`) become the single source for MikroTik bootstrap passwords; the duplicate `terraform-password` under `secrets/<dc>.sops.yaml` is left in place but no longer read by bootstrap.
- **Live infrastructure**: nothing is deployed or re-bootstrapped.
  Routers, clusters, and hosts are untouched; the FluxInstance sync path and all seed manifest contents are byte-identical.
- **Not touched, flagged as stale**: `mikrotik/BOOTSTRAP-GUIDE.md` and `mikrotik/NETWORK-REFERENCE.md` describe a multi-script flow (`bootstrap-complete.rsc`, `01-vlan-restoration…`) that no longer exists; the `.sops.yaml` rule for `systems/x86_64-install-iso/minimal/` matches nothing; `src/homelab/tools/_misc.py` still scans a `systems/` directory that no longer exists; the docs site's CLI pages list commands that do not exist.
  None of these are changed here.
