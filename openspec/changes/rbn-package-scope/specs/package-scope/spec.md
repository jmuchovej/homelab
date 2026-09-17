## Purpose

Defines how repo-local packages are laid out, discovered, named, and exposed to every host as the `pkgs.rbn` scope, so aspects can consume them the same way on NixOS and nix-darwin.

## ADDED Requirements

### Requirement: Package tree layout

The repository SHALL keep repo-local packages under a root-level `packages/` tree. Application packages SHALL live at `packages/by-name/<shard>/<name>/package.nix`, where `<shard>` is the lowercase two-letter prefix of `<name>` (the nixpkgs `by-name` convention) and `package.nix` is a function suitable for `callPackage` that returns a derivation. Fonts SHALL live at `packages/fonts/<name>/package.nix` with their font files under `packages/fonts/<name>/_files/`. Any other file beside a `package.nix` is private to that package. The tree SHALL be tracked in version control; an untracked path is invisible to the flake.

#### Scenario: Application package is discovered by name

- **WHEN** `packages/by-name/jj/jj-hooks/package.nix` exists and is tracked
- **THEN** `pkgs.rbn.jj-hooks` evaluates to the derivation it returns

#### Scenario: Shard directory is not part of the attribute path

- **WHEN** the tree is discovered
- **THEN** `pkgs.rbn` has no attribute named after a shard such as `jj` or `pl`

#### Scenario: Helper files beside a package are not packages

- **WHEN** `packages/by-name/or/orca-slicer/` contains `darwin.nix` and `linux.nix` beside `package.nix`
- **THEN** `pkgs.rbn` contains `orca-slicer` and no attribute named `darwin` or `linux`

#### Scenario: Untracked package is not discovered

- **WHEN** a `package.nix` exists on disk under `packages/` but is not tracked by the VCS
- **THEN** it does not appear in `pkgs.rbn`

### Requirement: Underscore-prefixed paths are skipped

Discovery SHALL ignore any `package.nix` whose path under `packages/` contains a segment beginning with `_`. This is how unfinished packages are parked without being evaluated.

#### Scenario: Stub package is parked

- **WHEN** `packages/by-name/af/_affinity/package.nix` exists with a body of `{ }`
- **THEN** `pkgs.rbn ? affinity` is `false` and forcing every attribute of `pkgs.rbn` does not throw

### Requirement: Packages form the `pkgs.rbn` fixed-point scope

The overlay SHALL expose discovered application packages as `pkgs.rbn`, a scope in which a package's function arguments resolve first against sibling packages in `pkgs.rbn` and then against the top-level nixpkgs package set. The scope SHALL support `.override` on each package and `overrideScope` on the scope. A package file SHALL therefore be usable unchanged in a nixpkgs `by-name` tree.

#### Scenario: Sibling resolves before nixpkgs

- **WHEN** a package declares an argument whose name matches both a sibling in `pkgs.rbn` and a nixpkgs attribute
- **THEN** it receives the sibling

#### Scenario: nixpkgs resolves when no sibling matches

- **WHEN** a package declares `rustPlatform` or `stdenv` as an argument
- **THEN** it receives the nixpkgs attribute of that name

#### Scenario: Scope-level override

- **WHEN** `pkgs.rbn.overrideScope (final: prev: { jj-hooks = prev.jj-hooks.overrideAttrs (_: { doCheck = true; }); })` is evaluated
- **THEN** every package in the returned scope that depends on `jj-hooks` sees the overridden derivation

### Requirement: Fonts form the nested `pkgs.rbn.fonts` scope

Discovered fonts SHALL be exposed as `pkgs.rbn.fonts`, a scope nested in `pkgs.rbn` whose arguments resolve first against sibling fonts, then against `pkgs.rbn`, then against nixpkgs.

#### Scenario: Font is discovered under the fonts namespace

- **WHEN** `packages/fonts/monolisa/package.nix` exists and is tracked
- **THEN** `pkgs.rbn.fonts.monolisa` evaluates to a derivation whose output contains the font files under `share/fonts/`

#### Scenario: Font resolves nixpkgs and rbn arguments

- **WHEN** a font declares `stdenv` and a name from `pkgs.rbn` as arguments
- **THEN** both resolve without the font naming `pkgs` or `rbn` explicitly

### Requirement: Top-level nixpkgs attributes are not replaced

The overlay SHALL add exactly one top-level attribute, `rbn`, and SHALL NOT define or override any other top-level attribute of the package set.

#### Scenario: Colliding name outside the scope

- **WHEN** `packages/by-name/be/beeper/package.nix` exists and nixpkgs also defines `beeper`
- **THEN** `pkgs.beeper` is the nixpkgs derivation and `pkgs.rbn.beeper` is the repo-local one

### Requirement: Scope is available on every host and exported

The `rbn` overlay SHALL be applied to the package set of every NixOS and nix-darwin host the flake defines, and SHALL be exported as `flake.overlays.rbn` for consumers outside this repository. The former `pkgs.contrib` namespace and `flake.overlays.contrib` SHALL NOT exist.

#### Scenario: Darwin host sees the scope

- **WHEN** the `da-n1x` configuration is evaluated
- **THEN** `pkgs.rbn.fonts.monolisa` is a derivation for `aarch64-darwin`

#### Scenario: NixOS host sees the scope

- **WHEN** a NixOS host configuration is evaluated
- **THEN** `pkgs.rbn.jj-hooks` is a derivation for that host's system

#### Scenario: External flake applies the overlay

- **WHEN** another flake imports nixpkgs with `overlays = [ homelab.overlays.rbn ]`
- **THEN** `pkgs.rbn` and `pkgs.rbn.fonts` are populated from this repository's `packages/` tree

#### Scenario: contrib is gone

- **WHEN** any host package set is evaluated
- **THEN** `pkgs ? contrib` is `false` and the flake has no `overlays.contrib` output

### Requirement: Repo-local fonts are installed on every host class

The fonts aspect SHALL install every derivation in `pkgs.rbn.fonts` on NixOS via `fonts.packages` and on nix-darwin via `fonts.packages`, and SHALL NOT reference font package files by path.

#### Scenario: NixOS installs repo-local fonts

- **WHEN** a NixOS host including the fonts aspect is built
- **THEN** its font directory contains Brandon Text, MonoLisa, and Albert Sans

#### Scenario: Darwin installs repo-local fonts

- **WHEN** `da-n1x` is switched
- **THEN** `/Library/Fonts/Nix Fonts` contains the Brandon Text, MonoLisa, and Albert Sans files

#### Scenario: Scope helpers are not installed as fonts

- **WHEN** the fonts aspect collects `pkgs.rbn.fonts`
- **THEN** only derivations are passed to `fonts.packages`; scope helpers such as `callPackage`, `newScope`, and `overrideScope` are excluded
