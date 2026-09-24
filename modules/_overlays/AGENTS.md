---
paths:
  - "modules/_overlays/**"
  - "packages/**"
---

# _overlays/ — package overlays and the `packages/` scope

`_`-prefixed: skipped by flake-level auto-discovery; `overlays.nix` (one level
up) discovers `*.nix` here explicitly and applies them **globally** through
`den.default` for nixos, darwin, and home-manager. This is an invariant, not
a convenience: per-aspect `nixpkgs.overlays` causes infinite recursion — never
wire an overlay anywhere but here.

Home-manager needs its own wiring because a standalone home (`den.homes.*`)
re-imports nixpkgs from `pkgs.path` using the `nixpkgs.overlays` option, so
overlays on the `pkgs` den hands it are discarded. On hosts
(`useGlobalPkgs = true`) home-manager shares the host's package set and its
`nixpkgs.overlays` is a stub that warns if merely defined. `overlays.nix`
therefore sets the list in the `hm` class only when `options.nixpkgs ? system`,
which the live home-manager nixpkgs module declares and the stub does not.

Each file is either a raw overlay (`final: prev: { … }`) or
`{ inputs }: final: prev: { … }` when it needs flake inputs (see
`nixpkgs-unstable.nix`, `lix.nix`, `vscode-extensions.nix`, `rbn.nix`).

## Overlay vs package

- **Overlay (a file here)**: overriding/patching an existing nixpkgs package,
  or changing its build flags.
- **Package (repo-root `packages/`)**: a novel `callPackage`-shaped
  derivation, exposed by `rbn.nix` as `pkgs.rbn.*` (below).
- **Repo-specific derivation (`_packages/`)**: not a package, wired
  explicitly by its one consumer — see `_packages/AGENTS.md`.

## `packages/` → `pkgs.rbn`

`rbn.nix` turns the repo-root `packages/` tree into one fixed-point scope,
also exported as `flake.overlays.rbn` for consumers outside this repo:

| On disk                                    | Attribute               |
| ------------------------------------------ | ----------------------- |
| `packages/by-name/<xx>/<name>/package.nix` | `pkgs.rbn.<name>`       |
| `packages/fonts/<name>/package.nix`        | `pkgs.rbn.fonts.<name>` |

- **Discovery is `package.nix`-only**, at any depth. The attribute name is
  the package's own directory; the two-letter shard (`by-name/<xx>/`) is the
  nixpkgs convention carried for portability and never appears in the
  attribute path. Any other file beside `package.nix` (`darwin.nix`,
  `patches/`, `_files/`) is private to that package.
- **`_` parks a package.** A directory whose name starts with `_` is invisible
  to discovery. Unfinished builders live there (`_affinity`, `_notion-app`,
  `fonts/_albert-sans`). A `package.nix` that is not a function returning a
  derivation _must_ be parked, or full-scope evaluation (`nix search`, the
  fonts aspect) throws.
- **Duplicate names throw** at evaluation, naming both paths. nixpkgs relies
  on CI for this; we have none.
- **Resolution order.** `pkgs.rbn` is `lib.makeScope` over `final.newScope`:
  a `package.nix` argument resolves against sibling packages first, then
  nixpkgs. `{ jj-hooks, rustPlatform }:` gets `pkgs.rbn.jj-hooks` and
  `pkgs.rustPlatform`, and a file written this way moves to a nixpkgs
  `by-name` tree or a NUR repo unchanged. `pkgs.rbn.fonts` is a nested scope
  over `rbn.newScope`: fonts, then rbn, then nixpkgs.
- **Shadowing is local.** Inside the scope, a sibling named like a nixpkgs
  attribute (`beeper`, `zulip`, `anytype`, `plexamp`, `orca-slicer`) wins.
  Outside it nothing changes: `pkgs.beeper` is still nixpkgs', and the
  overlay adds exactly one top-level attribute, `rbn`.
- **Consuming a scope**: filter with `lib.isDerivation` before handing values
  to a package list. `makeScope` adds `callPackage`, `newScope`,
  `overrideScope`, `packages`, and `recurseForDerivations` alongside the
  derivations (`system/fonts/fonts.nix` shows the idiom).
- **Paths come from `inputs.self`**, so the scope reads the flake's store copy
  of the tree. An untracked file is invisible: `jj file track` new packages
  and font files (`snapshot.auto-track` is off in this repo).
- **Fonts** keep their binaries under `packages/fonts/<name>/_files/` with
  `src = ./_files;`. Several are licensed for this repo only, which is why
  fonts are not `by-name`-shaped: they are not upstream-bound.
- **Unfree** packages in the scope go through `den.batteries.unfree
[ "<pname>" ]` like any other when an aspect consumes them.
