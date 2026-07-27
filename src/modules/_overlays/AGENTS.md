# _overlays/ — package overlays

`_`-prefixed: skipped by flake-level auto-discovery; `overlays.nix` (one level
up) discovers `*.nix` here explicitly and applies them **globally** through
`den.default` for both nixos and darwin. This is an invariant, not a
convenience: per-aspect `nixpkgs.overlays` causes infinite recursion — never
wire an overlay anywhere but here.

Each file is either a raw overlay (`final: prev: { … }`) or
`{ inputs }: final: prev: { … }` when it needs flake inputs (see
`nixpkgs-unstable.nix`, `lix.nix`, `vscode-extensions.nix`).

## Overlay vs package

- **Overlay (a file here)**: overriding/patching an existing nixpkgs package,
  or changing its build flags.
- **Package (`_packages/`)**: a novel derivation → see
  `_packages/AGENTS.md`; upstream-clean ones land in `pkgs.contrib.*`.
