# _packages/ — custom derivations

Not auto-discovered (double `_`-shield); wired by `../../overlays.nix`.

- **`contrib/`** — upstream-bound packages: nixpkgs-compatible
  `callPackage`-style derivations with **no den/rebellion dependencies**.
  Collected via `packagesFromDirectoryRecursive` into `pkgs.contrib.*`
  (nested dirs become nested attrs: `contrib/fonts/foo.nix` →
  `pkgs.contrib.fonts.foo`). Also exported as `flake.overlays.contrib`.
  Keep these clean enough to PR to nixpkgs unchanged.
- **Repo-specific derivations** (e.g. `installer.nix`) sit beside `contrib/`
  and are consumed by whatever wires them explicitly.

Create a package here only for novel derivations; to modify an existing
nixpkgs package, write an overlay in `../` instead (see `../AGENTS.md`).
