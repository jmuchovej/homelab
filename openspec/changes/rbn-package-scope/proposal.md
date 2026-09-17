## Why

The repo has three disconnected attempts at "my own packages": an untracked `packages/` tree at the root (24 app directories in the nixpkgs `by-name` shard layout plus three fonts) that the flake cannot see, a `contrib` overlay in `overlays.nix` that reads a directory which does not exist and silently yields an empty `pkgs.contrib`, and three fonts hand-wired with `callPackage` inside the NixOS branch of `system/fonts/fonts.nix`, so the MacBook gets none of them. One discovery mechanism producing `pkgs.rbn.*` on both NixOS and nix-darwin, with fonts under `pkgs.rbn.fonts.*`, replaces all three. Doing it directly after `flatten-src-tree` means every path it introduces is written once, against the flattened layout.

## What Changes

- Add an overlay `modules/_overlays/rbn.nix` that discovers `packages/by-name/**/package.nix` with `import-tree`, names each package after its parent directory (the two-letter shard is dropped), and wires the set as a `lib.makeScope` fixed point at `pkgs.rbn`. Inside the scope, a `package.nix` argument resolves against sibling packages first and nixpkgs second, so files stay verbatim-portable to a nixpkgs `by-name` tree.
- Add a nested scope `pkgs.rbn.fonts` built from `packages/fonts/*/package.nix` with `rbn.newScope`, so a font can depend on other fonts, on `rbn` packages, and on nixpkgs. Fonts are not intended for upstream and may carry non-redistributable binaries.
- **BREAKING** Remove the `contrib` overlay, `pkgs.contrib`, and `flake.overlays.contrib`. Export `flake.overlays.rbn` in its place. Nothing in the tree consumes `contrib` today.
- Track `packages/` in jj. The flake evaluates the git tree, so an untracked directory renders as nothing; this is the same rule the root `AGENTS.md` states for `rules/`.
- Consolidate fonts: the canonical location becomes `packages/fonts/<name>/package.nix` with the font files under `packages/fonts/<name>/_files/`. Delete the copies under `modules/system/fonts/_packages/` and the flat `packages/fonts/<name>.nix` + `<name>/` pairs. `system/fonts/fonts.nix` consumes `pkgs.rbn.fonts.*` in both its `nixos` and `macos` branches (`fonts.packages` exists on both).
- Underscore-prefix the fifteen stub package directories: fourteen whose `package.nix` is a bare `{ }` (`_affinity`, `_brave-browser`, and so on) and `no-tunes`, whose function body returns `{ }` instead of a derivation. Nine real packages remain: `anytype`, `beeper`, `jj-hooks`, `notion-app`, `notion-calendar`, `orca-slicer`, `plex-desktop`, `plexamp`, `zulip`. `import-tree` skips any path containing `/_`, so they stay parked without breaking `nix search` or `nix flake show`.
- Rewrite `modules/_overlays/AGENTS.md` and `modules/_overlays/_packages/AGENTS.md`, which document the `contrib` mechanism being removed, to describe the `rbn` scope and the `packages/` tree contract.

## Capabilities

### New Capabilities

- `package-scope`: the contract for repo-local packages. Where they live (`packages/by-name/<shard>/<name>/package.nix`, `packages/fonts/<name>/package.nix`), how they are discovered and named, that they are exposed as the fixed-point scope `pkgs.rbn` with `pkgs.rbn.fonts` nested inside it, the argument resolution order inside each scope, the underscore skip rule, and that the overlay applies to every NixOS and nix-darwin host and is exported as `flake.overlays.rbn`.

### Modified Capabilities

- None. `openspec/specs/` is empty. The `repo-layout` capability from the in-flight `flatten-src-tree` change lists the root trees; `packages/` is declared here rather than as a delta to a spec that has not been archived yet.

## Impact

- **Sequencing**: assumes `flatten-src-tree` has landed. Every path in this change is post-flatten (`modules/…`, not `src/modules/…`). If it is applied first, the overlay file and the relative path to `packages/` need one extra `..` hop and the `AGENTS.md` paths differ.
- **Nix evaluation, all hosts**: the overlay is applied through `den.default` for both `nixos` and `darwin`, as the existing `_overlays/AGENTS.md` invariant requires. `pkgs.rbn` is lazy, so hosts that reference nothing under it see no closure change. Every host does include `<rbn/system/fonts>` through `suite/common`, and the font derivations' `src` path changes (`./_files` instead of `./<name>`), so `toplevel.drvPath` changes on every host. That is a rebuild of three trivial font derivations, not a behavioural change.
- **nix-darwin (`da-n1x`)**: the three fonts are newly installed into `/Library/Fonts/Nix Fonts`. Today darwin only gets Homebrew cask fonts.
- **Shadowing inside the scope**: `beeper`, `zulip`, `anytype`, `plexamp`, `orca-slicer`, and several stubs share names with nixpkgs attributes. Inside `pkgs.rbn`, a sibling wins over nixpkgs. Outside it, `pkgs.beeper` and friends stay nixpkgs; this change does not replace any top-level attribute. The `den.batteries.unfree [ "beeper" ]` in `programs/social.nix` keeps pointing at nixpkgs.
- **Unfree packages**: `plex-desktop`, `plexamp`, and others declare `lib.licenses.unfree`. Nothing consumes them yet. When something does, it needs the usual `den.batteries.unfree [ "<pname>" ]`.
- **Licensed fonts in a public repo**: `jmuchovej/homelab` is public and the Brandon Text and MonoLisa binaries are already tracked under `modules/system/fonts/_packages/`. This change moves them, it does not change their exposure. Fixing that (private input, sops, or a fetch-from-private-URL) is a separate decision.
- **Untracked duplicates in the main checkout**: `packages/` and `modules/system/fonts/_packages/albert-sans*` exist only in the main checkout as untracked files. The move and consolidation happen there, not in a worktree, or the worktree must first receive the tree.
- **Not touched**: `_overlays/_packages/installer.nix` (repo-specific, consumed explicitly, stays where it is), the Homebrew cask font list on darwin, the nixpkgs font list on NixOS, `nixpkgs-unstable.nix`, `lix.nix`, `vscode-extensions.nix`.
