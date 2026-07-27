# _lib/ — `lib.rbn` helpers

`_`-prefixed: skipped by flake-level auto-discovery; `defaults.nix` imports
this directory explicitly. Each file is a function
`{ lib, inputs }: { _rbn-lib = { … }; }` — contributions merge into `lib.rbn`
by **extending nixpkgs.lib** (`lib.extend`), because a lib extension
propagates everywhere `nixosSystem`'s `lib` reaches — including den aspect
inner functions — which specialArgs / `_module.args` cannot do. That's the
whole reason this mechanism exists; don't convert it to specialArgs.

Files by concern: `attrs.nix` (attrset utilities, `enabled`, `merge-deep`),
`fs.nix` (filesystem helpers), `mesh.nix` (`with-consul`,
`mk-traefik-service`, `mk-healthcheck`), `options.nix`, `sops.nix`
(`get-secret`, `get-secret'`).

Helpers must be pure functions. Add a new concern as a new file — it is
auto-collected; name helpers kebab-case.
