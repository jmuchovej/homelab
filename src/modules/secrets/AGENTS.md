# secrets/ — sops material for modules

Layout: `hosts/<hostname>.sops.yaml` (per-host; `minimal.sops.yaml` for
bootstrap), `users/<username>.sops.yaml` (per-user), plus domain files
(`da.sops.yaml`, `en.sops.yaml`, `authentik.sops.yaml`, `secrets.sops.yaml`).
`secrets.nix` wires sops-nix into all three classes via `den.default`:
`defaultSopsFile` is `hosts/${host.name}.sops.yaml` for nixos/darwin and
`users/${host.primary-user.name}.sops.yaml` for homeManager.

Key facts:

- **Age identities derive from SSH ed25519 keys** (`sshKeyPaths`), NOT a
  standalone `age.keyFile` — `keyFile` is intentionally unset in all three
  classes; pinning it to a maybe-absent path makes sops-install-secrets bail
  before the SSH-derived key is tried. Host: `/etc/ssh/ssh_host_ed25519_key`;
  user: `~/.ssh/id_ed25519`.
- Aspects consume secrets via `lib.rbn.get-secret'`/`get-secret` (which
  declare the secret) and compose env files with `sops.templates` +
  `sops.placeholder` — see `services/AGENTS.md`.
- Recipient/key management (`.sops.yaml` rules, rotation) is handled by the
  repo's managing-secrets workflow — re-encrypt with `sops updatekeys` after
  changing recipients.

Repo-level (non-module) secrets — CA material, terraform, k8s seeds — live in
the top-level `secrets/` directory, which `src/terraform/secrets` symlinks.
