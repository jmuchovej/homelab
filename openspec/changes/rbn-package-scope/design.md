## Context

See proposal.md for motivation. The facts that shape the approach:

- `modules/overlays.nix` discovers `_overlays/*.nix` with `import-tree`, accepts each file either as a raw overlay or as `{ inputs }: final: prev: …`, and applies the list globally through `den.default` for `nixos` and `darwin`. `_overlays/AGENTS.md` records that per-aspect `nixpkgs.overlays` causes infinite recursion, so this is the only place an overlay may be wired. The `contrib` block in `overlays.nix` is the only thing that does not follow the file-per-overlay pattern.
- `import-tree` (locked `denful/import-tree@eb1b52e`) produces a flat list of file paths. Its default filter keeps `*.nix` and drops any path containing `/_`. `.filter` receives the path relative to the root, `.map` receives the absolute path. It has no notion of directory nesting.
- `lib.filesystem.packagesFromDirectoryRecursive` at the locked nixpkgs (`bd3bac8`) has no shard awareness (`by-name/jj/jj-hooks` would become `rbn.jj.jj-hooks`) and processes `_`-prefixed directories like any other.
- `lib.makeScope newScope f` builds `self = f self` and adds `callPackage`, `newScope`, `overrideScope`, `packages`, and `recurseForDerivations` (via `recurseIntoAttrs`). With `newScope = final.newScope`, the scope's `callPackage` is `callPackageWith (final // self)`, so siblings shadow nixpkgs. A nested scope built with `rbn.newScope` resolves as `final // rbn // nested`.
- nixpkgs' own `pkgs/top-level/by-name-overlay.nix` does the same two jobs with `readDir` at a fixed depth of two: map `name → package.nix`, then `self.callPackage` on each. Its fixed point is `pkgs` itself; ours is `rbn`.
- The main checkout has `snapshot.auto-track = none()`, so `packages/` is untracked and invisible to the flake. `modules/system/fonts/_packages/` is tracked (44 files, Brandon Text and MonoLisa binaries included); `albert-sans` there is untracked. `packages/fonts/` duplicates the same three fonts in the flat `<name>.nix` + `<name>/` layout.
- Of the 24 application directories, 9 hold real derivations (`anytype`, `beeper`, `jj-hooks`, `notion-app`, `notion-calendar`, `orca-slicer`, `plex-desktop`, `plexamp`, `zulip`) and 15 are stubs: 14 files that are a bare `{ }` and `no-tunes`, whose function returns `{ }`. No real package currently depends on a sibling. `orca-slicer` keeps `darwin.nix`, `linux.nix`, `patches/`, and `NOTES.md` beside its `package.nix`.
- `system/fonts/fonts.nix` has a `nixos` module function that `callPackage`s the three fonts by path, and a `macos` attribute set with Homebrew casks only. nix-darwin exposes `fonts.packages`, installing into `/Library/Fonts/Nix Fonts`.
- Every host includes `<rbn/system/fonts>` through `suite/common`, so any change to the font derivations changes every host's `toplevel.drvPath`.
- A store path name may begin with `_` (verified: `builtins.path { name = "_files"; … }` evaluates).
- The repo's `pre-tool-use` hook denies any Write or Edit whose content contains a literal parent-directory path segment. Planning artifacts therefore describe relative paths in words; the overlay file itself is written by the apply phase with the real path.

## Goals / Non-Goals

**Goals:**

- One overlay file, discovered like the others, that turns the tracked `packages/` tree into `pkgs.rbn` with `pkgs.rbn.fonts` nested inside.
- Package files that need no edit to move to a nixpkgs `by-name` tree or a NUR repository: `callPackage`-style, bare-name sibling dependencies, shard layout on disk.
- Fonts consumed by the fonts aspect on both host classes from the scope, never by file path.

**Non-Goals:**

- Exposing `packages.<system>` or `legacyPackages` flake outputs for `nix build .#foo`. Consumption is through host configuration; a flake-output projection of the scope is a separate change.
- Finishing any stub package, or wiring any application package into an aspect.
- Replacing top-level nixpkgs attributes with repo-local versions.
- Resolving the licensed-fonts-in-a-public-repo exposure.
- Validating the shard convention (`by-name/<xx>/<xx…>`). nixpkgs-vet does that upstream; here the shard is carried for portability and discovery ignores it.

## Decisions

### D1. Discover with `import-tree`, not `packagesFromDirectoryRecursive`

`import-tree` filtered to `/package.nix` and mapped to `baseNameOf (dirOf path)` gives `name → file` regardless of depth, which strips the shard for free and honours the repo-wide `_` skip convention. `packagesFromDirectoryRecursive` would need the shard layout flattened on disk, would not skip `_` directories, and offers nothing else we use once the scope is built by hand. Alternative rejected: a bespoke two-level `readDir` like nixpkgs' `by-name-overlay.nix`; it hardcodes depth and reimplements the `_` filter.

### D2. `pkgs.rbn` is a `makeScope` fixed point over `final.newScope`

Bare-name sibling dependencies are the property that keeps `package.nix` files verbatim-portable. Alternatives: (a) plain `final.callPackage` with `{ rbn }:` arguments works but ties every file to this repo's namespace; (b) merging packages into the top level would replace nixpkgs attributes (`beeper`, `zulip`, `anytype`, `plexamp`, `orca-slicer`) and change what existing aspects install. `recurseIntoAttrs` (implied by `makeScope`) lets `nix search`/`nix-env -qa` descend into the scope when the overlay is used externally.

### D3. `pkgs.rbn.fonts` is a nested scope built with `rbn.newScope`

