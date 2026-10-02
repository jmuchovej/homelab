---
paths:
  - "bootstrap/**"
---

# bootstrap/ — from nothing to the normal management tool

Everything that takes a target from bare metal or factory state to the point where its everyday tool takes over lives here, one directory per target.
Nothing bootstrap-related lives under `modules/`, `mikrotik/`, or `src/`.

| Directory     | What it holds                                                                                | Hands off to                                   |
| ------------- | -------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| `nix/`        | installer-ISO host (`iso.nix`) and `justfile` (ISO build/sync, `facter`, `install`)          | `deploy` / `nh`                                |
| `kubernetes/` | k3s seed manifests and their build check (`checks.nix`), read by `<rbn/services/kubernetes>` | Flux                                           |
| `mikrotik/`   | RouterOS first-boot script (`rbn-bootstrap.rsc`) and `justfile`                              | OpenTofu                                       |
| `talos/`      | non-secret machine-config base, read by `<rbn/system/virtualization/talos>`                  | Flux inside the guest (consumer not yet built) |

Entry point is the root justfile: `just bootstrap nix <recipe>` and `just bootstrap mikrotik <recipe>`; `just --list bootstrap <target>` shows each set.
Every justfile here also works standalone (`just -f bootstrap/<target>/justfile …`).

## Flake discovery

`bootstrap/nix/` is the second `import-tree` root (with `modules/`; the template lives in `modules/inputs.nix`).
Every `.nix` file placed there is loaded as a flake module, so a helper that must not load on its own takes a `_` prefix, exactly as under `modules/`.
Nothing else under `bootstrap/` is auto-imported; aspects read `kubernetes/` and `talos/` by path through `inputs.self + "/bootstrap/…"`, which is why a `.nix` file in those directories (`checks.nix`) is inert data.

## Justfile conventions

- No symlinks into the repo.
  Each justfile derives `root := parent_directory(parent_directory(source_directory()))` and builds `secrets`, `topology`, and friends from it, which resolves identically through the root justfile and standalone.
- No recipe invokes `just` recursively; a nested call re-roots `justfile_directory()`.
  Multi-step flows (`mikrotik run`) are recipe dependencies.
- The ISO recipes keep `[no-cd]` because they address the flake as `.#` and read `result/`; everything else is cwd-independent.
- Mixed interpreters: the file-wide `script-interpreter` is bash for the carried-over ISO recipes; new recipes are nushell via `[script("nu")]`.

## nix/

- `install <host> <addr> [--yes]` wipes `root@<addr>` and installs `nixosConfigurations.<host>` with `nixos-anywhere`.
  It refuses a host without `modules/hosts/<host>/<host>.nix`, stages the host's ed25519 SSH host key from `secrets/hosts/<host>.sops.yaml` as `/etc/ssh/ssh_host_ed25519_key` (so sops-nix derives the host's age identity on first boot), merges any `modules/hosts/<host>/root/` tree, writes `facter.json`, and waits for port 22.
- The stored host keys are OpenSSH format; a PKCS#8 one is converted in place with `ssh-keygen -p`.
  That needs an OpenSSL-linked `ssh-keygen`: Apple's rejects PKCS#8 with "invalid format", so `openssh` and `nixos-anywhere` come from the devshell.
- The iso-key private half is read from `RBN_ISO_KEY`, default `secrets/keys/iso-key`, which `.gitignore` names outright (it has no suffix the generic patterns catch).
  Its `.pub` is tracked and is what `iso.nix` reads through `inputs.self`; a clean clone must build the ISO.
- `iso.nix` keeps the host and aspect name `bootstrap`: `nix-builders.nix` excludes it by that name and the recipes address it by that name.
  `root` on the ISO must stay a POSIX shell; the comment in the file says why.

## mikrotik/

- Every password and the optional `host-key` come from `secrets/hosts/<dc>-<relay>.sops.yaml` and nowhere else.
  That file also seeds the `terraform` user, so `wait` can never present a password the device was not given; the duplicate `terraform-password` under `secrets/<dc>.sops.yaml` is not read here.
- Role and trunk ports come from `topology.yaml` (`.network.<dc>-<relay>`); the management IP is `10.42.0.<relay counter>`.
- The admin public key is `RBN_ADMIN_PUBKEY`, default `~/.ssh/id_ed25519.pub`.
  It cannot live beside the justfile because `*.pub` is gitignored there.
- The SSH-host-key import block in `rbn-bootstrap.rsc` is disabled while a bootstrap timeout on relay02 is investigated; `upload` still stages `/relay-host.pem` so re-enabling it is a one-line change in the script.
- `wait` validates TLS against the holonet cert through the devshell's `SSL_CERT_FILE` bundle and resolves the hostname to the management IP itself.

## kubernetes/ and talos/: the k3s/Talos seam

- `cilium.yaml` and `flux-operator.yaml` are k3s `HelmChart` CRs: k3s's helm-controller pulls the charts at runtime.
  `cilium-values.yaml`, `flux-instance.yaml`, and `flux-agekey.yaml` are distro-neutral.
- A Talos consumer supplies `cluster.inlineManifests` from rendered Helm output or a Flux `HelmRelease` instead of the `HelmChart` CRs.
  That is the point at which a `k3s/` vs `talos/` split under `kubernetes/` earns its cost; do not split speculatively before a consumer exists.
- `flux-instance.yaml` carries the sync path `kubernetes/clusters/<dc-domain>/flux`; k3s re-applies it from the node's generation, so it must be edited here, never patched live.
- `talos/machineconfig.yaml` is the non-secret half; the cluster PKI merges from sops at activation and never enters the store.
  Its `machine.install.image` pin is what `just k8s update-schemas` reads to choose the vendored Talos schema.
- Schema validation and vendoring for both trees are described in `modules/services/kubernetes/AGENTS.md`.
