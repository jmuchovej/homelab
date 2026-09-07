---
paths:
  - "secrets/**"
  - "src/modules/**"
---

# secrets/ — all sops material, one tree

Every secret in the repo lives here and is reached through sops; nothing
under `src/` holds encrypted material of its own (`src/terraform/secrets` is a
symlink back to this directory).

Layout: `hosts/<hostname>.sops.yaml` (per-host; `minimal.sops.yaml` for
bootstrap), `users/<username>.sops.yaml` (per-user), domain files
(`da.sops.yaml`, `en.sops.yaml`, `authentik.sops.yaml`, `secrets.sops.yaml`),
plus repo-level material: `certificates/` (CA), `keys/` (public identities,
tracked deliberately — see `.gitignore`), `topology.sops.yaml`,
`syncthing.sops.yaml`.

`src/modules/secrets.nix` wires sops-nix into all three classes via
`den.default`:
`defaultSopsFile` is `hosts/${host.name}.sops.yaml` for nixos/darwin and
`users/${user.userName}.sops.yaml` for homeManager.

Key facts:

- **Age identities derive from SSH ed25519 keys** (`sshKeyPaths`), NOT a
  standalone `age.keyFile` — `keyFile` is intentionally unset in all three
  classes; pinning it to a maybe-absent path makes sops-install-secrets bail
  before the SSH-derived key is tried. Host: `/etc/ssh/ssh_host_ed25519_key`;
  user: `~/.ssh/id_ed25519`.
- Aspects consume secrets via `lib.rbn.get-secret'`/`get-secret` (which
  declare the secret) and compose env files with `sops.templates` +
  `sops.placeholder` — see `services/AGENTS.md`.
- Recipient/key management (`.sops.yaml` rules, rotation): re-encrypt with
  `sops updatekeys` after changing recipients. Recipe helpers live in
  `secrets/justfile` (`just --list secrets`).