A font's arguments then resolve fonts → rbn → nixpkgs, which answers "can sub-scoped packages reference upstream" with yes and lets a future Nerd-Fonts-patched variant depend on a sibling font or on `rbn` tooling. Discovery root is `packages/fonts` with the same `package.nix` filter and parent-directory naming. Fonts are deliberately not `by-name`-shaped: they are not upstream-bound, and several are not redistributable.

### D4. Two explicit discovery roots, one helper

A local function `scopeFrom root newScope` runs the pipeline and builds a scope. It is called twice: `by-name` with `final.newScope`, `fonts` with `rbn.newScope`. A generic "every top-level directory becomes a sub-scope" rule was considered and rejected: two calls are clearer than a convention nobody else uses yet, and adding a third namespace later is one line.

### D5. Duplicate names fail loudly

`listToAttrs` is last-wins, so two shards each holding `foo/package.nix` would silently drop one. nixpkgs relies on CI for this; we have none. The helper groups by name before building the attribute set and throws naming both paths on collision. Three lines, prevents the one silent failure mode of the layout.

### D6. Overlay lives at `modules/_overlays/rbn.nix` in the `{ inputs }:` form

It needs `inputs.import-tree`, which the existing discovery already passes. `overlays.nix` loses the `contrib` block and gains `flake.overlays.rbn = import ./_overlays/rbn.nix { inherit inputs; };`, so the exported overlay is the same function the hosts use. From the overlay file, `packages/` is two parent-directory hops up (`modules/_overlays/` to `modules/` to the repo root) in the post-flatten layout.

### D7. Font files live under `_files/`, package is `src = ./_files`

Keeps `package.nix` itself out of the font derivation's source and, being `_`-prefixed, is skipped by any future `import-tree` walk that widens its filter. The install step is unchanged: copy into `share/fonts/truetype/`.

### D8. Fonts aspect filters the scope with `lib.isDerivation`

`makeScope` adds non-derivation helpers to the set. `lib.attrValues pkgs.rbn.fonts` would pass `callPackage`, `newScope`, `overrideScope`, `packages`, and `recurseForDerivations` to `fonts.packages` and fail type checking. `lib.filter lib.isDerivation (lib.attrValues pkgs.rbn.fonts)` is the consumption idiom, used identically in the `nixos` and `macos` branches. The `macos` branch becomes a module function to receive `pkgs`.

### D9. Stubs are parked by renaming their directory with a `_` prefix

Matches the repo's existing convention and the user's stated preference. Deleting them loses the intent-to-package list; leaving them breaks any full evaluation of the scope.

### D10. Existing `AGENTS.md` files are rewritten, no new rule

`_overlays/AGENTS.md` and `_overlays/_packages/AGENTS.md` document `contrib`, which is being removed. The durable constraints (only-wire-overlays-here, `package.nix`-only discovery, `_` parking, resolution order, fonts filter idiom) go into those two existing files. The root `AGENTS.md` policy says not to create a rule just to hold lifted context; `packages/` gets no rule of its own until a sweep shows it needs one.

## Risks / Trade-offs

- [Sibling shadowing is silent] A package in the scope that asks for `zulip` gets `rbn.zulip`, not nixpkgs'. → Intended and documented in `_overlays/AGENTS.md`; the spec scenario "Sibling resolves before nixpkgs" pins it.
- [`packages/` untracked in the main checkout] The flake would evaluate `rbn = { }` with no error. → Tracking is an explicit task, and the verification step asserts `attrNames pkgs.rbn` contains the 9 expected names.
- [Every host's `drvPath` changes] Font `src` paths move. → Accepted; the diff is three font derivations. Verification inspects `nix derivation show` on one font rather than comparing whole-host `drvPath`.
- [Unfree packages block full-scope forcing] `plex-desktop` and `plexamp` are `unfree`; forcing their `drvPath` under a host's package set throws unless allowed. → The "every attribute evaluates" check forces `.name`, which does not trigger the unfree check, and builds only free packages and fonts.
- [Darwin gets `.woff2` files copied into `/Library/Fonts/Nix Fonts`] macOS ignores them. → Harmless; trimming to `.otf`/`.ttf` in the install step is a later cleanup if the clutter bothers.
- [Font binaries stay in a public repo] Pre-existing. → Called out in the proposal; not addressed here.
- [Applying before `flatten-src-tree`] Paths in this design are post-flatten. → Tasks state the assumption up front; the only deltas if reordered are one extra parent-directory hop in the overlay path and `src/modules/…` in the `AGENTS.md` paths.
- [`makeScope` helpers appear in tab completion and `nix repl`] Cosmetic. → Accepted; nixpkgs package sets have the same shape.

## Migration Plan

1. Land in a worktree after `flatten-src-tree`; all steps are pure Nix and file moves, no cluster or state impact.
2. The worktree receives a copy of the main checkout's untracked `packages/` and `albert-sans` files, and tracks them; the main checkout's untracked copies are removed after the change lands so the tracked tree is the only one.
3. Gate: `nix flake check`, `nix eval` of `attrNames pkgs.rbn` and `pkgs.rbn.fonts` on an x86_64-linux host and on `da-n1x`, `nix build` of the three fonts and `jj-hooks` for both systems, a build of the `da-n1x` system closure.
4. Switch `da-n1x` first (fonts newly appear in `/Library/Fonts/Nix Fonts`); NixOS hosts on their next routine rebuild.
5. Rollback: revert the commit. No external state changes; `da-n1x` loses the three fonts from `Nix Fonts` on the next switch.

## Open Questions

- Whether to project `pkgs.rbn` into `packages.<system>` flake outputs so `nix build .#jj-hooks` works from the repo. Deferred; does not affect this change's specs or tasks.
