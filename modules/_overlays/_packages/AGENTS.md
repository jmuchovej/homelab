---
paths:
  - "modules/_overlays/_packages/**"
---

# _packages/ — repo-specific derivations

Not auto-discovered (double `_`-shield) and not part of any scope: each file
here is imported explicitly by the one consumer that needs it (e.g.
`installer.nix`). These are derivations that only make sense inside this
repo and may depend on den, host, or secrets wiring.

A novel `callPackage`-shaped package belongs in the repo-root `packages/`
tree instead, where `rbn.nix` exposes it as `pkgs.rbn.<name>` (fonts:
`pkgs.rbn.fonts.<name>`). To modify an existing nixpkgs package, write an
overlay in the parent directory. Both are described in the parent
directory's `AGENTS.md`.
